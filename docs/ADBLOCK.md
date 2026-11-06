# Ad blocking

Vox enables the `adblock` module on startup. It embeds the **full uBlock Origin
1.75.0 filtering engines**, pinned to upstream commit
[`21f0e686506bb21b514b451c8c6cb9bf8c82d232`](https://github.com/gorhill/uBlock/tree/21f0e686506bb21b514b451c8c6cb9bf8c82d232).
This is the Manifest V2 engine, with its cosmetic filters, procedural selectors,
scriptlets and redirect resources. It does not use uBlock Origin Lite or a
domain-only approximation of the lists.

The ten enabled lists are the nine English full-uBO defaults—uBlock filters
(Ads, Badware risks, Privacy, Unbreak and Quick fixes), EasyList, EasyPrivacy,
Online Malicious URL Blocklist, and Peter Lowe's Ad and tracking server list—plus
the Russian regional **RU AdList (`RUS-0`)**. RU AdList is enabled in Vox by
default, including on `pikabu.ru`. Its source is the full-uBO catalog's
[`RuAdList-uBO.txt`](https://raw.githubusercontent.com/easylist/ruadlist/master/RuAdList-uBO.txt),
which combines fourteen includes covering RU AdList, its CSS/JS fixes and the
Adblock Warning Removal List. The separate optional RU AdList Counters
subscription (`RUS-1`) is not enabled. Bundled snapshots work offline.
Their source URLs, download time, expanded includes and SHA-256 hashes are in
[`adblock/lists/manifest.json`](../adblock/lists/manifest.json). List updates are
explicit; the browser does not currently download background updates.

Network filtering runs before the browser's memory and disk caches, HTTP
preflights and native transport. Redirect destinations are filtered separately
with the initiating document's URL and resource type. Local replacement
resources take precedence over cached network bytes. A second full-uBO gate
matches response-header filters before bodies reach consumers or caches,
including native CURL streaming, Fetch preloads and cached responses. It
preserves repeated fields and uBO's case-insensitive header-name matching.
This includes RU AdList's Pikabu ad-payload rule,
`||pikabu.ru/ajax/$xmlhttprequest,responseheader=llasalbbubrrl`.
The compatibility build stages a repository-owned `net.http` header adapter
under `Build/v/modules`; it retains fields beyond the old 50-field array,
empty values and repeated fields without editing the V checkout. Header copies
detach before mutation. `python3 tools/httpcompat/check.py` verifies
the adapter and an empty Pikabu marker beyond the original limit.
Scriptlets run before
author scripts. Cosmetic CSS uses the user cascade origin and refreshes when
live document IDs/classes change; procedural selectors use upstream uBO code
and the compact browser's native DOM replay.

The filter engine has its own serialized JavaScriptCore context, inaccessible to
page scripts. Default lists are compiled at development time. Normal builds and
the installed bundle require neither Node nor a network connection for filtering.

## ChatGPT collector modules

The default snapshot also compiles Vox's local
[`site_resources.js`](../tools/adblock/site_resources.js) supplement through the
same uBO parser and network engine. The ten subscription identities stay intact;
independent custom-filter engines do not inherit the supplement.

For reviewed ChatGPT web-client deployments, the business-event serializer
and performance bootstrap receive local ES module replacements before transport
or cache access. The business replacement preserves `reportCesBusinessEvent()`.
The performance replacement preserves its asynchronous result, drains initial
long-task metrics, installs a measurement sink and completes the telemetry
caller's cleanup contract. It avoids importing the performance collector and its
dynamic dependencies. Empty JavaScript would break their named imports.

The rules require the reviewed, case-sensitive asset filenames, the script
request type and a ChatGPT document owner; worker-version queries are supported.
New filenames retain the site's original implementation until reviewed. Native
telemetry, shared analytics, consent, authentication, Sentinel and conversation
submission stay available because their modules also perform application work.
The existing event-endpoint blocking remains active.

On November 6, a fresh process using the signed bundle's updated filter assets
submitted **“capital of italy”** through its native composer and visibly rendered
**“The capital of Italy is Rome (Roma). 🇮🇹”**. Both replacements were active and
the performance-metrics module was never requested. Browser and memory-guard
exits were zero, with no reported JavaScript errors. The installed data update
uses the existing bundle resource loader; it does not require a browser compile.
Existing browser processes need restarting to adopt it. All 48 filter-package
tests and the native V engine checks pass (`-nocache` avoids a stale compiler
bridge encountered during verification).

The [verification receipt](performance/chatgpt-basic-blocking-20261106.json)
records identities, tests and every attempt; the
[document capture](parity/raw/chatgpt-basic-query-20261106.vox.png) retains the
rendered reply. A longer earlier observation received the answer, then exceeded
the default 12 GiB guard after 50.3 seconds. Sustained browsing and the overall
slowdown remain unresolved. This first check establishes basic query
functionality; performance is measured separately below.

### Before and after collector blocking

Seven alternating pairs compare the original three filter assets at
`01a58382b^` with the assets from `01a58382b`, using the same completed production
executable `4b1ce3741d725cd0947002d089a3a553b4df5ba7937903609a649d183b28d842`
and native libraries. Both variants retain the full uBO subscriptions. The
retained November 4 homepage is replayed at its original origin without live
forwarding. Each trial has an empty private profile/cache, a 1024×768 viewport,
scale two, an unfocused window and the same five-second settle. OS filesystem
and shader caches remain retained. No production rebuild or app copy is used.

| Metric, median of seven runs | Before | After | Observed reduction |
| --- | ---: | ---: | ---: |
| Process creation through PNG file write | 6.2336 s | 5.8964 s | 5.41% |
| Coalition instructions through encoded PNG | 26,362,796,603 | 26,326,045,842 | 0.1394% |
| Peak sampled browser physical footprint | 1,355.03 MiB | 1,336.47 MiB | 1.37% |
| Decoded HTTP JavaScript response bytes | 3,574,639 | 3,401,349 | 4.85% |
| HTTP JavaScript requests | 288 | 279 | Nine requests |

The elapsed-time metric includes the fixed five-second wait, startup, raster,
PNG encoding and file write; it is not isolated load/render time. Instructions
include startup and exited helpers through the native encoded-PNG marker, before
file write and semantic audit. Physical footprint covers sampled simultaneous
browser/descendant memory through exit, including capture and audit work; it is
a polling lower bound, separate from the guard's summed RSS.

CPU ranges overlap: 25.971–26.699 billion before and 26.192–26.678 billion after.
Two paired CPU results regress, and the highest-after/lowest-before ratio is
**1.02722**, so no conservative CPU saving is established. All seven paired
elapsed times improve, with overlapping absolute ranges of 6.011–6.598 s and
5.828–6.499 s. One-minute host load spans 9.94–13.64 before and 9.44–14.22 after
on 18 CPUs; timing variation remains material. Every attempt is retained.

All fourteen captures pass the unchanged content, author-bootstrap and exact
pixel checks. A separate logged diagnostic confirms both replacements execute;
its timings are excluded from the cohort. The default 12 GiB guard adopts all
browser identities and both diagnostic/cohort jobs exit zero. This short frozen
homepage workload does not resolve the longer conversation memory failure or
measure live query latency. It changes author-script policy, so it earns no
engine optimization credit or broad-check cadence reset.

The [comparison receipt](performance/chatgpt-blocking-comparison-20261106.json)
records every count, pair, scope and identity, with a verified durable archive of
the raw logs, counters, memory samples, screenshots and replay requests.

### Attempt to reach 3 MB

This earlier attempt did not meet the **3,000,000-byte target**. The working
policy at that point downloaded **3,401,349 decoded JavaScript bytes** in the
frozen homepage workload. No experimental rule from that attempt was retained.

Suppressing JavaScript dependency preload hints, while retaining the loader's
stylesheet and import/error contracts, passes 51 experimental tests and the
unchanged frozen-page checks. However, the capture still requests 3,396,133 bytes:
only the original 5,216-byte loader disappears from HTTP, while a 5,266-byte
replacement runs locally. The application still imports the same dependencies,
so this does not establish a useful reduction in the code loaded.

Also blocking the main `application-presentation-runtime` reduces the frozen
HTTP JavaScript count to 949,417 bytes, but fails the retained control-identity
check. Live tests cannot complete “capital of italy”: preparation requests begin,
but conversation updates and the assistant reply never arrive. A separate
JavaScript-disabled live navigation leaves Send disabled. These cuts are rejected
because they fail basic functionality, regardless of their download counts.

The original working source and installed filter resources are restored. All 48
original filter tests pass; a fresh installed process again receives **Rome**,
and a repeated frozen capture passes the unchanged content and exact pixel checks
at 3,401,349 bytes. The [attempt receipt](performance/chatgpt-3mb-attempt-20261106.json)
preserves the failed candidates, source, tests, screenshots, asset identities and
restoration checks. These experiments do not establish that further reduction is
impossible, and they earn no performance credit or broad-check cadence reset.

### Basic-site startup below 3 MB

The follow-up policy reaches the startup target while keeping the native text
composer and conversation runtime. The measured version's 23 exact module URLs cover the archived
and November 6 anonymous mobile-web deployments. Unknown versions load normally.
It suppresses optional install banners, trending suggestions, product popovers,
recurring login banners, one-tap login, bottom-sheet dialogs, follow-up CTA
enhancements and additional event collectors. Those optional surfaces are
unavailable under this basic-site policy; ordinary login navigation, text entry,
Send, Sentinel and streamed replies remain available.

The English startup loader retains every original startup message and digest,
without eagerly importing the entire locale catalog. Other locales and explicit
recovery URLs use the original loader. Separating the site's locale cache by
scope allows deferred conversation packs to load later. The first live query
exposed this shared-cache dependency; that failed attempt is retained in the
evidence, alongside the fix and regression test.

Seven alternating control/candidate pairs use the same production executable,
single-C-unit mode, 1024×768 viewport, 2× backing scale, fresh private profiles and
caches, original-origin disk replay and five-second settle. All fourteen pass
the original content, behavior-ready and pixel-exact reference checks.

| Startup metric | Previous policy | Basic-site policy |
| --- | ---: | ---: |
| Decoded HTTP JavaScript response bytes | 3,401,349 | **2,959,483** |
| HTTP JavaScript requests | 279 | **250** |
| Local replacement payload bytes | 805 | 31,391 |
| HTTP plus local replacement payloads | 3,402,154 | **2,990,874** |
| Median coalition instructions through encoded PNG | 26,798,575,155 | 24,775,952,414 |

HTTP JavaScript decreases 13.0%; counting local replacement payloads still stays
below 3,000,000 bytes. These are decoded payload bytes, not compressed wire
bytes. The CPU median falls 7.5%; the conservative maximum-candidate/minimum-
control ratio is 0.93284, which does not meet a 10% conservative CPU gate.
Counters include startup and exited owned helpers through PNG encoding, with
ownership audits; GPU execution and outside services are excluded. Host load
spans 13.55–15.56 on 18 CPUs. The measured author-script policy changes, so this
earns no engine optimization credit or broad-check cadence reset.

A separate cold live homepage observation records 2,983,642 bytes across 255
distinct original script responses. This is a unique-response payload estimate
from the observed URLs and independently hashed immutable sources, not a wire
transfer counter. Its local replacements add about 32 KB. A fresh process using
the installed, signed bundle submits **“capital of italy”** through native input
and receives an assistant answer containing **Rome**, shown in the
[document capture](parity/chatgpt-basic-3mb-installed-query-20261106.png). Headless startup and all
55 filter tests pass. The 3 MB budget covers homepage startup: submitting a
query loads additional conversation and rich-content code. Longer conversation
memory use and general rich-answer rendering remain outside this result.

The [result receipt](performance/chatgpt-basic-3mb-20261106.json) links the durable
raw evidence and installed-query screenshot. Reproduce the reviewed resources
with `npm --prefix tools/adblock run build`; source hashes, export contracts,
locale messages, fallback behavior and scope-cache behavior are tested. Isolated
experiments can use `node tools/adblock/build.mjs --output Build/NAME
--site-policy POLICY.json` without rewriting the shared production assets.

### Attempt to reach 2.5 MB

The **2,500,000-byte startup target remains unmet** when local replacement
payloads are counted alongside decoded HTTP JavaScript. No renderer-pruning,
rebundling, sidebar, preload or warm-up experiment from this attempt is shipped.

| Frozen homepage diagnostic | HTTP bytes | Local replacement bytes | Total bytes | Original content/pixels |
| --- | ---: | ---: | ---: | --- |
| Working 3 MB policy | 2,959,483 | 31,391 | **2,990,874** | Exact |
| Split module graph, preserved original signal bootstrap | 118,364 | 3,014,577 | 3,132,941 | Exact |
| Split only the two application entries | 1,456,163 | 2,393,815 | 3,849,978 | Exact |
| Prototype removing unexercised UI renderers | 1,990,209 | 668,480 | **2,658,689** | Exact |

An earlier split-graph candidate fails document-signal initialization and never
finishes author bootstrap; its smaller partial-load count is invalid. Preserving
the original signal-bootstrap module restores the homepage, but the resulting
split and facade overhead increases the total payload. The renderer-pruning
prototype passes the retained frozen-page checks, but misses 2.5 MB and does not
establish live conversation or general UI preservation. Its live deployment had
already changed asset versions. Coverage and warm-up diagnostics subsequently
obtain live replies, but those runs execute instrumented full renderer bodies;
they do not validate the smaller prototype. Removing more control code based
only on that coverage would not establish basic functionality across states.

These are isolated diagnostics, with actual local script payloads included.
They are not a CPU or load-time acceptance cohort and earn no engine optimization
credit. One early coalition-instrumented launch is invalidated by a concurrent
unrelated screenshot process. Later diagnostics use direct fresh processes
under the memory guard, with matching capture settings and input identities.
A separate two-turn live diagnostic with stale version-specific rules hits the
12 GiB guard after its first answer; it supplies no completed follow-up result
and does not resolve the known conversation-memory issue.

The retained change refreshes the existing basic policy for the newly deployed
anonymous client: 34 reviewed basic module URLs and six collector-module URLs
across three releases. The same export, URL-scope, locale and lifecycle checks
pass in all **55 tests**. The signed installed bundle blocks all fourteen expected
scripts in a fresh live query and receives **Rome** for “capital of italy”. The
original frozen homepage remains pixel-exact at 2,990,874 total bytes. A separate
cold live homepage estimates 2,987,776 bytes across 255 unique original script
responses, plus 32,028 local replacement bytes. This live estimate is based on
observed URLs and hashed immutable sources, not a compressed wire counter.

The [attempt receipt](performance/chatgpt-25mb-attempt-20261106.json) retains the
failures, candidate payloads, guards, source identities and installed validation.
The newly deployed asset refresh is committed independently of this diagnostic
report; the 2.5 MB target remains open.

## Startup snapshots

The checked-in default snapshot contains **276,172 network filters from all ten
lists**, along with the cosmetic, scriptlet and public-suffix state. The build
script compiles the raw lists with uBO and captures its native `toSelfie()`
records. Browser startup restores those records through `fromSelfie()` instead
of parsing compiled network-rule strings and rebuilding the tries on every
launch. Custom filters supplied through `adblock.new_engine()` still use the
normal uBO parser, compiler, freeze and optimization path.

The three generated runtime assets are `adblock/engine.js.gz`,
`adblock/engine.snapshot.json.gz` and `adblock/engine.snapshot.bin`. The first
contains the complete engine, including the custom-filter parser and compiler.
The second contains ASCII-escaped JSON metadata. A context-owned native callable,
`voxAdblockReadSnapshotMetadata()`, parses fresh objects through JavaScriptCore's
JSON API before Maps, Sets and regular expressions are reconstructed. Its native
text owner survives garbage collection and is released with the context. JSON
escapes preserve Unicode, embedded NULs, byte-order marks and lone surrogates.
Both gzip assets retain native CRC and exact input/output length validation.

The raw binary asset contains the network and public-suffix typed-array data.
Its 16-byte `VOXSNAP1` header records the payload length and CRC32. Startup checks
the magic, the 128 MiB bound, exact total length and CRC before copying the bytes
into context-owned storage. The current binary asset is 19,286,472 bytes;
`engine.js.gz` is 321,942 bytes and `engine.snapshot.json.gz` is 1,353,166 bytes.
The binary avoids inflation on each launch. JavaScript restoration checks the expected byte length,
and uBO retains its engine-version and trie-checksum validation.

The native host supplies the same signed 32-bit trie checksum as uBO's JavaScript
implementation. A build-time adapter selects that backend; hosts without it use
the original JavaScript checksum. Another adapter clears cached URL tokens when
trie storage is replaced, so repeated restores retain redirects for the same
URL. Both adapters require exact upstream source anchors and leave the pinned
vendor files unchanged.

The snapshot backing allocation belongs to JavaScriptCore through
`JSObjectMakeTypedArrayWithBytesNoCopy()` and a matching native deallocator. Its
isolated global property keeps it alive across garbage collections. Each restore
copies mutable typed arrays into engine-owned storage, preserving the bundled
bytes when switching between custom and default filters. Page scripts cannot
access the filtering context or its native callbacks.

Bundle inflation and UTF-8 script conversion also use native APIs. Conversion
accepts explicit byte lengths, preserving embedded NULs; empty sources, leading
UTF-8 byte-order marks and invalid UTF-8 retain the existing UTF-16 decoder path.

## Verification

For the 13-site matrix, native scriptlet regressions, and observed site limits,
see [Popular-site verification](ADBLOCK_POPULAR_SITES.md).

Compile the native diagnostic tool and replay the checked-in real The Verge
request corpus:

```sh
v -old-compiler -enable-globals -o Build/adblock-check tools/adblock_check.v
Build/adblock-check --verify tools/adblock/fixtures/theverge.json
```

For a fresh comparison, install Node.js 22 or newer and Brave with **full**
uBlock Origin 1.75.0 (Manifest V2), then run:

```sh
node tools/adblock/brave_parity.mjs
```

Add `--url https://edition.cnn.com/ --capture-dir Build/cnn-parity/new-capture`
to archive the successfully loaded page at 1024×768 and device scale 1. The
directory must be new. This optional archive keeps a script-free DOM, a live
viewport PNG, and successful GET response bodies in the native browser's cache
format. It preserves response security and CORS headers, removes decoded
transport framing, and records body hashes. The main replay body is the frozen
DOM; its original response hash remains in the manifest. No computed layout or
saved page raster replaces rendering. Missing or failed response bodies are
not synthesized. Treat captured pages as private browsing data.

This uses an isolated temporary Brave profile, disables its built-in Shields,
and loads only the full MV2 extension. It installs the repository's exact list
snapshots in the isolated extension before visiting `https://www.theverge.com/`.
The user's normal profile, browsing data and extension settings stay untouched.
The report under `Build/comparisons/adblock-theverge.json` includes every
distinct observed request and both engines' decisions, plus cosmetic and
scriptlet-selection comparisons. This comparison checks block/exception
decisions and filter selection; it does not prove every scriptlet has the same
effect in both DOM implementations. Use `--extension PATH` if automatic
discovery cannot find the extension, and `--checker PATH` for a separately built
native checker.

For repeated audits, `--profile-template PATH` copies an explicitly supplied,
closed prepared uBO profile into the temporary directory. It omits process
locks and the old debugging endpoint, disables Shields, clears user filters,
and reloads the repository list snapshots before checking requests. The source
profile stays unchanged. This avoids a fresh extension's initial list bootstrap
on every audit; startup still has a bounded watchdog. The CNN instruction driver
uses the same pinned prepared profile for its measured Brave runs and its
post-measurement filter audits.

To compare the requests actually recorded by Vox, use:

```sh
node tools/adblock/brave_parity.mjs --vox-log Build/comparisons/vox-theverge.requests.jsonl
```

This writes a separate `Build/comparisons/adblock-vox-theverge.json` report.

To audit a real Vox session, set `VOX_ADBLOCK_LOG` to an existing JSONL file:

```sh
mkdir -p Build/comparisons
touch Build/comparisons/vox-adblock.jsonl
VOX_ADBLOCK_LOG="$PWD/Build/comparisons/vox-adblock.jsonl" \
  Build/v/Vox.app/Contents/MacOS/Vox https://www.theverge.com/
```

Each entry records the filtering phase, URL, document URL, request type, matched
rule, decision and replacement. Response-phase entries also retain the raw
header pairs needed to replay their decisions. A request can pass several gates, so raw log entries are not a
popup-style unique request count. The Verge's content, consent state, geography,
list versions and execution timing can change its request count. The screenshot's
`4 (9%)` is not a stable test expectation: compare individual URLs and decisions.

Focused checks:

```sh
v -old-compiler -enable-globals test adblock browsernet
v -old-compiler -enable-globals test fetch/adblock_test.v requestserver/adblock_transport_test.v
v -old-compiler -enable-globals test fetch/adblock_response_test.v
v -old-compiler -enable-globals test main_adblock_test.v main_adblock_storage_test.v main_adblock_network_test.v
v -old-compiler -enable-globals test main_adblock_pikabu_test.v main_adblock_response_test.v
v -old-compiler -enable-globals test main_compact_selector_scope_test.v main_compact_computed_style_test.v main_navigation_encoding_test.v
v -old-compiler -enable-globals test html/adblock_navigation_type_test.v
v -old-compiler -enable-globals test css/container_rule_test.v layout/container_query_stabilization_test.v layout/dom_layout_bridge_test.v
```

## Rebuilding bundled snapshots

Rebuild from the checked-in, hash-verified lists without downloading updates:

```sh
cd tools/adblock
npm ci
npm run build
npm test
cd ../..
```

`npm test` covers the recorded Brave request decisions, default cosmetics and
scriptlet selection, custom filters, redirects and repeated default restores.
It also checks metadata types and fresh mutable storage. On macOS it compiles
native ownership/checksum tests, including raw magic/length/CRC rejection,
metadata corruption and bounds, fresh graphs, Unicode/BOM/NUL fidelity, garbage
collection, release ownership, empty arrays, offset views and signed hash
boundaries.

Review all three runtime assets together. The intermediate
`generated-defaults.js` and `snapshot-layout.json` are generated files. Rebuilding the current pinned inputs
produces byte-identical runtime assets; normal browser builds use the checked-in
assets and do not invoke Node.

## Refreshing assets

```sh
cd tools/adblock
npm ci
node refresh.mjs
npm run build
npm test
cd ../..
sh build-prod-browser.sh
```

Review changes to the list manifest and all three runtime assets together. Re-run
the live Brave comparison after refreshing; the historical fixture records its own
snapshot hashes. The upstream engine source remains pinned until deliberately
updated. Source licenses and third-party notices accompany the vendor files.
`node refresh-source.mjs` restores the pinned engine sources;
`node refresh-extended.mjs` restores the pinned procedural runtime and redirect
resources, checking their recorded source hashes.

To update only RU AdList while retaining the other list snapshots and public
suffix data, replace `node refresh.mjs` above with:

```sh
node refresh.mjs --only RUS-0
```

`--only` accepts comma-separated enabled list keys. Each refreshed entry records
its own download timestamp; the manifest retains the original snapshot timestamp
and records the partial update in `updated_at`. Rebuild and verify all three
runtime assets after any list update.

## Pikabu verification

The October 15, 2026 live `pikabu.ru` comparison used full MV2 uBO 1.75.0 with
Shields disabled and the same ten list snapshots in both engines. The harness
replayed the observed Brave traffic through Vox's native checker. On the shared
stream of **63 distinct requests**, Vox and full uBO each blocked **seven** and
allowed 56, with zero decision differences. The report also compares 55
response-header checks separately; those checks introduced no additional blocks
in that visit. Filter selection agreed for **1,206 normalized cosmetic CSS
rules, three procedural filters and six scriptlet filters**. The report is
`Build/comparisons/adblock-pikabu-ru.json`.

The checked-in [`pikabu.json`](../tools/adblock/fixtures/pikabu.json) retains
the 62 site resources (117 request/header checks), excluding one extension
update request from that live report. Guest cookie and CSRF values are redacted
while retaining the header fields. All 117 decisions, including their matched
rules, pass against the bundled engine. Seven additional synthetic checks in
[`pikabu-response-controls.json`](../tools/adblock/fixtures/pikabu-response-controls.json)
exercise the real full-uBO response-header matcher; they are separate from the
observed guest traffic.

The comparison counts each URL, initiating-document URL, request type and method
tuple once. Response checks stay attached to that request rather than adding
another request to the total. Independent live browser visits can load different
content and issue different traffic because of timing, caches, script execution
and browser capabilities. Their natural popup counters are therefore not a
stable equality test. The `common_stream` report verifies equal block counts
and individual decisions on the same traffic; matching counts alone would miss
one engine blocking a different URL.

The checked-in [`pikabu-slots.html`](../tools/adblock/fixtures/pikabu-slots.html)
fixture contains five representative RU AdList ad slots and two ordinary
content controls. It includes branding, a feed placeholder, a sponsored story,
the Russian advertising disclosure matched by a procedural filter, and a
sidebar removed procedurally. In full Brave + uBO, all five slots were hidden
or removed and both controls remained visible, recorded in
`Build/comparisons/adblock-pikabu-slots.json`. Vox passes the same five-slot,
two-control fixture in `main_adblock_pikabu_test.v`, including actual JSON-prune
and `Ya` property-abort scriptlet effects. The HTML and probe hashes match the
full-uBO report. All 34 focused native regression functions passed together,
covering existing sites, scoped queries, live computed styles, procedural error
reporting, encoding, response headers and redirect cache revalidation.

Run a fresh live comparison and the full-uBO slot probe with:

```sh
node tools/adblock/brave_parity.mjs --url https://pikabu.ru/ --output Build/comparisons/adblock-pikabu-ru.json
node tools/adblock/brave_parity.mjs --url https://pikabu.ru/ --document-fixture tools/adblock/fixtures/pikabu-slots.html --visibility-probe tools/adblock/fixtures/pikabu-slots-probe.json --output Build/comparisons/adblock-pikabu-slots.json
Build/adblock-check --verify tools/adblock/fixtures/pikabu.json
Build/adblock-check --verify tools/adblock/fixtures/pikabu-response-controls.json
```

To compare an actual Vox visit, record it with `VOX_ADBLOCK_LOG` as above, then
run the harness with `--url https://pikabu.ru/ --vox-log PATH --output REPORT`.
The response-header regression tests separately cover the Pikabu custom header,
ordinary responses, header casing and repetitions, exceptions, important rules,
preloads and rejecting a CURL body before its receiver receives bytes.

The final signed native build passed startup and loaded `https://pikabu.ru/`
with an empty cache. Its [viewport capture](../Build/comparisons/vox-pikabu-ru.png)
shows readable Cyrillic, the post image and ordinary page controls. Replaying
that visit's 30 distinct resources (60 request/header checks) through full uBO
produced zero differences and zero blocks in either engine, recorded in
`Build/comparisons/adblock-pikabu-native-ru.json`. This native visit generated
different traffic from the Brave visit above; its natural counter is not seven.
The shared request corpus and shared five-slot fixture establish the blocking
comparison on identical inputs. The final production build, signing check,
startup, capture and native replay all exited successfully.

Native Pikabu navigation decodes the HTTP `windows-1251` body before HTML
tokenization, retaining the charset through preloading, caching and history.
Procedural filters query the native DOM with the receiver's `:scope` and read
live resolved styles through the owning Window's CSSOM declaration. Procedural
evaluation errors are reported instead of silently skipping the remaining filters.

## Results and limits

The initial live comparison on October 15, 2026 matched all 159 observed
requests (10 blocked, 149 allowed), with zero disagreements against the live
uBO logger. The 498 normalized cosmetic CSS rules and all five selected
scriptlet filters also matched. A separate comparison replayed all 201 distinct
requests actually recorded by Vox: four blocked, 197 allowed, zero differences against full uBO. The blocked
requests were Amazon apstag, Google Publisher Tag, DoubleVerify, and Bullwhip
Sonar. Reports retain each URL and matching filter, rather than comparing only
aggregate counters. The historical fixture preserves 26 requests, including 15
blocked requests observed in an earlier visit.
The focused native suite also checks storage-scriptlet execution, user-origin
cosmetics, live procedural filtering, cache replacement and enable/disable
transitions, request-type ownership, redirect targets, and CSP enforcement.
All 26 focused adblock checks passed, as did the signed production build and
headless startup check. The final native The Verge visit completed layout and
produced a 1000×700 document-viewport capture at
`Build/comparisons/vox-theverge-adblock.png`. Its independent traffic comparison
again matched all 201 decisions (four blocked) with zero differences; the full
report is `Build/comparisons/adblock-vox-theverge-final.json`. The canonical
`svg-image-source-switch-same-size` comparison remained pixel-exact. Additional layout regressions cover hidden
query containers becoming visible, boxless containers gaining a box, nested
container resizing, and avoiding invalidation on an unchanged queried axis.
Page storage uses the existing native origin/traversable owners;
its contents persist in process, rather than across browser launches.

The native API exposes `adblock.check(Request{...})`,
`check_response(Request{...}, []ResponseHeader)`, `document_filters()` and
`set_enabled()`. Disabling removes cosmetic styles on the next layout; reload
the document to remove scriptlets already installed in its JavaScript realm.
There is currently no extension dashboard, element picker, per-site toggle UI
or user-defined dynamic firewall. These checks establish agreement for the
captured requests and page filters; they do not establish complete browser or
full-extension feature parity.
Response-header matching is supported; response-header/CSP modification,
HTML-response replacement, CNAME uncloaking,
and user-defined dynamic firewall behavior are not implemented by this embedding.
