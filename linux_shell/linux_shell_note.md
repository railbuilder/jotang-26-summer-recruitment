## 在接触Linux时学到的知识



### 指令

1. pwd (Print Working Directory)：
作用：显示绝对路径

2. ls (List)
作用：列出当前文件夹里的东西。
常用参数：
-l (Long)：看详细信息（权限、大小、时间）。
-a (All)：看所有文件，包括以 “ . ” 开头的隐藏文件。
例子：ls -la

1. cd (Change Directory)
作用：切换目录（走路）。
常用格式：
cd 文件夹名：进入子文件夹。
cd .. ：退回上一级（爸爸目录）
cd ~ ：回到用户主目录

1. mkdir (Make Directory)
作用：新建文件夹。
例子：mkdir output
1. rm (Remove) 
作用：删除文件或文件夹
参数：-r (Recursive) 递归删除文件夹及里面的一切；
-f (Force) 强制删除不提示。
例子：rm output/02_todo_files.txt 
1. cat (Concatenate)
作用：直接把文件内容全打印在屏幕上
参数：
-A (All) 显示隐藏字符（用来检查有没有多余空格和换行）。
例子：cat output/01_project_id.txt
7. nano
作用：终端里的“记事本”，用来编辑文件。
用法：nano 文件名。保存是 Ctrl+O 回车，退出是 Ctrl+X
8. head / tail
作用：只看文件的头几行 / 尾几行。
参数：-n 数字 指定看几行。
例子：head -n 1 只看第一行
9. find (查找文件)
作用：根据文件名找文件。
格式：find 范围 -name "名字"
例子：find . -name "*.txt"（在当前目录找所有 txt 文件）
10. grep (Global Regular Expression Print)
作用：根据文件内容找关键词。
常用参数：
-r (Recursive)：递归搜索子文件夹。
-n (Number)：显示行号。
-l (List)：只显示包含关键词的文件名，不显示具体内容。
-c (Count)：统计匹配的行数（一行有多个关键词只算1行）。
-o (Only-matching)：只输出匹配到的词，每行一个（常配合 wc -l 统计总次数）。
-I (大写i)：忽略二进制文件。
-v (Invert)：反向查找（找不包含关键词的行）。
例子：grep -rn "TODO" workspace/
11. cut (剪切)
作用：按指定分隔符切割文本，提取某几列。
参数：-d'分隔符'（Delimiter，默认是制表符），-f数字（Field，提取第几列
12. awk
作用：超级文本处理工具。默认会把连续空格视为一个分隔符。
格式：awk '{print \$列号}'
例子：awk '{print $1}'（提取第一列，比如日志里的IP）
13. sort
作用：排序。
参数：-n (Numeric) 按数值大小排；-r (Reverse) 逆序（从大到小）。
例子：sort -nr
14. uniq (Unique)
作用：去重。
致命陷阱：只能去重相邻的重复行！必须先用 sort 排序，再用 uniq。
参数：-c (Count) 统计每行出现的次数。
经典连招：| sort | uniq -c

15. wc (Word Count)
作用：字数统计
参数：-l (Lines) 统计行数。
经典连招：| wc -l（数数一共传过来几行）
16. tr (Translate)
作用：替换或删除字符。
参数：-s (Squeeze) 把连续重复的字符压缩成一个。
例子：tr -s ' '（把多个空格压缩成一个）'
17.  \> (重定向标准输出)
作用：把本该打印在屏幕上的正常结果，覆盖写入到文件里。
例子：grep ... > output.txt.
18. \>> (追加重定向)
作用：把结果追加写入文件末尾，不覆盖原有内容.  
19.  2> (重定向标准错误)
作用：把程序的报错信息单独存进文件。
例子：./check.sh 2> error.log.
20.  | (Pipeline 管道)
作用：把左边命令的输出，直接变成右边命令的输入。像流水线一样。
例子：command1 | command2 | command3.
21. tee
作用：T型水管。一份数据，既输出到屏幕，又保存到文件。
例子：./check.sh | tee output.txt.
22. chmod (Change Mode)
作用：修改文件权限。
参数：+x (eXecute) 赋予执行权限。
例子：chmod +x check.sh.
23. echo
作用：打印文字到屏幕。常配合 > 手动往文件里写内容。
例子：echo "7" > output/04.txt.
24. git clone
作用：从远程仓库下载代码到本地.
25. .
26. .
27. .
###  linux小巧思
1. 命令第一个词永远被当作“程序/命令”的名字。
2. \' > ' 符号不能直接接收裸数据，它必须接收一个命令的输出。
> 由1、2可知，7 \> output/08.txt是不行的，可以写成echo "7" > output/04_error_count.txt
3. \> 、| 默认只接收标准输出（stdout）