# Ad blocking

Vox enables the `adblock` module on startup. It embeds the **full uBlock Origin
1.75.0 filtering engines**, pinned to upstream commit
[`21f0e686506bb21b514b451c8c6cb9bf8c82d232`](https://github.com/gorhill/uBlock/tree/21f0e686506bb21b514b451c8c6cb9bf8c82d232).
This is the Manifest V2 engine, with its cosmetic filters, procedural selectors,
scriptlets and redirect resources. It does not use uBlock Origin Lite or a
domain-only approximation of the lists.

The nine English default lists are uBlock filters (Ads, Badware risks, Privacy,
Unbreak and Quick fixes), EasyList, EasyPrivacy, Online Malicious URL Blocklist,
and Peter Lowe's Ad and tracking server list. Bundled snapshots work offline.
Their source URLs, download time, expanded includes and SHA-256 hashes are in
[`adblock/lists/manifest.json`](../adblock/lists/manifest.json). List updates are
explicit; the browser does not currently download background updates.

Network filtering runs before the browser's memory and disk caches, HTTP
preflights and native transport. Redirect destinations are filtered separately
with the initiating document's URL and resource type. Local replacement
resources take precedence over cached network bytes. Scriptlets run before
author scripts. Cosmetic CSS uses the user cascade origin and refreshes when
live document IDs/classes change; procedural selectors use upstream uBO code
and the compact browser's native DOM replay.

The filter engine has its own serialized JavaScriptCore context, inaccessible to
page scripts. Default lists are compiled at development time. Normal builds and
the installed bundle require neither Node nor a network connection for filtering.

## Startup snapshots

The checked-in default snapshot contains **258,456 network filters from all nine
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
into context-owned storage. The current asset is 18,455,332 bytes, adding
12,062,639 bytes compared with its previous gzip form while avoiding inflation
on each launch. JavaScript restoration also checks the expected byte length,
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

Each entry records URL, document URL, request type, matched rule, decision and
replacement. A request can pass several gates, so raw log entries are not a
popup-style unique request count. The Verge's content, consent state, geography,
list versions and execution timing can change its request count. The screenshot's
`4 (9%)` is not a stable test expectation: compare individual URLs and decisions.

Focused checks:

```sh
v -old-compiler -enable-globals test adblock browsernet
v -old-compiler -enable-globals test fetch/adblock_test.v requestserver/adblock_transport_test.v
v -old-compiler -enable-globals test main_adblock_test.v main_adblock_storage_test.v main_adblock_network_test.v
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

The native API exposes `adblock.check(Request{...})`, `document_filters()` and
`set_enabled()`. Disabling removes cosmetic styles on the next layout; reload
the document to remove scriptlets already installed in its JavaScript realm.
There is currently no extension dashboard, element picker, per-site toggle UI
or user-defined dynamic firewall. These checks establish agreement for the
captured requests and page filters; they do not establish complete browser or
full-extension feature parity.
Response-header/CSP modification, HTML-response replacement, CNAME uncloaking,
and user-defined dynamic firewall behavior are not implemented by this embedding.
