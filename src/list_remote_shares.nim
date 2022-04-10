import winim
import std/parseopt
import os

var target = ""
var p = initOptParser(commandLineParams())
while true:
  p.next()
  case p.kind
  of cmdEnd: break
  of cmdArgument:
    target = p.key
  else:
    discard
if target == "":
    echo("Usage: ", getAppFilename(), " <serverName>")
    quit(1)
    
var structSize = sizeOf(typeof(SHARE_INFO_502))
var buf: PSHARE_INFO_502
var entriesread: DWORD
entriesread = 0
var totalentries: DWORD
totalentries = 0
var resume_handle: DWORD
resume_handle = 0
var ret = NetShareEnum(target,502,cast[ptr LPBYTE](&buf), MAX_PREFERRED_LENGTH, &entriesread, &totalentries,&resume_handle)
if NT_SUCCESS(ret) == true:
    var currentPtr = buf
    for i in 1 .. entriesread:
        echo(currentPtr.shi502_netname, " -> ", currentPtr.shi502_path)
        currentPtr = cast[PSHARE_INFO_502](cast[int](currentPtr) + cast[int](structSize))
    NetApiBufferFree(buf);


