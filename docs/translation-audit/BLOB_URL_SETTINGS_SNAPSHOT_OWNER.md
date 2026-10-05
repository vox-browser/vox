# Blob URL settings retention and parsed snapshots

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `6756a0cf`.

Source `FileAPI/BlobURLStore.h:19–27` stores live Blob/MediaSource references
and the creator's actual EnvironmentSettingsObject. `BlobURLStore.cpp:29–82`
generates the URL from current settings and retains those settings in the
process store. `DOMURL/DOMURL.cpp:438–469` resolves that live entry during the
LibWeb parser's finish step, copies current Blob bytes/type or an empty
MediaSource tag, and captures the settings' current typed Origin in the URL.
This differs from the public API URL parser, which uses the basic parser
without finish_parsing (`DOMURL.cpp:29–51`).

The old V store captured origin/partition strings and a textual cleanup ID;
finish_parsing returned its URL without an entry. The Source store now retains
the actual HTML settings through an interface implemented on the real heap
EnvironmentSettingsObject. Its origin method reads the current associated
Document. HTML's create-object-URL entry point selects settings through the
existing execution-context stack. Actual Blob references and the existing
MediaSource handle/attachment contract preserve live object identity. Native
insertion requires a live object; ID-only MediaSource descriptors remain in
the standalone adapter.

DOMURL parse/parse_from_byte_string now resolve the genuine store and set the
existing LibURL copied entry value. Source's default UTF16-to-UTF8 conversion
allows lone surrogates; the Blob snapshot uses its preserved type record's
WTF8 projection, including NUL and supplementary pairs. Byte snapshots are
independently owned and survive later deserialization, removal and cleanup.
The real Document unloading hook removes entries by settings pointer identity,
following `BlobURLStore.cpp:133–144` and `DOM/Document.cpp:5691`. Changing an
environment ID or giving another owner the same ID cannot remove its entries.
Resolve excludes URL fragments while removal includes them, as in the two
distinct Source serialization calls (`BlobURLStore.cpp:120–129,148–160`).

Former behavior is preserved explicitly in `legacy_blob_url_store.v` with
Legacy names, its own store and its existing caller tests. The standalone
DOMURL helper, Fetch scheme branch and media attachment adapter still use
that compatibility store at this commit. They do not provide Source settings
ownership or copied-request-URL integration.

## Executed evidence

An original probe at `19e871c7` inserted an actual Blob through the old
environment adapter and called the actual DOMURL parser. Its assertion that
the parsed URL contained an entry failed: the result was `Option(none)`.
The exact original probe is retained as
`Build/audit-fixes/source-blob-settings-original-test.v.txt` (SHA256
`487a48eb6a20454ba507036cd8da8cae04baa80cf6f6a5ac05c961159f82a0c4`).
This is an executed behavior failure, distinct from the later fixture error.

| Canonical run | Result | Seconds |
| --- | --- | ---: |
| Original probe, GC-none | One executed assertion failure | 97.663 |
| Initial corrected implementation, GC-none | 5/6 pass; one test mutability diagnostic | 152.263 |
| Final focused and compatibility callers, default GC | 6/6 PASS | 153.643 |
| Final focused, compatibility and Window/URL neighbors, GC-none | 8/8 PASS | 156.015 |

The fixture now edits the mutable copied entry instead of aliasing a mutable
array from an immutable local. New HTML tests cover live Blob identity, byte
and raw-type copy isolation, a fresh parse after deserialization, opaque owner
identity, settings/Document reassociation, nested current contexts, colliding
textual IDs, unload and fragment semantics. The new MediaSource test creates
a genuine platform object and checks its live handle, empty copied tag and
retained URL snapshot after unload. Existing legacy store, DOMURL, Fetch and
MediaSource caller tests pass in both modes; Window cleanup and LibURL entry
neighbors add GC-none coverage.

Commands use `v -old-compiler -enable-globals test`, adding `-gc none` for
the corresponding rows; final runs use VJOBS=2. Logs use
`Build/audit-fixes/source-blob-settings-` with suffixes
`original-gc-none`, `initial-fixture-diagnostic`, `canonical-default` and
`canonical-gc-none`. Exact argv, Source pin, feature file hashes, summaries
and log hashes are in `source-blob-settings-manifest.json`, SHA256
`0dcb4066f21faddaf6c2486f193082ead24f3b55fb055cecb29db97eb66ae64a`.

Typed partition authorization, actual requesting-Environment selection and
Source revoke are the next separate feature. Genuine DOM cached parsing,
Fetch request snapshots, native public URL bindings, IPC/remote processes,
ConservativeHashMap GC tracing and complete WrapperWorld ownership remain
separate. These focused checks follow the frozen 6f1df913 bundle; they do not
claim a new production build or screenshots. The ledger remains
**32 fixed / 25 partial / 9 open**.
