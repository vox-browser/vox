# Shared Source referrer enum and acyclic header algorithm

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/ReferrerPolicy/ReferrerPolicy.{h,cpp}`,
`ReferrerPolicy/AbstractOperations.cpp:23–41`, and
`HTML/PolicyContainers.h`.

Source's PolicyContainer, referrer operations and Fetch redirect caller use the
same ReferrerPolicy enum. The V DOM record, `referrerpolicy` and acyclic
`referrercore` instead declared three unrelated enum types. A parsed policy
could not be retained directly by the actual Document PolicyContainer without
inventing a cast or another parse. Fetch also cannot import `referrerpolicy`,
because that package already imports Fetch for its public Response API.

Both referrer packages now alias the existing actual `dom.ReferrerPolicy`
record. The already-translated header token loop and actual HeaderList
extraction body live in the existing acyclic `referrercore` package. The public
Response helper passes its actual retained HeaderList to that same algorithm.
No copied header map, synthetic Response, numeric enum cast or string reparse
is introduced. Public enum names and response/token APIs retain their existing
forms, and the prior raw-value Source behavior remains unchanged.

Three focused cases in `referrerpolicy/shared_header_core_owner_test.v` check
that actual parsed policies can be retained by Document's PolicyContainer and
its clone/serialized record; both public referrer APIs consume the same actual
enum; and a retained Response HeaderList reflects later appends directly in
both the core and public helper while preserving raw comma/whitespace values.
The first two cases exposed the pre-fix type-owner mismatch at compilation in
18.62 seconds (`Build/audit-fixes/source-referrer-shared-core-original-default.log`);
no test body ran. The old V compiler then required concrete enum types at
exhaustive match boundaries and actual enum names for constant initialization.
The intermediate diagnostics are retained separately: the alias match check
prevented compilation, and the following three-file run had two passes plus
the existing default-policy failure because an alias-qualified constant became
zero. Signatures/constants now name the actual shared record directly while
public aliases remain; the round-trip fixture also names the actual enum.
Both package defaults are explicitly checked. No casts or new fallback branch
were added to bypass those compiler constraints. The corrected three-file
default batch passed in 23.27 seconds
(`source-referrer-shared-core-default.log`): the new shared record/header core,
prior raw-response cases and existing referrer API. The corrected GC-none
five-file batch passed in 89.31 seconds
(`source-referrer-shared-core-gc-none.log`), covering the new shared owner,
raw-response and existing referrer API files plus the genuine Fetch referrer
runtime and Fetch runtime neighbors. The earlier compiler diagnostics and
partial run remain recorded separately; they are not counted as clean passes.

The core HeaderList parameter is the cycle-safe projection of Source's
Response-only header read; it retains the actual header owner and unchanged
Source algorithm. This prerequisite does not yet replace the duplicate Fetch
HTTP-redirect caller or HTML response factory. Complete Source Response/GC
ownership and policy parsing remain separate. Existing `to_string` and
`from_string` bodies keep their Source case handling with the shared enum.
