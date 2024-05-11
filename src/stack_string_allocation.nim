#[
    Author: zimawhit3 & m4ul3r (@m4ul3r_0x00)
    Source: https://github.com/zimawhit3/Bitmancer/blob/main/src/Bitmancer/core/str.nim
    License: BSD 3-Clause

    Description: 
      Allocate a CString or WString on the stack using macros.
    
      Stack strings can be created manually with the following:
        var ss: array[10, char]
        ss[0] = 'A'
        ss[1] = 'B'
        ...

      Using the macro below will modify Nim's AST to transform a regular string this at compile time. 

      See the usage in the `main` procedure on how to use these macros.
]#

import std/[macros]

proc assignChars(smt: NimNode, varName: NimNode, varValue: string, wide: bool) {.compileTime.} =
  var
    asnNode:        NimNode
    bracketExpr:    NimNode
    dotExpr:        NimNode
    castIdent:      NimNode
  for i in 0 ..< varValue.len():
    asnNode     = newNimNode(nnkAsgn)
    bracketExpr = newNimNode(nnkBracketExpr)
    dotExpr     = newNimNode(nnkDotExpr)
    castIdent   =
      if wide:    ident"uint16"
      else:       ident"uint8"
    bracketExpr.add(varName)
    bracketExpr.add(newIntLitNode(i))
    dotExpr.add(newLit(varValue[i]))
    dotExpr.add(castIdent)
    asnNode.add bracketExpr
    asnNode.add dotExpr
    smt.add asnNode
  asnNode     = newNimNode(nnkAsgn)
  bracketExpr = newNimNode(nnkBracketExpr)
  dotExpr     = newNimNode(nnkDotExpr)
  bracketExpr.add(varName)
  bracketExpr.add(newIntLitNode(varValue.len()))
  dotExpr.add(newLit(0))
  dotExpr.add(castIdent)
  asnNode.add bracketExpr
  asnNode.add dotExpr
  smt.add asnNode

proc makeBracketExpression(s: string, wide: static bool): NimNode =
  result = newNimNode(nnkBracketExpr)
  result.add ident"array"
  result.add newIntLitNode(s.len() + 1)
  if wide:    result.add ident"uint16"
  else:       result.add ident"byte"

macro stackStringA*(sect) =
  result = newStmtList()
  let
    def = sect[0]
    bracketExpr = makeBracketExpression(def[2].strVal, false)
    identDef = newIdentDefs(def[0], bracketExpr)
    varSect = newNimNode(nnkVarSection).add(identDef)
  result.add(varSect)
  result.assignChars(def[0], def[2].strVal, false)

macro stackStringW*(sect) =
  result = newStmtList()
  let
    def = sect[0]
    bracketExpr = makeBracketExpression(def[2].strVal, true)
    identDef = newIdentDefs(def[0], bracketExpr)
    varSect = newNimNode(nnkVarSection).add(identDef)
  result.add(varSect)
  result.assignChars(def[0], def[2].strVal, true)


#[ EXAMPLE CODE ]#
import std/[strformat, strutils, widestrs]
proc main() =
  # initialize a stackStringA
  var stackStr1 {.stackStringA.} = "I am a stackStringA"
  # get a pointer to the stack string
  let pStackStr1 = cast[pointer](stackStr1[0].addr)

  stdout.writeLine("stackStringA:")
  stdout.writeLine(&"\tAddress : 0x{cast[int](pStackStr1).toHex}")
  stdout.writeLine(&"\tContents: {cast[cstring](pStackStr1)}")
  stdout.writeLine(&"\tLength  : {stackStr1.len}")
  stdout.writeLine(&"\tVar Type: {$type(stackStr1)}\n")

  # initialize a stackStringW
  var stackStr2 {.stackStringW.} = "I am a stackStringW"
  # get a pointer to the stack string
  let pStackStr2 = cast[pointer](stackStr2[0].addr)

  stdout.writeLine("stackStringW:")
  stdout.writeLine(&"\tAddress : 0x{cast[int](pStackStr2).toHex}")
  # Cast the array to a WideCString for printing
  stdout.writeLine(&"\tContents: {cast[WideCString](pStackStr2)}")
  stdout.writeLine(&"\tLength  : {stackStr2.len}")
  stdout.writeLine(&"\tVar Type: {$type(stackStr2)}\n")

  # initialize a nim string - this is stored in the 
  var nimStr1 = "I am a Nim String"
  # get a pointer to the nim string
  var pNimStr1 = cast[pointer](nimStr1[0].addr)
  stdout.writeLine("NimString:")
  stdout.writeLine(&"\tAddress : 0x{cast[int](pNimStr1).toHex}")
  stdout.writeLine(&"\tContents: {cast[cstring](pNimStr1)}")
  stdout.writeLine(&"\tLength  : {nimStr1.len}")
  stdout.writeLine(&"\tVar Type: {$type(nimStr1)}")

when isMainModule:
  main()