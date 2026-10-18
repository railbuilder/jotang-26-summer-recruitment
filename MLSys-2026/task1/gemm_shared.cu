#include <cuda_runtime.h>
#include <cublas_v2.h>
#include <algorithm>
#include <random>
#include <vector>
#include <cstdio>
#include <cmath>
#include <string>

#define CUDA_CHECK(call)                                                       \
    do {                                                                       \
        cudaError_t err = (call);                                              \
        if (err != cudaSuccess) {                                              \
            fprintf(stderr, "CUDA error %s at %s:%d\n",                        \
                    cudaGetErrorString(err), __FILE__, __LINE__);              \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

#define CUBLAS_CHECK(call)                                                     \
    do {                                                                       \
        cublasStatus_t st = (call);                                            \
        if (st != CUBLAS_STATUS_SUCCESS) {                                     \
            fprintf(stderr, "cuBLAS error %d at %s:%d\n", (int)st,             \
                    __FILE__, __LINE__);                                       \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

// ============ 1.4 Shared Memory Tiling：一个 block 负责 C 的一个 TILE×TILE 块 ============
// 对每个 k 段：协作把 A 的 TILE×TILE 小片和 B 的 TILE×TILE 小片搬进 Shared Memory，
// 之后所有线程从 Shared（班组背包）里重复读——同一份数据只从显存读一次。
template <int TILE>
__global__ void gemm_shared(const float* A, const float* B, float* C,
                            int M, int N, int K) {
    __shared__ float As[TILE][TILE];   // 本 block 需要的 A 小片
    __shared__ float Bs[TILE][TILE];   // 本 block 需要的 B 小片

    int row = blockIdx.y * TILE + threadIdx.y;   // 本 block 负责的 C 块的行
    int col = blockIdx.x * TILE + threadIdx.x;   // 本 block 负责的 C 块的列
    float sum = 0.0f;

    for (int k0 = 0; k0 < K; k0 += TILE) {       // 把 K 切成 K/TILE 段
        // ① 协作加载：TILE² 个线程一起把两个小片从显存搬进 Shared
        int ar = blockIdx.y * TILE + threadIdx.y;
        int ac = k0 + threadIdx.x;
        As[threadIdx.y][threadIdx.x] =
            (ar < M && ac < K) ? A[ar * K + ac] : 0.0f;   // 越界补 0

        int br = k0 + threadIdx.y;
        int bc = blockIdx.x * TILE + threadIdx.x;
        Bs[threadIdx.y][threadIdx.x] =
            (br < K && bc < N) ? B[br * N + bc] : 0.0f;

        __syncthreads();   // ② 屏障：所有线程都搬完了，才能开始读

        // ③ 计算：从这个 k 段里累加 TILE 个乘积
        for (int k = 0; k < TILE; k++)
            sum += As[threadIdx.y][k] * Bs[k][threadIdx.x];

        __syncthreads();   // ④ 屏障：所有人都用完本段，才能覆盖进下一段
    }
    if (row < M && col < N)
        C[row * N + col] = sum;
}

// ============ 统计 ============
float percentile(std::vector<float>& v, double p) {
    std::sort(v.begin(), v.end());
    int idx = (int)((v.size() - 1) * p);
    return v[idx];
}

struct Timing { float median_ms; float p95_ms; };

template <typename Launch>
Timing time_it(Launch launch, int warmup, int reps) {
    cudaEvent_t s, e;
    CUDA_CHECK(cudaEventCreate(&s));
    CUDA_CHECK(cudaEventCreate(&e));
    for (int i = 0; i < warmup; i++) launch();
    CUDA_CHECK(cudaGetLastError());
    std::vector<float> t(reps);
    for (int i = 0; i < reps; i++) {
        CUDA_CHECK(cudaEventRecord(s));
        launch();
        CUDA_CHECK(cudaEventRecord(e));
        CUDA_CHECK(cudaEventSynchronize(e));
        CUDA_CHECK(cudaEventElapsedTime(&t[i], s, e));
    }
    CUDA_CHECK(cudaEventDestroy(s));
    CUDA_CHECK(cudaEventDestroy(e));
    Timing r;
    r.median_ms = percentile(t, 0.50);
    r.p95_ms    = percentile(t, 0.95);
    return r;
}

void init_gemm_inputs(float* A, float* B, size_t nA, size_t nB) {
    std::mt19937 rng(2026);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
    for (size_t i = 0; i < nA; i++) A[i] = dist(rng);
    for (size_t i = 0; i < nB; i++) B[i] = dist(rng);
}

int main() {
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("GPU: %s\n", prop.name);

    const int shapes[][3] = {
        {2048, 2048, 2048},
        {4096, 64,  4096},
        {1,    4096, 4096},
        {32,   4096, 4096},
        {256,  4096, 4096},
        {127,  131,  129}
    };
    const int numShapes = sizeof(shapes) / sizeof(shapes[0]);
    const int tiles[] = {8, 16, 32};
    const int warmup = 3, reps = 10;

    cublasHandle_t cublas;
    CUBLAS_CHECK(cublasCreate(&cublas));
    CUBLAS_CHECK(cublasSetMathMode(cublas, CUBLAS_PEDANTIC_MATH));

    printf("\n%-22s %-6s %-10s %-12s %-12s %-12s %-10s %-9s\n",
           "shape(M,N,K)", "TILE", "correct", "median(ms)", "P95(ms)", "TFLOPS", "cuBLAS(ms)", "%ofBLAS");
    for (int i = 0; i < numShapes; i++) {
        int M = shapes[i][0], N = shapes[i][1], K = shapes[i][2];
        float *dA, *dB, *dC_t, *dC_blas;
        CUDA_CHECK(cudaMalloc((void**)&dA, (size_t)M * K * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&dB, (size_t)K * N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&dC_t,   (size_t)M * N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&dC_blas, (size_t)M * N * sizeof(float)));
        std::vector<float> hA((size_t)M * K), hB((size_t)K * N);
        init_gemm_inputs(hA.data(), hB.data(), hA.size(), hB.size());
        CUDA_CHECK(cudaMemcpy(dA, hA.data(), hA.size() * sizeof(float), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(dB, hB.data(), hB.size() * sizeof(float), cudaMemcpyHostToDevice));

        float alpha = 1.0f, beta = 0.0f;
        auto launch_blas = [&]() {
            CUBLAS_CHECK(cublasSgemm(cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                                     N, M, K, &alpha, dB, N, dA, K, &beta, dC_blas, N));
        };
        Timing tb = time_it(launch_blas, warmup, reps);

        for (int t = 0; t < 3; t++) {
            int TILE = tiles[t];
            dim3 block(TILE, TILE);
            dim3 grid((N + TILE - 1) / TILE, (M + TILE - 1) / TILE);
            Timing tn;
            if (TILE == 8) {
                auto l = [&]() { gemm_shared<8><<<grid, block>>>(dA, dB, dC_t, M, N, K); };
                tn = time_it(l, warmup, reps);
            } else if (TILE == 16) {
                auto l = [&]() { gemm_shared<16><<<grid, block>>>(dA, dB, dC_t, M, N, K); };
                tn = time_it(l, warmup, reps);
            } else {
                auto l = [&]() { gemm_shared<32><<<grid, block>>>(dA, dB, dC_t, M, N, K); };
                tn = time_it(l, warmup, reps);
            }

            std::vector<float> hC1((size_t)M * N), hC2((size_t)M * N);
            CUDA_CHECK(cudaMemcpy(hC1.data(), dC_t,   hC1.size() * sizeof(float), cudaMemcpyDeviceToHost));
            CUDA_CHECK(cudaMemcpy(hC2.data(), dC_blas, hC2.size() * sizeof(float), cudaMemcpyDeviceToHost));
            float maxerr = 0.0f;
            for (size_t j = 0; j < hC1.size(); j++) {
                float err = fabsf(hC1[j] - hC2[j]);
                if (err > maxerr) maxerr = err;
            }
            bool correct = (maxerr < 1e-2f);
            double tf = 2.0 * (double)M * N * K / (tn.median_ms / 1e3) / 1e12;
            printf("%-22s %-6d %-10s %-12.3f %-12.3f %-12.2f %-10.3f %-8.1f%%\n",
                   ("(" + std::to_string(M) + "," + std::to_string(N) + "," + std::to_string(K) + ")").c_str(),
                   TILE, correct ? "PASS" : "FAIL",
                   tn.median_ms, tn.p95_ms, tf, tb.median_ms,
                   correct ? 100.0 * tb.median_ms / tn.median_ms : 0.0);
        }
        CUDA_CHECK(cudaFree(dA));
        CUDA_CHECK(cudaFree(dB));
        CUDA_CHECK(cudaFree(dC_t));
        CUDA_CHECK(cudaFree(dC_blas));
    }
    CUBLAS_CHECK(cublasDestroy(cublas));
    return 0;
}
