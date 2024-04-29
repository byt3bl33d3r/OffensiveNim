#[
    Author: m4ul3r (@m4ul3r_0x00)
    Reference: Maldev Academy
    License: BSD 3-Clause

    Description: Utilize TLS to check if a debugger is attached via a breakpoint on the entrypoint. Include the snippet once, to your "main.nim" file.
]#

import winim/lean

{.emit: """
#include <Windows.h>
#include <stdio.h>
#define _CRTALLOC(x) __attribute__((section(x)))
extern int main(int argc, char** args, char** env);
""".}

{.passC:"-masm=intel".}
proc getAddressOfEntryPoint(): pointer {.inline.} =
  var pPeb: PPEB
  asm """
    mov rax, qword ptr gs:[0x60]
    :"=r"(`pPeb`)
  """
  var 
    uModule = cast[int](pPeb.Reserved3[1])
    pImgNtHdrs = cast[PIMAGE_NT_HEADERS](cast[int](uModule) + cast[PIMAGE_DOS_HEADER](uModule).e_lfanew)
  return cast[pointer](cast[int](uModule) + pImgNtHdrs.OptionalHeader.AddressOfEntryPoint)

proc antiDebuggingTlsCallback*(hModule: PVOID, dwReason: DWORD, pContext: PVOID): void {.exportc.} =
  var 
    dwOldProtection: DWORD
    entryPoint = getAddressOfEntryPoint()

  # fetch entry point from the "_start" function
  if (dwReason == DLL_PROCESS_ATTACH) or (dwReason == DLL_THREAD_ATTACH):
    {.emit: """
    printf("[i] Entry Point Address: 0x%p\n", entryPoint);
    // Check if breakpoint is set on entrypoint
    if (*(BYTE*)entryPoint == 0xcc) {
      printf("[!] Entry Point Is Patched With \"INT 3\" Instruction!\n");
      // Overwrite main function with breakpoints
      if (VirtualProtect(entryPoint, 4096, PAGE_EXECUTE_READWRITE, &dwOldProtection)) {
        memset(entryPoint, 0xCC, 4096);
        printf("[+] Entry Point Is Overwritten With 0xCC Bytes!\n");
      } else {
        printf("[!] Failed To Overwrite The Entry Point!\n");
      }
    }
    """.}

#
{.emit: """_CRTALLOC(".CRT$XLB") PIMAGE_TLS_CALLBACK ___xd_z = (PIMAGE_TLS_CALLBACK) antiDebuggingTlsCallback;""".}

proc main() =
  echo "whoami"

when isMainModule:
  main()