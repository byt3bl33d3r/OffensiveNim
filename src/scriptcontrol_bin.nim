#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    Stolen from Winim's examples with a few modifications
      - https://github.com/khchen/winim/blob/df04327df3016888e43d01c464b008d619253198/examples/com/MSScriptControl_ScriptControl.nim
]#

import strformat
import system
import winim/com

when defined(amd64):
  echo "ScriptControl only support windows i386 version"
  quit(1)

var obj = CreateObject("MSScriptControl.ScriptControl")
obj.allowUI = true
obj.useSafeSubset = false

obj.language = "JavaScript"
var exp = "Math.pow(5, 2) * Math.PI"
var answer = obj.eval(exp)
var msg = fmt"{exp} = {$answer}"

obj.language = "VBScript"
var title = "Windows COM for Nim"
var vbs = fmt"""
    MsgBox("This is a VBScript message box." & vbCRLF & "{msg}", vbOKOnly, "{title}")
  """

obj.eval(vbs)

try:
  obj.eval "MsgBox()"
except COMException:
  echo fmt"Error: ""{getCurrentExceptionMsg()}"""