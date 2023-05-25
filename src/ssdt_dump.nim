when not defined(windows):
    {.error: "This module is only supported on Windows".}

# Import required libs
import strutils
import strformat

# Import external libs
import ptr_math
import winim

type
    Syscall = object
        ssn: int
        name: string
        address: int64
        
    IMAGE_RUNTIME_FUNCTION_ENTRY_UNION {.pure, union.} = object
        UnwindInfoAddress: DWORD
        UnwindData: DWORD
    
    IMAGE_RUNTIME_FUNCTION_ENTRY {.pure.} = object
        BeginAddress: DWORD
        EndAddress: DWORD
        u1: IMAGE_RUNTIME_FUNCTION_ENTRY_UNION
    PIMAGE_RUNTIME_FUNCTION_ENTRY = ptr IMAGE_RUNTIME_FUNCTION_ENTRY

## utils from https://github.com/khchen/memlib/blob/master/memlib.nim
template `++`[T](p: var ptr T) =
    ## syntax sugar for pointer increment
    p = cast[ptr T](p[int] +% sizeof(T))

proc `[]`[T](x: T, U: typedesc): U {.inline.} =
    ## syntax sugar for cast
    when sizeof(U) > sizeof(x):
        when sizeof(x) == 1: cast[U](cast[uint8](x).uint64)
        elif sizeof(x) == 2: cast[U](cast[uint16](x).uint64)
        elif sizeof(x) == 4: cast[U](cast[uint32](x).uint64)
        else: cast[U](cast[uint64](x))
    else:
        cast[U](x)

proc `{}`[T](x: T, U: typedesc): U {.inline.} =
    ## syntax sugar for zero extends cast
    when sizeof(x) == 1: x[uint8][U]
    elif sizeof(x) == 2: x[uint16][U]
    elif sizeof(x) == 4: x[uint32][U]
    elif sizeof(x) == 8: x[uint64][U]
    else: {.fatal.}
    
proc `{}`[T](p: T, x: SomeInteger): T {.inline.} =
    ## syntax sugar for pointer (or any other type) arithmetics
    (p[int] +% x{int})[T]
##

# Use RunTime Function table from exception directory to gather SSN: https://www.mdsec.co.uk/2022/04/resolving-system-service-numbers-using-the-exception-directory/
iterator syscalls(codeBase: pointer, exports: PIMAGE_EXPORT_DIRECTORY, rtf: PIMAGE_RUNTIME_FUNCTION_ENTRY): (string, int, DWORD) =
    var
        i: int = 0
        ssn: int = 0
    
    # Loop runtime function table
    while rtf[i].BeginAddress:
        let current = rtf[i].BeginAddress
        # Reset pointers
        var
            nameRef = codeBase{exports.AddressOfNames}[PDWORD]
            funcRef = codeBase{exports.AddressOfFunctions}[PDWORD]
            ordinal = codeBase{exports.AddressOfNameOrdinals}[PWORD]
        
        # Search Begin Address in Export Table
        for j in 0 ..< exports.NumberOfFunctions:
            let
                syscall = $(codeBase{nameRef[]}[LPCSTR])
                offset = funcRef[ordinal[j][int]]
            
            # Check offset with current function, ensure this is a syscall
            if (offset == current) and syscall.startsWith("Zw"):
                yield (syscall, ssn, offset)
                # Increase syscall number
                ssn += 1
                break

            ++nameRef

        # Go next address
        i += 1

proc lpwstrc(bytes: array[MAX_PATH, WCHAR]): string =
    result = newString(bytes.len)
    for i in bytes:
        result &= cast[char](i)
    result = strip(result, chars = {cast[char](0)})

proc listSyscalls(codeBase: pointer): seq[Syscall] =
    # Extract headers
    let dosHeader = cast[PIMAGE_DOS_HEADER](codeBase)
    let ntHeader = cast[PIMAGE_NT_HEADERS](cast[DWORD_PTR](codeBase) + dosHeader.e_lfanew)
    
    # Get export table
    let directory = ntHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT]
    let exports = codeBase{directory.VirtualAddress}[PIMAGE_EXPORT_DIRECTORY]
    
    # Get runtime functions table
    let dirExcept = ntHeader.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXCEPTION]
    let rtf = codeBase{dirExcept.VirtualAddress}[PIMAGE_RUNTIME_FUNCTION_ENTRY] 
    
    # Resolve ssn & offset
    for name, ssn, offset in codeBase.syscalls(exports, rtf):
        var entry = Syscall(name: name, ssn: ssn)
        # Calculate syscall address
        entry.address = cast[int64](codeBase + offset)
        result.add(entry)
    
    return result

proc getInfos(me32: MODULEENTRY32): (string, string) =
    let
        modPath = lpwstrc(me32.szExePath)
        infos = modPath.split("\\")
        modName = infos[^1].toLower()
        modAddr = toHex(cast[int64](me32.modBaseAddr))
    
    return (modName, modAddr)

proc dumpSSDT(pid: DWORD): seq[Syscall] =
    # Create module snapshot
    let hModule = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, pid)
    defer: CloseHandle(hModule)

    # Store process handle
    let handle = OpenProcess(PROCESS_ALL_ACCESS, FALSE, pid)

    var
        me32: MODULEENTRY32
        mi: MODULEINFO

    me32.dwSize = cast[DWORD](sizeof(MODULEENTRY32))

    # SKip to ntdll.dll
    hModule.Module32First(addr me32)
    hModule.Module32Next(addr me32)

    # Infos about dll
    let (modName, modAddr) = me32.getInfos()
    echo &"[+] {modName} -> loaded @ 0x{modAddr}"
    handle.GetModuleInformation(me32.hModule, addr mi, cast[DWORD](sizeof(mi)))

    return listSyscalls(mi.lpBaseOfDll)
    
when isMainModule:
    # Could set arg parse to check different process
    let pid = GetCurrentProcessId()
    
    for entry in dumpSSDT(pid):
        # You have now everything to rebuild syscall stub...
        echo &"\t. 0x{entry.address.toHex()}\t{entry.ssn}\t{entry.name}"