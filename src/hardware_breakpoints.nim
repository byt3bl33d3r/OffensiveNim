#[
    Author: m4ul3r (@m4ul3r_0x00)
    Reference: Maldev Academy
    License: BSD 3-Clause

    Description: 
      Utilize Hardware Breakpoints to hook functions. 
      See "EXMAPLE USAGE" on how to use hardware breakpoints.
]#

import winim/lean

type
  DRX = enum
    Dr0, Dr1, Dr2, Dr3
  HookFuncType = proc(pContext:PCONTEXT){.stdcall.}

var 
  g_VectorHandler: PVOID              # Vectored Exception Handler
  g_DetourFuncs: array[4, PVOID]      # Array of 4 Hook functions
  g_CriticalSection: CRITICAL_SECTION

proc ucRet() {.asmNoStackFrame.} = 
  ## Ret used to terminate original function execution
  asm """.byte 0xc3"""

proc BLOCK_REAL(pThreadCtx: PCONTEXT) =
  ## Used in detour function to block execution of original hooked function
  pThreadCtx.Rip = cast[int](ucRet)

proc setDr7Bits(currentDr7Register, startingBitPosition, nmbrOfBitsToModify, newBitValue: int): int =
  ## Enable or disable an installed breakpoint
  var
    mask: int = ((1 shl nmbrOfBitsToModify) - 1)
    newDr7Register: int = (currentDr7Register and not (mask shl startingBitPosition)) or (newBitValue shl startingBitPosition)
  return newDr7Register
  
proc setHardwareBreakpoint(pAddress: PVOID, fnHookFunc: PVOID, drx: DRX): bool = 
  var threadCtx: CONTEXT
  threadCtx.ContextFlags = CONTEXT_DEBUG_REGISTERS

  if GetThreadContext(cast[HANDLE](-2), threadCtx.addr) == 0:
    echo "[!] GetThreadContext Failed: ", GetLastError()
    return false
  
  case drx:
  of Dr0:
    if (threadCtx.Dr0 == 0):
      threadCtx.Dr0 = cast[int](pAddress)
  of Dr1:
    if (threadCtx.Dr1 == 0):
      threadCtx.Dr1 = cast[int](pAddress)
  of Dr2:
    if (threadCtx.Dr2 == 0):
      threadCtx.Dr2 = cast[int](pAddress)
  of Dr3:
    if (threadCtx.Dr3 == 0):
      threadCtx.Dr3 = cast[int](pAddress)
  
  # Save the hooked function at index 'drx' in global array
  EnterCriticalSection(g_CriticalSection.addr)
  g_DetourFuncs[cast[int](drx)] = fnHookFunc
  LeaveCriticalSection(g_CriticalSection.addr)

  # Enable the breakpoint
  threadCtx.Dr7 = setDr7Bits(threadCtx.Dr7, (cast[int](drx) * 2), 1, 1)

  if SetThreadContext(cast[HANDLE](-2), threadCtx.addr) == 0:
    echo "[!] SetThreadContext Failed", GetLastError()
    return false

  return true

proc removeHardwareBreakpoint(drx: DRX): bool =
  var threadCtx: CONTEXT
  threadCtx.ContextFlags = CONTEXT_DEBUG_REGISTERS

  if GetThreadContext(cast[HANDLE](-2), threadCtx.addr) == 0:
    echo "[!] GetThreadContext Failed: ", GetLastError()
    return false

  # Remove the address of the hooked function from the thread context
  case drx:
  of Dr0:
    threadCtx.Dr0 = cast[int](0)
  of Dr1:
    threadCtx.Dr1 = cast[int](0)
  of Dr2:
    threadCtx.Dr2 = cast[int](0)
  of Dr3:
    threadCtx.Dr3 = cast[int](0)

  # Disabling the breakpoint
  threadCtx.Dr7 = setDr7Bits(threadCtx.Dr7, (cast[int](drx) * 2), 1, 0)

  if SetThreadContext(cast[HANDLE](-2), threadCtx.addr) == 0:
    echo "[!] SetThreadContext Failed", GetLastError()
    return false

  return true

proc vectorHandler(pExceptionInfo: ptr EXCEPTION_POINTERS): int = 
  # If the exception is 'EXCEPTION_SINGLE_STEP' then its caused by a bp
  if (pExceptionInfo.ExceptionRecord.ExceptionCode == EXCEPTION_SINGLE_STEP):
    if (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr0) or
      (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr1) or
      (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr2) or 
      (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr3):
      var 
        dwDrx: DRX
        fnHookFunc = cast[HookFuncType](0)
      
      EnterCriticalSection(g_CriticalSection.addr)

      if (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr0):
        dwDrx = Dr0
      if (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr1):
        dwDrx = Dr1
      if (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr2):
        dwDrx = Dr2
      if (cast[int](pExceptionInfo.ExceptionRecord.ExceptionAddress) == pExceptionInfo.ContextRecord.Dr3):
        dwDrx = Dr3
      
      discard removeHardwareBreakpoint(dwDrx)

      # Execute the callback (detour function)
      fnHookFunc = cast[HookFuncType](g_DetourFuncs[cast[int](dwDrx)])
      fnHookFunc(pExceptionInfo.ContextRecord)

      discard setHardwareBreakpoint(pExceptionInfo.ExceptionRecord.ExceptionAddress, g_DetourFuncs[cast[int](dwDrx)], dwDrx)

      LeaveCriticalSection(g_CriticalSection.addr)

      return EXCEPTION_CONTINUE_EXECUTION
  # The exception is not handled
  return EXCEPTION_CONTINUE_SEARCH

