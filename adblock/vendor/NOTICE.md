The vendored uBlock Origin source is the full extension's static filtering,
cosmetic filtering, scriptlet and redirect implementation from release 1.75.0,
commit `21f0e686506bb21b514b451c8c6cb9bf8c82d232`:
https://github.com/gorhill/uBlock/tree/21f0e686506bb21b514b451c8c6cb9bf8c82d232

It is copyright Raymond Hill and contributors, distributed under
GPL-3.0-or-later; see [LICENSE.txt](ublock/LICENSE.txt). Individual library and
scriptlet headers retain their respective copyright and license notices.
`manifest.json` records each retained upstream source path and SHA-256 hash.
The source files themselves are unmodified; native platform adapters live under
`tools/adblock/`.

`adblock/extended/procedural.js` is the same release's unmodified
`src/js/contentscript-extra.js`. `adblock/extended/redirect-resources.json`
contains that release's original web-accessible resources encoded as local data
URLs; text resources retain their original text and license headers. Their
source paths and hashes are recorded in `adblock/extended/manifest.json` and can
be restored with `tools/adblock/refresh-extended.mjs`.

The isolated JavaScriptCore bundle additionally includes standard Web API
polyfills from:

- core-js 3.45.1, copyright Denis Pushkarev and contributors, MIT license:
  https://github.com/zloirock/core-js/tree/v3.45.1
- fast-text-encoding 1.0.6, copyright Google LLC, Apache-2.0 license:
  https://github.com/samthor/fast-text-encoding/tree/v1.0.6

Copies of their licenses are in `licenses/`. The exact npm source archives,
versions and integrity hashes are pinned in `tools/adblock/package-lock.json`.
The esbuild 0.25.10 build dependency is MIT licensed and does not execute in the
browser. The public suffix list carries its MPL-2.0 notice in
`adblock/lists/public_suffix_list.dat`.

Filter list snapshots retain their upstream headers, authorship and license
references. `adblock/lists/manifest.json` records source URLs, download time,
preprocessor capabilities, resolved includes and content hashes. The ten enabled
lists comprise the nine English full-extension defaults and the upstream
Russian regional subscription `RUS-0`; no Lite/DNR rulesets are used.

`RUS-0` comes from the full-uBO catalog's
[`RuAdList-uBO.txt`](https://raw.githubusercontent.com/easylist/ruadlist/master/RuAdList-uBO.txt)
and combines fourteen same-origin includes from
[easylist/ruadlist](https://github.com/easylist/ruadlist). The expanded snapshot
preserves each included filter's text, source comments and preprocessor
conditions; added `Included from` comments identify the source files. Its root
URL, expanded snapshot hash and included content hashes are recorded in the
list manifest.

RU AdList declares [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/)
in its upstream [`advblock.txt` header](https://raw.githubusercontent.com/easylist/ruadlist/master/advblock.txt).
That header credits its creator Akuma (DemonSat), denis-ovs, MORPEH, Fanboy,
UA-IX Banlist and Reek's Anti-Adblock Killer; it names denis-ovs, Akuma and
Radik245 as past maintainers, and Lain_13 and dimisa as current maintainers.
RU AdList CSS Fixes and JS Fixes retain their own upstream headers and project
links in the combined subscription.

The included `AWRL-non-sync.txt` identifies the Adblock Warning Removal List and
links to the [EasyList repository licensing policy](https://easylist.to/pages/licence.html):
GPL-3.0-or-later or CC-BY-SA-3.0-or-later, with attribution to
[The EasyList authors](https://easylist.to/), unless a file states otherwise.
These component notices remain distinct from RU AdList's CC BY attribution.
