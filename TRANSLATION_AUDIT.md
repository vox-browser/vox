# Ladybird C++ → V translation audit

Audit date: **2026-10-02**. Upstream:
`/Users/alex/code/3rd/ladybird`, commit
`963d46a829f3e1b79f44dba9d02afb70654300fa` (clean checkout).
Translation: `/Users/alex/code/vox2`, starting commit
`0783ddfa41600f77e4ae0396ef7472fea3d33c7c`, including the working tree as read.
Pre-existing changes to `README.md`, `PORT_STATUS.md` and `libjs/PORT_STATUS.md`
were left untouched. Those existing documentation edits were committed
separately as `692d54bc642a5ceac601e2f47e7f5e9e6e2d0642` during the review;
the implementation contents did not change between those two revisions.

**The requested standard is not met.** Confirmed stubs, untranslated upstream
responsibilities, disconnected runtime integrations and behavior-changing
substitutes remain. This report records findings rather than repairing the
translation. It does not certify the unaffected code as correct or establish
the historical origin of all V algorithms.

## Coverage and parallel reviews

“Big C++ source” means a **tracked `.cpp` file containing at least 1,000 physical
lines in the current checkout**. This makes the coverage boundary explicit and
reproducible. There are **128** such files: **111 production/utility sources**
(248,788 lines) and **17 test/harness sources**. The 70 LibWeb/LibJS sources
account for 168,447 lines. Headers, smaller C++ files, upstream Rust algorithms,
Objective-C/Swift UI and historical/deleted C++ units are outside this size
inventory. Some were inspected as dependencies; that is not a complete audit
of those additional units.

Four agents reviewed the implementation concurrently. Each core report maps
every assigned source to actual V files, identifies the bodies or integration
paths compared, and records concrete evidence. Core review was selective
within each source; it was **not every-function/every-branch verification**.
For the additional 41 sources, the review identifies responsibility, related
code and boundaries; it does not assert that a host replacement is equivalent.

| Review | Large sources | Report |
| --- | ---: | --- |
| DOM, HTML, parsing, navigation and canvas | 21 | [DOM and navigation findings](docs/translation-audit/dom-navigation.md) |
| CSS, layout, painting, animation and view transitions | 15 | [Style and paint findings](docs/translation-audit/style-paint.md) |
| Networking, storage, streams, crypto, page APIs and other web APIs | 17 | [Web API findings](docs/translation-audit/web-apis.md) |
| LibJS runtime, builtins and execution integration | 17 | [LibJS findings and execution probes](docs/translation-audit/libjs.md) |
| Other libraries, services, Qt UI and standalone utilities | 41 | [Additional source boundaries](docs/translation-audit/additional-sources.md) |
| Tests and harnesses, inventoried only | 17 | Listed in the additional source report; no production-parity verdict |

The repository describes itself as the canonical **LibWeb** V workspace and
contains a separately refreshed LibJS slice. Translating those libraries does
not automatically translate LibWebView, LibWasm, the process services or Qt UI.
Their inclusion here answers the broader “translation of Ladybird” request;
missing ports there must not be confused with newly introduced LibWeb defects.

## How to interpret the findings

The detailed reports distinguish:

- **Untranslated logic:** upstream performs meaningful work for which the
  examined V production path lacks an implementation or rejects the operation.
- **Stub:** a represented operation returns a placeholder, logs a request,
  fabricates a result or stops at an unavailable backend without performing
  the upstream work.
- **Semantic divergence:** both paths execute, but a concrete branch,
  ordering rule, state transition or result differs.
- **Adaptation/boundary:** a V representation or platform backend differs;
  this alone is not proof of a bug or of invented logic.
- **Unverified:** no concrete defect was established in the compared sample,
  or source provenance/equivalence requires further work. This is not a pass.

An upstream FIXME, allocator-only factory or deliberate upstream no-op is not
a translation defect merely because the V body is small. The reviewers traced
helpers and browser adapters to distinguish model-level gaps from live browser
behavior. A matching method name, passing model test, screenshot or explanatory
comment is not a proof that the source unit was faithfully translated.

“No logic written from scratch” is a provenance requirement as well as a
behavioral one. Source comparisons can demonstrate a substituted algorithm
or missing work, but cannot prove the origin of every implementation. A future
provenance sign-off needs a function-level source mapping with upstream
revision, reviewed control/data flow and documented language adaptations.

