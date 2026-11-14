## Vox Browser

https://vox-browser.org

[Windows build instructions](docs/WINDOWS.md)

<img width="2078" height="1628" alt="image" src="https://github.com/user-attachments/assets/ed3d6776-78dd-4903-b716-a95cd5845cab" />

WebGL uses a shader frontend written in V, with direct Metal generation on
macOS and native driver compilation on Linux and Windows. See
[shader validation and backend equivalence tests](docs/SHADER_VALIDATION.md).

### Building

Setup and build helpers run as V `.vsh` scripts. Python is used by optional
tests, benchmarks, and generators. See
[build-tool commands](tools/BUILDING.md).

Install a current [V compiler](https://github.com/vlang/v), put `v` on `PATH`,
and install the shared V UI with `v install ui2` (or update it with `v up ui2`).

Install native dependencies once, then prepare the development environment once
per terminal from the repository root. Subsequent builds use **`v .`**. The setup
command prepares native bridges and compiler adapters and selects the checked C
backend. Re-run setup after updating V, UI2 or the build dependencies. `V_BIN`
and `UI2_SOURCE_DIR` can select existing checkouts.

#### macOS

```sh
brew install freetype openssl ffmpeg libavif
eval "$(sh tools/run_v_tool.sh dev_build_env)"
v .
./vox2 https://example.com
```

The first setup installs the [HarfBuzz VPM module](https://github.com/vlang/harfbuzz),
including a checksum-verified, optimized HarfBuzz 15.1.0 archive for Apple Silicon
or Intel from its GitHub release. It enables OpenType/AAT/CoreText without
Graphite2 and reuses the installed archive for development and production builds.
HarfBuzz is downloaded precompiled; no local C++ build or Homebrew HarfBuzz is
needed. Use a current VPM with `vpm-binaries.json` support. The dependency is also
listed in `v.mod`, so `v install` installs it directly.

For an existing macOS checkout, rerun
`eval "$(sh tools/run_v_tool.sh dev_build_env)"` before the next `v .` build.

Font selection, Unicode processing and glyph-run policy use V code with bundled
Unicode 17 data. FFmpeg and libavif supply media and AVIF support. HTTP uses
macOS's built-in libcurl; Homebrew curl is not required. OpenSSL remains a
dependency for WebCrypto. To produce the signed application bundle:

```sh
sh build-prod-browser.sh --prod
open Build/v/Vox.app
```

#### Linux (Ubuntu 24.04+ / Debian 13)

```sh
sudo apt-get update
sudo apt-get install build-essential clang pkg-config git ca-certificates \
    libjavascriptcoregtk-4.1-dev libglib2.0-dev libharfbuzz-dev \
    libcurl4-openssl-dev libssl-dev libegl1-mesa-dev libgles2-mesa-dev \
    libgl1-mesa-dev libxi-dev libxcursor-dev libxrandr-dev libx11-dev \
    libasound2-dev libgc-dev libfreetype-dev libfontconfig-dev libwebp-dev \
    libpng-dev libjpeg-dev fonts-liberation2 fonts-dejavu-core
eval "$(sh tools/run_v_tool.sh dev_build_env)"
v .
Build/linux/vox https://example.com
```

The desktop renderer uses X11 (including XWayland). For the managed production
build use `sh build-prod-browser.sh`. See [Linux setup and tests](docs/LINUX.md),
including the Xvfb window test and optional media dependencies.

#### Windows (x86-64)

Use an [MSYS2 MinGW64](https://www.msys2.org/) terminal with V and the
compiler tools on `PATH`. Install:

```sh
pacman -S --needed mingw-w64-x86_64-toolchain mingw-w64-x86_64-pkgconf \
    mingw-w64-x86_64-icu mingw-w64-x86_64-harfbuzz mingw-w64-x86_64-freetype \
    mingw-w64-x86_64-openssl mingw-w64-x86_64-curl mingw-w64-x86_64-7zip
```

Supply a Windows x86-64 `JavaScriptCore.dll` and its matching WebKit DLLs;
[Playwright's WebKit distribution](https://playwright.dev/docs/browsers) is one
source. The setup verifies the required exports and creates its import library:

```sh
eval "$(sh tools/run_v_tool.sh dev_build_env --shell sh \
    --javascriptcore-dll C:/path/to/webkit/JavaScriptCore.dll)"
v -b c .
./vox2.exe https://example.com
```

Keep MinGW and matching WebKit DLL directories on `PATH`, or put their DLLs
beside the executable. Enable Windows Developer Mode for the module links.
Some pixel-test fixture names cannot be checked out on Windows; use the
[sparse-checkout instructions](docs/WINDOWS.md#checkout-limitation).
[Windows build details](docs/WINDOWS.md) also cover cross-compiling and the
current runtime limitations.

For a quick engine check, run the resulting executable with `--headless-smoke`.
The latest [Linux VM checks](docs/LINUX.md#vm-follow-up-2026-11-12) and
[Windows VM checks](docs/WINDOWS.md#vm-follow-up-2026-11-12) record the verified
builds, runtime checks and earlier failed attempts.
Repository contributors run builds and tests through
`sh tools/run_v_tool.sh run_memory_bounded --lock Build/JOB.lock --report Build/JOB.json -- v .`.

HTML/CSS - pure V, rendering via the V graphics module (DirectX 11, Metal, OpenGL, FreeType/stb_truetype).

GUI - V UI2

JS - JavaScriptCore/V8/Vox JS engine (still WIP)

### Goals

The goal is to develop a free, clean, fast to compile (a couple of seconds), easily embeddable (like Electron), efficient and low memory (like Opera's old Presto) browser engine.

Full pixel parity with Chrome.

Today's web is dominated by the Chromium engine. It's slow to compile (5 hours on top tier 2026 desktop hardware), hard to develop because of the huge and complicated C++ code base, uses a huge amount of resources.

Firefox, the last alternative to Chromium, has unfortunately strayed away from its initial focus on privacy (it has huge amounts of telemetry and questionable partnerships), it's not embeddable at all, is even harder to build and develop than Chromium due to an older code base, has worse performance and battery usage.

There's a clear room for a new fresh alternative. Having more browsers is healthier for the open web.

Developing a browser is a very difficult task because of the ever increasing complexity of the web. Companies like Opera and Microsoft gave up developing their own engines and switched to Chromium. However it's not impossible. For example, a new proprietary browser Flow now successfully works with Gmail, one of the most complicated web apps. The NetSurf browser works quite well with websites that don't rely on JavaScript for rendering.

The graphics/text rendering is handled completely by V's builtin libraries, and cross platform UI is handled by V UI2.

With the V language which focuses on simple and maintainable code with fast compilation time, developing a browser will be a much easier task.  

Initially we started with an implementation from scratch, but decided to use [Ladybird](https://ladybird.org/) as the foundation. In March 2026, we adopted an older version of Ladybird's C++ codebase, translated it into V, and have heavily modified and extended it since.


### Existing features
- Built-in ad blocking (using uBlock Origin lists).
- Built-in cookie banner blocking


### Planned features

- Focus on privacy and security. Complete lack of telemetry.
- Optional Vim-like keyboard control for working without mouse (similar to Chrome's Vimium plugin).
- Vertical tabs option (similar to Firefox's old Tree Style Tab extension).
- Mouse gestures (like in Opera).

### Acknowledgements

Vox builds on the work of Andreas Kling and the Ladybird and SerenityOS contributors. We thank them for the browser engine and libraries that made this translation possible.

Ladybird-derived code retains its BSD 2-Clause license and original copyright notices. See [third-party notices](THIRD_PARTY_NOTICES.md) for the full Ladybird license and notices for other bundled components.

### License

Copyright (c) 2026 Alexander Medvednikov.

Except where otherwise noted, Vox is licensed under the [GNU General Public License, version 2 or any later version](LICENSE) (`GPL-2.0-or-later`). The bundled uBlock Origin integration requires GPL version 3 or later for the combined distribution; see [third-party notices](THIRD_PARTY_NOTICES.md).

