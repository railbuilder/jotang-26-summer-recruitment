#include <cuda_runtime.h>
#include <algorithm>
#include <random>
#include <vector>
#include <cstdio>
#include <cmath>

// ============ 宏：任何 CUDA 调用出错就打印位置并退出 ============
#define CUDA_CHECK(call)                                                       \
    do {                                                                       \
        cudaError_t err = (call);                                              \
        if (err != cudaSuccess) {                                              \
            fprintf(stderr, "CUDA error %s at %s:%d\n",                        \
                    cudaGetErrorString(err), __FILE__, __LINE__);              \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

// ============ kernel：每个线程算一个元素 ============
__global__ void vec_add(const float* a, const float* b, float* c, int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i < N) {
        c[i] = a[i] + b[i];
    }
}

// ============ 统计：中位数（抗抖动） ============
float median(std::vector<float>& v) {
    std::sort(v.begin(), v.end());
    return v[v.size() / 2];
}

// ============ 测一组 (N, block) 的 kernel 耗时（返回毫秒） ============
float measure(const float* d_A, const float* d_B, float* d_C, int N, int block) {
    const int WARMUP = 10;   // 预热次数：排除第一次启动的一次性开销
    const int REPS   = 100;  // 正式计时次数：之后取中位数

    // CUDA Event = 在 GPU 时间线上打两个点，ElapsedTime 算出中间耗时
    cudaEvent_t start, stop;
    CUDA_CHECK(cudaEventCreate(&start));
    CUDA_CHECK(cudaEventCreate(&stop));

    // 预热
    for (int i = 0; i < WARMUP; i++)
        vec_add<<<(N + block - 1) / block, block>>>(d_A, d_B, d_C, N);
    CUDA_CHECK(cudaGetLastError());   // kernel 启动是异步的，错误要单独查

    // 正式计时
    std::vector<float> t(REPS);
    for (int i = 0; i < REPS; i++) {
        CUDA_CHECK(cudaEventRecord(start));              // 打点：开始
        vec_add<<<(N + block - 1) / block, block>>>(d_A, d_B, d_C, N);
        CUDA_CHECK(cudaEventRecord(stop));               // 打点：结束
        CUDA_CHECK(cudaEventSynchronize(stop));          // 等 GPU 真正干完（Event 是异步的）
        CUDA_CHECK(cudaEventElapsedTime(&t[i], start, stop));  // 两点间隔毫秒数
    }
       
    CUDA_CHECK(cudaEventDestroy(start));
    CUDA_CHECK(cudaEventDestroy(stop));
    return median(t);
}

// ============ 主程序 ============
int main() {
    // ① 设备信息（写报告要用）
    cudaDeviceProp prop;
    CUDA_CHECK(cudaGetDeviceProperties(&prop, 0));
    printf("GPU: %s\n", prop.name);
    printf("SM count: %d, Max threads/SM: %d, Max block threads: %d\n",
           prop.multiProcessorCount, prop.maxThreadsPerMultiProcessor,
           prop.maxThreadsPerBlock);
    int v;
    cudaRuntimeGetVersion(&v);
    printf("CUDA Runtime version: %d.%d\n", v / 1000, (v % 100) / 10);

    double peak = 448;
    printf("理论带宽: %.1f GB/s \n", peak);

    const int Ns[]     = { 1 << 20, 1 << 22, 1 << 24 };         
    const int blocks[] = { 32, 64, 128, 256, 512, 1024 };        
    const int numN = 3, numB = 6;

    printf("\n%-12s %-8s %-12s %-12s %-8s\n", "N", "block", "median(ms)", "BW(GB/s)", "util%");
    for (int n = 0; n < numN; n++) {
        int N = Ns[n];

        float *d_A, *d_B, *d_C;
        CUDA_CHECK(cudaMalloc((void**)&d_A, N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&d_B, N * sizeof(float)));
        CUDA_CHECK(cudaMalloc((void**)&d_C, N * sizeof(float)));

        std::mt19937 rng(2026);
        std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
        std::vector<float> hA(N), hB(N);
        for (int i = 0; i < N; i++) { hA[i] = dist(rng); hB[i] = dist(rng); }
        CUDA_CHECK(cudaMemcpy(d_A, hA.data(), N * sizeof(float), cudaMemcpyHostToDevice));
        CUDA_CHECK(cudaMemcpy(d_B, hB.data(), N * sizeof(float), cudaMemcpyHostToDevice));

        for (int b = 0; b < numB; b++) {
            int block = blocks[b];
            if (block > prop.maxThreadsPerBlock) {   
                printf("%-12d %-8d 跳过(超出硬件上限)\n", N, block);
                continue;
            }
            float ms = measure(d_A, d_B, d_C, N, block);
            double bw = 12.0 * N / (ms / 1000.0) / 1e9;
            printf("%-12d %-8d %-12.4f %-12.2f %-8.1f\n", N, block, ms, bw, 100.0 * bw / peak);
        }
        CUDA_CHECK(cudaFree(d_A));
        CUDA_CHECK(cudaFree(d_B));
        CUDA_CHECK(cudaFree(d_C));
    }
    return 0;
}
