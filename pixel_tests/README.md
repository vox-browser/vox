# Site pixel comparisons

For the ten-site **Brave + full uBlock Origin** comparison, use
[`tools/forum_news_pixels.py`](../tools/forum_news_pixels.py). Its separate
catalog is [`Tests/Browser/Brave/forum-news.json`](../Tests/Browser/Brave/forum-news.json).
It requires **zero differing RGBA pixels** and does not use the allowances below.

```sh
python3 tools/forum_news_pixels.py --extension /path/to/uBlock0.chromium \
  --checker Build/adblock-check
```

Build the checker with current V and the repository memory guard:

```sh
python3 tools/run_memory_bounded.py --limit-gib 3 \
  --lock Build/forum-checker.lock --report Build/forum-checker.json -- \
  ~/code/v/v -memory-limit 10G -nocache -enable-globals -o Build/adblock-check tools/adblock_check.v
```

`--sites hacker-news` selects a site. `--capture --fixtures Build/new-site-fixtures`
records new guest-page fixtures without overwriting existing archives. All
browser/compiler children run through their own 3 GiB memory guards. The runner
uses the installed production bundle directly and never schedules a rebuild.
Each Vox capture launches a new process with an empty private profile, records
the executable/native-library identities, and rejects a concurrent bundle change.
`--audit-config FILE` selects additional native layout observations while
diagnosing a mismatch; retain the `body` and `images` selectors in that config.
The checker is built without temporary module-cache dependencies so it remains
usable after compiler scratch directories are cleaned.

The reference runs the full MV2 uBO version pinned in `adblock/lists/manifest.json`,
with the identical list bytes, no custom filters and Brave Shields disabled.
Both engines request the same captured document and resources at their original
URLs through a local archive proxy that never forwards missing requests. TLS
trust is private to those processes. The DOM snapshot removes author scripts;
it preserves author layout/styles rather than replacing them with computed
geometry or a page image. The archived live Brave screenshot must also match
the replay, and two consecutive reference captures must be stable. This is a
frozen viewport regression, not a claim of live JavaScript/interaction parity.

The runner checks native document identity/readiness and compares the requests
actually recorded by Vox with full uBO before assessing pixels. Every site gets
a result in `Build/forum-news-pixels-*/summary.json`; missing fixtures, access
checks, incomplete references, filtering disagreements and pixel differences
all fail. A failure on one site does not prevent checking the remaining sites.

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

A fourth 40-page batch was frozen on 2026-09-10. As with the earlier batches,
scripts were removed and all resources that affect the captured viewport were
localized:

| Case | Original page |
| --- | --- |
| `pcre` | [PCRE](https://www.pcre.org/) |
| `libffi` | [libffi](https://sourceware.org/libffi/) |
| `bzip2` | [bzip2](https://sourceware.org/bzip2/) |
| `c-ares` | [c-ares](https://c-ares.org/) |
| `openwall` | [Openwall](https://www.openwall.com/) |
| `cloc` | [cloc](https://cloc.sourceforge.net/) |
| `nano` | [GNU nano](https://www.nano-editor.org/) |
| `less` | [less](https://www.greenwoodsoftware.com/less/) |
| `lynx` | [Lynx](https://lynx.invisible-island.net/) |
| `links` | [Links](https://links.twibright.com/) |
| `w3m` | [w3m](https://w3m.sourceforge.net/) |
| `rsync` | [rsync](https://rsync.samba.org/) |
| `opensmtpd` | [OpenSMTPD](https://www.opensmtpd.org/) |
| `openntpd` | [OpenNTPD](https://www.openntpd.org/) |
| `postfix` | [Postfix](https://www.postfix.org/) |
| `exim` | [Exim](https://www.exim.org/) |
| `haproxy` | [HAProxy](https://www.haproxy.org/) |
| `memcached` | [Memcached](https://memcached.org/) |
| `bearssl` | [BearSSL](https://bearssl.org/) |
| `gnutls` | [GnuTLS](https://www.gnutls.org/) |
| `libtomcrypt` | [LibTomCrypt](https://www.libtom.net/) |
| `nghttp2` | [nghttp2](https://nghttp2.org/) |
| `uclibc-ng` | [uClibc-ng](https://uclibc-ng.org/) |
| `ninefront` | [9front](https://9front.org/) |
| `plan9` | [Plan 9](https://9p.io/plan9/) |
| `cgit` | [cgit](https://git.zx2c4.com/cgit/about/) |
| `subversion` | [Apache Subversion](https://subversion.apache.org/) |
| `schemers` | [Schemers.org](https://www.schemers.org/) |
| `lobsters` | [Lobsters](https://lobste.rs/) |
| `susam` | [Susam Pal](https://susam.net/) |
| `beej` | [Beej's Bit Bucket](https://beej.us/) |
| `sive` | [Derek Sivers](https://sive.rs/) |
| `jvns` | [Julia Evans](https://jvns.ca/) |
| `250bpm` | [250bpm](https://250bpm.com/) |
| `benhoyt` | [Ben Hoyt](https://benhoyt.com/writings/) |
| `tarsnap` | [Tarsnap](https://www.tarsnap.com/) |
| `pigz` | [pigz](https://www.zlib.net/pigz/) |
| `lzo` | [LZO](https://www.oberhumer.com/opensource/lzo/) |
| `ijg` | [Independent JPEG Group](https://www.ijg.org/) |
| `netlib` | [Netlib](https://www.netlib.org/) |

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
