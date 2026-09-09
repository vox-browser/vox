# Site pixel comparisons

These tests compare screenshots from the V browser with checked-in screenshots
from the upstream C++ Ladybird browser. The pages and visible resources are
frozen locally so a site update, network failure, advertisement, or timestamp
cannot change the result.

Run every confirmed site:

```sh
./compare_site_pixels.sh
```

Run one or more named cases:

```sh
./compare_site_pixels.sh example-com hacker-news old-reddit-worldnews
```

Artifacts are written to `Build/site-pixel-comparison/`: the V screenshot,
amplified diff image, and raw metrics for each case. A case fails if any ceiling
in `cases.tsv` is exceeded.

## Fixtures and references

- `example-com` is the static Example Domain page and is pixel exact.
- `hacker-news` is a frozen 2026-09-09 front page. Its small allowance covers
  text and SVG antialiasing; no pixel currently differs by more than 10.
- `old-reddit-worldnews` is the Internet Archive's
  [2024-01-01 capture](https://web.archive.org/web/20240101010757id_/https://old.reddit.com/r/worldnews/),
  with scripts removed and visible resources localized. The live URL currently
  rejects automated requests. Its allowance records the remaining text and
  image rasterization delta after layout parity.

The expected PNGs were captured at the viewport sizes in `cases.tsv` with the
release build at `../3rd/ladybird/Build/release/bin/Ladybird.app`. They are
macOS references because both browsers use the installed Arial and Verdana
faces. Regenerate them only when intentionally adopting a new upstream render;
review the resulting diff images before updating a ceiling.
