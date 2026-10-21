# Security implementation boundaries

## Shared modes

File, text and mnemonic encryption use the same V2 AES-256-GCM / Argon2id
implementation and new-password policy. Existing V2 passwords remain valid for
decryption. Public async operations share a serial executor to bound concurrent
Argon2 memory use. Controlled byte buffers use `memset_s` on release paths,
including failed/cancelled key derivation. Argon2 runs through `CArgon2Shim`,
which owns the workspace allocation: every return path, including the upstream
`ARGON2_THREAD_FAIL` path that skips its own cleanup, zeroes and frees the
256 MiB workspace and zeroes the output (`Tests/Integration/test-argon2-cleanup.sh`).
The shim also sets `ARGON2_FLAG_CLEAR_PASSWORD`, so the UTF-8 password buffer is
wiped once Argon2 has absorbed it. That buffer and the 32-byte derived key live in
`mlock`ed pages (`SecretBytes`); failure to lock them aborts the operation. The
Argon2 workspace is not locked. CryptoKit's `SymmetricKey` is still an unlocked
copy, and the Swift `String` itself still cannot be wiped. Unlocked pages may be
paged out; swap protection is managed by macOS. The app does not infer FileVault
status from URL volume-encryption attributes: they do not reliably represent
FileVault on modern APFS systems. Check FileVault in System Settings instead.
The vendored reference implementation itself is unmodified and checksum-pinned.

Passwords must be nonempty; new encryption passwords are limited to 4096 UTF-8
bytes, but complexity is not required. The app trims leading/trailing whitespace
from new passwords and confirmation, and rejects internal whitespace. Decryption
preserves the original password and does not impose the new-password length
limit, so legacy ciphertexts remain readable.
The local strength indicator is advisory only, not an entropy estimate. Passwords are hashed as UTF-8
without normalization, so the UI warns when a new password contains non-ASCII.
Password fields use `NSSecureTextField` while hidden. An explicit eye toggle
switches the same row to an ordinary `NSTextField`; revealed text is readable
on screen and through accessibility. Deactivation, disabling or leaving the
view hides it again. Neither field sets a password or new-password content type,
so the system AutoFill save pipeline is not asked to store it in Keychain.

The app conceals content when inactive and drops a completed or in-flight text
decryption instead of retaining the plaintext string. It clears secret drafts on screen lock,
sleep and session switch, and clears/cancels after 120 seconds of inactivity.
Decrypted text starts concealed; revealing and sensitive clipboard copies expire
after 30 seconds. Sensitive clipboard content is also cleared on app deactivation.
Sensitive copies use `NSPasteboard.ContentsOptions.currentHostOnly`, so they are
not offered to other devices through Universal Clipboard; this cannot clear a
copy that a local clipboard manager has already recorded.
Clipboard cleanup checks ownership before clearing. These
clipboard markers are cooperative conventions, not protection from a malicious
clipboard reader. No secret is saved in preferences or logged by these flows.
The plaintext text editor and the mnemonic field editor disable Writing Tools
(macOS 15+), inline predictions, completion, correction and Services, so system
text assistance is not offered the content.

## BIP39

- Only the canonical 2048-word English list is bundled. SHA-256 verifies its
  exact order/content before use; a missing or corrupted list fails closed.
- Source commits, hash and license notices are in `Vendor/bip39/`.
- Generation requests exactly 32 bytes from `SecRandomCopyBytes`, appends the
  eight SHA-256 checksum bits, and maps 264 bits to 24 eleven-bit word indices.
  Failure of the system random source aborts; there is no fallback PRNG.
- The UI generates a plaintext 24-word draft without requiring a password, for
  manual transcription before encryption. Entropy and intermediate byte buffers
  are wiped; returned word Strings and framework copies cannot be reliably wiped.
  Generated words remain in memory, are read-only and start masked. Only the
  hovered word is revealed; leaving its cell immediately removes the plaintext.
  There is no reveal-all control or model state. The reveal uses a short entrance
  animation, with no plaintext exit animation, and respects Reduce Motion. No automatic clipboard copy or file write occurs.
