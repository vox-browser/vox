# Popular-site adblock verification

The matrix exercises guest pages on 13 representative news, video, social,
shopping, reference, and developer sites. It compares Vox's native filtering
engine with full Manifest V2 uBlock Origin 1.75.0 in an isolated Brave profile,
using the repository's exact list snapshots and disabling Brave Shields.

Run the matrix with Node.js 22 or newer, Brave, full uBO, and the native checker
described in [ADBLOCK.md](ADBLOCK.md):

```sh
node tools/adblock/popular_sites.mjs
node tools/adblock/popular_sites.mjs --sites cnn,wikipedia,github,yahoo,espn,stackoverflow
node tools/adblock/popular_sites.mjs --sites pikabu
```

Reports, browser navigation evidence, matched logger filters, and a progressive
`summary.json` are written under `Build/comparisons/adblock-popular`. Each site
retains its requested and final URLs, title, HTTP status, document text sample,
request decisions, and cosmetic/procedural/scriptlet comparisons. Redirected
pages use their final URL for cosmetic selection.

The runner continues after an unavailable site, then exits nonzero for any
filtering disagreement, engine error, missing comparison, insufficient traffic,
navigation failure, access check, or consent interstitial. Matching a few
requests to an error page never counts as successful site coverage.
Unexpected redirects outside the requested host's domain also fail coverage.
`--reports-only` assesses existing reports without making fresh page visits.

To add comparisons of actual Vox traffic, pass a JSON map of catalog IDs to
audit JSONL files recorded with `VOX_ADBLOCK_LOG`:

```sh
node tools/adblock/popular_sites.mjs --sites cnn --vox-logs Build/vox-audits.json
```

For example, `Build/vox-audits.json` can contain
`{"cnn":"Build/comparisons/adblock-popular/cnn-vox.requests.jsonl"}`.
Recorded comparisons verify request filtering; native page availability must
also be checked through a capture or interactive visit.

## Observed coverage

