#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Credit to @jonasLyk for the discovery of this method and LloydLabs for the initial C PoC code.

    References:
        - https://github.com/LloydLabs/delete-self-poc
        - https://twitter.com/jonasLyk/status/1350401461985955840
]# 


import winim
import system

var DS_STREAM_RENAME = newWideCString(":wtfbbq")

proc ds_open_handle(pwPath: PWCHAR): HANDLE =
    return CreateFileW(pwPath, DELETE, 0, NULL, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0)

proc ds_rename_handle(hHandle: HANDLE): WINBOOL =
    var fRename: FILE_RENAME_INFO
    RtlSecureZeroMemory(addr fRename, sizeof(fRename))

    var lpwStream: LPWSTR = DS_STREAM_RENAME
    fRename.FileNameLength = sizeof(lpwStream).DWORD;
    RtlCopyMemory(addr fRename.FileName, lpwStream, sizeof(lpwStream))

    return SetFileInformationByHandle(hHandle, fileRenameInfo, addr fRename, sizeof(fRename) + sizeof(lpwStream))

proc ds_deposite_handle(hHandle: HANDLE): WINBOOL =
    var fDelete: FILE_DISPOSITION_INFO
    RtlSecureZeroMemory(addr fDelete, sizeof(fDelete))

    fDelete.DeleteFile = TRUE;

    return SetFileInformationByHandle(hHandle, fileDispositionInfo, addr fDelete, sizeof(fDelete).cint)

when isMainModule:
    var
        wcPath: array[MAX_PATH + 1, WCHAR]
        hCurrent: HANDLE

    RtlSecureZeroMemory(addr wcPath[0], sizeof(wcPath));

    if GetModuleFileNameW(0, addr wcPath[0], MAX_PATH) == 0:
        echo "[-] Failed to get the current module handle"
        quit(QuitFailure)

    hCurrent = ds_open_handle(addr wcPath[0])
    if hCurrent == INVALID_HANDLE_VALUE:
        echo "[-] Failed to acquire handle to current running process"
        quit(QuitFailure)

    echo "[*] Attempting to rename file name"
    if not ds_rename_handle(hCurrent).bool:
        echo "[-] Failed to rename to stream"
        quit(QuitFailure)

    echo "[*] Successfully renamed file primary :$DATA ADS to specified stream, closing initial handle"
    CloseHandle(hCurrent)

    hCurrent = ds_open_handle(addr wcPath[0])
    if hCurrent == INVALID_HANDLE_VALUE:
        echo "[-] Failed to reopen current module"
        quit(QuitFailure)

    if not ds_deposite_handle(hCurrent).bool:
        echo "[-] Failed to set delete deposition"
        quit(QuitFailure)

    echo "[*] Closing handle to trigger deletion deposition"
    CloseHandle(hCurrent)

    if not PathFileExistsW(addr wcPath[0]).bool:
        echo "[*] File deleted successfully"
