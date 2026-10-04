# Actual LibURL blob entry value and origin prerequisite

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibURL/URL.h:45–64,153–154,158–173,205`, `URL.cpp:352–354` and
`AK/ByteBuffer.h:30–35,52–61`.

The Source URL record owns an optional `URL::BlobURLEntry` value. This is distinct
from the FileAPI store's entry: the URL value holds either copied Blob bytes and
type or an empty MediaSource tag, plus an environment projection containing the
actual typed Origin. For a blob scheme, the first origin branch returns that
entry's environment origin before considering its serialized path.

The V URL record previously had no such value, accessors or branch. It now
translates both object variants, the environment origin, optional slot and
getter/setter. Origin values retain their actual nonce, File tag, scheme, host,
port and domain. Blob byte copying follows the Source ByteBuffer value-copy
operation; URL component copies retain the entry and have an independent
optional owner slot. The existing value-returning V getter copies bytes to
preserve the Source const accessor's protection of its owned snapshot.

Four URL tests cover actual typed opaque/File and tuple/domain owners, raw Blob
bytes/type and copy isolation, the MediaSource tag, component-copy retention,
clearing an entry, blob-only origin consumption and the absent-entry fallback.
A DOMURL test supplies that actual entry record to the existing Source
`initialize_a_url` constructor and checks opaque identity through Origin
extraction, query/fragment setters and later href replacement. These are actual
entry values and constructors, without string-origin reconstruction or a
fabricated settings object.

The original URL test could not compile because the Source value types and
public accessors were absent (1.966 seconds). That retained diagnostic is not
a behavioral test run. An initial two-file corrected run passed the DOMURL
case but exposed an invalid mutable-array assignment in the URL test
(8.583 seconds); the test was corrected to mutate its copied public Blob value,
matching Source's public struct fields. After correction the two new files
passed with default GC (2/2 files, 6.287 seconds). A `-gc none` batch passed
them plus existing URL parser/origin and DOMURL neighbors (5/5 files,
15.560 seconds). Commands used
`VJOBS=1 /Users/alex/code/v/v -old-compiler -enable-globals test`, adding
`-gc none` for the latter batch. Retained logs under `Build/audit-fixes/` are
`source-url-blob-entry-{original-default,initial-fixture-diagnostic,default,gc-none}.log`.

This is a prerequisite, not completion of blob URL resolution. The FileAPI
store still needs actual settings/environment ownership in place of its string
projection; Source DOMURL `finish_parsing` still needs the real store resolution
and Blob/MediaSource/environment snapshot (`DOMURL.cpp:438–469`). Actual DOM
cached URL parsing, native bindings, IPC encoding/decoding and the complete
Source copy-on-write/GC graph remain separate. No new store-resolution hook or
fallback origin recovery is introduced here.
