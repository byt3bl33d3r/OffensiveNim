#[
    Author: HuskyHacks
    License: BSD 3-Clause

    Compile:
        nim c -d:mingw --cpu=amd64 --app=console simpleAntiAnalysis.nim
]#

import winim

# If you want to see the console out with an --app=console build, uncomment this import
# import strformat

# Uncomment for convinience breakpoint function that hangs the program until you hit enter in the console window
# proc breakpoint(): void =
#     discard(readLine(stdin))

# Using winim's library to perform the check and convert the WINBOOL result into a simple bool for ease of access
proc checkForDebugger(): bool =
    winimConverterBOOLToBoolean(IsDebuggerPresent())

proc main(): void =
    let debuggerIsDetected = checkForDebugger()
    # Uncomment to see the console output in an --app=console build
    # echo fmt"[*] Debugger Detected: {debuggerIsDetected}"

    if debuggerIsDetected:
        MessageBox(0, "Oh, you think you're slick, huh? I see your debugger over there. No soup for you!", "MEGASUSBRO", 0)
        quit(1)
    else:
        MessageBox(0, "No debugger detected! Cowabunga, dudes!", "COAST IS CLEAR", 0)
        MessageBox(0, "Boom!", "PAYLOAD", 0)
    
    # Breakpoint for convinience
    # breakpoint()

when isMainModule:
    main()