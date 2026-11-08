# LibRegex wrapper translation

Upstream reference: Ladybird
`963d46a829f3e1b79f44dba9d02afb70654300fa`.

| Source | V implementation | Completed behavior |
| --- | --- | --- |
| `Libraries/LibRegex/RustRegex.{h,cpp}` | `compiled_rust_regex.c.v` | Native owner construction/destruction and moves, all compile flags, original compile errors, ASCII/UTF-16 dispatch, named captures, cached capture slots, matching, single-astral-literal detection, and the source 256-slot doubling loop for bulk matches |
| `Libraries/LibRegex/ECMAScriptRegex.{h,cpp}` | `ecmascript_regex.v` | Concrete wrapper construction and moves, match/limit result mapping, all forwarding operations, named-group records and match pairs |
| `Libraries/LibUnicode/CharacterTypes.cpp` C exports | `unicode_abi.v` | Calls to the existing translated LibJS Unicode property, string-property, case-fold, range and closure helpers through their ICU ABI |
| `Libraries/LibWeb/HTML/HTMLInputElement.cpp:303–335,3856–3894` | `../html/html_input_element.v` | Original-pattern compile gate, UnicodeSets mode, noncapturing full-value anchors, applicable-state and empty-value gates, multiple-email nonempty split views and live validity synchronization |

The C++ source wrappers use a Rust backend. This translation uses byte-exact,
repository-owned copies of that same pinned backend, listed with SHA-256 hashes
in [native/manifest.json](native/manifest.json). The native header contains ABI
declarations only. No substitute V regex grammar or JavaScriptCore regex call is
used for this HTML algorithm. The Rust parser, compiler and instruction loop
have **not** been translated to V; the separate LibJS runtime RegExp objects and
its partial V regex VM remain unfinished.

Build the offline dependency with `python3 tools/build_regex_backend.py` before
running V tests in a fresh checkout. `build-prod-browser.sh` performs this step
automatically. It requires Rust edition 2024 support; `RUSTC` selects the
compiler. Archives are built under `Build/libregex/{darwin,linux,windows}/` so
concurrent hosts keep separate link inputs, without reading or linking the
Ladybird checkout. Source verification is available separately as
`python3 tools/build_regex_backend.py --verify-only`.

The focused wrapper tests cover UnicodeSets intersections, named captures and
backreferences, original compile errors, empty input, capture preservation on a
failed match, ASCII and retained UTF-16 storage paths, 300-match buffer growth,
move ownership and astral literals. They pass with default GC and `-gc none`.
The HTML tests cover set subtraction, changed backreference numbering under the
old capturing wrapper, missing/empty/invalid/inapplicable patterns and email
lists; the new and existing input test files pass together with GC disabled.
The new input and wrapper files also pass together with default GC. A
`-prod -gc none` probe executes UnicodeSets matching, named captures and buffer
growth outside assertions and passes (`source-regex-wrapper-production.log`
under `Build/audit-fixes/`).

Callers explicitly destroy the native owner, matching the source's destructor;
automatic V GC finalization and FlyString interning are not implemented here.
The HTML caller uses the existing UTF-8 DOM/model string representation;
arbitrary lone-surrogate DOM strings remain a broader string-storage boundary.
The source Rust panic initialization hook and complete native startup/VM graph
are outside this wrapper slice. These limits do not use replacement regex
algorithms or fabricated execution results.
