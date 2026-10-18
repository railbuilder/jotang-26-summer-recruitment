#include <cuda_runtime.h>
#include <algorithm>
#include <cstddef>
#include <random>
#include <vector>
#include <cstdio>
#include <cmath>

#define CUDA_CHECK(call)                                                       \
    do {                                                                       \
        cudaError_t err = (call);                                              \
        if (err != cudaSuccess) {                                              \
            fprintf(stderr, "CUDA error %s at %s:%d\n",                        \
                    cudaGetErrorString(err), __FILE__, __LINE__);              \
            exit(1);                                                           \
        }                                                                      \
    } while (0)


void init_vector_inputs(float* d_A, float* d_B, std::size_t N) {
    std::mt19937 rng(2026);
    std::uniform_real_distribution<float> dist(-1.0f, 1.0f);
    std::vector<float> h_A(N), h_B(N);
    std::generate(h_A.begin(), h_A.end(), [&] { return dist(rng); });
    std::generate(h_B.begin(), h_B.end(), [&] { return dist(rng); });

    cudaMemcpy(d_A, h_A.data(), N * sizeof(float), cudaMemcpyHostToDevice);
    cudaMemcpy(d_B, h_B.data(), N * sizeof(float), cudaMemcpyHostToDevice);
}

__global__ void vec_add(float *a,float *b,float *c,int N){
    int i=threadIdx.x + blockIdx.x * blockDim.x;
    if (i < N)
    c[i]=a[i]+b[i];
}

int main(){
    const int N =1<<20;
    const int block=256;
    float *d_A, *d_B, *d_C;
    CUDA_CHECK(cudaMalloc((void**)&d_A, N * sizeof(float)));
    CUDA_CHECK(cudaMalloc((void**)&d_B, N * sizeof(float)));
    CUDA_CHECK(cudaMalloc((void**)&d_C, N * sizeof(float)));

    init_vector_inputs(d_A, d_B, N);
    
    vec_add<<<(N + block - 1) / block, block>>>(d_A, d_B, d_C, N);
    cudaError_t err = cudaGetLastError();   
if (err != cudaSuccess) {
    fprintf(stderr, "Kernel launch failed: %s\n", cudaGetErrorString(err));}
    
    std::vector<float> h_a(N), h_b(N), h_c(N);
    CUDA_CHECK(cudaMemcpy(h_a.data(), d_A, sizeof(float) * N, cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(h_b.data(), d_B, sizeof(float) * N, cudaMemcpyDeviceToHost));
    CUDA_CHECK(cudaMemcpy(h_c.data(), d_C, sizeof(float) * N, cudaMemcpyDeviceToHost));
    float maxerr=0;
    for(int i=0;i<N;i++) {
        float tem=h_a[i]+h_b[i];
        float err=fabsf(tem-h_c[i]);
        if (err > maxerr) 
        maxerr=err;
    }
    if (maxerr < 1e-5) 
    printf("PASS\n");
    else printf("FAIL\n");

    CUDA_CHECK(cudaFree(d_A));
    CUDA_CHECK(cudaFree(d_B));
    CUDA_CHECK(cudaFree(d_C));
    return 0;
}