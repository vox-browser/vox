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

The following pages were frozen from their original sites on 2026-09-09. Their
executable script elements were removed and their visible styles, fonts, and
images were localized. Lua's animated logo is fixed at its first frame so both
browsers capture the same content.

| Case | Original page |
| --- | --- |
| `never-ssl` | [NeverSSL](http://neverssl.com/) |
| `cern` | [The first website](https://info.cern.ch/) |
| `motherfucking-website` | [motherfuckingwebsite.com](https://motherfuckingwebsite.com/) |
| `best-motherfucking-website` | [thebestmotherfucking.website](https://thebestmotherfucking.website/) |
| `httpbin-html` | [httpbin HTML sample](https://httpbin.org/html) |
| `nginx` | [nginx.org](https://nginx.org/) |
| `sqlite` | [sqlite.org](https://www.sqlite.org/index.html) |
| `lua` | [lua.org](https://www.lua.org/) |
| `kernel` | [kernel.org](https://www.kernel.org/) |
| `suckless` | [suckless.org](https://suckless.org/) |
| `wiby` | [wiby.me](https://wiby.me/) |
| `npr-text` | [NPR text](https://text.npr.org/) |
| `curl` | [curl.se](https://curl.se/) |
| `vim` | [vim.org](https://www.vim.org/) |
| `git-scm` | [git-scm.com](https://git-scm.com/) |
| `css-zen-garden` | [CSS Zen Garden](https://www.csszengarden.com/) |
| `space-jam-1996` | [Space Jam 1996](https://www.spacejam.com/1996/) |
| `bellard` | [bellard.org](https://bellard.org/) |
| `pgl-yoyo` | [pgl.yoyo.org](https://pgl.yoyo.org/) |
| `knuth` | [Donald Knuth](https://www-cs-faculty.stanford.edu/~knuth/) |

A second 20-page batch was frozen on the same date and with the same script
and resource treatment:

| Case | Original page |
| --- | --- |
| `openbsd` | [OpenBSD](https://www.openbsd.org/) |
| `netbsd` | [NetBSD](https://www.netbsd.org/) |
| `musl` | [musl libc](https://musl.libc.org/) |
| `libexpat` | [Expat](https://libexpat.github.io/) |
| `zlib` | [zlib](https://www.zlib.net/) |
| `libpng` | [libpng](https://libpng.org/pub/png/) |
| `libjpeg-turbo` | [libjpeg-turbo](https://www.libjpeg-turbo.org/) |
| `busybox` | [BusyBox About](https://busybox.net/about.html) |
| `ffmpeg` | [FFmpeg About](https://ffmpeg.org/about.html) |
| `delorie` | [Delorie Software](https://www.delorie.com/) |
| `paul-graham` | [Paul Graham](https://paulgraham.com/) |
| `cat-v` | [cat-v](https://cat-v.org/) |
| `toybox` | [Toybox](https://landley.net/toybox/) |
| `daring-fireball` | [Daring Fireball Colophon](https://daringfireball.net/colophon/) |
| `better-motherfucking-website` | [Better Motherfucking Website](http://bettermotherfuckingwebsite.com/) |
| `idlewords` | [Idle Words](https://idlewords.com/) |
| `stallman` | [Richard Stallman](https://stallman.org/) |
| `cr-yp-to` | [cr.yp.to](https://cr.yp.to/) |
| `ncurses` | [ncurses](https://invisible-island.net/ncurses/) |
| `teensy-elf` | [Teensy ELF](https://www.muppetlabs.com/~breadbox/software/tiny/teensy.html) |

A third 20-page batch was frozen on the same date. Executable script elements
were removed and visible resources were localized as above. Query-bearing QEMU
resource names were normalized for local files. Fossil and lighttpd's
network-origin CSP meta policies were removed because they reject those same
localized `file:` resources in the C++ browser.

| Case | Original page |
| --- | --- |
| `openssh` | [OpenSSH](https://www.openssh.com/) |
| `libressl` | [LibreSSL](https://www.libressl.org/) |
| `mandoc` | [mandoc](https://mandoc.bsd.lv/) |
| `tinycc` | [Tiny C Compiler](https://bellard.org/tcc/) |
| `libarchive` | [libarchive](https://www.libarchive.org/) |
| `libuv` | [libuv](https://libuv.org/) |
| `ninja` | [Ninja](https://ninja-build.org/) |
| `valgrind` | [Valgrind](https://valgrind.org/) |
| `hare` | [Hare](https://harelang.org/) |
| `qemu` | [QEMU](https://www.qemu.org/) |
| `textfiles` | [TEXTFILES.COM](https://www.textfiles.com/) |
| `fossil` | [Fossil](https://fossil-scm.org/home/doc/trunk/www/index.wiki) |
| `xz` | [XZ Utils](https://tukaani.org/xz/) |
| `man7` | [Linux man-pages](https://man7.org/linux/man-pages/) |
| `danluu` | [Dan Luu](https://danluu.com/) |
| `nullprogram` | [null program](https://nullprogram.com/) |
| `drew-devault` | [Drew DeVault](https://drewdevault.com/) |
| `tim-berners-lee` | [Tim Berners-Lee](https://www.w3.org/People/Berners-Lee/) |
| `jemalloc` | [jemalloc](https://jemalloc.net/) |
| `lighttpd` | [lighttpd](https://www.lighttpd.net/) |

The expected PNGs were captured at the viewport sizes in `cases.tsv` with the
release build at `../3rd/ladybird/Build/release/bin/Ladybird.app`. They are
macOS references because both browsers use the same installed font files,
including the selected faces in macOS TrueType collections. Regenerate them
only when intentionally adopting a new upstream render; review the resulting
diff images before updating a ceiling.

The ceilings intentionally bound four image-wide measurements. Some text-heavy
pages retain sizeable raw pixel counts because the V replay path rasterizes
glyph edges differently; the checked-in pairs were also reviewed for matching
layout, wrapping, colors, and visible assets.
