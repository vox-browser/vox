# Vox on Windows

Windows support is experimental. The canonical workspace builds and runs on
macOS and Linux; this document tracks the Windows release work and what runs
today.

## Status

- `v run build.v` orchestrates the build on every host through `x.imp`
  flows. On Windows the `browser` flow reports that the native build is not
  supported yet; macOS and Linux delegate to their existing shell builders.
- There is no Windows installer, portable zip, or update feed yet. The
  update checker (`browserupdate/`) compares one shared release version on
  every platform through `packaging/version.txt`.
- The translated LibJS engine is not production-ready, so the Windows
  JavaScript engine choice stays open: there is no first-party
  JavaScriptCore for Windows. The candidates are WinCairo JavaScriptCore,
  the in-tree `libjs` engine once it reaches parity, or an alternate runtime
  behind the existing JS host boundary.
- The native platform backend (Win32 window hosting, input, clipboard,
  timers, dialogs), the Windows Skia acquisition, and DirectWrite font
  enumeration do not exist yet.

## Checkout limitation

46 fixture paths under `pixel_tests/` contain characters illegal on Windows
(`:`, `?`). A native Windows `git checkout` of the full tree fails inside
those fixtures, and sparse-checkout exclusions do not avoid the failure.
Until the fixtures are renamed, check this repository out under WSL, or work
with a partial worktree that skips `pixel_tests/`. `Tests/` (Brave evidence
archives) is also excluded from Windows worktrees for size.

## Baseline checks

With V on `PATH` (any host, including Windows):

```sh
v run build.v --help
```

To verify the pinned LibRegex sources without building:

```sh
python3 tools/build_regex_backend.py --verify-only
```

`v run build.v` builds the browser for the current host. It fails on
Windows until the native backend lands; macOS and Linux behave exactly as
their `build-prod-browser.sh` / `build-linux-browser.sh` entrypoints do
today. `v run build.v package-zip` reserves the portable-zip flow name and
fails until packaging (Phase 4) is implemented.

## Future native prerequisites

For the eventual native Windows build: Visual Studio Build Tools (MSVC),
CMake, Ninja, a Rust compiler with edition 2024 support, Python 3.12 or
newer, and a current V checkout with `x.imp` (`vlib/x/imp`). Dependency
acquisition (Skia, ICU, HarfBuzz, curl/OpenSSL equivalents) and the
JavaScript engine decision precede any native compile.
