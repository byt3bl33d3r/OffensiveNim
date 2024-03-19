#[
    Author: @0xC130D
    License: BSD 3-Clause
]#

import winim/lean

proc listProcesses() =
    var 
        returnLengthA: ULONG = 0
        returnLengthB: ULONG = 0
    
    # Get size of data using a dummy call
    NtQuerySystemInformation(systemProcessInformation, NULL, 0, addr returnLengthA)
    
    # Allocate memory now that we know the size of the results
    var system_process_info = newSeq[byte](returnLengthA)
    
    # The actual call
    var STATUS: NTSTATUS = NtQuerySystemInformation(
        systemProcessInformation, 
        addr system_process_info[0], 
        returnLengthA, 
        addr returnLengthB)
    
    if STATUS != 0:
        echo "[!] - Unable to query system info. Error: ", GetLastError()
        return
 
    var 
        offset = 0
        sysproc: PSYSTEM_PROCESS_INFORMATION
    
    echo "PID \t- Name"
    # We use a pointer to SYSTEM_PROCESS_INFORMATION because we are looping with pointer math
    while true:
        sysproc = cast[PSYSTEM_PROCESS_INFORMATION](addr system_process_info[offset])
        if sysproc.NextEntryOffset == 0:
            echo "End Of List..."
            break
        
        offset += sysproc.NextEntryOffset
        echo sysproc.UniqueProcessId, "\t- ", sysproc.ImageName.Buffer
        

if isMainModule:
    listProcesses()