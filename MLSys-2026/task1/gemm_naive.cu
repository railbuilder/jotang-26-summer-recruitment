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

// ============ 1.3 Naive GEMM：一个线程算 C 的一个元素 ============
// 行主序存储：A[row][k] 的地址 = row*K + k
__global__ void gemm_naive(const float* A, const float* B, float* C,
                           int M, int N, int K) {
    int row = blockIdx.y * blockDim.y + threadIdx.y;  // 负责 C 的第 row 行 (0..M-1)
    int col = blockIdx.x * blockDim.x + threadIdx.x;  // 负责 C 的第 col 列 (0..N-1)
    if (row < M && col < N) {
        float sum = 0.0f;
        for (int k = 0; k < K; k++)
            sum += A[row * K + k] * B[k * N + col];   // A 的 row 行 × B 的 col 列点积
        C[row * N + col] = sum;
    }
}

// ============ 统计：排序后取百分位 ============
float percentile(std::vector<float>& v, double p) {
    std::sort(v.begin(), v.end());
    int idx = (int)((v.size() - 1) * p);
    return v[idx];
}

// ============ 计时工具：跑给定 kernel 多次，返回中位数和 P95（毫秒） ============
// kernel 启动是异步的，所以用 CUDA Event 打点 + Synchronize 等 GPU 干完。
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

// ============ 初始化输入（seed=2026，uniform[-1,1]，与题目一致） ============
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

    // 题目要求的 shape 集合：(M, N, K)
    const int shapes[][3] = {
        {2048, 2048, 2048},   // 大方阵
        {4096, 64,  4096},    // 瘦矩阵（N 很小）
        {1,    4096, 4096},   // M=1
        {32,   4096, 4096},   // M=32
        {256,  4096, 4096},   // M=256
        {127,  131,  129}     // 不规则尺寸
    };
    const int numShapes = sizeof(shapes) / sizeof(shapes[0]);
    const int TILE = 16;               // 用 16×16 的 block 网格
    const int warmup = 3, reps = 10;   // 大 kernel 抖动小，次数不用太多

    cublasHandle_t cublas;
    CUBLAS_CHECK(cublasCreate(&cublas));
    // 关掉 TF32 近似，保证 cuBLAS 是"真正 FP32"的参考结果
    CUBLAS_CHECK(cublasSetMathMode(cublas, CUBLAS_PEDANTIC_MATH));

    printf("\n%-22s %-10s %-12s %-12s %-12s %-10s %-10s\n",
           "shape(M,N,K)", "correct", "median(ms)", "P95(ms)", "TFLOPS", "cuBLAS(ms)", "%ofBLAS");
    for (int i = 0; i < numShapes; i++) {
        int M = shapes[i][0], N = shapes[i][1], K = shapes[i][2];

        // 分配 + 生成数据（不计时）
        float *dA, *dB, *dC_naive, *dC_blas;
        CUDA_CHECK(cudaMalloc((void**)&dA, (size_t)M * K * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&dB, (size_t)K * N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&dC_naive, (size_t)M * N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&dC_blas,   (size_t)M * N * sizeof(float)));
        std::vector<float> hA((size_t)M * K), hB((size_t)K * N);
        init_gemm_inputs(hA.data(), hB.data(), hA.size(), hB.size());
        CUDA_CHECK(cudaMemcpy(dA, hA.data(), hA.size() * sizeof(float), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(dB, hB.data(), hB.size() * sizeof(float), cudaMemcpyHostToDevice));

        // block 网格：x 方向覆盖 N，y 方向覆盖 M
        dim3 block(TILE, TILE);
        dim3 grid((N + TILE - 1) / TILE, (M + TILE - 1) / TILE);

        // 1) naive 计时
        auto launch_naive = [&]() {
            gemm_naive<<<grid, block>>>(dA, dB, dC_naive, M, N, K);
        };
        Timing tn = time_it(launch_naive, warmup, reps);

        // 2) cuBLAS 计时（列主序等价调用：行主序 C=A×B ⇔ 列主序 Cᵀ=Bᵀ×Aᵀ）
        float alpha = 1.0f, beta = 0.0f;
        auto launch_blas = [&]() {
            CUBLAS_CHECK(cublasSgemm(cublas, CUBLAS_OP_N, CUBLAS_OP_N,
                                     N, M, K, &alpha,
                                     dB, N, dA, K, &beta, dC_blas, N));
        };
        Timing tb = time_it(launch_blas, warmup, reps);

        // 3) 正确性：naive 结果 vs cuBLAS 结果，最大绝对误差
        std::vector<float> hC1((size_t)M * N), hC2((size_t)M * N);
        CUDA_CHECK(cudaMemcpy(hC1.data(), dC_naive, hC1.size() * sizeof(float), cudaMemcpyDeviceToHost));
        CUDA_CHECK(cudaMemcpy(hC2.data(), dC_blas,   hC2.size() * sizeof(float), cudaMemcpyDeviceToHost));
        float maxerr = 0.0f;
        for (size_t j = 0; j < hC1.size(); j++) {
            float err = fabsf(hC1[j] - hC2[j]);
            if (err > maxerr) maxerr = err;
        }
        bool correct = (maxerr < 1e-2f);

        double tf = 2.0 * (double)M * N * K / (tn.median_ms / 1e3) / 1e12;
        printf("%-22s %-10s %-12.3f %-12.3f %-12.2f %-10.3f %-9.1f%%\n",
               ("(" + std::to_string(M) + "," + std::to_string(N) + "," + std::to_string(K) + ")").c_str(),
               correct ? "PASS" : "FAIL",
               tn.median_ms, tn.p95_ms, tf, tb.median_ms,
               correct ? 100.0 * tb.median_ms / tn.median_ms : 0.0);

        CUDA_CHECK(cudaFree(dA));
        CUDA_CHECK(cudaFree(dB));
        CUDA_CHECK(cudaFree(dC_naive));
        CUDA_CHECK(cudaFree(dC_blas));
    }
    CUBLAS_CHECK(cublasDestroy(cublas));
    return 0;
}
