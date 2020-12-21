#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause
]#

import winim

var pipe: HANDLE = CreateFile(
    r"\\.\pipe\crack",
    GENERIC_READ or GENERIC_WRITE, 
    FILE_SHARE_READ or FILE_SHARE_WRITE,
    NULL,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL,
    0
)

if bool(pipe):
    echo "[*] Connected to server"
    try:
        var
            buffer: array[100, char]
            bytesRead: DWORD

        var result: BOOL = ReadFile(
            pipe,
            addr buffer,
            (DWORD)buffer.len,
            addr bytesRead,
            NULL
        )
        echo "[*] bytes read: ", bytesRead
        echo repr(buffer)
    finally:
        CloseHandle(pipe)
