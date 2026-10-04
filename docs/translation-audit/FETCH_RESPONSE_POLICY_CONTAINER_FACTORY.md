# Source Fetch-response policy-container factory

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/PolicyContainers.cpp:38–75`,
`ContentSecurityPolicy/Policy.cpp:98–145,199–213`, and
`ReferrerPolicy/AbstractOperations.cpp:23–41`.

Source creates a new PolicyContainer, assigns the actual response CSP parser's
result, and updates the container's default referrer policy only when the actual
raw-header helper returns a nonempty policy. The pinned blob-environment clone,
embedder-policy and integrity-policy work remains marked FIXME in Source.

The V factory manually combined each CSP header kind into one string and parsed
it with a local adapter. It kept empty policies and used one response-origin
invocation for every policy. Referrer values were comma-split and trimmed even
though the pinned Source extraction preserves each entire raw value. The
factory now allocates its actual DOM PolicyContainer first, then invokes the
completed CSP response parser through Fetch's actual HeaderList/typed URL
projection. It copies Source's serialized parsed-policy fields into the existing
DOM list and assigns a nonempty referrer result through the shared Source enum.
Original decoded metadata, directive/source/disposition order and typed origins
are retained. The existing LibURL-to-DOM Origin constructor is exposed for direct
record copying, preserving opaque nonce and file type without reconstruction.

The pre-existing private CSP String helper remains a separately completed
compatibility adapter for supplied String/origin fixtures. The actual response
factory uses the response/ByteString parser and does not invoke that helper.
The old policy/history fixture's comma-referrer setup is migrated to two real
header entries, retaining its expected valid-policy assertion; the new raw
comma regression independently requires the Source default policy.

Five focused cases in `html/fetch_response_policy_factory_owner_test.v` cover
repeated enforced/report-only headers, raw comma preservation, byte-decoded
metadata and first duplicate; missing/empty/invalid raw referrer defaults;
empty policy omission even when the Response URL is absent; fresh actual
file/data origin invocations retained through clone and Fetch projection; and
real Page/Window/Document/settings identity, later Meta append and actual Fetch
blocking before transport. An initial four-case setup combined empty CSP and
raw referrer checks, so its empty-policy failure prevented later raw-referrer
subcases from running; that 36.59-second diagnostic remains separately retained
(`Build/audit-fixes/source-html-response-policy-factory-initial-combined-fixture.log`).
After separating the independent empty-policy case, four pre-fix cases failed
behaviorally and the actual-owner control passed in 45.81 seconds
(`source-html-response-policy-factory-original-default.log`), including the
genuine factory's incorrect comma-referrer override. The corrected default
two-file batch passed in 95.89 seconds
(`source-html-response-policy-factory-default.log`): new actual factory cases
and the existing policy/history file with its Source header fixture update.
The GC-none four-file batch passed in 345.73 seconds
(`source-html-response-policy-factory-gc-none.log`): new factory cases, existing
policy/history, actual settings policy ownership and native Meta lifecycle
consumers. The final settings-owner file completed its longer C compilation
and then passed; it was not a behavioral timeout. Both earlier fixture/failure
outcomes remain separately retained.

Document PolicyContainer still owns the existing serialized DOM policy list,
with explicit projections to native translated CSP PolicyList objects. This
feature translates the factory's selection and field-copy algorithms; it does
not replace that representation with Source's native PolicyList/GC pointer graph.
Source blob/environment, embedder and integrity FIXMEs remain open, as do the
compact URL wrapper's existing blob-entry/resource-origin boundaries.
