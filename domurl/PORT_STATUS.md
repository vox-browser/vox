# DOMURL translation status

Upstream reference: `~/code/3rd/ladybird/Libraries/LibWeb/DOMURL`.
Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Translation workspace: `~/code/vox2/domurl`. Reviewed: 2026-10-05.

| Upstream source | V mapping |
| --- | --- |
| `DOMURL.cpp` | `dom_url.v`; actual current settings supplied by `../html/blob_url_operations.v` |
| `Origin.cpp` | `dom_url.v`, typed Origin behavior from `../url/origin.v` |
| `URLSearchParams.cpp` | `url_search_params.v` |
| `URLSearchParamsIterator.cpp` | `url_search_params.v` |

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
browser regression. Actual Fetch/media request integration is unfinished. Native public URL WebIDL conversion and exposure, realm/world
identity, source UTF16 parser/encoding boundaries, OOM/allocation handling and
complete GC/IPC ownership remain separate. The existing structural inventory
must not be read as full DOMURL parity.
