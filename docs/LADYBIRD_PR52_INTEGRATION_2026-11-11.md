# PR #52 review and integration audit — 2026-11-11

## Scope and changes

[PR #52](https://github.com/vox-browser/vox/pull/52) was integrated with master,
including the squash merges of PRs #56 and #55. Seven initial textual conflicts
were resolved while retaining both translation behavior and master's BOM
decoding, selector, DOM lifecycle, style invalidation and orthogonal grid work.

The three original review fixes were already present in the PR: AES-CTR counter
exhaustion rejection, cancellation of unsupported stylesheet loads and their
blockers, and outer opacity/blending around filtered clips. Their focused
regressions now execute successfully, including the native stylesheet completion
path.

Two additional issues were repaired during integration:

- Cached redirected stylesheets now keep the request URL as their CSSOM location
  and the final response URL as their resource base. Both URLs invalidate the
  synchronization cache. The regression also checks UTF-16 decoding, origin-clean
  behavior and stable identity when the source is unchanged.
- Iframe load dispatch now uses the actual active DOM document's load/mute state,
  rather than calling DOM document methods on the lightweight navigation record.
  Tests cover `document.open()`, replacement during dispatch, navigation gaps and
  standalone model behavior.

The stylesheet blocker fixtures were corrected to use `text/html` before a body
exists. They retain all script, load and rendering blocker assertions and now
check the rendering-blocker precondition explicitly.

## Source identities

These are **Git tree hashes**, independent of local versus API-created commit
identities. The final code/test candidate is
`5dcd48826ca408711461910f9f009ebf9fd345af`; this audit is a subsequent
documentation-only change.

| Source checkpoint | Git tree | Credited focused functions |
| --- | --- | ---: |
| Initial master integration | `c66ed7645fa33d002d30206256eff078e523073a` | 6 AES-CTR |
| Combined October translations | `a2ffa51cf3cae4cc83086c1cfd372ae6f937d9ae` | 14 crypto format/operation |
| Cached redirect repair | `3b13eb52c2310b4b25fcc655f1fd9239e278df23` | 13 CSS |
| Active DOM iframe repair | `4d3aba53eee75bc885258bd7a176b5653ce76aa5` | 3 iframe |
| Corrected stylesheet fixtures and final candidate | `5dcd48826ca408711461910f9f009ebf9fd345af` | 17 stylesheet/native/layout |

This is a composite of incremental checks, not one fresh full-suite run. Some
disjoint HTML preparation overlapped CSS-only checks; the checkpoints identify
the corresponding scoped source inputs. Later changes did not alter the tested
crypto, CSS or iframe inputs. The earlier AES-CTR implementation and its two test
files were unchanged by the October merge; the affected crypto format paths were
checked again on the combined source. Repeated attempts are not counted twice.

## Passing coverage

**53 distinct test functions across 14 files passed at runtime.**

| Test file | Functions |
| --- | ---: |
| `webcrypto/aes_ctr_test.v` | 4 |
| `webcrypto/aes_ctr_counter_wrap_test.v` | 2 |
| `webcrypto/aes_key_formats_test.v` | 4 |
| `webcrypto/chacha20_poly1305_test.v` | 4 |
| `webcrypto/ec_key_formats_test.v` | 6 |
| `css/remote_link_style_sheet_test.v` | 3 |
| `css/stylesheet_response_encoding_test.v` | 1 |
| `css/quirks_table_color_test.v` | 9 |
| `html/iframe_load_state_test.v` | 3 |
| `html/link_stylesheet_mime_test.v` | 6 |
| `resources/stylesheet_type_completion_test.v` | 1 |
| `layout/filter_clip_order_test.v` | 2 |
| `layout/grid_intrinsic_prior_day_test.v` | 5 |
| `layout/grid_definite_aspect_ratio_test.v` | 3 |

## Method and unsuccessful attempts

Execution used Linux, V 0.5.2 at
`f7f3add7af3c4615ba5dbedc06e18f76ef604346`, Clang 19 and
`tools/test_linux_native.py --gc none`. The runner selected the C backend,
enabled globals and OpenSSL, retained strict native pointer diagnostics and
passed `-memory-limit 10G`. Outer jobs used the 12 GiB sampled process-tree guard;
test binaries used its 3 GiB runtime limit. **Application/test GC was `none` in
every credited run.** Native completion compiled the application module with UI2
at `a97098663a0708cf21519f7d18138053df15f48d`.

The unsuccessful attempts remain part of this result:

- Early setup attempts stopped on missing Clang/ICU, then the ANGLE extension
  header and GLES runtime. Actual headers and native libraries were staged;
  stopped attempts receive no runtime credit.
- The first combined engine analysis exposed the invalid `EmbeddedDocument`
  method calls. The actual DOM bridge repair above resolved that failure.
- The first stylesheet MIME run failed its rendering-blocker assertion because
  the fixture retained an XML content type and an existing body. The corrected
  fixtures passed without weakening the assertions.
- The first final aspect-ratio compilation exited with SIGKILL (`-9`) before any
  test executed. Its outer guard completed normally and sampled
  9,088,065,536 bytes, below its 12 GiB limit. Host memory pressure was plausible,
  but an OOM event was not confirmed. Only that unexecuted file was retried with
  the same pinned compiler source rebuilt with Boehm for the **compiler's** own
  allocations. Project source, test GC and guard limits were unchanged. All three
  functions then passed; the retry took 66.9 seconds and sampled 9,108,226,048
  bytes. No peak-memory reduction is claimed.

The native stylesheet completion case exercised both successful and failed
transport completion after the owner became unsupported. The final grid checks
covered intrinsic contributions, flexible spanning tracks, automatic minimum
edges and definite-height/aspect-ratio behavior. No additional tests were queued
after the scoped retry.

## Limits

No full-repository suite, graphical browser run or production bundle is claimed.
Normal managed post-commit hooks ran, but their production requests reported
`Production builds require master in the canonical checkout` in this Linux PR
checkout. No hook was bypassed. `git diff --check` against the integrated master
passed, and implementation/test changes were committed separately from this
audit.
