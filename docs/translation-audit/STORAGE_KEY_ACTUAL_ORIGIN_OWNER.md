# Source StorageKey actual origin prerequisite

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/StorageAPI/StorageKey.cpp:17–63` and `StorageKey.h:19–35`.

Source StorageKey contains the actual URL Origin. Its string operation delegates
to Origin serialization and its equality delegates to exact same-origin
comparison, including opaque nonce identity. The direct-origin overload copies
that actual record. The Environment overload selects a settings object's origin
or evaluates its creation URL's origin. Normal obtain-key then replaces a tagged
opaque File origin with the shared file tuple and rejects remaining opaque
origins. Source's disabled-storage step is still a FIXME with no effect.

The V record instead contained serialization and opaque flags, and equality
rejected every opaque key. It now owns the translated LibURL Origin value and
uses those actual Source operations. The existing standalone StorageEnvironment
record is explicitly a captured-value adapter, carrying a typed settings origin
or real creation URL record. Its disabled flag has no invented effect. The
IndexedDB caller passes its actual DOM typed origin into the obtain-key body;
the explicit standalone untyped DOM-origin path retains unavailable storage.

Four key tests cover retained opaque/File identity, equality and opaque rejection,
the normal file override without mutating the non-storage key, exact environment
selection with freshly evaluated opaque creation URLs, and tuple port/domain
retention plus the disabled-storage FIXME. A genuine Page/Document/Window
regression observes old and replacement settings origins across reassociation.
Existing StorageAPI tests now construct actual parsed/opaque origins; only the
disabled-storage assertion changes the previously invented behavior.

The former string/flag byte codec has no native consumers in this repository.
It is preserved separately as LegacyStorageKeyRecord with explicitly named
legacy encode/decode functions. Its original length-prefixed payload and two
flags retain their exact bytes and error handling. It cannot construct a native
StorageKey or recover an opaque nonce. Source IPC encoding/decoding instead
delegates to the actual Origin codec (`StorageKey.cpp:68–80`,
`LibIPC/Encoder.cpp:153–168`, `Decoder.cpp:140–157`) and remains open.

The original focused typed-key test could not compile against the missing
direct-origin API and flag-only field type (1.502 seconds); that is not a
behavioral run. An earlier test-preparation diagnostic also retains a corrected
invalid optional binding (1.420 seconds). The first default implementation batch
passed the new key, existing StorageAPI model/endpoint and genuine IndexedDB
files, but its reassociation test helper incorrectly propagated an Option through
a Result-returning function (4 passed, 1 compilation failure, 142.415 seconds).
After correcting that helper, the reassociation file and Blob-store neighbor
passed (2/2 files, 46.612 seconds). The complete six-file batch then passed with
`-gc none` (6/6 files, 101.065 seconds). This evidence preserves the mixed first
batch rather than relabeling it as clean. Commands used
`VJOBS=1 /Users/alex/code/v/v -old-compiler -enable-globals test`, adding
`-gc none` for the final batch. Logs under `Build/audit-fixes/` are
`source-storage-key-origin-{initial-fixture-diagnostic,original-default,original-owner-fixture-diagnostic,default,gc-none}.log`.

Actual FileAPI retained settings ownership and its native partition check are
the next slices. Existing standalone StorageEnvironment/SessionStorageBottle
construction adapters, browser host proxy/IPC/storage-jar behavior and the full
Source Environment/Page/GC graph remain separate. This prerequisite does not
claim complete Blob partition, StorageAPI or native IPC parity.