## Findings to address first

The core reports record **61 finding IDs** (21 DN, 14 SP, 18 WA and 8 JS),
plus five broader source boundaries (EX). They give source references and the
translation work required. The confirmed issues include:

- Missing production LibJS instructions, builtin graph and primitive boxing;
  ordinary array/function literals and numeric primitive method access fail.
  See **JS-01 through JS-06** and the reproduced runner outputs.
- Missing cryptographic operation backends and WebAssembly validation/execution.
  Symbol-shaped entry points do not supply the upstream algorithms.
- WebGL queries that fabricate metadata/status instead of consulting a native
  rendering backend, and XHR entry points disconnected from actual fetch.
- Missing fetch policy integration, IndexedDB connection/upgrade coordination
  and stream Promise-driven sequencing; the writable close sentinel also
  collides with an ordinary user-written string.
- DOM/HTML omissions including resizable-buffer serialization and execution
  dependencies for event handlers/navigation operations.
- Animation and live view-transition behavior that differs from the upstream
  lifecycle and rendering integration.

These are examples from the completed audit findings, not an exhaustive list
of every remaining translation task. Do not treat the current status documents'
completion language as a source-equivalence certification. Also do not discard
working translated slices wholesale: the reports identify concrete missing
dependencies and branches that can be completed with focused tests.

## Automated inventory evidence

Ran the existing `tools/libweb_translation_audit.py` against the current
checkout. It is a **symbol candidate inventory**, not semantic verification:

| Scanner metric | Observed |
| --- | ---: |
| Module directories with C++ sources | 76 |
| Module-owned C++ files scanned | 1,193 |
| Extracted upstream implementation symbols | 21,401 |
| Candidate name matches | 14,261 |
| Consolidated name matches | 525 |
| Unmatched symbols | 4,158 |
| V function-name inventory | 27,809 |
| Suspicious trivial implementations reported | 0 |
| Existing allowlisted “verified trivial implementations” | 541 |
| Semantic-divergence comment markers reported | 6 |

The scanner excludes five LibWeb root C++ files from its module pass, hence
1,193 rather than the checkout's 1,198 LibWeb `.cpp` files. Its 4,158 unmatched
symbols need investigation; they are not 4,158 proven missing algorithms.
Conversely, zero suspicious trivial bodies does **not** establish zero stubs:
the body reviews found backend termination, fabricated results and missing
integration that this heuristic does not detect. The allowlist label is the
tool's classification, not an independent approval by this audit.

Verification performed:

- Existing translation-inventory Python tests: **34 passed**, using
  `python3 -m unittest discover -s tools -p '*translation_audit_test.py'`.
- Existing standalone LibJS runner compiled successfully with
  `v -old-compiler -enable-globals`; nine documented execution probes completed
  with the documented supported or missing-translation observations.
- Three web-API probes reproduced the stream sentinel collision, invalid Wasm
  validation and IndexedDB upgrade coordination gap; their full V source is
  included in the web-API report.
- Report inventory, file references and finding anchors checked against the
  current working tree before committing the documentation.

No implementation was changed. Full translation tests, heap-ownership tests,
AST differential corpus, browser rebuild and screenshots were not run for
this documentation-only audit. Their absence limits behavioral validation;
existing tests are not being represented as failing or passing here.

## Reproduce the source inventory

```sh
python3 - <<'PY'
from pathlib import Path
import subprocess
root = Path.home() / 'code/3rd/ladybird'
for relative in subprocess.check_output(
    ['git', '-C', str(root), 'ls-files', '*.cpp'], text=True
).splitlines():
    path = root / relative
    if not path.exists():
        continue
    lines = len(path.read_bytes().splitlines())
    if lines >= 1000:
        kind = 'test/harness' if relative.startswith('Tests/') else 'production/utility'
        print(f'{lines:5} {kind:18} {relative}')
PY

python3 tools/libweb_translation_audit.py --ladybird ~/code/3rd/ladybird
```

The symbol scanner intentionally returns status 1 while unmatched symbols
remain. For full scanner data, add `--json` and save the output outside tracked
sources. Re-run and revise these reports when either checkout changes; their
line references and counts describe this snapshot only.

Completion of the strict request requires resolving the confirmed gaps and
then extending review to every remaining method/branch, headers and current
Rust responsibilities. This audit supplies a concrete review/translation queue;
it is not a claim that all translation work has been completed.
