# Blob scheme Fetch through the actual request and Environment

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `08d65915`, following the
[owned DOM URL record](BLOB_URL_DOM_RECORD_OWNER.md).

Source `Fetch/Fetching/Fetching.cpp:768–782,1016–1078` reads the current URL's
copied entry. It requires GET, selects reserved client before client, and uses
the selected Environment's creation URL for self-fetch. The global Window and
logical navigable parent still belong to the client. Document navigation and
top-level self-fetch select their respective bypass markers; ordinary fetch
obtains the object through the actual Environment's non-storage partition.
MediaSource tags cannot produce a Blob response.

The V scheme caller now consumes that retained entry and creates the Blob
from its independent bytes and type. It does not resolve the native store
again, so a parsed Request or clone survives revocation; a later parse without
an entry fails. Typed adapters retain the actual request client references
and query their current Origin. Reserved Environment records follow their
real settings back-reference or current creation URL. No captured string key,
synthetic origin or replacement settings object is constructed. The actual
HTML client top-level query now checks its Window's current navigable and
logical parent, including absence of the navigable. The compact missing-owner
boundary returns a network error; valid Source ordinary requests require an
Environment. Raw standalone strings retain their explicitly named Legacy
store and previous response behavior.

`FileAPI/Blob.h:44–45` reconstructs the copied String type through
`Utf16String::from_utf8(String const&)`; `AK/Utf16String.h:49–52` directly uses
the unvalidated conversion. The translated call therefore retains lonely
surrogates instead of using the generic scalar-string adapter. This owner
commit preserves the earlier header/body/range machinery. Its type case
initially checks the existing WTF8 header output. Source's separate
isomorphic header conversion and that expectation are addressed by the
[header encoding follow-up](BLOB_URL_HEADER_ISOMORPHIC_ENCODING.md).

## Focused verification

The original actual Request test executed and failed with a network error
because the old caller looked in the Legacy store. The final five-case owner
file creates genuine Pages, Documents, Windows/settings and Environments:

- Retained data/type, request cloning and ranges survive Blob mutation and
  revocation; a fresh parse, raw string and POST fail.
- Matching opaque identity succeeds, a different null-serialized identity
  fails, and current Document origin changes immediately affect authorization.
- Reserved-client priority and live base/settings-backed Environment selection
  use the real owners, including a creation URL disagreeing with settings.
- A distinct actual reserved settings owner supplies the matching creation
  URL while the client's creation URL differs. The client's logical parent
  and missing navigable disable the bypass; the reserved Window's parent does
  not select the client's global.
- The copied type takes Source's unvalidated UTF8 reconstruction path.

Initial compiler diagnostics cover optional Destination unwrapping, a wrong
UTF16 helper name and a duplicate import. The GC-none duplicate-import run
was cancelled after its deterministic diagnostic. A separate self-fetch
fixture initially used a base Environment whose Blob creation URL already
made its partition match; its expected denial was wrong. A settings-backed
foreign Environment and distinct client now distinguish the bypass. These
runs are retained and excluded from final passing proof.

| Run | Result | Seconds |
| --- | --- | ---: |
| Original Request, GC-none | Executed network-error failure | 107.829 |
| Initial typing batch, GC-none | Two compiler failures | 92.876 |
| Import batch, default GC | One compiler failure; runtime neighbor passes | 140.890 |
| Self-fetch fixture, default GC | One fixture failure; runtime neighbor passes | 216.035 |
| Self-fetch fixture, GC-none | One fixture failure; three neighbors pass | 437.080 |
| Final actual Fetch/media callers, default GC | 2/2 PASS | 256.504 |
| Final callers and neighbors, GC-none | 5/5 PASS | 743.454 |

The final default files are `html/blob_url_fetch_owner_test.v` and
`mediasourceextensions/blob_url_media_owner_test.v`. GC-none adds
`mediasourceextensions/media_source_test.v`,
`mediasourceextensions/blob_url_settings_owner_test.v` and the 66-case
`main_test.v`. Existing `fetch/runtime_test.v` passed in both modes with the
same corrected implementation; actual partition and Window-context neighbors
also passed before the self-fetch fixture correction. Final commands use
`VJOBS=2 v -old-compiler -enable-globals test`, adding `-gc none` as appropriate.

The seven combined feature file hashes matched their saved contents before
committing each feature separately. Complete argv, Source pin, original
probes, implementation/test hashes, log hashes and summaries are in
`Build/audit-fixes/source-blob-callers-manifest.json`, SHA256
`2cb126a1cb529dfba79000eb282a8b33c972d95e8ea86e0613577cc8ab5b36d0`.
Logs retain the `source-blob-fetch-` and `source-blob-callers-` prefixes.

This completes the bounded copied-entry/Environment scheme caller. Full Fetch
policy/network execution, native public URL bindings and remote transport,
physical allocation and complete GC/WrapperWorld ownership remain separate.
No new full package sweep, production build or screenshot proof is claimed.
The ledger remains **32 fixed / 25 partial / 9 open**.
