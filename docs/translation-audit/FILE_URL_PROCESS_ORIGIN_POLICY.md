# Source process-wide file URL origin policy

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibURL/URL.cpp:22,335–345,400–401` and `URL.h:210–211`.

Source owns one process-wide boolean, initially false. Its setter verifies that
the flag has never been enabled and then enables it; its getter returns that
same flag. File URL origin evaluation asks the getter each time. Enabled file
URLs receive a tuple containing the file scheme, empty host and absent port;
otherwise each evaluation returns a new opaque origin tagged as File.

The V translation now has that actual flag, public setter/getter and direct
origin branch. The setter uses an unconditional fatal guard so Source VERIFY's
repeat-set failure also holds in production. There is no reset API. A URL
record parsed before enabling the flag participates in the new policy when its
origin is evaluated later, while an already-created opaque Origin retains its
nonce and File type. URL authorities and paths are not rewritten.

`url/file_origin_policy_test.v` runs enabled, fresh-default and repeat-set modes
in separate executions of its own test binary. The parent retains the default
policy. It checks the actual parsed records, file and blob:file origins,
unchanged pre-enable opaque values, and data/HTTPS/resource controls.
`html/file_origin_policy_owner_test.v` separately exercises default and enabled
processes through a real cached DOM URL, real Fetch HeaderList/Response factory,
serialized policy clone, actual Page/Document/Window/settings container and CSP
self consumer. It checks typed origin identity through the existing native CSP
projection and proves the child's opt-in does not mutate the parent process.

The baseline command could not compile because both Source public APIs were
absent (10.455 seconds). That diagnostic is retained and is not a behavioral
execution result. After translation, both new files passed with default GC
(2/2 files, 86.292 seconds). A `-gc none` batch passed the two new files plus
existing URL-origin, cached DOM-resource and actual CSP-self neighbors
(5/5 files, 81.624 seconds). The lightweight URL test also passed under `-prod`
(1/1 file, 10.637 seconds), including the fatal repeated setter in its child
process. All commands used
`VJOBS=1 /Users/alex/code/v/v -old-compiler -enable-globals test` with the
corresponding GC/production flags. Retained logs under `Build/audit-fixes/` are
`source-file-origin-policy-{original-default,default,gc-none,production}.log`.

Source WebContent and WebWorker service command lines call this setter for
`--tuple-file-origins` (`Services/WebContent/main.cpp:210` and
`Services/WebWorker/main.cpp:92`). Their startup/CLI wiring remains separate.
Blob URL entry/environment ownership and the native Policy/Response/GC graph
also remain open; this feature preserves the existing no-entry blob fallback
and cycle-safe serialized policy projection.
