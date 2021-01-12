#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    References:
        - https://github.com/outflanknl/WdToggle/blob/main/Syscalls.h#L5
        - https://outflank.nl/blog/2020/12/26/direct-syscalls-in-beacon-object-files/
]#

{.passC:"-masm=intel".}

import winim/lean

proc GetTEBAsm64(): LPVOID {.asmNoStackFrame.} =
    asm """
        push rbx
        xor rbx, rbx
        xor rax, rax
        mov rbx, qword ptr gs:[0x30]
        mov rax, rbx
        pop rbx
        jno theEnd
       theEnd:
        ret
    """

var p = GetTEBAsm64()
echo repr(p)
