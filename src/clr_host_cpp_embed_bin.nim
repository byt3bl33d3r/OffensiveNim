#[

    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    This was an initial attempt at trying to embed the CLR before Winim 3.6.0 was out (which now supports all of the necessary API calls to load .NET assemblies).

    If anything it was a pretty cool excercise and an example of how to embed C++ directly within Nim.

    Few thangs:
        - When using Nim's C++ backend and cross-compiling to Windows you need to statically link the binaries by passing the '-static' flag to the linker. 
          Otherwise the resulting binaries will **not** run (Seems like a bug?)

        - This particular example will only work on x64 machines and requires the metahost.h and mscoree.lib files (in the rsrc directory).
          Both of those files were stolen directly from my Windows VM. If you want to compile to x86 you need to grab the x86 version of mscoree.lib.

    Gr33tz & huge thanks to Pancho for helping me get this to work.

    References:
        - https://gist.github.com/xpn/e95a62c6afcf06ede52568fcd8187cc2#gistcomment-2553021

]#

{.passL:"-L ./rsrc -l mscoree -static".}
{.passC:"-I ./rsrc".}

when not defined(cpp):
    {.error: "Must be compiled in cpp mode"}

{.emit: """
#include <iostream>
#include <windows.h>
#include <metahost.h>
#include <mscoree.h>

//#pragma comment(lib, "mscoree.lib")

//const IID CLSID_CLRRuntimeHost;
//const IID IID_ICLRRuntimeHost;

EXTERN_GUID(CLSID_CLRRuntimeHost, 0x90F1A06E, 0x7712, 0x4762, 0x86, 0xB5, 0x7A, 0x5E, 0xBA, 0x6B, 0xDB, 0x02);
EXTERN_GUID(IID_ICLRRuntimeHost, 0x90F1A06C, 0x7712, 0x4762, 0x86, 0xB5, 0x7A, 0x5E, 0xBA, 0x6B, 0xDB, 0x02);
//DEFINE_GUID(CLSID_CLRRuntimeHost, 0x90f1a06e,0x7712,0x4762,0x86,0xb5,0x7a,0x5e,0xba,0x6b,0xdb,0x02);
//DEFINE_GUID(IID_ICLRRuntimeHost, 0x90f1a06c, 0x7712, 0x4762, 0x86,0xb5, 0x7a,0x5e,0xba,0x6b,0xdb,0x02);

int RunAssembly()
{
    ICLRMetaHost* metaHost = NULL;
    ICLRRuntimeInfo* runtimeInfo = NULL;
    ICLRRuntimeHost* runtimeHost = NULL;

    if (CLRCreateInstance(CLSID_CLRMetaHost, IID_ICLRMetaHost, (LPVOID*)&metaHost) == S_OK) {
        if (metaHost->GetRuntime(L"v4.0.30319", IID_ICLRRuntimeInfo, (LPVOID*)&runtimeInfo) == S_OK) {
            if (runtimeInfo->GetInterface(CLSID_CLRRuntimeHost, IID_ICLRRuntimeHost, (LPVOID*)&runtimeHost) == S_OK) {
                if (runtimeHost->Start() == S_OK)
                {
                    std::cout << "Loading random.dll!\n";
                    DWORD pReturnValue;
                    runtimeHost->ExecuteInDefaultAppDomain(L"C:\\random.dll", L"dllNamespace.dllClass", L"ShowMsg", L"It works!!", &pReturnValue);
            
                    runtimeInfo->Release();
                    metaHost->Release();
                    runtimeHost->Release();
                }
            }
        }
    }
    return 0;
}
""".}

proc RunAssembly(): int
    {.importcpp: "RunAssembly", nodecl.}

when isMainModule:
    var result = RunAssembly()
    echo "[*] Assembly executed: ", bool(result)
