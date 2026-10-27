# 4chan catalog comparison

Pixel-perfect parity for `https://boards.4chan.org/pol/catalog` remains open.
The latest completed production run is
`Build/4chan-catalog-20261027-final-1/`. It compares fresh processes at native
scale 2 against Brave 156.1.98.60 (Chromium 156.0.8078.48).

## Completed browser and identity

The executable SHA256 is
`d0b28fb544c7ac9befb56b43402ed9c090f05651a2a2c1936df64f8793498d93`.
`results.json` records the native library hashes, successful signing, startup
smoke, installation into `Build/v/Vox.app`, and unchanged frozen source,
capture scripts, and executable/library identity throughout the comparisons.
The pinned copy is `device.app` in the run directory. The earlier `label-2`
bundle cannot validate the subsequent fixes.

The retry preserved generated C and the exact native compiler command, exited
V, and then compiled the native executable separately. This avoided the
overlap that exceeded the memory budget in the earlier production attempt.
`guard-retry-vlib.json` records a 9,435,447,296-byte sampled process-tree peak
against the unchanged 12 GiB budget. The overall check exits 1 because visual
acceptance fails; the native compiler, signing and smoke each exit 0.
The intentional compiler deferral exits V before native compilation and is
recorded separately from compilation success. Earlier failed attempts remain
in their original directories.

## Executed pixel results

These compare every pixel without a tolerance. The replay freezes animated
GIFs and explicitly hides `.danbo-slot` in both browsers to match Vox's enabled
EasyList policy. This controlled oracle does not establish parity with an
unmodified live Brave page.

| Comparison | Differing pixels | Total pixels |
| --- | ---: | ---: |
| Initial catalog, logical pixels | 1 | 786,432 |
| Initial catalog, native pixels | 7 | 3,145,728 |
| Catalog at 800×600, native pixels | 0 | 1,920,000 |
| Catalog at 1280×768, native pixels | 5 | 3,932,160 |
| Precision fixture, native pixels | 0 | 1,920,000 |
| Teaser fixture, native pixels | 0 | 1,920,000 |
| Transformed shadow fixture, native pixels | 19,277 | 1,920,000 |
| Select fixture, unchanged bundle retry | 0 | 1,920,000 |

The final run's select capture timed out in the Brave websocket handshake.
The unchanged select retry in `Build/4chan-catalog-20261027-filter-ready-1/`
passed with fresh Vox PID 37915, exit 0, and the same executable/library hashes.
`Build/4chan-catalog-20261027-acceptance-retry-1/` combines that receipt with
unchanged final-run results. Its `strict-pixel-acceptance.json` reports false;
no nonzero result is accepted as pixel exact. The original infrastructure
failure remains in the final run's log.

`scroll-coverage.json` establishes complete coverage of the 14,457-pixel document
through all 19 viewport offsets. Every row below compares 3,145,728 native pixels.

| Scroll offset (CSS pixels) | Differing pixels |
| ---: | ---: |
| 0 | 7 |
| 768 | 8 |
| 1536 | 6 |
| 2304 | 25,908 |
| 3072 | 3,873 |
| 3840 | 4 |
| 4608 | 26,022 |
| 5376 | 1,502 |
| 6144 | 1 |
| 6912 | 1,047 |
| 7680 | 1,897 |
| 8448 | 1,409 |
| 9216 | 4 |
| 9984 | 33,846 |
| 10752 | 1,035 |
| 11520 | 1,912 |
| 12288 | 4,217 |
| 13056 | 1,342 |
| 13689 | 4 |

The scrolling canvas-background fix is now exercised by the browser: the
previous 476,731 and 706,206 differences at offsets 768 and 1536 drop to 8 and
6. Remaining scrolled differences concentrate in particular thumbnail interiors,
some teaser text lines, and shadow edges. Their causes still need isolation.
The seven initial differences are each one blue-channel unit at shadow corners.

The transformed shadow fixture remains unchanged: normal, rounded and offset
regions match, while half-scale, double-scale and rotated regions differ by
952, 17,364 and 961 pixels respectively. Standalone transparent/opaque raster
probes provide diagnostic samples, not proof of a browser compositing fix.

## Live Brave and filter limitations

`device-live-run.json` records fresh Vox PID 19724, exit 0, and unchanged build
identity. The live catalog reached its expected title, complete readiness,
over 100 threads and decoded thumbnails. This establishes live document loading,
not live screenshot parity.

Both live Brave comparisons retain a 728×90 advertisement slot, while Vox's
EasyList cosmetic rule hides it. The initial board navigation, title, post-form
link and blotter geometry match; the controls and threads in Brave start
103.3359375 CSS pixels lower. `live-geometry.json` reports geometry failure.
`default-brave-live-geometry-corrected.json` resolves the default capture's
classes from its retained raw rectangle rows, including elements that also have
IDs; the original report and raw evidence remain intact. It also reports failure.

Copying seven signed public filter components into fresh profiles did not
reproduce the ad-hidden oracle, even with default component registration
enabled. Both component probes differ at 882,138 native pixels. Their archives
retain identical frozen assets and differ from the controlled oracle only by
removing the explicit cosmetic style. No personal browsing profile was copied.
The separate filter-readiness probe in
`Build/4chan-catalog-20261027-filter-ready-1/` also retains the ad slot after
reload: both its initial and reloaded captures differ at 882,138 pixels.

## Focused checks already executed

The option-label mutation hook, fractional shadow-color transport,
device-scaled shadow cutout, and scrolling canvas-background changes passed 31
focused runtime tests in `Build/4chan-catalog-20261027-background-1/`, plus four
native cache tests. The runtime receipt records exit 0 under the 3 GiB guard.
Legacy comma-separated `rgba()` alpha rounding passed its parser-to-paint
focused runtime check under the same limit in
`Build/4chan-catalog-20261027-alpha-1/`. Modern space-separated alpha retains its
fractional value. The completed production comparisons above now exercise
these changes together; they do not meet strict catalog acceptance.
