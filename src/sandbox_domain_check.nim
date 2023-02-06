#[
    Author: Shashwat Shah, Twitter: @0xEr3bus
    License: BSD 3-Clause
    Using Network Management Windows API to check if the computer is connected to domain. Used for sandbox evasion.
    References:
        - https://ppn.snovvcrash.rocks/red-team/maldev/sandbox-evasion
        - https://github.com/khchen/winim/blob/a485708a243e2f2acbce783027b8cf8582536414/winim/inc/lm.nim#L3988
        - https://learn.microsoft.com/en-us/windows/win32/api/lmjoin/nf-lmjoin-netgetjoininformation
    Compile:
        nim c -d=mingw --app=console --checks:off -d:danger --deadCodeElim:op --hints:off --passc=-flto --passl=-flto --stackTrace:off --lineTrace:off -d:strip --opt:size --cpu=amd64 sandbox_domain_check.nim
        strip sandbox_domain_check.exe; upx sandbox_domain_check.exe
]#

import winim


proc IsDomainJoined(): bool =
    var joined = false
    var lpNameBuffer: LPWSTR
    lpNameBuffer = nil
    var joinStatus: NETSETUP_JOIN_STATUS
    joinStatus = netSetupUnknownStatus
    var status: NET_API_STATUS
    status = NetGetJoinInformation(lpNameBuffer, &lpNameBuffer, &joinStatus)
    if status == NERR_Success:
        joined = joinStatus == netSetupDomainName

    if lpNameBuffer != nil:
        NetApiBufferFree(lpNameBuffer)

    return joined


var result = IsDomainJoined()
if not result:
    echo "[-] Wrong choice, you aren't connected!"
    quit(1)
else:
    echo "[+] Sounds Fair, you are connected!"
    quit(0)
