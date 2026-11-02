# Five additional news-site comparisons

The [forum/news catalog](../Tests/Browser/Brave/forum-news.json) now contains
15 sites. TechCrunch, Engadget, The Register, Slate and WIRED have sealed guest
DOM archives, original response bodies, full-uBlock Origin reports and source
PNGs. They are registered as strict conformance tests; **none of the five has
passed the complete pixel gate yet**.

The original ten are also incomplete: six accessible archives pass both source
fidelity and native equality; CNN matches frozen Brave but retains its separate
source-fidelity failure. Reddit is blocked, and Stack Overflow/Pikabu remain
deferred. See [the original checkpoints](ADBLOCK_POPULAR_SITES.md).

## Initial production baseline, November 2, 2026

All comparisons use a fresh private profile, an empty response cache, 1024×768
document viewport and scale 1. Brave Shields is disabled and full MV2 uBlock
Origin uses the repository's pinned lists. Vox uses the same filtering policy,
including disabling its additional cookie-banner blocker. Slate's initial
consent banner remains part of this guest viewport.

The production executable SHA-256 is
`0bb14e2f940d1ee83a4a57f48179ab40fb3ecf71aa8b7331f199676792ab6974`.
Each attempt retains before/after executable, native-library, runtime-asset and
Brave-framework identities. Comparisons replay original URLs through a sealed
private TLS proxy; missing resources never fetch from the network.

| Site | Saved source → frozen Brave pixels | Vox → frozen Brave pixels | Result |
| --- | ---: | ---: | --- |
| TechCrunch | 0 | 42,597 | Native rendering gap |
| Engadget | 90,850 | 1,717 | Source fidelity and native rendering gaps |
| The Register | 110,180 | 6,786 | Source fidelity and native rendering gaps |
| Slate | 19,064 | 221,448 | Source fidelity and native rendering gaps |
| WIRED | Unqualified | Unmeasured | Frozen reference changed between consecutive frames |
| Hacker News control | 0 | 0 | Strict pass |

The six-case command exited 1. All attempts, guards, exact commands, PNGs,
request/header checks, CSS comparisons and readiness audits are retained in
[the baseline](../Build/forum-news-expansion-20261102/registered-baseline/summary.json).
The shared bundle remained unchanged throughout each comparison. Small errors
still count: Engadget/Register source gaps are predominantly low-channel-error
image differences, not accepted equality.

An independent [TechCrunch diagnostic](../Build/forum-news-expansion-20261102/techcrunch-audit/summary.json)
again gives source equality but 41,841 native differing pixels, with no hovered
or focused element. The first capture's additional link underline was transient.
Remaining differences include image sampling and its SVG menu mask. No source
reference or tolerance was changed.

## Acquisition and oracle policy

Ars Technica returned HTTP 405 human verification, AP News returned HTTP 403
Cloudflare verification, and NPR navigation timed out. They were not substituted
with access pages. Direct captures also failed on several eventual additions;
Engadget, The Register and WIRED were acquired through the configured explicit
HTTP proxy. That proxy is used only for acquisition; comparisons remain sealed.
[Initial attempts](../Build/forum-news-expansion-20261102/acquisition-summary.json),
[replacement attempts](../Build/forum-news-expansion-20261102/replacement-acquisition-summary.json)
and [proxy attempts](../Build/forum-news-expansion-20261102/proxy-acquisition-summary.json)
retain failures as well as successes. ESPN's unsuccessful candidates remain
diagnostic evidence outside the selected five.

WIRED exposed an oracle bug: the pinned list contains `@@||wired.com^$ghide`.
Vox correctly suppressed generic cosmetics, but the old comparison queried
uBO's cosmetic engine without its tab policy. The oracle now obtains both
generic/specific switches from the matching full-uBO top-level PageStore,
passes them to the specific engine, and omits generic retrieval when disabled.
It rejects absent, disabled and unrelated tabs. The source capture
passes all filtering checks with `generic_enabled:false`; it has 20 cosmetic
rules, instead of the old query's invented 1,203.
[The corrected acquisition](../Build/forum-news-expansion-20261102/wired-policy-fixed/capture.json)
and [23 passing Node checks](../Build/forum-news-expansion-20261102/oracle-policy-tests.guard.json)
validate the change. Hacker News remains an independent normal-policy control.
This is a harness correction, not an engine rendering improvement.

Restored profiles exposed another oracle ambiguity: multiple PageStores can
have the same URL. The oracle now creates its own uniquely marked Chrome tab,
binds that tab ID to the corresponding CDP target, and closes other tabs in
the disposable profile. Cosmetic policy queries require that explicit tab ID.
[Seventeen focused Node checks](../Build/forum-news-expansion-20261102/oracle-target-tests.guard.json)
pass. An [Engadget complete-cache diagnostic](../Build/forum-news-expansion-20261102/engadget-complete-target/summary.json)
finishes the entire capture/filtering workflow with matching tab identities;
its source gap is 221 pixels and native gap remains 1,717. That alternate
diagnostic archive does not replace the registered cold archive.

