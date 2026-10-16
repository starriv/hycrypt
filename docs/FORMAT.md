# Hycrypt V2 file format

All integers are unsigned, big endian. This format is versioned by its exact
8-byte magic. Unsupported versions must not be interpreted as V2.

## Header (25 bytes)

| Offset | Bytes | Meaning |
| --- | --- | --- |
| 0 | 8 | ASCII `HYCRYPT2` |
| 8 | 16 | Cryptographically random salt |
| 24 | 1 | Payload kind: 0 = file bytes; 1 = ZIP directory archive |

Derive 32 bytes from the UTF-8 password (no Unicode normalization) with Argon2id
v1.3: t=5, m=262144 KiB, p=6. Use the result directly as the AES-256-GCM key.
Parameters are fixed for V2; changing them requires a new format version.

## Records

Each record contains a 4-byte plaintext length, ciphertext of exactly that
length, and a 16-byte GCM tag. Length must be <= 1048576. Records start at index
0; each record increments the 64-bit index. The 12-byte nonce is four zero
bytes followed by the 8-byte index. A fresh random salt derives a new key for
every encryption; never reuse a salt with the same password.

Additional authenticated data is the complete 25-byte header followed by the
8-byte index and the exact 4-byte length field. There is no stored nonce.
The final record MUST have length 0 and a valid GCM tag; it MUST be followed
by EOF. No plaintext is published until the entire sequence has been verified.
Consequently empty files consist of the 25-byte header and one 20-byte record.

This construction detects changes to metadata, chunk order, truncation and
appended data. It is an application-specific protocol, not a claim of an
independent cryptographic audit. The 256-bit key, random salt, and 128-bit GCM
tags do not compensate for a weak password.

## Directories

Kind 1 contains a ZIP archive with exactly one top-level directory. The root
name is retained in ZIP, but final restore uses the user-selected destination
name. Only regular files and directories are accepted. ZIP path validation
and CRC checks remain mandatory even for an authenticated payload.

Filenames, permissions, timestamps and metadata are not stored for kind 0.
The GUI derives a suggested filename from the encrypted file's external name.

## Unsupported formats

Only the exact `HYCRYPT2` magic is accepted. Unknown versions, damaged magic
and historical unauthenticated AES-CBC files are rejected without publishing
output. There is no fallback decoder or compatibility mode.

## Text transport

Text mode Base64-encodes a complete V2 kind-0 payload. Plaintext is UTF-8 without
normalization, limited to 1,048,576 bytes. Empty plaintext uses only the authenticated
terminator. Text decryption rejects directory payloads and invalid UTF-8, and checks
all authentication tags and EOF before returning any text. Whitespace surrounding
or within Base64 is ignored; other invalid Base64 characters are rejected. Encoded
input including whitespace is limited to 1,398,200 UTF-8 bytes.
