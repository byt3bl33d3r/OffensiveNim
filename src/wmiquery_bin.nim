#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Winim's examples are extremely useful

    Reference:
      - https://github.com/khchen/winim/blob/df04327df3016888e43d01c464b008d619253198/examples/com/diskinfo.nim
]#

import winim/com

echo "Getting installed AV products"
var wmi = GetObject(r"winmgmts:{impersonationLevel=impersonate}!\\.\root\securitycenter2")
for i in wmi.execQuery("SELECT displayName FROM AntiVirusProduct"):
    echo "AntiVirusProduct: ", i.displayName

echo "\n"

echo "Getting processes"
wmi = GetObject(r"winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
for i in wmi.execQuery("select * from win32_process"):
  echo i.handle, ", ", i.name
