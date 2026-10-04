# CSP self matching reads the actual URL origin

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/Directives/DirectiveOperations.cpp:627–665`,
especially `634–637`.

Source's first self-keyword condition compares the supplied policy origin to
the target URL's actual `origin()` operation. The V caller instead invoked a
helper that constructed a tuple from the outer scheme, host and port regardless
of URL kind. That did not represent blob URL origins and replaced the newly
translated shared resource origin with the resource URL's authority.

The actual self consumer now calls the translated URL operation directly.
Repository search found this method was the tuple helper's only remaining
caller, so its unused invented origin construction is removed. The subsequent
Source host/port/secure-upgrade branches are unchanged; this feature does not
claim a fresh audit of all source-expression matching logic.

Four focused cases in `fetch/csp_self_url_origin_owner_test.v` derive protected
origins from real Fetch Response HeaderLists through the completed Source CSP
response parser. They pass cached resource URL records to the actual self
matcher; match a blob target through its actual nested URL origin while rejecting
another host; retain cloned typed data/file opaque owners and their default
nonmatching controls; and preserve ordinary HTTPS host/port gates. No policy
origin is reconstructed from serialization or substituted with a synthetic tuple.
The original caller compiled cleanly but failed the resource and blob cases;
both opaque-origin and ordinary HTTPS controls passed. Its retained log is
`Build/audit-fixes/source-csp-self-url-origin-original-default.log`
(11.558 seconds). After correction, the new file and existing matching tests
passed with default GC (2/2 files, 34.494 seconds). The new file, existing
matching/source-expression tests and actual response-owner neighbor passed
with `-gc none` (4/4 files, 68.200 seconds). Logs are
`source-csp-self-url-origin-default.log` and
`source-csp-self-url-origin-gc-none.log` under the same directory. All commands
used `VJOBS=1 /Users/alex/code/v/v -old-compiler -enable-globals test`, adding
`-gc none` for the latter batch.

The protected policies retain the existing cycle-safe native CSP projection;
full native Policy/Response/GC and DOM serialized-policy ownership remain open.
Blob URL entry ownership and Source's process-wide file-origin opt-in also remain
separate from this actual URL-origin consumer.
