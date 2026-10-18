\#### 1.1 GPU Architecture



1.spmd是指我自己写了一个程序，但是希望它能处理多组数据。simd是指cpu一条指令要处理多个数据，simt是指每一个线程各自有自己的数据，但是都执行相同的指令  

2.warp就是32个线程组成的调度与执行基本单元。数据各个不同，执行的指令都相同  

3.Warp Divergence是一种问题，指一个 warp 内的 32 个线程走了不同的分支，让耗时增加  

4.Memory Coalescing是一个 warp 的 32 个线程同时访问内存中32给连续地址，硬件把 32 次访问合并成 1 个内存事务   

5.Register、Shared Memory、L2、HBM都是存储数据的硬件，Register线程私有，访问快可操纵，Shared Memory Block 内共享延迟较低可操纵，L2 Cache设备全局，延迟比显存低，不可操纵，HBM / Global，即显存，延迟高，数据传输受带宽约束，不可操纵 

6\.多个线程访问同一个 bank 的 "不同地址"，(如果是同一bank的相同地址反耳没有conflict了，可以广播给所有线程）硬件只能串行化（排队），这就是 bank conflict；

7.Occupancy 是每个 SM 上活跃的 warp 数 / SM 最多能容纳的 warp 数   

8.Occupancy不一定越高越好，会抢夺存储资源，只要调到刚好能隐藏延迟即可

9.REgister Pressure指每个线程需要的寄存器数量，超过了可用配额。如果需要的寄存器数超过配额，编译器编译器把多余的变量溢出到 local memory，每次访问从 1 cycle 变成几百 cycle，性能可能掉一个数量级，且一个SM的寄存器总数是固定的，寄存器需求高意味着每个 SM 能活跃的warp变少，Occupancy降低

