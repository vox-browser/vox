# Audit fix progress

Tracks implementation against the historical [audit](../../TRANSLATION_AUDIT.md), upstream `963d46a829f3e1b79f44dba9d02afb70654300fa`. Each completed translation slice receives a focused implementation-and-test commit. Findings stay open until all their stated omissions are addressed; a supporting slice does not close a broad finding.

The user requested ten agents. This session permits four active agents including the coordinator, so ten assignments run in waves in isolated worktrees. Root reviews and integrates each fix and runs shared checks. Existing untracked work is excluded.

| Assignment | Findings | Status |
| --- | --- | --- |
| 1. Streams, storage and scheduling | WA-05, WA-09, WA-10, WA-13 | Paused between waves; unfinished work retained |
| 2. CSS fonts, matching and observers | SP-05, SP-06, SP-07, SP-08, SP-09, SP-10, SP-12 | Paused between waves; unfinished work retained |
| 3. LibJS intrinsics, primitive references and Math | JS-02, JS-04, JS-06 | Paused between waves; unfinished work retained |
| 4. DOM, forms and events | DN-01, DN-04, DN-05, DN-06, DN-07, DN-11, DN-12, DN-13, DN-19, DN-20, DN-21 | Paused between waves; unfinished work retained |
| 5. Navigation and HTML lifecycle | DN-02, DN-08, DN-09, DN-14, DN-15, DN-16, DN-17, DN-18 | Active |
| 6. Canvas, layout, animations and view transitions | DN-10, SP-01, SP-02, SP-03, SP-04, SP-11, SP-13, SP-14 | Queued |
| 7. Fetch, XHR, Page and diagnostics | WA-03, WA-04, WA-06, WA-07, WA-08, WA-16, WA-17, WA-18, EX-05 | Queued |
| 8. Crypto and WebGL | WA-01, WA-02, WA-14, WA-15 | Queued |
| 9. Wasm, platform and source boundaries | WA-11, WA-12, EX-01, EX-02, EX-03 | Active |
| 10. LibJS execution, remaining builtins and Intl | DN-03, JS-01, JS-03, JS-05, JS-06, JS-07, JS-08, EX-04 | Active |

JS-06 is split: assignment 3 owns Math; assignment 10 owns JSON, Date and Temporal. The coordinator completed DN-17 and WA-18 and is integrating DN-19 construction state.

