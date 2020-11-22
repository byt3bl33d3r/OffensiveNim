<p align="center">
    <img height="300" alt="OffensiveNim" src="https://user-images.githubusercontent.com/5151193/98487722-ed729600-21e1-11eb-9d77-a79b0f3634de.png">
</p>

# OffensiveNim

My experiments in weaponizing [Nim](https://nim-lang.org/) for implant development and general offensive operations.

## Why Nim?

- Compiles *directly* to C, C++, Objective-C and Javascript.
- Since it doesn't rely on a VM/runtime does not produce what I like to call "T H I C C malwarez" as supposed to other languages (e.g. Golang)
- Python inspired syntax, allows rapid native payload creation & prototyping.
- Has **extremely** mature [FFI](https://nim-lang.org/docs/manual.html#foreign-function-interface) (Foreign Function Interface) capabilities.
- Avoids making you actually write in C/C++ and subsequently avoids introducing a lot of security issues into your software.
- Super easy cross compilation to Windows from Nix/MacOS, only requires you to install the `mingw` toolchain and passing a single flag to the nim compiler.
- The Nim compiler and the generated executables support all major platforms like Windows, Linux, BSD and macOS. Can even compile to Nintendo switch , IOS & Android. See the cross-compilation section in the [Nim compiler usage guide](https://nim-lang.github.io/Nim/nimc.html#crossminuscompilation)
- You could *technically* write your implant and c2 backend both in Nim as you can compile your code directly to Javascript. Even has some [initial support for WebAssembly's](https://forum.nim-lang.org/t/4779) 

## Examples in this Repo

| File | Description |
| ---  | --- |
| `pop_bin.nim` | Call `MessageBox` WinApi *without* using the Winim library |
| `pop_winim_bin.nim` | Call `MessageBox` *with* the Winim libary |
| `pop_winim_lib.nim` | Example of creating a Windows DLL with an exported `DllMain` |  
| `wmiquery_bin.nim` | Queries running processes and installed AVs using using WMI |
| `shellcode_bin.nim` | Creates a suspended process and injects shellcode with `VirtualAllocEx`/`CreateRemoteThread`. Also demonstrates the usage of compile time definitions to detect arch, os etc..| 
| `passfilter_lib.nim` | Log password changes to a file by (ab)using a password complexity filter |
| `minidump_bin.nim` | Creates a memory dump using `MiniDumpWriteDump` |
| `http_request_bin.nim` | Demonstrates a couple of ways of making HTTP requests |
| `execute_sct_bin.nim` | `.sct` file Execution via `GetObject()` |
| `scriptcontrol_bin.nim` | Dynamically execute VBScript and JScript using the `MSScriptControl` COM object | 
| `excel_com_bin.nim` | Injects shellcode using the Excel COM object and Macros |
| `clr_bin.nim` | Hosts the CLR and executes .NET assemblies (**WIP, help appreciated**) | 
| `excel_4_com_bin.nim` | Injects shellcode using the Excel COM object and Excel 4 Macros (**WIP**) |

## Compiling the examples in this repo

This repository does not provide binaries, you're gonna have to compile them yourself.

This repo was setup to cross-compile the example Nim source files to Windows from Nix/MacOS, however they should work just fine directly compiling them on Windows (Don't think you'll be able to use the Makefile tho which compiles them all in one go).

[Install Nim](https://nim-lang.org/install_unix.html) using your systems package manager (for windows [use the installer on the official website](https://nim-lang.org/install_windows.html))

- `brew install nim`
- `apt install nim`

(Nim also provides a docker image but don't know how it works when it comes to cross-compiling, need to look into this)

You should now have the `nim` & `nimble` commands available, the former is the Nim compiler and the latter is Nim's package manager.

Install the `Mingw` toolchain needed for cross-compilation to Windows (Not needed if you're compiling on Windows):
- Nix: `apt-get insatall mingw`
- MacOS: `brew install mingw`

Finally, install the magnificent [Winim](https://github.com/khchen/winim) library:

- `nimble install winim`

Then cd into the root of this repository and run `make`.

You should find the binaries and dlls in the `bin/` directory

## Cross Compiling

See the cross-compilation section in the [Nim compiler usage guide](https://nim-lang.github.io/Nim/nimc.html#crossminuscompilation), for a lot more details.

Cross compiling to Windows from MacOs/Nix requires the `mingw` toolchain, usually a matter of just `brew install mingw` or `apt install mingw`.

You then just have to pass the  `-d=mingw` flag to the nim compiler.

E.g. `nim c -d=mingw --app=console --cpu=amd64 source.nim`

## Interfacing with C/C++

See the insane [FFI section](https://nim-lang.org/docs/manual.html#foreign-function-interface) in the Nim manual.

If you're familiar with csharps P/Invoke it's essentially the same concept albeit a looks a tad bit uglier:

Calling `MessageBox` example

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

For any complex Windows API calls use the [Winim library](https://github.com/khchen/winim), saves an insane amount of time and doesn't add too much to the executable size (see below) depending on how you import it.

Even has COM support!!!

## Creating Windows DLLs with an exported `DllMain`

Big thanks to the person who posted [this](https://forum.nim-lang.org/t/1973) on the Nim forum.

The Nim compiler tries to create a `DllMain` function for you automatically at compile time whenever you tell it to create a windows DLL, however, it doesn't actually export it for some reason. In order to have an exported `DllMain` you need to pass `--nomain` and define a `DllMain` function yourself with the appropriate pragmas (`stdcall, exportc, dynlib`).

You need to also call `NimMain` from your `DllMain` to initialize Nim's garbage collector. (Very important, otherwise your computer will literally explode).

Example:

```nim
import winim/lean

proc NimMain() {.cdecl, importc.}

proc DllMain(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID) : BOOL {.stdcall, exportc, dynlib.} =
  NimMain()
  
  if fdwReason == DLL_PROCESS_ATTACH:
    MessageBox(0, "Hello, world !", "Nim is Powerful", 0)

  return true
```

To compile:

```
nim c -d=mingw --app=lib --nomain --cpu=amd64 mynim.dll
```


## Optimizing executables for size

Taken from the [Nim's FAQ page](https://nim-lang.org/faq.html)

For the biggest size decrease use the following flags `-d:danger -d:strip --opt:size`

Additionally, I've found you can squeeze a few more bytes out by passing `--passc=-flto --passl=-flto` to the compiler. Also take a look at the `Makefile` in this repo.

These flags decrease sizes **dramatically**: the shellcode injection example goes from 484.3 KB to 46.5 KB when cross-compiled from MacOSX!

## Executable size difference when using the Winim library vs without

Incredibly enough the size difference is pretty negligible. Especially when you apply the size optimizations outlined above.

The two examples `pop_bin.nim` and `pop_winim_bin.nim` were created for this purpose.

The former defines the `MessageBox` WinAPI call manually and the latter uses the Winim library (specifically `winim/lean` which is only the core SDK, see [here](https://github.com/khchen/winim#usage)), results:

```
byt3bl33d3r@ecl1ps3 OffensiveNim % ls -lah bin
-rwxr-xr-x  1 byt3bl33d3r  25K Nov 20 18:32 pop_bin_32.exe
-rwxr-xr-x  1 byt3bl33d3r  32K Nov 20 18:32 pop_bin_64.exe
-rwxr-xr-x  1 byt3bl33d3r  26K Nov 20 18:33 pop_winim_bin_32.exe
-rwxr-xr-x  1 byt3bl33d3r  34K Nov 20 18:32 pop_winim_bin_64.exe
```

If you import the entire Winim library with `import winim/com` it adds only around ~20ish KB which considering the amount of functionality it abstracts is 100% worth that extra size:
```
byt3bl33d3r@ecl1ps3 OffensiveNim % ls -lah bin
-rwxr-xr-x  1 byt3bl33d3r  42K Nov 20 19:20 pop_winim_bin_32.exe
-rwxr-xr-x  1 byt3bl33d3r  53K Nov 20 19:20 pop_winim_bin_64.exe
```

## Debugging

Use the `repr()` function in combination with `echo`, supports almost all (??) data types, even structs!

See [this blog post for more](https://nim-lang.org/blog/2017/10/02/documenting-profiling-and-debugging-nim-code.html)

## Setting up a dev environment

VSCode has a Nim extension which works pretty well.

## Pitfalls I found myself falling into

- When calling winapi's with Winim and trying to pass a null value, make sure you pass the `NULL` value (defined within the Winim library) as supposed Nim's builtin `nil` value. (Ugh)

- To get the OS handle to the created file after calling `open()` on Windows, you need to call `f.getOsFileHandle()` and **not** `f.getFileHandle()` cause reasons.

- The Nim compiler does accept arguments in the form `-a=value` or `--arg=value` even tho if you look at the usage it only has arguments passed as `-a:value` or `--arg=value`. (Important for Makefiles)

- When defining a byte array, you also need to indicate at least in the first value that it's a byte array, bit weird but ok (https://forum.nim-lang.org/t/4322)

Byte array in C#:
```csharp
byte[] buf = new byte[5] {0xfc,0x48,0x81,0xe4,0xf0,0xff}
```

Byte array in Nim:
```nim
var buf: array[295, byte] = [byte 0xfc,0x48,0x81,0xe4]
```

## Converting C code to Nim

https://github.com/nim-lang/c2nim

Used it to translate a bunch of small C snippets, haven't tried anything major.

## Language Bridges

  - Python integration https://github.com/yglukhov/nimpy
    * This is actually super interesting, [especially this part](https://github.com/yglukhov/nimpy/blob/master/nimpy/py_lib.nim#L330). With some modification could this load the PythonxXX.dll from memory?

  - Jave VM integration: https://github.com/yglukhov/jnim

## Interesting Nim libraries

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

## Nim for implant dev links

- https://secbytes.net/Implant-Roulette-Part-1:-Nimplant
- https://securelist.com/zebrocys-multilanguage-malware-salad/90680/
- https://github.com/MythicAgents/Nimplant
- https://github.com/elddy/Nim-SMBExec
- https://github.com/elddy/NimScan