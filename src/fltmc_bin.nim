#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    References:
        - https://github.com/nim-lang/Nim/pull/1260
        - https://github.com/matterpreter/Shhmon/blob/master/Shhmon/Win32.cs
        - https://github.com/gentilkiwi/mimikatz/blob/master/mimikatz/modules/kuhl_m_misc.c
        - https://docs.microsoft.com/en-us/windows-hardware/drivers/ddi/fltuserstructures/ns-fltuserstructures-_filter_aggregate_standard_information
]#

import winim
import strformat
import strutils
import unicode

const
    FLTFL_AGGREGATE_INFO_IS_MINIFILTER = 0x00000001
    FLTFL_AGGREGATE_INFO_IS_LEGACYFILTER = 0x00000002

type
    wchar_t {.importc.} = object

    MINI_FILTER = object
        Flags: culong
        FrameID: culong
        NumberOfInstances: culong
        FilterNameLength: cushort
        FilterNameBufferOffset: cushort
        FilterAltitudeLength: cushort
        FilterAltitudeBufferOffset: cushort

    LEGACY_FILTER = object
        Flags: culong
        FilterNameLength: cushort
        FilterNameBufferOffset: cushort
        FilterAltitudeLength: cushort 
        FilterAltitudeBufferOffset: cushort

    TYPE {.union.} = object
        MiniFilter: MINI_FILTER
        LegacyFilter: LEGACY_FILTER

    FILTER_AGGREGATE_STANDARD_INFORMATION {.pure.} = object
        NextEntryOffset: culong
        Flags: culong
        Type: TYPE

    PFILTER_AGGREGATE_STANDARD_INFORMATION= ptr FILTER_AGGREGATE_STANDARD_INFORMATION

    #[
    FILTER_AGGREGATE_BASIC_INFORMATION = object
        NextEntryOffset: uint
        Flags:  uint
    
    FILTER_FULL_INFORMATION = object
        NextEntryOffset: uint
        Flags:  uint
    ]#

    FILTER_INFORMATION_CLASS {.pure.} = enum
        FilterFullInformation = 0
        FilterAggregateBasicInformation
        FilterAggregateStandardInformation

proc FilterFindFirst(dwInformationClass: FILTER_INFORMATION_CLASS, lpBuffer: LPVOID, dwBufferSize: DWORD, lpBytesReturned: LPDWORD, lpFilterFind: LPHANDLE): HRESULT {.importc, dynlib:"fltlib", stdcall.}
proc FilterFindNext(hFilterFind: HANDLE, dwInformationClass: FILTER_INFORMATION_CLASS, lpBuffer: LPVOID, dwBufferSize: DWORD, lpBytesReturned: LPDWORD): HRESULT {.importc, dynlib:"fltlib", stdcall.}
proc FilterFindClose(hFilterFind: HANDLE): HRESULT {.importc, dynlib:"fltlib", stdcall.}

# This parsing is extremely naive but couldn't figure out how to properly extract the Filter Name and Altitude from their buffer offsets.
proc findAltitude(buf: string, altitude_len: int): int =
    var altitude = newString(altitude_len)
    var c_found: int = 0

    for c in buf:
        if c_found  == altitude_len:
            break

        if isDigit(c):
            altitude.add(c)
            c_found += 1
    
    return parseInt(strutils.strip(altitude, chars={'\0'}))

proc findFilterName(buf: string, filter_name_len: int): string =
    var filter_name = newString(filter_name_len)
    var c_found: int = 0

    for c in buf:
        if c_found ==  filter_name_len:
            break

        if isAlpha($c):
            filter_name.add(c)
            c_found += 1

    return strutils.strip(filter_name, chars={'\0'})


proc printFilterInfo(info: PFILTER_AGGREGATE_STANDARD_INFORMATION): void =
    case info.Flags:
        of FLTFL_AGGREGATE_INFO_IS_MINIFILTER:
            echo "--- Minifilter ---"

            var filter_len: int = int(cast[int](info.Type.MiniFilter.FilterNameLength) / sizeof(wchar_t))
            #echo fmt"    \---- Filter Name Length: {filter_len}"

            var filter_name = findFilterName($(&info.Type.MiniFilter.FilterNameBufferOffset), filter_len)
            echo fmt"    \---- Filter Name: {filter_name}"

            var alt_len: int = int(cast[int](info.Type.MiniFilter.FilterAltitudeLength) / sizeof(wchar_t))
            #echo fmt"    \---- Filter Altitude Length: {alt_len}"

            var filter_alt = findAltitude($(&info.Type.MiniFilter.FilterAltitudeBufferOffset), alt_len)
            echo fmt"    \---- Filter Altitude: {filter_alt}"

            echo fmt"    \---- Instances: {info.Type.MiniFilter.NumberOfInstances}"
            echo fmt"    \---- Frame: {info.Type.MiniFilter.FrameID}"

            echo ""
        of FLTFL_AGGREGATE_INFO_IS_LEGACYFILTER:
            echo "--- Legacy Filter (Not Supported) ---"
            echo repr(info)
        else:
            echo "--- Unknown filter type ---"

var
    szNeeded: DWORD
    hDevice: HANDLE
    res: HRESULT
    info, info2: PFILTER_AGGREGATE_STANDARD_INFORMATION
    nfilters: int = 0

res = FilterFindFirst(
    FILTER_INFORMATION_CLASS.FilterAggregateStandardInformation,
    NULL, 0, &szNeeded, &hDevice
)

if res == HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER):

    info = cast[PFILTER_AGGREGATE_STANDARD_INFORMATION](LocalAlloc(LPTR, szNeeded))
    res = FilterFindFirst(
        FILTER_INFORMATION_CLASS.FilterAggregateStandardInformation,
        info, szNeeded, &szNeeded, &hDevice
    )

    if res != S_OK:
        LocalFree(cast[HLOCAL](info))

    printFilterInfo(info)

    while true:
        res = FilterFindNext(hDevice, FILTER_INFORMATION_CLASS.FilterAggregateStandardInformation, NULL, 0, &szNeeded)

        if res == HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER):

            info2 = cast[PFILTER_AGGREGATE_STANDARD_INFORMATION](LocalAlloc(LPTR, szNeeded))
            res = FilterFindNext(hDevice, FILTER_INFORMATION_CLASS.FilterAggregateStandardInformation, info2, szNeeded, &szNeeded)
            if res == S_OK:
                printFilterInfo(info2)
            LocalFree(cast[HLOCAL](info2))
        
            #if res != S_OK or res != HRESULT_FROM_WIN32(ERROR_NO_MORE_ITEMS):
            #    dump res
            #    break

        nfilters += 1

        if res == HRESULT_FROM_WIN32(ERROR_NO_MORE_ITEMS):
            break

    echo fmt"[*] Enumerated {nfilters} minifilter(s)"

elif res == HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED):
    echo "[-] Access denied, not enough privs?"

discard FilterFindClose(hDevice)