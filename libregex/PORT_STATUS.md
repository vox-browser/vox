# LibRegex V translation

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`.

The regex parser, bytecode compiler, fast/general execution loops, lookarounds,
required-literal analysis and high-level engine are implemented in `../libjs/`.
`compiled_regex.v` translates the source owner wrapper, including flags, original
compile errors, named captures, ASCII/UTF-16 dispatch, capture slots, moves,
single-astral detection and bulk-buffer growth. `ecmascript_regex.v` preserves
the concrete wrapper's result mapping and forwarding operations. HTML input
pattern validation now calls this V engine in UnicodeSets mode, preserving
the original-pattern compile gate and noncapturing full-value anchors.

There is no regex Rust snapshot, archive build or link dependency. Unicode
properties and case data still use the existing ICU bridge. This does not
replace JavaScriptCore or complete LibJS's RegExp object, constructor and
prototype integration; the frontend `compile_regex_pattern()` hook remains
unfinished.

The frozen parser corpus contains 3,018 complete source AST/error records.
The full-engine corpus contains 26,544 exact source records, including every
capture/output slot, UTF-16 surrogates, flags, ASCII dispatch and bulk-buffer
capacities. Both GC modes pass. The temporary migration oracle used the pinned,
unchanged Rust implementation and the same translated Unicode exports as the
old browser backend. Future checks consume the frozen records without Rust;
see [the reference-checker guide](../tools/REFERENCE_CORPORA.md).

The broad LibJS check passes 241/243 files in each GC mode, with failures in
the existing ICU default-locale regex folding and String casing tests. All 100
upstream AST fixtures match. [The migration report](../docs/translation-audit/RUST_TO_V_PROGRESS.md)
retains those failures and the direct host-ICU reproduction.

Ninety repeated-empty-class-string `/v` cases could not produce source
expectations: the source exceeded the 3 GiB memory guard. They are excluded
from the count above. Separate regression tests bound zero-progress repetition
and verify captures against Node v26.8.1 for six patterns, including nested set
intersection. Successful source records have no case overrides. This fixes an
inherited source defect; it does not establish full ECMAScript conformance.
The source 10,000,000-step execution limit is retained. Group/class parsing
and nested lookaround execution have explicit stack-safety bounds of 128.

The focused wrapper tests cover errors, moves, destruction, set operations,
named backreferences, buffer growth and source surrogate conversion. They pass
in both GC modes. The HTML input-pattern caller also executes successfully with
`-gc none` and unavailable Rust compiler paths. Windows native smoke code
compiles and links with warnings treated as errors; it was not executed on
Windows for this change. No production browser was rebuilt or launched for this change; the executed
library and HTML caller tests supply the new-runtime evidence.

`destroy()` detaches V-owned references and is idempotent; allocation lifetime
now follows V's collector or the caller's arena. It does not reproduce immediate
Rust destructor reclamation under `-gc none`. DOM strings still use the existing
UTF-8 representation, so arbitrary lone-surrogate DOM storage remains a broader
boundary. JPEG XL remains a separate Rust dependency pending its V decoder port.