## Focused mask regression

`techcrunch-mask-sizing` retains the publisher's original 12×10 vector menu
shape. Ten cases cover contain sizing in integer/fractional/wide/tall boxes,
natural and explicit dimensions, cover sizing, percentage positioning and an
existing square-mask control; a zero-sized image must retain a transparent
mask group. Two independent full-uBO Brave captures agree exactly; the
production baseline differs at 1,286 pixels.
[Reference receipts](../Build/forum-news-expansion-20261102/mask-reference-complete/references.json)
and [the failing native check](../Build/forum-news-expansion-20261102/mask-expanded-before.guard.json)
are retained. Commit `7f31cf052` resolves concrete non-repeating SVG mask tiles
before collecting paths. Six focused V tests execute successfully with both
[default GC](../Build/forum-news-expansion-20261102/mask-final2-default-run.guard.json)
and [GC disabled](../Build/forum-news-expansion-20261102/mask-final2-none-run.guard.json).
Existing SVG-image, mask-origin, document-cache and gradient-mask controls also
pass in [the focused checks](../Build/forum-news-expansion-20261102/focused-masks/).
Production pixel validation is pending a bundle containing that change; the
old executable cannot validate it.

Commit `e2ccd4b63` also snaps generated linear/radial mask image origins in the
Chromium profile while preserving fractional layout and image dimensions.
The new eight-column `techcrunch-gradient-solid` regression removes image
decoding from the comparison: its two integer-origin columns already match,
while fractional columns account for all 50,400 differing pixels in the old
bundle. Two full-uBO Brave references agree exactly in
[the reference receipts](../Build/forum-news-expansion-20261102/solid-mask-reference2/references.json).
The layout test checks 32 policy/origin/gradient combinations and passes with
both [default GC](../Build/forum-news-expansion-20261102/gradient-origin-default-run.guard.json)
and [GC disabled](../Build/forum-news-expansion-20261102/gradient-origin-none-run.guard.json).
The browser regression remains pending a production bundle containing the fix.

## Photo-mask isolation

A synthetic [original-origin HTTP diagnostic](../Build/forum-news-expansion-20261102/http-image-probe/summary.json)
uses TechCrunch's unchanged encoded WebP response, object-fit geometry,
fractional placement, green backdrop, gradient mask and dark overlay. Both
browsers load the same sealed response bytes with full uBO. Source and frozen
Brave agree exactly; Vox differs at 7,634 pixels, with maximum channel error 2.
The four separate controls have 24 plain-photo differences, 6,149 mask-only
differences, 4 overlay-only differences and 1,457 combined differences.

The corresponding local-file capture is a separate decoder diagnostic: local
WebP files currently enter AppKit's loader, while HTTP response bytes use the
resource decoder. Its larger error cannot establish HTTP mask behavior.
Constant-alpha composition is independently exact in 144 image/mask GPU
comparisons, alongside 56 existing scope/pixel cases and 24 opacity comparisons,
under both optimized and AddressSanitizer/UndefinedBehaviorSanitizer builds.
[The final native controls](../Build/forum-news-expansion-20261102/mask-composite-controls-final/result.json)
pin their canonical source and native-library inputs. Earlier `before2` and
`after` attempts used an incorrectly constructed empty mask and are invalid
for diagnosing composition; no renderer change was retained from them.

The durable [HTTP image-effects command](../tools/forum_news_image_effects.py)
now reconstructs that sealed diagnostic, checks a fresh full-uBO source against
the committed PNG, then applies the normal source/frozen/native conformance
workflow. It pins tools, canonical inputs and both browsers and rejects input
changes. [Its initial complete run](../Build/forum-news-expansion-20261102/http-image-command/summary.json)
reproduces the same 7,634 native differences with source equality;
[23 catalog/archive unit tests](../Build/forum-news-expansion-20261102/image-effects-final-unit.guard.json)
pass. The plain local-file fixture is intentionally absent from the inline
suite because that route exercises a different decoder.

## Run

```sh
python3 tools/forum_news_pixels.py \
  --sites techcrunch,engadget,theregister,slate,wired \
  --extension Build/forum-news-parity-20261030/extension/uBlock0.chromium \
  --checker Build/slashdot-packaged-validation-20261102/adblock-check \
  --diff-tool Build/forum-news-parity-20261030/hn-baseline/pixel_diff \
  --output Build/forum-news-five-UNIQUE

python3 tools/forum_news_image_effects.py \
  --extension Build/forum-news-parity-20261030/extension/uBlock0.chromium \
  --checker Build/slashdot-packaged-validation-20261102/adblock-check \
  --diff-tool Build/forum-news-parity-20261030/hn-baseline/pixel_diff \
  --output Build/forum-news-image-effects-UNIQUE
```

Run expensive checks through the repository's memory guard. The driver also
guards every browser invocation at 3 GiB. Both native and source/frozen RGBA
comparisons must be exact. Frozen, script-free viewports do not establish live
scripting, scrolling, media or whole-site parity.