- Encryption requires explicit confirmation that all 24 words were transcribed
  and checked, plus a valid confirmed password. It encrypts that exact draft;
  it never silently generates a replacement. Confirmation is a user assertion,
  not an automated proof that the paper backup or wallet import is correct.
- Switching away hides the draft; locking, inactivity and changing modes clear
  it. Starting encryption clears the UI draft and confirmation, even on failure;
  the already-confirmed paper backup is then needed for retry.
- The separate Core generate-and-encrypt API still returns only ciphertext and
  checks the password before generation. The UI no longer uses that shortcut.
- The 24-cell draft accepts lowercase English words. Local prefix lookup uses a
  binary search and returns at most eight dictionary entries. It never silently
  replaces an unknown word. Encryption requires all 24 words plus a valid BIP39
  checksum. A full-phrase paste is validated before any cell is replaced.
- Mnemonic input uses AppKit NSSecureTextField and its native secure field editor,
  including while typing. Undo, correction, spelling and automatic completion
  are disabled; the field rejects Services. Native secure editing prevents
  ordinary cut/copy. A separate eye button reveals only one manually entered word and its local
  candidates for at most 10 seconds. Editing, changing focus to another word,
  disabling input, deactivation or leaving the view conceals that preview.
- Draft validation accepts the existing word array directly, avoiding a joined
  full-phrase String on each validation and paste check. The encryption handoff
  still creates a String; UI/framework and async copies are not securely erasable.
- Empty draft: generate for backup. Nonempty imported draft: validate and encrypt
  the entered phrase. A rejected paste cannot silently switch into generation.
  A generated draft cannot be overwritten without an explicit clear.
- The codec tests cover the published Trezor English entropy/mnemonic vectors,
  checksum mutations, the complete last-word space, wordlist corruption, RNG
  failures, cancellation, ciphertext round trips, local lookup and UI state races.
  Seed derivation, BIP39 passphrases, addresses and wallet operations are outside
  this feature.

## Remaining boundaries

This is a self-use application, not a certified or independently audited security
product. Tests establish specific behavior; they do not prove absence of leaks.
Swift/AppKit/OS allocations may retain copies that cannot be reliably erased by
this code. An untrusted input method, accessibility client, administrator or
compromised OS can still observe secrets being entered or displayed.

Folder packing walks the source with `openat`/`fstatat` and `O_NOFOLLOW` relative
to verified directory descriptors (device/inode checked), so replacing an
ancestor with a symlink mid-operation cannot redirect reads outside the selected
folder. Each source file's identity, length and modification time are compared
before and after reading, and the bytes actually read are hashed and checked
against a second read. A truncated, extended or rewritten source — including a
same-size rewrite that restores mtime — fails with "source changed" instead of
producing valid ciphertext of partial or substituted content.

A document opened while the app is locked (for example by double-clicking a
`.hycrypt` file at launch) is held until unlock and discarded by locking.

The general file workflow still needs plaintext staging for ZIP creation and
explicit file restoration. On a destination volume that also holds the app's
private temporary directory, staging uses a 0700 `hycrypt-staging` root there;
on other volumes it uses a descriptor-owned `itemReplacementDirectory` probe.
Both are outside the selected folder, so a client syncing only that folder cannot
upload in-progress plaintext. `isExcludedFromBackup` is still set; it does not by
itself stop iCloud Drive.
If the destination volume is not local or is cloud-synced, the plaintext ZIP
stays in the app's local temporary directory and only the finished result is
copied onto that volume. Local `hycrypt-scratch-*` directories carry a `.lock`;
a live scratch is never reclaimed, and a crashed one is removed by the next
local-scratch creation.
Decrypting into a synced, network or cloud-storage folder still publishes plaintext
there; the UI warns before that. Private permissions, descriptor-anchored
publication and normal cancellation cleanup reduce exposure; they do not guarantee
removal after a process crash, power loss or SSD snapshots.
A live transaction must obtain an exclusive `flock` or it fails closed. The next
transaction on that volume removes `.hycrypt-<UUID>` directories in the same
staging root that are owned by the user, unlocked and older than 60 seconds, using
the opened directory descriptor rather than a path. Until then, and on media
snapshots, abandoned plaintext can remain in the volume temporary area.
Text and mnemonic workflows do not use that filesystem staging path. The local
build enables App Sandbox and Hardened Runtime with ad-hoc signing; it is not
Developer ID signed or notarized by default; `SIGNING_IDENTITY` plus an explicit
`NOTARY_PROFILE` keychain profile enables timestamped signing, notarization,
stapling and a Gatekeeper assessment in `scripts/build-app.sh`.

