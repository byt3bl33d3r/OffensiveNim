<p align="center">
    <img height="300" alt="OffensiveNim" src="https://user-images.githubusercontent.com/5151193/98487722-ed729600-21e1-11eb-9d77-a79b0f3634de.png">
</p>

# OffensiveNim

这是我使用[Nim](https://nim-lang.org/)开发implant(植入体)和常用的攻击作战工具的实验。

## 目录

- [OffensiveNim](#offensivenim)
  * [为什么用Nim](#为什么用Nim)
  * [使用范例](#使用范例)
  * [范例中的半成品](#范例中的半成品)
  * [编译范例](#编译范例)
  * [跨平台编译](#跨平台编译)
  * [C/C++接口](#C/C++接口)
  * [用DllMain入口点函数创建Windows DLLs](#用-dllmain入口点函数创建windows-dlls)
  * [优化可执行程序大小](#优化可执行程序大小)
  * [是否使用Winim库，可执行程序大小是不同的](#是否使用Winim库，可执行程序大小是不同的)
  * [Opsec考虑](#Opsec考虑)
  * [转换C代码去Nim](#转换C代码去Nim)
  * [跨语言使用](#跨语言使用)
  * [调试](#调试)
  * [配置开发环境](#配置开发环境)
  * [我遇到过的陷阱](#我遇到过的陷阱)
  * [有趣的Nim库](#有趣的Nim库)
  * [Nim植入体开发相关连接](#Nim植入体开发相关连接)

## 为什么用Nim

- 直接编译成 C, C++, Objective-C 和 Javascript。
- 由于它不依赖于VM/运行时不会产生像别的语言一样的"T H I C C malwarez"(e.g. Golang)。
- 受Python语法启发, 允许快速的创建native payload和样本制作。
- 有**非常**成熟的 [FFI](https://nim-lang.org/docs/manual.html#foreign-function-interface) (Foreign Function Interface) 能力。
- 避免使用C/C++代码编写，同时也就避免了在软件中引入一些安全问题.
- 超级容易在*nix/MacOS系统上跨平台编译Windows程序, 仅仅需要安装 `mingw` 工具集和给nim编译器指定一个参数。
- Nim编译器支持大多数主流平台的可执行程序生成，如：Windows、Linux、BSD和macOS。甚至能够支持Nintendo switch、IOS和Android平台。查看跨平台编译部分的详情在[Nim编译器使用指南](https://nim-lang.github.io/Nim/nimc.html#crossminuscompilation)
- 从技术上讲，你能够使用Nim编写implant(植入体)和c2后端，因为你可以直接将代码编译成 Javascript。Nim甚至初步支持 [WebAssembly](https://forum.nim-lang.org/t/4779) 

## 使用范例

| File | Description |
| ---  | --- |
| `pop_bin.nim` | 调用 `MessageBox` 使用WinApi，不用Winim库 |
| `pop_winim_bin.nim` | 调用 `MessageBox` 使用Winim库 |
| `execute_assembly_bin.nim` | 托管CLR，在内存中反射执行.NET assemblies |
| `clr_host_cpp_embed_bin.nim` | 通过直接嵌入C++代码托管CLR，执行硬盘上的.NET assembly |
| `scshell_c_embed_bin.nim` | 通过将[SCShell](https://github.com/Mr-Un1k0d3r/SCShell)(C)直接嵌入Nim中，来演示如何快速武器化现有C代码工具 |
| `fltmc_bin.nim` | 枚举所有Minifilter驱动程序 |
| `blockdlls_acg_ppid_spoof_bin.nim` | 创建一个挂起的进程并使用PPID欺骗，使它的父进程为explorer.exe， 同时开启BlockDLLs和ACG |
| `named_pipe_client_bin.nim` | 命名管道客户端 |
| `named_pipe_server_bin.nim` | Named Pipe Server |
| `pop_winim_lib.nim` | 举例创建一个具有 `DllMain`入口点函数的Windows DLL |
| `wmiquery_bin.nim` | 使用WMI查询运行和安装的杀毒软件 |
| `shellcode_bin.nim` | 创建一个挂起的精彩，并用 `VirtualAllocEx`/`CreateRemoteThread`方法来注入shellcode。 同时也演示了使用编译时定义来侦测架构、 系统等等 |
| `passfilter_lib.nim` | 通过使用（滥用）密码复杂性过滤器来记录密码改变 |
| `minidump_bin.nim` | 使用`MiniDumpWriteDump`来创建一个lsass进程的内存拷贝 |
| `http_request_bin.nim` | 演示发送HTTP请求的2种方式 |
| `execute_sct_bin.nim` | 通过 `GetObject()`来执行`.sct`扩展文件 |
| `scriptcontrol_bin.nim` | 使用`MSScriptControl` COM对象来动态执行VBScript和JScript |
| `excel_com_bin.nim` | 使用Excel COM 对象和Macros来注入shellcode |
| `keylogger_bin.nim` | 使用 `SetWindowsHookEx`来做键盘记录 |
| `amsi_patch_bin.nim` | 在当前进程通过补丁AMSI的方式绕过AMSI |

## 范例中的半成品

| File                   | Description                                                  |
| ---------------------- | ------------------------------------------------------------ |
| `amsi_patch_2_bin.nim` | 用另外一种方法在当前经常通过补丁AMSI的方式绕过AMSI (**半成品，感谢帮助**) |
| `excel_4_com_bin.nim`  | 使用Excel COM对象和Excel 4 Macros注入shellcode (**半成品**)  |

## 编译范例

此仓库不提供二进制文件，你需要自己编译。

这个仓库配置的是在*nix/MacOS平台上跨平台编译成Windows程序的Nim源码例子，当然它们应该也可以在Windows平台上直接编译 (你可以无脑的使用Makefile文件一键编译)。

[安装Nim](https://nim-lang.org/install_unix.html) 用系统软件管理器 (对于Windows平台可以直接使用官网的 [安装包](https://nim-lang.org/install_windows.html))

- `brew install nim`
- `apt install nim`

(Nim也提供了一个docker image但是不知道他是怎么执行跨平台编译工作的，需要研究一下)

你现在应该可以使用 `nim` & `nimble` 命令了，前者是Nim编译器， 后者是Nim的包管理器。

跨平台编译Windows程序需要安装 `Mingw` 工具集 (Windows平台不需要):
- *nix: `apt-get install mingw-w64`
- MacOS: `brew install mingw-w64`

最后，安装牛逼的[Winim](https://github.com/khchen/winim)库:

- `nimble install winim`

然后cd进入仓库当前目录并执行 `make`。

你应该能够找到二进制文件和dlls在 `bin/` 目录。

## 跨平台编译

查看更多跨平台编译部分的详情，在 [Nim编译器指南](https://nim-lang.github.io/Nim/nimc.html#crossminuscompilation)中。

在MacOs/*nix跨平台编译Windows程序需要 `mingw` 工具集，常常使用`brew install mingw-w64`或者`apt install mingw-w64`安装。

在编译时你仅仅需要指定 `-d=mingw` 参数。

E.g. `nim c -d=mingw --app=console --cpu=amd64 source.nim`

## C/C++接口

查看在Nim手册中的 [FFI 部分](https://nim-lang.org/docs/manual.html#foreign-function-interface) 。

假如你熟悉csharps P/Invoke，它本质上是相同的概念，竟然看上去有点难看：

调用 `MessageBox` 举例

```nim
type
    HANDLE* = int
    HWND* = HANDLE
    UINT* = int32
    LPCSTR* = cstring

proc MessageBox*(hWnd: HWND, lpText: LPCSTR, lpCaption: LPCSTR, uType: UINT): int32 
  {.discardable, stdcall, dynlib: "user32", importc: "MessageBoxA".}

MessageBox(0, "Hello, world !", "Nim is Powerful", 0)
```

对于一些复杂的Windows API调用使用 [Winim库](https://github.com/khchen/winim)，既节约时间也不会增加文件大小 (参见下文) ，依赖于你导入它的方式。

甚至支持COM调用!!!

## 用 `DllMain`入口点函数创建Windows DLLs

非常感谢这位朋友在Nim论坛的[文章](https://forum.nim-lang.org/t/1973)。

每当你告诉Nim编译器创建Windows DLL时，它都会在编译时自动的为你创建`DllMain`函数，但是由于某种原因，它实际上并未导出。为了有一个入口点函数 `DllMain` ，你需要通过 `--nomain` 和利用合适的pragmas (`stdcall, exportc, dynlib`)定义一个 `DllMain` 函数。

你也需要调用 `NimMain` 为 `DllMain` 去初始化Nim的垃圾回收。(非常重要的，否则你的电脑可能被气的炸)。

举例:

```nim
import winim/lean

proc NimMain() {.cdecl, importc.}

proc DllMain(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID) : BOOL {.stdcall, exportc, dynlib.} =
  NimMain()
  
  if fdwReason == DLL_PROCESS_ATTACH:
    MessageBox(0, "Hello, world !", "Nim is Powerful", 0)

  return true
```

编译:

```
nim c -d=mingw --app=lib --nomain --cpu=amd64 mynim.dll
```


## 优化可执行程序大小

取至 [Nim的常见问题说明](https://nim-lang.org/faq.html)

要最大程度的减小程序体积，请使用一下参数 `-d:danger -d:strip --opt:size`

此外，我发现通过以下参数可以进一步减小程序体积 `--passc=-flto --passl=-flto` 。你也可以看一看项目中的 `Makefile` 文件。

这些参数**显著的**减小了程序体积: 在MacOSX上交叉编译shellcode注入示例，程序大小从484.3 KB变成了46.5 KB!

## 是否使用Winim库，可执行程序大小是不同的

大小差异基本上可以忽略不计。尤其是当你使用了上面提到的方法优化程序体积。

 `pop_bin.nim` 和 `pop_winim_bin.nim` 例子就是为了这个目的而创建的。

定义了一个`MessageBox`，前者使用手动调用WinAPI，后者用Winim库(具体是 `winim/lean` ，这是其中一个核心的SDK，详情看 [usage](https://github.com/khchen/winim#usage))，结果如下:

```
byt3bl33d3r@ecl1ps3 OffensiveNim % ls -lah bin
-rwxr-xr-x  1 byt3bl33d3r  25K Nov 20 18:32 pop_bin_32.exe
-rwxr-xr-x  1 byt3bl33d3r  32K Nov 20 18:32 pop_bin_64.exe
-rwxr-xr-x  1 byt3bl33d3r  26K Nov 20 18:33 pop_winim_bin_32.exe
-rwxr-xr-x  1 byt3bl33d3r  34K Nov 20 18:32 pop_winim_bin_64.exe
```

假如你使用 `import winim/com`全部的导入Winim库，它仅仅增加了20KB左右，考虑到它抽象的功能量，是100％值得的：
```
byt3bl33d3r@ecl1ps3 OffensiveNim % ls -lah bin
-rwxr-xr-x  1 byt3bl33d3r  42K Nov 20 19:20 pop_winim_bin_32.exe
-rwxr-xr-x  1 byt3bl33d3r  53K Nov 20 19:20 pop_winim_bin_64.exe
```

## Opsec考虑

由于Nim有FFI，就不会使用 `LoadLibrary` 做自动导入，因此您的外部导入函数都不会真正显示在可执行文件的静态导入中 (更多详情看这篇 [文章](https://secbytes.net/Implant-Roulette-Part-1:-Nimplant)):

![](https://user-images.githubusercontent.com/5151193/99911179-d0dd6000-2caf-11eb-933a-6a7ada510747.png)

假如你编译Nim源码成为一个DLL，似乎看上去总有一个 `NimMain`导入函数，不管你是否指定了`DllMain` (??)。这可能会被用来作为一个潜在的特征，不知道有多少的应用使用Nim作为开发语言。不然这个特征会特别突出。

![](https://user-images.githubusercontent.com/5151193/99911079-4563cf00-2caf-11eb-960d-e500534b56dd.png)

## 转换C代码去Nim

https://github.com/nim-lang/c2nim

用它去转换一些小的C代码片段，还有没有尝试过一些主要功能。

## 跨语言使用

  - Python整合https://github.com/yglukhov/nimpy
    * 这是个非常有趣的项目， [尤其是这部分](https://github.com/yglukhov/nimpy/blob/master/nimpy/py_lib.nim#L330)。经过一些修改可以从内存中加载PythonxXX.dll?

  - Jave VM 整合: https://github.com/yglukhov/jnim

## 调试

主要使用 `repr()` 函数和 `echo`，支持大部分 (??) 数据样式， 甚至结构体！

详情看这篇 [文章](https://nim-lang.org/blog/2017/10/02/documenting-profiling-and-debugging-nim-code.html)

## 配置开发环境

VSCode中有一个Nim扩展 是非常好用的。这似乎是目前唯一的选择。

## 我遇到过的陷阱

- 当使用Winim库调用winapi需要传递一个null值时，确保使用Winim定义的 `NULL` 去代替Nim内置的`nil`。(呸)
- 在Windows上使用open()打开的文件句柄，您需要使用f.getOsFileHandle()而不是f.getFileHandle()。

- Nim编译器不接受如下参数形式 `-a=value` 或者 `--arg=value` ，只能使用如下形式 `-a:value` 或者 `--arg:value`. (对于使用Makefile文件来说是重要的)
- 当定义byte数组时，你至少要在第一个值中标识它是一个字节，有点奇怪但就是这样的 (https://forum.nim-lang.org/t/4322)

C#的字节数组写法:
```csharp
byte[] buf = new byte[5] {0xfc,0x48,0x81,0xe4,0xf0,0xff}
```

Nim的字节数组写法:
```nim
var buf: array[5, byte] = [byte 0xfc,0x48,0x81,0xe4,0xf0,0xff]
```

## 有趣的Nim库

- https://github.com/dom96/jester
- https://github.com/pragmagic/karax
- https://github.com/Niminem/Neel
- https://github.com/status-im/nim-libp2p
- https://github.com/PMunch/libkeepass
- https://github.com/def-/nim-syscall
- https://github.com/tulayang/asyncdocker
- https://github.com/treeform/ws
- https://github.com/guzba/zippy
- https://github.com/rockcavera/nim-iputils
- https://github.com/FedericoCeratto/nim-socks5
- https://github.com/CORDEA/backoff
- https://github.com/treeform/steganography
- https://github.com/miere43/nim-registry
- https://github.com/status-im/nim-daemon

## Nim植入体开发相关连接

- https://secbytes.net/Implant-Roulette-Part-1:-Nimplant
- https://securelist.com/zebrocys-multilanguage-malware-salad/90680/
- https://github.com/MythicAgents/Nimplant
- https://github.com/elddy/Nim-SMBExec
- https://github.com/elddy/NimScan