#[ Function argument handling ]#
proc getFunctionArgument(pThreadCtx: PCONTEXT, dwParamIdx: int): pointer =
  # amd64
  case dwParamIdx:
  of 1:
    return cast[PULONG](pThreadCtx.Rcx)
  of 2:
    return cast[PULONG](pThreadCtx.Rdx)
  of 3:
    return cast[PULONG](pThreadCtx.R8)
  of 4:
    return cast[PULONG](pThreadCtx.R9)
  else:
    # else more arguments are pushed to the stack
    return cast[PULONG](pThreadCtx.Rsp + (dwParamIdx * sizeof(PVOID)))

proc setFunctionArgument(pThreadCtx: PCONTEXT, uValue: PULONG, dwParamIdx: int) =
  # amd64
  case dwParamIdx:
  of 1:
    pThreadCtx.Rcx = cast[int](uValue)
  of 2:
    pThreadCtx.Rdx = cast[int](uValue)
  of 3:
    pThreadCtx.R8 = cast[int](uValue)
  of 4:
    pThreadCtx.R9 = cast[int](uValue)
  else:
    # else more arguments are pushed to the stack
    cast[ptr int](pThreadCtx.Rsp + (dwParamIdx * sizeof(PVOID)))[] = cast[int](uValue)

# getFunctionArgument macros
template GETPARAM_1(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 1)
template GETPARAM_2(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 2)
template GETPARAM_3(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 3)
template GETPARAM_4(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 4)
template GETPARAM_5(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 5)
template GETPARAM_6(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 6)
template GETPARAM_7(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 7)
template GETPARAM_8(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 8)
template GETPARAM_9(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, 9)
template GETPARAM_a(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, a)
template GETPARAM_b(ctx: PCONTEXT): pointer = getFunctionArgument(ctx, b)

# setFunctionArgument macros
template SETPARAM_1(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 1)
template SETPARAM_2(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 2)
template SETPARAM_3(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 3)
template SETPARAM_4(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 4)
template SETPARAM_5(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 5)
template SETPARAM_6(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 6)
template SETPARAM_7(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 7)
template SETPARAM_8(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 8)
template SETPARAM_9(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, 9)
template SETPARAM_a(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, a)
template SETPARAM_b(ctx: PCONTEXT, value: untyped) = setFunctionArgument(ctx, value, b)

#[ init/uninit HW BP]#
proc initializeHardwareBPVariables(): bool =
  # If 'g_CriticalSection' is not yet initialized
  if g_CriticalSection.DebugInfo == NULL:
    InitializeCriticalSection(g_CriticalSection.addr)
  
  # If 'g_VectorHandler' is not yet initialized
  if (cast[int](g_VectorHandler) == 0):
    # Add 'VectorHandler' as the VEH
    g_VectorHandler = AddVectoredExceptionHandler(1, cast[PVECTORED_EXCEPTION_HANDLER](vectorHandler))
    if cast[int](g_VectorHandler) == 0:
      echo "[!] AddVectoredExceptionHandler Failed"
      return false
  
  if (cast[int](g_VectorHandler) and cast[int](g_CriticalSection.DebugInfo)) != 0:
    return true

proc uninitializeHardwareBPVariables() =
  # Remove breakpoints
  for i in 0 ..< 4:
    discard removeHardwareBreakpoint(cast[DRX](i))
  # If the critical section is initialized, delete it
  if (cast[int](g_CriticalSection.DebugInfo) != 0):
    DeleteCriticalSection(g_CriticalSection.addr)
  # If VEH if registered, remove it
  if (cast[int](g_VectorHandler) != 0):
    RemoveVectoredExceptionHandler(g_VectorHandler)
  
  # Cleanup the global variables
  zeroMem(g_CriticalSection.addr, sizeof(g_CriticalSection))
  zeroMem(g_DetourFuncs.addr, sizeof(g_DetourFuncs))
  g_VectorHandler = cast[PVOID](0)

template CONTINUE_EXECUTION(ctx: PCONTEXT) = (ctx.EFlags = (ctx.EFlags or (1 shl 16)))


#[ EXMAPLE USAGE ]#
proc MessageBoxADetour(pThreadCtx: PCONTEXT) =
  echo "[i] MessageBoxA's Old Parameters:"
  echo "    [i] ", cast[cstring](GETPARAM_2(pThreadCtx))
  echo "    [i] ", cast[cstring](GETPARAM_3(pThreadCtx))

  var msg1 = "HOOKED".cstring
  var msg2 = "HOOKED".cstring
  SETPARAM_2(pThreadCtx, cast[PULONG](msg1[0].addr))
  SETPARAM_3(pThreadCtx, cast[PULONG](msg2[0].addr))
  SETPARAM_4(pThreadCtx, cast[PULONG](MB_OK or MB_ICONEXCLAMATION))

  # CONTINUTE_EXECUTION needs to be called in the hooked function
  CONTINUE_EXECUTION(pThreadCtx)

proc main() =
  # initialize
  if not initializeHardwareBPVariables():
    echo "[!] Failed to initialize"
    quit(1)
  
  MessageBoxA(0, "Normal 1", "Normal 1", MB_OK)

  echo "[i] Installing Hooks..."
  if not setHardwareBreakpoint(MessageBoxA, MessageBoxADetour, Dr0):
    quit(1)

  MessageBoxA(0, "Should be hooked", "Should be hooked", MB_OK)

  # Unhooking the installed hook on 'Dr0'
  echo "[i] Uninstalling Hooks..."
  if not removeHardwareBreakpoint(Dr0):
    quit(1)
  
  #[ NOT HOOKED ]#
  MessageBoxA(0, "Normal 2", "Normal 2", MB_OK)

  # Clean up
  uninitializeHardwareBPVariables()
  stdout.write "[#] Press <Enter> to Quit ..."
  discard stdin.readLine()

when isMainModule:
  main()