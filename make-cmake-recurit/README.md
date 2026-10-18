# Make & CMake Recruit

## 环境

推荐使用 Linux环境，并安装：

```bash
sudo apt update
sudo apt install build-essential cmake
```

确认：

```bash
gcc --version
make --version
cmake --version
```

## 仓库结构

```text
.
├── answers/
│   ├── task1.md
│   └── task4.md
├── make-task/
│   ├── include/
│   ├── src/
│   └── Makefile
├── cmake-task/
│   ├── include/
│   ├── src/
│   └── CMakeLists.txt
├── check.sh
└── README.md
```

## Task 1：编译流程笔记

请在 `answers/task1.md` 中，用自己的语言简要说明一个 C 程序从 `.c` 源文件到可执行文件的大致过程。

你可以自己尝试：

```bash
gcc -E hello.c -o hello.i
gcc -S hello.i -o hello.s
gcc -c hello.s -o hello.o
gcc hello.o -o hello
```

重点理解各阶段在做什么。

## Task 2：完成 Makefile

进入：

```bash
cd make-task
```

补全 `Makefile` 中的 TODO，使以下命令都能正常工作：

```bash
make
./calculator
make clean
```

程序应输出：

```text
[INFO] Calculator started
10 + 5 = 15
10 - 5 = 5
```

完成后修改一次 `src/calculator.c`（也可以使用 `touch src/calculator.c`），再次运行 `make`，观察哪些文件被重新编译，并思考为什么。

## Task 3：完成 CMakeLists.txt

进入：

```bash
cd cmake-task
```

补全 `CMakeLists.txt` 中的 TODO，使：

```bash
cmake -S . -B build
cmake --build build
./build/calculator
```

可以正常工作。

你只需要用到很基础的 CMake 内容，例如：

```cmake
add_executable(...)
target_include_directories(...)
```

## Task 4：思考题

请在 `answers/task4.md` 中回答：

1. Make 和一个简单的 `build.sh`（把所有 gcc 命令依次执行）有什么区别？
2. CMake 本身是不是编译器？执行 `cmake --build build` 时，最终是谁在编译 C 源文件？
3. 如果一个项目有很多 `.c` 文件，只修改了其中一个，为什么通常不希望把所有源文件都重新编译？

## 自检

在仓库根目录运行：

```bash
chmod +x check.sh
./check.sh
```

自检脚本会检查 Make 和 CMake 两个实践任务是否可以正常构建和运行。

> 允许查资料、搜索和使用 AI，但请确保你能够解释自己提交的 Makefile、CMakeLists.txt 和文字答案。