Pikabu was added with RU AdList enabled. Its captured site traffic has seven
blocked resources out of 62, with identical Vox/full-uBO decisions; the native
shared fixture hides all five ad candidates and preserves both content controls.
See [Pikabu verification](ADBLOCK.md#pikabu-verification) for the request/header
corpus, scriptlet checks and live native capture. The earlier 12-site results
below retain their original list snapshots and observed counts.

These are public guest-page observations from October 15, 2026. Counts vary
with live content, timing, location, consent, and connectivity. They do not cover
logged-in flows, purchases, video playback, or every browser API.

| Site | Live Brave/full-uBO comparison | Native Vox observation |
| --- | --- | --- |
| CNN | Matched; 23 blocked out of 123 requests | Article grid rendered; some images missing; all 118 native request decisions matched |
| Wikipedia | Matched; 1 blocked out of 29 | Readable Main Page; image/layout gaps; all 31 native decisions matched |
| GitHub | Matched; 2 blocked out of 170 | Homepage hero and sign-up controls rendered; all 53 native decisions matched |
| Yahoo | Matched on follow-up; 75 blocked out of 248 | Homepage content rendered; media/feed partly incomplete; all 185 native decisions matched |
| ESPN | Matched; 17 blocked out of 173 | Homepage and lead photograph rendered; score strip partly incomplete; all 46 native decisions matched |
| Stack Overflow | Matched; 3 blocked out of 79 | Native transport received HTTP 403; native page coverage unavailable |
| BBC News | DNS failure in the isolated Brave session | Native connection failure; page coverage unavailable |
| Reuters | HTTP 401 | Native HTTP 401; page coverage unavailable |
| The New York Times | HTTP 403 | Native HTTP 403; page coverage unavailable |
| YouTube | DNS failure in the isolated Brave session | Native connection failure; playback coverage unavailable |
| Reddit | Network-security access check | Native splash screen without a feed; page coverage unavailable |
| Amazon | Continue-shopping access check with too few requests | Partial navigation/category shell; all 28 native decisions matched, including one blocked request |

The six accessible live pages in that capture supplied **822 requests, 121
blocked, zero Vox/full-uBO static decision differences**, with equal cosmetic
CSS, procedural filters, and scriptlet selections. The other six sites remain
explicit coverage failures in the aggregate report. Native rendering has image
and SPA gaps; these checks do not establish complete site functionality or
attribute each rendering gap to a particular subsystem.

An initial Yahoo capture had four live-uBO-logger/replay disagreements on video
telemetry pings, while Vox and the static oracle agreed. Its report is retained
as `yahoo-initial-anomaly.json`. Two follow-ups retained individual logger filters and matched all 258 and 248
decisions, respectively, without that anomaly. Its original cause is
unresolved; any recurrence fails the matrix instead of being ignored.

## Offline and native regressions

The checked-in [request corpus](../tools/adblock/fixtures/popular-sites.json)
retains 89 observed requests across the six accessible pages: 41 blocks and 48
allowed content controls. It records the full engine/list hashes and covers
distinct filter rules, resource types, methods, and initiating domains. Refresh
the recorded oracle evidence after changing list snapshots; the V test rejects
a corpus with different engine/list identities.

```sh
v -old-compiler -enable-globals test adblock
v -old-compiler -enable-globals test main_adblock_popular_test.v
node --test tools/adblock/navigation.test.mjs tools/adblock/popular_sites_test.mjs
```

Eight native page tests exercise actual selected scriptlets and the native
user-origin stylesheet adapter on CNN, YouTube, Reddit, Amazon, Yahoo, GitHub,
ESPN, and Wikipedia. They check CNN ad settings, YouTube ad-response fields,
Reddit outbound-link JSON pruning, Amazon ad/cuepoint JSON pruning, selected
privacy constants, domain ad-slot hiding, and preservation of article content.
They also preserve uBO's generic-hide exceptions on YouTube, Reddit, Amazon,
GitHub, and Wikipedia. These deterministic native effects remain testable when
a public site is unreachable, while the live matrix continues to report the
missing page coverage.


## Strict rendering checkpoint, October 30, 2026

The ten-site pixel suite is implemented in `tools/forum_news_pixels.py` with
`Tests/Browser/Brave/forum-news.json`. It uses full MV2 uBO 1.75.0 and the exact
repository filter-list bytes in both engines. Each native capture gets a fresh
private profile, a pinned executable/library identity, and a 3 GiB process-tree
guard. The shared production bundle is reused without an automatic rebuild.

Commits `cbea4277` and `29a4305e` register all ten cases, retain eight sealed
guest-page captures, and record explicit coverage failures for Reddit and
Stack Overflow. `69515a3d` preserves the content-addressed HTTP bodies as binary
assets so line-ending conversion cannot change their hashes.

Only **Hacker News** currently has exact full-viewport evidence: zero differing
RGBA pixels at 1024 by 768, including an exact live-to-frozen Brave comparison
and matching actual Vox/full-uBO request decisions. The other nine acceptance
cases remain open. Captures for CNN, The Verge, and Pikabu show pixel differences;
Lobsters and BBC also differ between the live capture and frozen replay.
The Slashdot native attempt is invalid because another session replaced the
shared bundle during capture. Reddit returns an HTTP 403 network-security
block. Stack Overflow's response-body capture is incomplete. None are skips or
passing comparisons, and no mismatch bounds were introduced.

Fix `05f1d30a` makes native RequestServer subresources honor navigation's
process-local `SSL_CERT_FILE` trust configuration. The focused default-GC TLS
regression passes its trusted-CA, unrelated-CA, and wrong-host checks. The
no-GC attempt stalls on a later unrelated-CA check and remains unresolved.
A production build fails at C compilation while the shared disk is exhausted;
the later diagnostic compiler and its guard receipt also encounter ENOSPC.
The last completed browser remains available but does not validate this fix.

The tooling checks pass four Python cases and twelve Node cases. Raw reports,
screenshots, actual guard outcomes and the consolidated `summary.json` are
retained under `Build/forum-news-parity-20261030/`. Duplicate intermediate
archives and private replay caches were removed after sealing their canonical
bytes in the fixtures; screenshots, raw filter evidence and logs are retained.
This workstream contains one native code fix. Broad regression suites were
not run and the repository's existing broad-test baseline was not reset.
