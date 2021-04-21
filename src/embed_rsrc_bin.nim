#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause
]#

import zippy/ziparchives
import strformat
import streams
import os

const MY_RESOURCE = slurp("../rsrc/super_secret_stuff.zip")

let path: string = getEnv("LOCALAPPDATA") / "Temp"

proc extractStuff(): bool =
    var archive = ZipArchive()
    let dataStream = newStringStream(MY_RESOURCE)

    archive.open(dataStream)
    archive.extractAll(path)
    archive.clear()

    return true

echo fmt"[*] Path to extract to: {path}"
if extractStuff():
    echo fmt"[*] extracted"
