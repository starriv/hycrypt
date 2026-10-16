# BIP39 sources

English wordlist verified byte-for-byte against bitcoin/bips. No upstream JavaScript is executed or bundled.

- onekey: `fff0de03b8e2ce45a5bdee8e309926a4252f5c52`
- bips: `927b6de9915c9262615a6399de51b200f81e5aa4`
- trezor: `b57a5ad77a981e743f4167ab2f7927a55c1e82a8`

Canonical English list SHA-256 (UTF-8, LF, final LF): `2f5eed53a4727b4bf8880d8f3f199efc90e58503646d9ff8eff3a2ed3b24dbda`.

- OneKeyHQ/bip39: src/js/jsbip39.js reviewed; src/js/wordlist_english.js wordlist.
- bitcoin/bips: bip-0039/english.txt verification and BIP-0039 specification.
- trezor/python-mnemonic: vectors.json English vectors for tests (entropy and mnemonic only).
