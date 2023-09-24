#[
    Author: Itay Migdal
    License: BSD 3-Clause

    Two anti-debugging techniques implemented in Nim
]#

import winim

{.passC:"-masm=intel".}


proc pebBeingDebugged(): bool {.asmNoStackFrame.} = 
    # https://anti-debug.checkpoint.com/techniques/debug-flags.html#manual-checks-peb-beingdebugged-flag
    asm """
    mov rax, gs:[0x60]
    movzx rax, byte ptr [rax+2]
    ret
    """


proc getProcessFileHandle(): bool =
    # https://anti-debug.checkpoint.com/techniques/object-handles.html#createfile
    var fileName: array[MAX_PATH + 1, WCHAR]
    discard GetModuleFileNameW(
        0,
        addr fileName[0],
        MAX_PATH
    )
    var res = CreateFileW(
        addr fileName[0], 
        GENERIC_READ, 
        0, 
        NULL, 
        OPEN_EXISTING, 
        0, 
        0
        )
    
    var isDebugged = (res == INVALID_HANDLE_VALUE)
    CloseHandle(res)
    return isDebugged


proc isDebugged*(): bool =
    return pebBeingDebugged() or getProcessFileHandle()