| Finding | Audit description | State | Evidence |
| --- | --- | --- | --- |
| DN-01 | Raw inline event handlers become inert callbacks (High) | Open |  |
| DN-02 | Intercepted navigation continues normal navigation and finishes synchronously (High) | Open |  |
| DN-03 | Module linking is represented by a boolean after a fetch walk (High) | Open |  |
| DN-04 | Form submission uses a reduced entry-list algorithm (High) | Open |  |
| DN-05 | Form reset bypasses the implemented control reset algorithms (High) | Fixed concrete controls `8e2a5634` | Snapshot associated membership, concrete input/textarea/select/output reset and retained model synchronization; custom reaction runtime tracked under DN-07. |
| DN-06 | Submit events lose their submitter interface (High) | Fixed `afe3779c` | SubmitEvent interface, button/null submitter, cancellation and legacy bypass; existing form tests pass. |
| DN-07 | Form-owner lookup skips an earlier non-form with the same ID (High) | Partial `0f325e2b` | First-ID tree-order/HTML-only lookup fixed with duplicate-ID/live reassociation tests; custom reactions remain open. |
| DN-08 | Image decode omits active-document checks and initial asynchronous ordering (High) | Open |  |
| DN-09 | Input pattern compilation substitutes V regex semantics (High) | Open |  |
| DN-10 | Canvas path rasterization drops paint-style, blur, filter and stroke semantics (High) | Open |  |
| DN-11 | Microtask checkpoints omit their final cleanup steps (High) | Open |  |
| DN-12 | Rendering uses registration order and drops two document filters (High) | Open |  |
| DN-13 | Element client geometry omits root/quirks and inline exceptions (High) | Open |  |
| DN-14 | Media seeking and timeupdate use different algorithms (High) | Open |  |
| DN-15 | Navigable scroll promises always resolve after an instant change (High) | Open |  |
| DN-16 | Live local-link media changes do not refresh the installed sheet (High) | Fixed `a3129ce6` | Loaded CSS sheet identity survives media changes and cache hits; CSSOM edits retained. Four focused/existing test files pass. |
| DN-17 | Structured cloning loses resizable ArrayBuffer capacity (High) | Fixed `3cd450b7` | Resizable capacity, byte-copy independence, storage, tracking view identity, malformed records; focused and existing structured clone tests pass. |
| DN-18 | Window.find counts DOM source text without selecting a rendered match (High) | Open |  |
| DN-19 | Direct navigation document construction drops supplied sandbox flags (High, entry-point scoped) | Partial `7710ab3a`, `f8d8f5ae` | Flags/about-base/navigation-ID/policy pointer copied; real HTML global registry factory installed and tested. Full policy/realm environment integration remains open. |
| DN-20 | Global exception reporting replaces ErrorEvent and changes omitError behavior (High) | Open |  |
| DN-21 | Global service getters return empty facades (Medium, API integration) | Open |  |
| SP-01 | Live view transitions do not populate or render captured elements | Open |  |
| SP-02 | `Animation.cancel()` loses cancel-time capture and invalidation | Open |  |
| SP-03 | Finish notification resolves immediately and uses the wrong event time | Open |  |
| SP-04 | The Web Animations `KeyframeEffect` drops custom-property keyframes | Open |  |
| SP-05 | Manually created `FontFace` objects always register a normal slope | Fixed `e2ef1376` | Manual FontFace normal/italic/oblique matching and setter re-keying. |
| SP-06 | URL font loading completes synchronously | Open |  |
| SP-07 | Font matching mixes installed faces with author family faces | Fixed `95be0742` | Installed Arial versus registered nonexact-weight author face. |
| SP-08 | Dashed CSS function lookup omits layers, origins and enclosing scopes | Open |  |
| SP-09 | Quirks-mode class/ID candidate lookup does not fold case | Fixed `8bd4532e` | Quirks bucket/matcher/hash folding and constructed-sheet cache isolation; focused and existing adopted-sheet tests pass. |
| SP-10 | CSS image observation omits cursor/border images and reverses replacement order | Open |  |
| SP-11 | Styled `::first-letter` has no translated layout construction | Open |  |
| SP-12 | Computed pseudo custom-property lookup lacks originating-element fallback | Fixed `cf04b760` | Live shadow-slot pseudo custom property inheritance and own override tests pass. |
| SP-13 | Portable shadow replay uses sharp/rectangular approximations | Open |  |
| SP-14 | View-transition dynamic rules are replaced instead of updated as upstream | Fixed standalone record `5d2c5e9f` | Retained rule object updates selector only; preserves declaration values, image refresh and cleanup. Live CSSOM binding remains under SP-01. |
| WA-01 | Upstream cryptographic operations are explicit unavailable-backend stubs | Open |  |
| WA-02 | SubtleCrypto Promise/task behavior is replaced with synchronous typed results | Open |  |
| WA-03 | Shared Fetch omits CSP, mixed-content, and integrity policy gates | Open |  |
| WA-04 | Shared Fetch does not determine the request referrer | Open |  |
| WA-05 | IndexedDB opens/upgrades bypass connection queue and version-change coordination | Fixed package coordination `4798ceb6` | All 11 IndexedDB test files pass; HTML task-source binding tracked under DN-11/DN-21. |
| WA-06 | Internals layout-tree dumping returns a marker instead of inspecting layout | Open |  |
| WA-07 | Page EventHandler DOM pointer/click/activation algorithms are log operations | Open |  |
| WA-08 | Page load/reload methods update logs instead of invoking navigation | Open |  |
| WA-09 | Streams underlying callbacks cannot remain pending | Open |  |
| WA-10 | WritableStream close sentinel collides with a normal string chunk | Fixed `4b8ca372` | All 12 Streams test files; private sentinel collision regression. |
| WA-11 | WebAssembly validate/compile skip core sections and validation | Open |  |
| WA-12 | WebAssembly instantiation fabricates exports without machine execution | Open |  |
| WA-13 | WebDriver action tick durations and queue scheduling are omitted | Fixed tick scheduling `16ca55b7` | All five WebDriver test files pass; platform timer/task delay and real pause. Browser input endpoint wiring remains open under WA-07. |
| WA-14 | WebGL has synthetic answers and no real backend dispatch | Open |  |
| WA-15 | WebGL2 sync completion is fabricated | Open |  |
| WA-16 | XMLHttpRequest send does not start Fetch or schedule a timeout | Open |  |
| WA-17 | XMLHttpRequest document responses are strings, without HTML/XML parsing | Open |  |
| WA-18 | XMLHttpRequest progress dispatch lacks upstream throttling | Fixed `a02f2a92` | Deterministic 50 ms upload/download boundary tests; all four XHR test files pass. |
| JS-01 | Missing creation/suspension instructions and ECMAScript function execution | Open |  |
| JS-02 | Native slices are not connected to the complete production intrinsic graph | Open | Supporting slice `26335b81`: ObjectPrototype record/tag dispatch; graph remains open. |
| JS-03 | RegExp and remaining String prototype responsibilities are absent | Open |  |
| JS-04 | Production numeric/string primitive references stop at an InternalError | Open |  |
| JS-05 | Object private elements, Proxy branches, eval and disposal are not translated | Partial `fa7eb0ef` | Private-element algorithms and private Reference dispatch with focused default/none GC tests; class instructions, Proxy/eval/disposal remain open. |
| JS-06 | Math, JSON, Date and Temporal source units have no runtime counterparts | Partial `6171f757` | Complete Math methods/metadata installed; JSON/Date/Temporal still open. |
| JS-07 | Value.str() substitutes a class label for upstream recursive value inspection | Open |  |
| JS-08 | Persistent bytecode-cache materialization is missing | Open |  |
| EX-01 | See [additional source boundaries](additional-sources.md) | Open | |
| EX-02 | See [additional source boundaries](additional-sources.md) | Open | |
| EX-03 | See [additional source boundaries](additional-sources.md) | Open | |
| EX-04 | See [additional source boundaries](additional-sources.md) | Open | |
| EX-05 | See [additional source boundaries](additional-sources.md) | Open | |

## Integrated fix validation

- `4b8ca372`: Streams queue close identity and ordinary string/undefined/null/byte chunks.
- `e2ef1376`: CSS manual font slope registration.
- `95be0742`: CSS author-family candidate isolation (macOS installed-font check).
- `26335b81`: LibJS ObjectPrototype source-order initializer and tag dispatch. Broad JS-02 remains open.

Agent checks run with `v -old-compiler -enable-globals`. Isolated worktrees use direct compiler argv for each `_test.v`, because the V test runner does not preserve a quoted `-path` containing `|`. Shared integration checks run from the canonical workspace.

- Integrated LibJS suite: `v -old-compiler -enable-globals test libjs` — **218/218 passed**. `-gc none` run also **218/218 passed**. Exact upstream AST corpus `--all`: **100/100 passed**. Root is preserving concurrent user regex work and status documentation.
