#[
    References:
        - https://blog.ropnop.com/hosting-clr-in-golang/#part-1---loading-a-managed-dll-from-disk
        - https://gist.github.com/xpn/e95a62c6afcf06ede52568fcd8187cc2


        This mess seems to be the closest thing we're trying to do here as it's calling a function from a struct from a vtbl, my eyes bleed as a side affect of looking at it tho.
            - https://github.com/khchen/winim/blob/d300192c588f73dddef26e3c317f148aa23465c3/winim/inc/wincodec.nim 
]#

import winim/lean

const
    CLSID_CLRMetaHost = DEFINE_GUID(0x9280188d'i32, 0xe8e, 0x4867, [0xb3'u8, 0xc, 0x7f, 0xa8, 0x38, 0x84, 0xe8, 0xde])
    IID_ICLRMetaHost = DEFINE_GUID(0xD332DB9E'i32, 0xB9B3, 0x4125, [0x82'u8, 0x07, 0xA1, 0x48, 0x84, 0xF5, 0x32, 0x16])

    #[
        IID_ICLRRuntimeInfo = windows.GUID{0xBD39D1D2, 0xBA2F, 0x486a, [8]byte{0x89, 0xB0, 0xB4, 0xB0, 0xCB, 0x46, 0x68, 0x91}}
        CLSID_CLRRuntimeHost = windows.GUID{0x90F1A06E, 0x7712, 0x4762, [8]byte{0x86, 0xB5, 0x7A, 0x5E, 0xBA, 0x6B, 0xDB, 0x02}}
        IID_ICLRRuntimeHost = windows.GUID{0x90F1A06C, 0x7712, 0x4762, [8]byte{0x86, 0xB5, 0x7A, 0x5E, 0xBA, 0x6B, 0xDB, 0x02}}
        IID_ICorRuntimeHost = windows.GUID{0xcb2f6722, 0xab3a, 0x11d2, [8]byte{0x9c, 0x40, 0x00, 0xc0, 0x4f, 0xa3, 0x0a, 0x3e}}
        CLSID_CorRuntimeHost = windows.GUID{0xcb2f6723, 0xab3a, 0x11d2, [8]byte{0x9c, 0x40, 0x00, 0xc0, 0x4f, 0xa3, 0x0a, 0x3e}}
        IID_AppDomain = windows.GUID{0x5f696dc, 0x2b29, 0x3663, [8]uint8{0xad, 0x8b, 0xc4, 0x38, 0x9c, 0xf2, 0xa7, 0x13}}
    ]#

type
    ICLRMetaHost {.pure.} = object
        vtbl: ptr ICLRMetaHostHostVtbl

    ICLRMetaHostHostVtbl {.pure.} = object
        EnumerateInstalledRuntimes: proc(self: ptr ICLRMetaHost, pInstalledRuntimes: ptr ptr uint): HRESULT {.stdcall.}

        # We don't care about the rest of these
        QueryInterface: ptr uint
        AddRef: ptr uint
        Release: ptr uint
        GetRuntime: ptr uint
        GetVersionFromFile: ptr uint
        EnumerateLoadedRuntimes: ptr uint
        RequestRuntimeLoadedNotification: ptr uint 
        QueryLegacyV2RuntimeBinding: ptr uint
        ExitProcess: ptr uint

    ICLRRuntimeInfo {.pure.} = object
        vtbl: ptr ICLRRuntimeInfoVtbl

    ICLRRuntimeInfoVtbl {.pure.} = object
        QueryInterface: ptr uint
        AddRef: ptr uint
        Release: ptr uint
        GetVersionString: ptr uint
        GetRuntimeDirectory: ptr uint
        IsLoaded: ptr uint
        LoadErrorString: ptr uint
        LoadLibrary: ptr uint
        GetProcAddress: ptr uint
        GetInterface: ptr uint
        IsLoadable: ptr uint
        SetDefaultStartupFlags: ptr uint
        GetDefaultStartupFlags: ptr uint
        BindAsLegacyV2Runtime: ptr uint
        IsStarted: ptr uint

proc EnumerateInstalledRuntimes(self: ICLRMetaHost, pInstalledRuntimes: ptr ptr uint): HRESULT = {.gcsafe.}:
    self.vtbl.EnumerateInstalledRuntimes(self, pInstalledRuntimes)

proc CLRCreateInstance*(clsid: REFCLSID, riid: REFIID, ppInterface: LPVOID): HRESULT
    {.dynlib: "mscoree", importc: "CLRCreateInstance", stdcall, sideEffect.}

when isMainModule:
    var
        pMetaHost: ptr ICLRMetaHost = nil
        pInstalledRuntimes: ptr uint
        pRuntimeInfo: ptr ICLRRuntimeInfo = nil
        #pRuntimeHost: ptr ICLRRuntimeHost = nil
        #pEnumRuntime: ptr IUnknown = nil
        frameworkName: LPWSTR = nil
        bytes: DWORD = 2048
        result: DWORD = 0
        hr: HRESULT

    hr = CLRCreateInstance(
        cast[REFCLSID](unsafeAddr(CLSID_CLRMetaHost)),
        cast[REFIID](unsafeAddr(IID_ICLRMetaHost)),
        cast[ptr LPVOID](addr(pMetaHost))
    ) 
    
    if hr != S_OK:
        echo "[X] CLRCreateInstance() failed"

    echo repr(pMetaHost)

    hr = pMetaHost.EnumerateInstalledRuntimes(
        addr pInstalledRuntimes
    )
    
    if hr != S_OK:
        echo "[x] Error: EnumerateInstalledRuntimes()"

    echo repr(pInstalledRuntimes)
    
    #[
    frameworkName = cast[LPWSTR](LocalAlloc(LPTR, 2048))
    while runtime.Next(1, addr(pEnumRuntime), 0) == S_OK:
        if pEnumRuntime.QueryInterface < ICLRRuntimeInfo > (addr(pRuntimeInfo)) == S_OK:
            if pRuntimeInfo != nil:
                pRuntimeInfo.GetVersionString(frameworkName, addr(bytes))
                echo(fmt"[*] Supported Framework: {frameworkName}\n")

    ##  For demo, we just use the last supported runtime
    pRuntimeInfo.GetInterface(
        CLSID_CLRRuntimeHost,
        IID_ICLRRuntimeHost,
        cast[ptr LPVOID](addr(runtimeHost))
    )

    echo(fmt"[*] Using runtime: {frameworkName}\n")
    pRuntimeHost.Start()

    echo("[*] ======= Calling .NET Code =======\n\n")
    pRuntimeHost.ExecuteInDefaultAppDomain(
        "myassembly.dll",
        "myassembly.Program",
        "test",
        "argtest",
        addr(result)
    )
    echo("[*] ======= Done =======\n")
    ]#