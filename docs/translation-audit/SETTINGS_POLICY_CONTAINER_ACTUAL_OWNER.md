# Current Window and Worker settings policy-container owners

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/Scripting/WindowEnvironmentSettingsObject.cpp:134–138`,
`HTML/Scripting/WorkerEnvironmentSettingsObject.cpp:103–107`,
`HTML/WorkerGlobalScope.cpp:176–201`, and
`DOM/Document.cpp:5508–5518`.

Environment settings stored a separate copied PolicyContainer value. Window
settings consequently ignored the actual Document container and kept old
policies after associated-document replacement. Worker settings similarly used
a copied outside-settings snapshot rather than the WorkerGlobalScope's live
container. Fetch/CSP projections, embedder checks and serialization read that
copied field directly, bypassing the Source getters.

Window settings now return their actual Window's current associated Document
container. Worker settings return their actual scope's persistent lazy
container, including a new owner installed by the existing response
initialization algorithm. Fetch request policy/CSP projections, credentialless
embedder checks and serialized environment settings all use these getters.
No origin or policy is reconstructed from an inferred alternate owner.

The existing V settings installation method is an explicit compatibility API:
it routes to Source Document's direct owner setter or assigns the actual Worker
container field. Genuine owners retain the supplied pointer, including both
integrity fields. Worker setup no longer creates an unused second policy copy
from outside settings; Source's Worker getter reads its scope, and its local
non-blob initialization branch retains Source's owner-cloning FIXME. Settings
constructed without either actual global continue their explicit copied-value
adapter, with all genuine owner reads excluded from that branch.

Four focused cases in `html/settings_policy_container_owner_test.v` use real
Pages, navigation Documents, Windows, Workers, response headers, parser-factory
Meta elements and request clients. They check direct owner identity and
header/Meta order, genuine inline/Trusted Types/Fetch blocking before transport,
serialization, Window reassociation/restoration and direct installation,
preservation of both integrity fields, Worker response-owner replacement and
absence of outside-policy inheritance, and the explicit standalone adapter.

The pre-fix default run failed all three genuine owner cases while the
standalone adapter passed
(`Build/audit-fixes/source-settings-policy-owner-original-default.log`, 180.19
seconds).

The first post-routing run reached the forbidden transport because its test
request omitted the existing client-population stage required before the
low-level `main_fetch` entry point (`source-settings-policy-owner-default.log`).
The fixture now runs that ordinary embedding stage, matching the existing
genuine Fetch/Meta tests; this diagnostic did not require another production
change.

The corrected four-case file passed with default GC in 125.54 seconds
(`source-settings-policy-owner-clean-default.log`). Before the final neighbor
batch, the private branch reused the independent Source typed-origin projection
`4d90ca4e` and storage-history defaults/copy feature `528ae74e`; these were
already canonical and are separate from this settings fix.

The final GC-none batch passed all eight files in 882.94 seconds
(`source-settings-policy-owner-gc-none.log`): the new owner cases, environments,
Workers, genuine Meta lifecycle, inline policy ownership, Trusted Types, Fetch
security policies and typed-origin projection. This proof covers retained owner
identity and the existing consumers without relying on the garbage collector.

This is actual settings getter and consumer routing. CSP engine lists are still
materialized from the existing serialized shared records; resolved request
snapshots and the full GC/realm graph retain their existing boundaries. The
separate typed-origin projection preserves actual opaque/file/tuple records.
Document CSP initialization and SourceSnapshot policy cloning still use the
old settings-based helper, whereas Source reads each original Document's own
container; their reassociation cases require separate immediate caller fixes.
Meta referrer still writes only its compatibility string until the following
Source field-write feature. No complete policy-container, Worker startup or
document initialization parity is claimed.
