# CSP response parsing through actual headers and URL records

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ContentSecurityPolicy/Policy.cpp:98–145`,
`Fetch/Infrastructure/HTTP/Responses.h`, and
`Libraries/LibHTTP/HeaderList.cpp:194–225` / `Header.cpp:50–85`.

Source's response parser extracts Content-Security-Policy values from the
actual Response HeaderList, parses each ByteString as an enforced header policy
and retains policies with nonempty directive sets. It then repeats that body
for report-only values. All enforced policies precede all report-only policies,
while repeated values retain their header order. The pinned generic extraction
FIXME returns each whole raw CSP header value; arbitrary comma splitting is
not part of this Source body. Finally, every policy obtains the response URL's
origin through the actual URL operation, separately for each policy.

The V Fetch projection copied headers into a map and reparsed URL serialization.
The CSP parser walked that map, could interleave report-only policies before
enforced policies, used the String parsing path for raw header bytes and made
tuple origins even for file/data/blob URLs. The existing cycle-safe CSP Response
record now retains the actual HeaderList pointer. Genuine Fetch projection
reads DOM URL's existing cached typed LibURL record and retains the actual
headers; it does not also copy a header map. Source's parser consumes that
owner, translates the two extraction loops and invokes the byte branch completed
separately. Typed URL.origin() supplies each policy's own origin invocation.

Standalone callers may still construct the pre-existing header map when no
actual HeaderList exists. That path explicitly adapts the legacy input into a
HeaderList before running the same extraction body. A map never contributes
extra policies when the actual header owner is supplied.

Focused genuine Fetch Response cases are in
`fetch/csp_response_header_owner_test.v`: retained header pointer identity and
later append visibility despite a stale map; enforced/report-only ordering,
mixed-case names and repeated raw values; empty policy omission and first
duplicate; byte-decoded original metadata; actual blob tuple origin and
fresh file/data opaque origins per policy; and the standalone compatibility
input. The initial owner fixture used a panic and stopped after confirming the
missing actual HeaderList; that 7.79-second diagnostic is retained separately
(`Build/audit-fixes/source-csp-response-owner-initial-panic-diagnostic.log`).
After changing the fixture to a focused assertion, all five pre-fix cases
failed behaviorally in 10.09 seconds
(`source-csp-response-owner-original-default.log`). The corrected default
two-file batch passed in 43.66 seconds
(`source-csp-response-owner-default.log`), covering the new actual-owner and
existing directive/parser files. The GC-none five-file batch passed in
183.57 seconds (`source-csp-response-owner-gc-none.log`): new owner, existing
directive/parser, byte-input branch, complete Fetch runtime file and genuine
HTML Fetch security-policy consumers. Neither the earlier panic diagnostic
nor pre-fix failures is counted as a clean run.

The acyclic CSP record projects a typed URL value for this synchronous call;
it does not implement the complete native Fetch Response/GC object graph. A
genuine header owner with nonempty policies requires an actual Response URL,
matching Source's required URL dereference. The old null-URL allowance is
retained only for standalone records without the actual header owner.
DOM's compact URL wrapper and LibURL's pending blob-entry/resource-origin work
retain their existing boundaries. The actual Source PolicyList is still
represented separately from Document PolicyContainer's serialized list. HTML's
Fetch-response factory caller remains a separate translation slice.
