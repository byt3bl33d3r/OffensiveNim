#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause
]#

import winim

var pipe: HANDLE = CreateNamedPipe(
    r"\\.\pipe\crack",
    PIPE_ACCESS_DUPLEX,
    PIPE_TYPE_BYTE,
    1,
    0,
    0,
    0,
    NULL
)

if not bool(pipe) or pipe == INVALID_HANDLE_VALUE:
    echo "[X] Server pipe creation failed"
    quit(1)

try:
    echo "[*] Waiting for client(s)"
    var result: BOOL = ConnectNamedPipe(pipe, NULL)
    echo "[*] Client connected"

    var data: cstring = "*** Hello from the pipe server ***"
    var bytesWritten: DWORD
    WriteFile(
        pipe,
        data,
        (DWORD) data.len,
        addr bytesWritten,
        NULL
    )
    echo "[*] bytes written: ", bytesWritten

finally:
    CloseHandle(pipe)
