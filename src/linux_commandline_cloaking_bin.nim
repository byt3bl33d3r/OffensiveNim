#[
    Author: @pathtofile
    License: BSD 3-Clause

    # Overview:
        This example demonstrates how to mess with our own arguments at runtime,
        to 'cloak' what the actual arguments and parent process is. It does:
            - Uses prctl syscall to change the value in /proc/<pid>/comm
            - Overwrites the address of argv[0] and argv[1] to fake the real values to tools such as ps.
            - Double-forks to make it's parent appear to be PID 1

        To edit our own argv, we need to overwrite Nim's default main function, which means
        taking control of setting up Nim's environment ourselves with a call to NimMain()

    # Building:
        nim compile --nomain --out:./linux_commandline_cloaking ./linux_commandline_cloaking.nim

    # Using:
        ./linux_commandline_cloaking

    # Reference:
        For more information see: https://github.com/pathtofile/commandline_cloaking/tree/main/dodgy
]#

import os
import posix
import strformat
import strutils

proc NimMain() {.cdecl, importc.}

# Use syscall function call from stdlib
proc syscall(number: clong): clong {.importc, varargs, header: "sys/syscall.h".}
var NR_PRCTL {.importc: "__NR_prctl", header: "unistd.h".}: int
var PR_SET_NAME {.importc: "PR_SET_NAME", header: "sys/prctl.h".}: int

proc memset(s: pointer, c: cint, n: csize_t): pointer {.importc, header: "string.h"}

# Compiled with --nomain so we overwrite Nim's default main func
proc main(argc: int, argv: cstringArray, envp: cstringArray): int {.cdecl, exportc.} =
    # Need to call NimMain ourselves first to avoid explosions
    NimMain()

    # Print data
    echo("-------- REAL --------")
    echo(fmt"  PID     {getpid()}")
    echo(fmt"  PPID    {getppid()}")
    echo(fmt"  argc    {argc}")
    for i in 0..(argc-1):
        echo(fmt"  argv[{i}] {argv[i]}")

    # Double-fork to make parent pid look like PID 1
    var childPID = fork()
    if childPID != 0:
        # First parent, exit
        return 0
    childPID = fork()
    if childPID != 0:
        # Second parent, exit
        return 0

    # Use prctl syscall to change /proc/pid/comm
    var err = syscall(NR_PRCTL, PR_SET_NAME, cstring("faked"))
    if err < 0:
        echo(fmt"Error calling PRCTL {err}")
        return -1

    # Overwrite args, have to use 'memset'
    discard memset(argv[0], ord('F'), csize_t(len(argv[0])))
    if argc > 1:
        discard memset(argv[1], ord('B'), csize_t(len(argv[1])))

    # Sleep for a second for parent to be reaped
    # and PID 1 to adopt us
    sleep(1 * 1000)

    # Print data
    echo("---- FORK & FAKE -----")
    echo(fmt"  PID     {getpid()}")
    echo(fmt"  PPID    {getppid()}")
    echo(fmt"  argc    {argc}")
    for i in 0..(argc-1):
        echo(fmt"  argv[{i}] {argv[i]}")

    echo("----------------------")
    echo("  Sleeping for 60 seconds so you can lookup the PID")
    setControlCHook(proc() {.noconv.} = discard)
    sleep(60 * 1000)

    return 0
