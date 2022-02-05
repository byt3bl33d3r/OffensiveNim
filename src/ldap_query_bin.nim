#[
    Author: @fkadibs
    License: BSD 3-Clause

    This is an example of querying Active Directory by using ADO's ADSI provider
]#

import winim/com
import strformat

# Connect to ADSI via ADO COM interface
var conn = CreateObject("ADODB.Connection")
conn.Provider = "ADsDSOObject"
#conn.Properties("User ID") = <username>
#conn.Properties("Password") = <password>
#conn.Properties("Encrypt Password") = true
conn.Open("Active Directory Provider")


# Create query object to connection
var command = CreateObject("ADODB.Command")
command.ActiveConnection = conn
# command.Properties("Page Size") = 100


# Retrieve DNS name of domain controller
var sysinfo = CreateObject("ADSystemInfo")
var dn = sysinfo.DomainDNSName
var root = fmt"<LDAP://{dn}>"


# Build and execute LDAP query
var queryFilter = "(&(objectCategory=person)(objectClass=user))"
var queryAttrib = "cn,distinguishedName"
var queryText = fmt"{root};{queryFilter};{queryAttrib};SubTree"
command.CommandText = queryText
var records = command.Execute()


# Check for empty recordset
if (records.BOF == true) and (records.EOF == true):
    echo "No records found"


# Iterate over recordset
else:
    records.MoveFirst()
    while records.EOF == false:
        # Iterate over row fields
        var i = 0
        var row: string
        while i < records.Fields.Count:
            var field = records.Fields.Item(i)
            row = fmt"{row}{field} "
            inc i
        echo row
        records.MoveNext()

# Cleanup
records.Close()
conn.Close()
