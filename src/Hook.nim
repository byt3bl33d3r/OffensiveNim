import winim

type
    typeMessageBox* = proc (hWnd: HWND, lpText: LPCSTR, lpCaption: LPCSTR, uType: UINT): int32 {.stdcall.}


type
    MyNtFlushInstructionCache* = proc (processHandle: HANDLE, baseAddress: PVOID, numberofBytestoFlush: ULONG): NTSTATUS {.stdcall.}


type
  HookedFunction* {.bycopy.} = object
    origFunction*: typeMessageBox
    functionStub*: array[16, BYTE]

  HookTrampolineBuffers* {.bycopy.} = object
    originalBytes*: HANDLE    ##  (Input) Buffer containing bytes that should be restored while unhooking.
    originalBytesSize*: DWORD  ##  (Output) Buffer that will receive bytes present prior to trampoline installation/restoring.
    previousBytes*: HANDLE
    previousBytesSize*: DWORD

var ntdlldll = LoadLibraryA("ntdll.dll")
if (ntdlldll == 0):
    echo "[X] Failed to load ntdll.dll"


var ntFlushInstructionCacheAddress = GetProcAddress(ntdlldll,"NtFlushInstructionCache")
if isNil(ntFlushInstructionCacheAddress):
    echo "[X] Failed to get the address of 'NtFlushInstructionCache'"


var ntFlushInstructionCache*: MyNtFlushInstructionCache
ntFlushInstructionCache = cast[MyNtFlushInstructionCache](ntFlushInstructionCacheAddress)


proc fastTrampoline*(installHook: bool, addressToHook: LPVOID, jumpAddress: LPVOID, buffers: ptr HookTrampolineBuffers = nil): bool

proc restoreHook() : void

var gHookedFunction*: HookedFunction

var messageBoxAddress*: HANDLE

var messageBox*: typeMessageBox


proc myMessageBox(hWnd: HWND, lpText: LPCSTR, lpCaption: LPCSTR, uType: UINT): int32 =

    restoreHook()
    MessageBoxA(hWnd, "Hooked!", "Hooked!", uType)
    if(fastTrampoline(true, cast[LPVOID](messageBoxAddress), cast[LPVOID](myMessageBox), nil)):
        echo "[+] Re-Hooked 'MessageBoxA'"
    else:
        echo "[-] Failed to re-hook 'MessageBoxA'"
    return 0

proc restoreHook() : void =
    var buffers: HookTrampolineBuffers
    buffers.originalBytes = cast[HANDLE](addr gHookedFunction.functionStub[0])
    buffers.originalBytesSize = DWORD(sizeof(gHookedFunction.functionStub))

    if(fastTrampoline(false, cast[LPVOID](messageBoxAddress), cast[LPVOID](myMessageBox), &buffers)):
        echo "[+] Restored 'MessageBoxA'"
    else:
        echo "[-] Failed to restore 'MessageBoxA'"

proc fastTrampoline(installHook: bool; addressToHook: LPVOID; jumpAddress: LPVOID;
                    buffers: ptr HookTrampolineBuffers): bool =
    var trampoline: seq[byte]
    if defined(amd64):
        trampoline = @[
            byte(0x49), byte(0xBA), byte(0x00), byte(0x00), byte(0x00), byte(0x00), byte(0x00), byte(0x00), # mov r10, addr
            byte(0x00),byte(0x00),byte(0x41), byte(0xFF),byte(0xE2)                                         # jmp r10
        ]
        var tempjumpaddr: uint64 = cast[uint64](jumpAddress)
        copyMem(&trampoline[2] , &tempjumpaddr, 6)
    elif defined(i386):
        trampoline = @[
            byte(0xB8), byte(0x00), byte(0x00), byte(0x00), byte(0x00), # mov eax, addr
            byte(0x00),byte(0x00),byte(0xFF), byte(0xE0)                                      # jmp eax
        ]
        var tempjumpaddr: uint32 = cast[uint32](jumpAddress)
        copyMem(&trampoline[1] , &tempjumpaddr, 3)
    
    var dwSize: DWORD = DWORD(len(trampoline))
    var dwOldProtect: DWORD = 0
    var output: bool = false
    

    if (installHook):
        if (buffers != nil):
            if ((buffers.previousBytes == 0) or buffers.previousBytesSize == 0):
                echo "[-] Previous Bytes == 0"
                return false
            copyMem(unsafeAddr buffers.previousBytes, addressToHook, buffers.previousBytesSize)

        if (VirtualProtect(addressToHook, dwSize, PAGE_EXECUTE_READWRITE, &dwOldProtect)):
            copyMem(addressToHook, addr trampoline[0], dwSize)
            output = true
    else:
        if (buffers != nil):
            if ((buffers.originalBytes == 0) or buffers.originalBytesSize == 0):
                echo "[-] Original Bytes == 0"
                return false

            dwSize = buffers.originalBytesSize

            if (VirtualProtect(addressToHook, dwSize, PAGE_EXECUTE_READWRITE, &dwOldProtect)):
                copyMem(addressToHook, cast[LPVOID](buffers.originalBytes), dwSize)
                output = true
    
    var status = ntFlushInstructionCache(GetCurrentProcess(), addressToHook, dwSize)
    if (status == 0):
        echo "[+] NtFlushInstructionCache success"
    else:
        echo "[-] NtFlushInstructionCache failed: ", toHex(status)
    VirtualProtect(addressToHook, dwSize, dwOldProtect, &dwOldProtect)

    return output

proc hookFunction(funcname: string, dllName: LPCSTR, hookFunction: LPVOID): bool =
    var addressToHook: LPVOID = cast[LPVOID](GetProcAddress(GetModuleHandleA(dllName), funcname))
    messageBoxAddress = cast[HANDLE](addressToHook)
    var buffers: HookTrampolineBuffers
    var output: bool = false
    
    if (addressToHook == nil):
        return false
        
    buffers.previousBytes = cast[HANDLE](addressToHook)
    buffers.previousBytesSize = DWORD(sizeof(addressToHook))
    gHookedFunction.origFunction = cast[typeMessageBox](addressToHook)
    var pointerToOrigBytes: LPVOID = addr gHookedFunction.functionStub
    copyMem(pointerToOrigBytes, addressToHook, 16)
    
    output = fastTrampoline(true, cast[LPVOID](addressToHook), hookFunction, &buffers)
    return output

echo "[*] Loading User32.dll"
var user32dll = LoadLibraryA("user32.dll")
if (user32dll == 0):
    echo "[-] Failed to load user32.dll"
    quit(1)

echo "[*] Getting the address of 'MessageBoxA'"
messageBoxAddress = cast[HANDLE](GetProcAddress(user32dll,"MessageBoxA"))
if (messageBoxAddress == 0):
    echo "[X] Failed to get the address of 'MessageBoxA'"
    quit(1)

messageBox = cast[typeMessageBox](messageBoxAddress)

echo "[*] Hooking 'MessageBoxA'"

if (hookFunction("MessageBoxA", "user32.dll", cast[LPVOID](myMessageBox))):
    echo "[+] Hooked 'MessageBoxA'"
else:
    echo "[-] Failed to hook 'MessageBoxA'"
    quit(1)

echo "[*] Calling Hooked MessageBoxA!"
discard messageBox(0, "Hello World", "Hello World", 0)

echo "[*] Restoring old MessageBoxA"
restoreHook()

echo "[*] Calling Original MessageBoxA!"
discard messageBox(0, "Hello World", "Hello World", 0)
