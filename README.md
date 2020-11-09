<p align="center">
    <img height="300" alt="OffensiveNim" src="https://user-images.githubusercontent.com/5151193/98487722-ed729600-21e1-11eb-9d77-a79b0f3634de.png">
</p>

# OffensiveNim

My experiments in weaponizing Nim (https://nim-lang.org/)

## Why Nim?

**TO DO**

Compiles to C, C++ and Javascript. Python inspired syntax. Allows rapid native payload creation & prototyping. Additionally has extremely mature [FFI](https://nim-lang.org/docs/manual.html#foreign-function-interface) (Foreign Function Interface) capabilities.

Super easy cross compilation to Windows.

> The Nim compiler and the generated executables support all major platforms like Windows, Linux, BSD and macOS.

Even compiles to Android, IOS and Nintendo Switch.

Because it does not rely on a VM/runtime (Nim code gets translated to the target backend and then directly compiled) generated executables are way smaller than other languages (e.g Golang).

## Notes

Cross compiling to Windows from Mac/Nix requires the MingW toolchain.

- [Example of type casting with FFI](https://nim-by-example.github.io/variables/type_casting_inference/)
- [Example of procedure taking an array of variable length as an argument](https://nim-by-example.github.io/arrays/)

- [Winim](https://github.com/khchen/winim) is life. Use this for interfacing with Windows API and COM.

### Creating Windows DLLs with a `DllMain`

You need to pass `--app=lib` to the command line for Nim to compile a Dll

The Nim compiler tries to create a `DllMain` for you automatically at compile time (??) however, its not actually exported. In order to have an exported `DllMain` you need to pass `--nomain` and define a `DllMain` function yourself with the appropriate pragmas (`stdcall, exportc, dynlib`). 
You also need call `NimMain` from your `DllMain` to initialize Nim's GC.

```nim
import winim/lean

proc NimMain() {.cdecl, importc.}

proc DllMain(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID) : BOOL {.stdcall, exportc, dynlib.} =
  NimMain()
  
  if fdwReason == DLL_PROCESS_ATTACH:
    MessageBox(0, "Hello, world !", "Nim is Powerful", 0)

  return true
```
