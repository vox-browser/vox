# DOMURL translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/DOMURL`.
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Translation workspace: `~/code/vox2/domurl`. Reviewed: 2026-10-05.

| Upstream source | V mapping |
| --- | --- |
| `DOMURL.cpp` | `dom_url.v`; actual current settings supplied by `../html/blob_url_operations.v` |
| `Origin.cpp` | `dom_url.v`, typed Origin behavior from `../url/origin.v` |
| `URLSearchParams.cpp` | `url_search_params.v`; actual engine wrappers in `../browserjs/url_search_params_host{,_darwin.c}.v` |
| `URLSearchParamsIterator.cpp` | `url_search_params.v`; actual engine iterator prototypes in `../browserjs/url_search_params_host_darwin.c.v` |

The pinned inventory contains four `.cpp` files (1,039 physical lines), four
headers (248) and three IDL files (59). These structural mappings and counts
do not establish full source runtime or generated-binding parity.

URL components, Origin, same-object searchParams, iteration and encoding use
the translated typed LibURL records. Origin same-site classification uses the
existing public suffix implementation. Public API URL parsing follows Source's
basic parser. The separate LibWeb parse/parse_from_byte_string finish step now
resolves the actual FileAPI store and copies Blob bytes/type or a MediaSource
tag plus the creator settings' current typed Origin (`6756a0cf`). Previous
parsed entries remain independent of later object updates, reassociation,
removal and unload. [Settings and snapshot evidence](../docs/translation-audit/BLOB_URL_SETTINGS_SNAPSHOT_OWNER.md)
records the executed original missing-entry failure and **6/6 default plus
8/8 GC-none** focused/neighbor proof.

Current-context create/revoke use actual HTML settings and the genuine store.
Revoke parses the copied entry, checks non-storage partition equality against
its current requesting owner and removes the typed URL (`02226729`). It keeps
Source's fragment serialization behavior. The former ID-only hooks and
standalone string-partition store helpers remain explicitly named adapters.
[Partition and revoke evidence](../docs/translation-audit/BLOB_URL_PARTITION_ACTUAL_ENVIRONMENT.md)
records **5/5 focused files in each GC mode**, including the existing DOMURL
embedded-entry owner test. These are focused checks, not a full module sweep.

Actual settings/DOM resource parsing now retains an owned typed URL record
and independent Blob snapshot (`d1531756`). A Source finish hook crosses the
module import cycle; serialized compatibility URLs retain their basic-parser
boundary. [DOM record evidence](../docs/translation-audit/BLOB_URL_DOM_RECORD_OWNER.md)
records **3/3 default and 4/4 GC-none** final focused files, including the main
browser regression. Actual Fetch (`08d65915`) and node-document media (`a0f60763`) now consume
those snapshots through genuine Environment owners;
[caller evidence](../docs/translation-audit/BLOB_URL_MEDIA_ACTUAL_DOCUMENT.md)
records **2/2 default and 5/5 GC-none** combined focused/neighbor files.

Constructor value ownership (`c1e5845d`) now copies a supplied typed URL record,
preventing later caller path mutation from changing the platform object's href.
[Constructor copy evidence](../docs/translation-audit/DOMURL_CONSTRUCTOR_COPY_OWNER.md)
records the original two executed alias failures and all three DOMURL files
passing in both GC modes. A separate actual Blob DOM-owner retry passes after
restoring its private regex archive; those GC-none results span two runs.

URL-encoded parsing now preserves each tuple's leading BOM (`554c7759`),
matching Source's UTF-8 decoding without BOM handling. Actual lazy DOMURL query
owners retain those names/values across mutation and replacement.
[BOM caller evidence](../docs/translation-audit/URLENCODED_BOM_OWNER.md) records
the two original executed failures, **4/4 default and 5/5 GC-none** final files,
and the separate invalid test-path diagnostic before the corrected GC run.

Native page scripts now construct URLSearchParams and use its operations,
stringifier, live iterators and forEach through actual V records (`6f92c2ca`).
USVString conversion, ordered record collisions, conversion/exception ordering,
same-realm prototypes, live DOMURL query ownership and actual page replay pass
**3 default files across two commands and 6/6 combined GC-none files**.
[Native query evidence](../docs/translation-audit/NATIVE_URLSEARCHPARAMS_OWNER.md)
includes the executed absent-constructor baseline, corrected fixture diagnostics,
two exact unmodified Source sort outputs per GC mode and the 66-case main
regression. Browser/root binding support remains outside the 78-owner LOC total.

Native public URL WebIDL conversion and exposure, foreign realm/world
identity, source UTF16 parser/encoding boundaries, OOM/allocation handling and
Worker startup exposure, generated diagnostic text and complete GC/IPC ownership
remain separate. The existing structural inventory
must not be read as full DOMURL parity.