## Release checks and capture limits

The app build runs `scripts/verify-app-security.sh`. It rejects invalid signatures,
missing Hardened Runtime, missing sandbox grants, and any entitlements outside an
independent exact allowlist: App Sandbox, user-selected read/write files, and
app-scoped bookmarks. Network client/server, debugging and runtime exceptions
are not allowed. The check applies to the generated bundle, not arbitrary
`swift run` binaries or an older installed copy. `SIGNING_IDENTITY` can select a
local signing identity; without one the development bundle remains ad-hoc signed.
Notarization credentials are never read from the environment or stored by the
script; only a keychain profile named by `NOTARY_PROFILE` is used.

There is no claim of screenshot prevention or memory-read detection. A revealed
word/candidate can be captured; a continuous recording can accumulate multiple
reveals. No legacy window sharing flag or debugger polling is treated as a security
boundary. Hardened Runtime restricts access; it does not notify the app of every
memory read or protect against a compromised OS. Native secure input and buffer
wiping likewise do not prove that all secret copies are gone.


## Apple platform integration and portable recovery

The selected design preserves portable password-based HYCRYPT2 ciphertext.
LocalAuthentication gates the local app session; it is not an additional factor
in the ciphertext and does not prevent password guessing against a stolen copy.
A fresh app launch opens an empty workspace without authentication. After a
manual or lifecycle lock, reactivation requests `deviceOwnerAuthentication`
(Touch ID or the system's supported owner-authentication fallback). Restarting
the app creates a fresh unlocked session; this gate protects the current session,
not access to launching the application. A manual lock also
immediately requests authentication. Only one automatic prompt is attempted per
locked session; after cancellation or failure the full-window gate offers an
explicit retry. The main and Settings windows share the same gate and session.
While locked, the workspace is replaced by a full-window gate so no content or
controls are reachable.
Authentication failure or
unavailability does not unlock the app. Contexts are invalidated after use, and
no recent Touch ID reuse interval is requested. App deactivation revokes the
session; lock, sleep, user-session change and inactivity also clear/cancel secrets.
The system authentication prompt's activation transition does not cancel itself.
Attempt identifiers prevent cancelled/late callbacks from unlocking a new session.
File processing, text processing, generation and plaintext reveal check the shared
authorization guard. Pure Core APIs remain portable cryptographic services.

No wallet secret, encryption password, recovery secret, or device private key is
persisted in Keychain. The selected portable design needs no persistent local
unlock key. Touch ID's biometric processing is managed by Apple's system; this
app does not implement a Secure Enclave key wrapper, device-bound ciphertext or
claim that the mnemonic/AES encryption executes inside the Secure Enclave.
Changing to mandatory hardware-bound decryption would need a separate recovery
format and is not part of the selected option.

The signed bundle has no network entitlements. This restricts direct networking
by the application; it is not a guarantee against every possible exfiltration
channel in a compromised process or OS. Source URLs hold balanced security-scoped
leases. Output directories need separate user selection: authorization to read a
file does not grant write access to its parent. Saved defaults use security-scoped
bookmarks, refresh stale bookmark data when resolvable, and fail closed when a
bookmark cannot be resolved or accessed. A legacy saved path alone is not treated
as sandbox authorization. Active operations retain their source and output leases
until completion/cancellation, even if settings change. SwiftPM tests are not
sandboxed; `Tests/Integration/test-sandbox.sh` exercises actual OS denial with a
disposable bundle signed using the production entitlement file, and
`Tests/Integration/test-sandbox-file.sh` runs file and directory round trips
inside a signed sandbox process (staging and publication path).
