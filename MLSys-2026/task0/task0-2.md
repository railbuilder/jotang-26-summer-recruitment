AI的单位是FLOPs/Byte，高意味着更偏向计算，低意味着更偏向搬运数据

P\_peak / BW\_peak=AI\*，当算子的AI高于AI\*，就更偏向于Compute Bound，低于AI\*，更偏向于Memory Bound。而由于P\_peak 和 BW\_peak由硬件决定，所以不同GPU的AI\*不同，所以同一个算子在不同的GPU上会有不同的判断。

\---

假设有N个元素。

每个元素执行一次加法，所以总的FLOPs=N

每个元素读8字节写4字节，所以Memory Traffic=12N字节

AI=N/12N=1/12<1，大概率是memory bound

\---

cache：数据驻留cache使访问速度变快，实际nmemory traffic减小，使实测结果偏高。

重复访存：oofline 模型假设数据只访问一次，如果程序多次重复读取显存中同一块数据，会使实际显存流量高于理论值，算子真实算术强度下降，更容易受带宽限制，实测性能低于 Roofline 理论上限

Kernel Launch Overhead在短kernel里占比大，让吞吐低于roofline，使实测低于预测

硬件利用率不足导致运行时达不到 P\_peak 或 BW\_peak，使实测低于预测

