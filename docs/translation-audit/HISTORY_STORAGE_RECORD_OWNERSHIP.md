# Source history storage record ownership

Source pin: `963d46a829f3e1b79f44dba9d02afb70654300fa`.
Reviewed: 2026-10-04. Features: `1da658c0`, `528ae74e`.

`HTML/SessionHistoryEntry.h` owns classic and Navigation API state as
`StorageSerializationRecord`. `DOM/Document.cpp:6873–6885` therefore selects
StructuredDeserialize's storage overload when restoring classic state. The
DOM dependency-cycle record carries bytes only; its HTML callback must retain
that statically known storage type. The old callback rebuilt an IPC record,
causing valid LBSC history strings to become null after deserialization failed.
`1da658c0` restores the Source overload without guessing the codec from bytes.

`SessionHistoryEntry.cpp:44–50` constructs default null/undefined states with
StructuredSerializeForStorage. `528ae74e` uses the same serialization calls,
then preserves the record representation across entry cloning, navigation
population/redirect results and NavigationDestination state copies. Source
copies/moves retain the concrete record type; V's shared DTO must carry its
type explicitly. Existing standalone IPC DTO callers keep their representation
and same-process shared backing references during copies.

Actual initialized Document/Window history restoration checks raw UTF-16,
signed zero, integer/string/boolean values and error-to-null behavior. A clean
**4/4 canonical GC-disabled batch** passes the new owner cases, existing
event-loop history restoration, storage codec and unload-check task cases
(`source-history-storage-owner-canonical-gc-none-recheck.log`). The initial new
fixture's incorrect URL accessor is retained as a compile diagnostic; the
unchanged production correction passed the existing event-loop regression
on that initial run.

Storage defaults, entry/destination copies and navigation population/redirect
state checks pass with five existing owner/population/navigation/history/
traversable neighbors, **6/6 canonically with GC disabled**
(`source-history-record-copy-canonical-gc-none.log`). Payloads deserialize and
preserve raw UTF-16/signed-zero bits rather than merely matching DTO fields.

This repairs codec selection and record copies. Full target-realm/native
SerializableObject reconstruction, process history transport and production
LibJS/wrapper ownership remain separate boundaries. It does not complete those
graphs or change the pinned deserializer's error-to-null history behavior.
