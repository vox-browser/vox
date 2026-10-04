# Document policy-container shared records and lazy owner

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/DOM/Document.cpp:5508–5518`,
`HTML/PolicyContainers.{h,cpp}`, `HTML/SerializedPolicyContainer.h`,
`HTML/EmbedderPolicy.h`, `ReferrerPolicy/ReferrerPolicy.h` and
`Fetch/Infrastructure/HTTP/Requests.h`.

The native Document used an empty `dom.PolicyContainer` unrelated to the real
HTML policy records. Its getter also allocated a new empty object on every call
when no container had been set. Source instead stores the first lazily created
container and returns that same actual owner on later calls; the setter and
navigation initializer retain the supplied owner directly.

The existing translated HTML policy records now live in the cycle-safe DOM
package, with HTML aliases preserving their existing public names and callers.
Document uses that same concrete PolicyContainer record rather than an empty
placeholder. Its getter retains the lazily allocated object. Referrer and
embedder enum/string methods, CSP serialized records, integrity destination
enum/records, cloning and serialization are relocated existing implementation;
policy parsing and consumer behavior are unchanged in this prerequisite.

The old V compiler does not propagate a struct's heap attribute or underlying
sum variant identity through aliases. Pointer-retaining session-history and
history-sum boundaries consequently use the concrete shared DOM type; aliases
remain where supported. `SourceSnapshotParams` also receives the heap
annotation corresponding to its actual Source `GC::Cell` declaration in
`HTML/SourceSnapshotParams.h`, preserving pointer retention without an unsafe
stack-reference workaround.

All current fields remain present: CSP records with source, disposition, raw
input and exact typed origin, complete embedder values/endpoints, referrer
policy, and both enforced and report-only integrity fields. Pinned Source
`PolicyContainers.cpp:85–104` copies the enforced integrity policy during clone
and returns without copying the report-only integrity policy. The existing V
clone and its focused test preserve that exact behavior. Source serialization
contains only CSP, embedder and referrer policies; those existing fields remain
unchanged here as well.

Three focused cases in `dom/document_policy_container_owner_test.v` prove
persistent lazy identity/default fields, exact setter/navigation identity, and
retention of complete incoming records with a genuine opaque origin. Mutating
the retained actual CSP list reaches the Document, including a second actual
tuple origin with its nondefault port.

A further genuine Page/navigation Document case in the existing
`html/source_snapshot_params_test.v` retains a SourceSnapshotParams pointer
beyond its constructor's local scope. Its cloned CSP values, raw input and
opaque-origin identity survive replacement of the live settings container;
the actual fetch-client pointer remains the same. The existing two snapshot
cases and policy/history tests retain their original clone behavior.

The initial test fixture needed mutable Document variables for its finalizers
(`Build/audit-fixes/source-document-policy-owner-original-default.log`). The
clean pre-fix run failed the lazy pointer-identity assertion while the supplied
setter/navigation case passed
(`source-document-policy-owner-clean-original-default.log`). The first post-fix
run passed the new DOM cases but exposed the HTML alias/heap/sum compile
diagnostics described above (`source-document-policy-owner-default.log`).
Both existing HTML files then passed in 190.95 seconds
(`source-document-policy-owner-concrete-default.log`). The final GC-none batch
passed all six files in 370.49 seconds: new Document owner cases, native
navigation initialization, existing policy/history, retained SourceSnapshot
cases, environment-settings serialization and actual Meta lifecycle
(`source-document-policy-owner-gc-none.log`).
The final retained-snapshot file also passed with default GC in 75.48 seconds
(`source-document-policy-owner-snapshot-default.log`).

This slice removes the empty native record and fresh-object getter behavior.
Window/Worker settings still need their separate Source owner routing fix;
existing settings currently retain their own copied value. Meta referrer writes
to the actual shared field will be a later feature. CSP lists still use the
existing serialized DTO representation and consumers materialize engine lists;
the native GC/PolicyList graph remains a separate boundary. Document CSP
initialization and SourceSnapshot policy cloning also still use the existing
settings-based helper rather than Source's own Document container; their exact
own-Document caller fixes will follow the settings routing feature. No complete
policy-container or document initialization parity is claimed.

Canonical integration (`3006c89b`) passes the new Document owner, native
navigation initialization, retained SourceSnapshot, environment serialization
and actual Meta files with GC disabled. The six-file run retained an independent
failure in the old history clone fixture: it expected bare IPC null/undefined
tags although canonical `528ae74e` had already translated Source's owning storage
defaults. Source `SessionHistoryEntry.cpp:42–44` constructs the distinct
StorageSerializationRecords. The separate fixture commit `30e5d944` checks
cloned storage kinds, exact retained bytes and decoded null/undefined values.
It and the existing storage-record neighbor pass 2/2 GC-none. Original and
corrected logs are `source-document-policy-owner-canonical-gc-none.log` and
`source-policy-history-storage-default-canonical-gc-none.log`; the first is
5/6 rather than a clean six-file sweep.
