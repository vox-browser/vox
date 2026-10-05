# Blob URL partition authorization and current-context revoke

Reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Feature commit: `02226729`, following the separately committed
[settings/snapshot owner](BLOB_URL_SETTINGS_SNAPSHOT_OWNER.md).

Source `FileAPI/BlobURLStore.cpp:85–117` operates on the copied LibURL Blob
entry, not the live store entry. It compares non-storage StorageKeys for the
copied environment Origin and the actual requesting HTML Environment.
`StorageAPI/StorageKey.cpp:39–59` obtains that requesting origin from settings
when the Environment is a settings object, otherwise from its creation URL.
`StorageKey.h:28–35` compares keys using Origin::is_same_origin. Neither the
opaque-origin rejection nor normal storage's shared file-origin override
belongs to this partition algorithm.

The V functions now consume the actual copied LibURL entry and retain the
requesting owner through HTML's implemented interface. Actual settings read
their current Document origin. Actual base Environments follow their real
settings back-reference when present, otherwise their current creation URL.
No textual partition key or replacement settings object is constructed.
TopLevelNavigation and TopLevelSelfFetch preserve the two Source bypass arms.
Returned Blob bytes are copied independently, following Source's by-value
variant and ByteBuffer return; the MediaSource value remains an empty tag.

V rejects interfaces directly inside sum types. BlobURLRequestEnvironment
wraps the actual owner interface for that arm instead of capturing an origin
or flags. The initial compiler diagnostic is retained separately; it is not
an executed authorization regression.

The real current-context HTML entry points now call DOMURL's create/revoke
bodies. Source revoke parses through finish_parsing, checks scheme and the
embedded entry, authorizes against current settings, and removes the typed
URL (`DOMURL/DOMURL.cpp:102–137`). Removal retains the Source serialization
including a fragment. Consequently revoking a URL with a fragment leaves the
fragmentless stored URL intact at this pin; resolving the same URL still
excludes the fragment. The former object-ID hook helpers remain explicitly
named with_hook, and the Legacy store helper keeps its original adapter
semantics.

## Focused verification

The new actual-owner test file has four cases. They create genuine Page,
Document, Window, settings and base Environment records, then exercise the
Source store and parser before partition authorization:

- The same opaque nonce succeeds across actual settings owners; a different
  opaque nonce fails despite both origins serializing as null. Normal storage
  rejects that opaque origin, while non-storage Blob authorization succeeds.
  Returned bytes are independently mutable, and both top-level arms bypass
  the requesting-owner check.
- Different file-origin nonces fail the partition check even though normal
  storage maps both to the same shared file key.
- Base Environment creation URL changes affect its partition; settings-backed
  Environment records select settings instead. Window reassociation changes
  the requesting origin while the earlier URL snapshot remains unchanged.
- Nested actual execution contexts supply current settings for revoke.
  Cross-origin revoke fails; malformed/non-blob input is silent; fragment
  removal and previously parsed snapshot retention follow pinned Source.

| Canonical batch | Result | Seconds |
| --- | --- | ---: |
| Initial interface form, default GC | 4 compiler failures; StorageKey neighbor passes | 112.155 |
| Initial interface form, GC-none | 4 compiler failures; StorageKey neighbor passes | 113.230 |
| Corrected owner/partition/MediaSource/StorageKey/DOMURL, default GC | 5/5 PASS | 144.729 |
| Same corrected files, GC-none | 5/5 PASS | 139.059 |

Commands use VJOBS=2 and `v -old-compiler -enable-globals test`, with
`-gc none` for the corresponding rows. The five files are
`html/blob_url_partition_owner_test.v`, `html/blob_url_settings_owner_test.v`,
`mediasourceextensions/blob_url_settings_owner_test.v`,
`storageapi/storage_key_origin_owner_test.v` and
`domurl/blob_url_entry_record_owner_test.v`.
Logs use `Build/audit-fixes/source-blob-partition-` with
`initial-interface-diagnostic-{default,gc-none}` and
`canonical-{default,gc-none}` suffixes. Exact argv, file/log hashes, Source
pin and summaries are in `source-blob-partition-manifest.json`, SHA256
`ac22a537438c2ffdf6870b8233ccd528117e16754d3055174b7bf4c7906bd5fc`.

This completes the bounded Source partition/obtain and current-context revoke
path. Compact DOM URL caching, actual Fetch request URL snapshots and media
attachment callers still require integration; existing standalone consumers
retain their explicitly named Legacy behavior. Public native URL WebIDL
conversion/exposure, remote IPC, physical allocation and complete Source
GC/WrapperWorld ownership remain separate. No new full package, production
build or screenshot proof is claimed. The ledger remains
**32 fixed / 25 partial / 9 open**.
