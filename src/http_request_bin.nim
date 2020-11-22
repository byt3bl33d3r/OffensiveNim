#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    You have 4 options (that I'm aware of at the time of writing) to make an HTTP request with Nim from Windows:

    - Use Nim's builtin httpclient library (which has it's own HTTP implementation and uses raw sockets)
        - Warning: httpclient module currently doesn't perform cert validation, see https://nim-lang.org/docs/httpclient.html#sslslashtls-support

    - Use the WinHttp Com Object (through Winim) apperently that's a thing. Either didn't know about it or forgot about it.

    - Use Winim's wininet or winhttp modules which call their respective Windows API's

    - Use the IE Com Object (through Winim)
    
    The first two of those are by far the easiest.

    References:
        - https://github.com/khchen/winim/blob/master/examples/com/InternetExplorer_Application.nim
        - https://github.com/khchen/winim/blob/master/examples/com/WinHttp_WinHttpRequest.nim

]#


import winim/com
import httpclient

echo "[*] Using httpclient"
var client = newHttpClient()
echo client.getContent("https://ifconfig.me")

echo "[*] Using the WinHTTP.WinHttpRequest COM Object"
var obj = CreateObject("WinHttp.WinHttpRequest.5.1")
obj.open("get", "https://ifconfig.me")
obj.send()
echo obj.responseText
