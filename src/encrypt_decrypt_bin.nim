#[

    Author: Marcello Salvati, Twitter: @byt3bl33d3r
    License: BSD 3-Clause

    AES256-CTR Encryption/Decryption
]#

import nimcrypto
import nimcrypto/sysrand
import base64

func toByteSeq*(str: string): seq[byte] {.inline.} =
  ## Converts a string to the corresponding byte sequence.
  @(str.toOpenArrayByte(0, str.high))

var
    data: seq[byte] = toByteSeq(decode("SGVsbG8gV29ybGQ="))
    envkey: string = "TARGETDOMAIN"

    ectx, dctx: CTR[aes256]
    key: array[aes256.sizeKey, byte]
    iv: array[aes256.sizeBlock, byte]
    plaintext = newSeq[byte](len(data))
    enctext = newSeq[byte](len(data))
    dectext = newSeq[byte](len(data))

# Create Random IV
discard randomBytes(addr iv[0], 16)

# We do not need to pad data, `CTR` mode works byte by byte.
copyMem(addr plaintext[0], addr data[0], len(data))

# Expand key to 32 bytes using SHA256 as the KDF
var expandedkey = sha256.digest(envkey)
copyMem(addr key[0], addr expandedkey.data[0], len(expandedkey.data))

ectx.init(key, iv)
ectx.encrypt(plaintext, enctext)
ectx.clear()

dctx.init(key, iv)
dctx.decrypt(enctext, dectext)
dctx.clear()

echo "IV: ", toHex(iv)
echo "KEY: ", expandedkey
echo "PLAINTEXT: ", toHex(plaintext)
echo "ENCRYPTED TEXT: ", toHex(enctext)
echo "DECRYPTED TEXT: ", toHex(dectext)