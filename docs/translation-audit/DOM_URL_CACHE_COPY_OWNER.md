# DOM URL cache value copies

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `f273f1ef`; implementation and its two-case focused test are
committed together. This follows the separately completed
[owned DOM URL record](BLOB_URL_DOM_RECORD_OWNER.md) prerequisite.

Source `LibWeb/DOM/Document.h:334` returns a URL value. `LibURL/URL.h:120–124`
exposes const path storage and component setters; its `Data::clone()` copies
paths and Blob entries, and `AK/CopyOnWrite.h:21–26` detaches shared data before
a mutable access. A caller's URL mutation therefore cannot change the owner.
The translated compatibility cache has no Source counterpart and must preserve
that value contract when exposing V's mutable path array.

The original two-case probe executed with GC disabled and failed both cases.
A first raw URL parse shared paths with its newly stored cache entry; an
existing cached Document URL likewise exposed the same array. Changing the
returned path changed serialization from `original` to `changed`, including
the Document's base URL. The fix stores an independent record on first parse
and returns an independent copy on a cache hit. The existing owned-record
branch already copies its record and remains unchanged.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original regression, GC-none | Executed both mutation failures | 28.005 |
| Final default GC | 3/3 files PASS | 232.173 |
| Final GC-none | 5/5 files PASS | 509.921 |

Default files: the new cache owner test, existing resource-origin owner test,
and actual settings/Blob DOM-record owner test. GC-none files: the cache test,
actual DOM-record owner, MediaSource owner, Blob header owner, and the 66-case
main regression. These runs started with the reviewed patch on `5ae375e7` and
ended at the focused feature commit. All seven relevant code/test file hashes
remained unchanged; this is scoped input proof, rather than a whole-checkout
immutable-commit claim.

Exact argv, original/final code hashes, Source contract-header hashes and all
three log hashes are in `Build/audit-fixes/source-dom-url-cache-manifest.json`,
SHA256 `aa3a3552aae9bc1cf333272be071758d14eb964a1b9a1ad8b85a148833f1a162`.
A separate optional upstream C++ witness did not execute: its initial build
needed the generated Lagom include, and the corrected compile could not link
allocator/fly-string symbols from the existing local dylibs. Those diagnostics
remain under `source-dom-url-copy-oracle-`; no C++ runtime proof is asserted.

This fixes the observable cache alias without replacing its serialized
compatibility boundary or physical allocation model. Raw URLs still use the
basic parser and do not acquire a Blob snapshot through this cache. Native
public URL WebIDL exposure, UTF16/encoding-aware parser boundaries, remote IPC
and full GC/WrapperWorld ownership remain open. The audit ledger remains
**32 fixed / 25 partial / 9 open**.
