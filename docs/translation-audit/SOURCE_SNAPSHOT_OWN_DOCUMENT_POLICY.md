# SourceSnapshot clones the source Document's own policy container

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/SourceSnapshotParams.cpp:18–64`,
`HTML/SourceSnapshotParams.h:18–46`, and
`HTML/PolicyContainers.cpp:80–100`.

SourceSnapshot reads activation and the fetch client through the source
Document's relevant Window/settings, but explicitly clones that Document's
own policy container. Current settings instead return the Window's current
associated Document container. Those owners can differ during reassociation.
The V snapshot now clones directly through `source_document.policy_container()`
while preserving the existing actual settings and activation reads.

The new genuine regression uses two Page-created navigation Documents, their
actual Windows and response-header containers. The original container retains
header and parser-factory Meta policy order, a port-bearing tuple origin and a
real opaque Meta origin, referrer/embedder/enforced integrity metadata and
sandbox flags. The original Window is then associated with the replacement
Document before snapshotting the original. Fetch-client identity and activation
must still follow its actual Window/settings while the policy clone belongs to
the original Document. Later insertion, mutation and owner replacement must
leave the retained snapshot unchanged.

Pinned Source clones enforced integrity and omits report-only integrity; that
existing behavior is preserved. The null-source UI branch and explicit
Document-without-settings adapter retain their existing boundaries. The V
snapshot's policy field is a value record retained inside the heap-annotated
SourceSnapshot holder; full Source GC and pointer graph parity remain separate.

The new reassociation case failed the clean baseline in 39.65 seconds
(`Build/audit-fixes/source-snapshot-own-policy-original-default.log`); the other
three existing cases had no failures. After the single Source owner-read
correction, all four cases passed with default GC in 58.32 seconds
(`source-snapshot-own-policy-default.log`). Before checking policy/history
neighbors, the private branch reused the independent canonical history-clone
fixture correction `30e5d944`; it expects the already-translated Source storage
serialization envelope and is separate from this snapshot feature. The final
GC-none batch passed all three files in 112.71 seconds
(`source-snapshot-own-policy-gc-none.log`): SourceSnapshot, navigation population
requests and policy/history cloning. The retained snapshot proof does not rely
on garbage collection.
