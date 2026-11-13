# DEB/RPM packaging for Vox

This directory holds the Linux system-package scaffolding:

- `nfpm.yaml` — the [nFPM](https://nfpm.goreleaser.com/) manifest. It packs
  the prebuilt portable Linux tree (the supervised-build `Build/linux/vox`
  plus its bundled `*.so` libraries), so both packages ship exactly the
  binary the tarball release publishes. App id: `org.vox_browser.vox`
  (the hyphen in `vox-browser.org` maps to an underscore, keeping a valid
  reverse-DNS id).
- `vox-wrapper.sh` — installed as `/usr/bin/vox`. The real browser and its
  bundled native libraries live together in `../lib/vox` relative to the
  wrapper (the same relative layout as the portable tarball); the wrapper
  resolves that directory from its own path (via `readlink -f` when
  available), exports it for loader paths that need it, and execs the real
  binary. Relocatable resolution lets the same file work installed as
  `/usr/bin/vox` and when smoke-testing an extracted package tree
  (`./deb-root/usr/bin/vox` runs `deb-root/usr/lib/vox/vox`, not the host's).
- `org.vox_browser.vox.desktop` — the desktop entry installed to
  `/usr/share/applications`. It uses `Exec=vox %u` (single URL) because
  `parse_launch_options` in `main.v` accepts only one launch source.
- `org.vox_browser.vox.desktop` — the desktop entry installed to
  `/usr/share/applications`.
- `README.md` — this file.

The icon ships from the shared `packaging/Vox.png`; CI installs it as
`/usr/share/icons/hicolor/256x256/apps/org.vox_browser.vox.png`.

## Status: scaffolding, not submitted

What works today: `release-deb-rpm.yml` CI validates the scaffolding with
`tools/check_deb_rpm_manifest.py`, builds Vox with the pinned Linux
toolchain, packs the `.deb` and `.rpm` with nFPM, vendors the Ubuntu 24.04
ICU 74 runtime into the payload for Fedora portability (the RPM does not
depend on system `icu`), smoke-tests both extracted payloads
(`--headless-smoke` via the relocatable wrapper), and publishes both
packages to GitHub Releases on `v*` tags with `--latest=false` so the
macOS publisher's bare-version parser keeps working.

What is still needed before repository submission:

1. **Runtime-dependency verification.** The `depends` (DEB, Ubuntu 24.04
   names) and `overrides.rpm.depends` (Fedora-style names) lists are
   best-effort. Install both packages on clean Debian/Ubuntu and
   Fedora/RHEL sessions, fix the closure, and confirm `amd64`/`x86_64`
   end-user installs pull everything they need.
2. **Debian policy pass.** Ship `/usr/share/doc/vox/copyright`, add
   `section`/`priority` if a sponsor requires them, and run `lintian`
   before proposing the package to Debian/Ubuntu.
3. **RPM conventions.** Confirm the Fedora `Requires` names and add any
   `%post` scriptlets a reviewer asks for (none are needed today: no
   `ldconfig` dir is installed outside the default search path and the
   desktop/icon payloads need no cache updates beyond what the
   installers run themselves).
4. **Repository hosting.** Publish to a PPA/COPR or vendor the artifacts;
   that step needs a maintainer.

## Manual build

```sh
# From the repository root, after building the Linux browser:
sh build-prod-browser.sh
test -x Build/linux/vox

# Stage the prebuilt tree exactly like CI does:
rm -rf release-staging
mkdir -p release-staging/deb-rpm-prime/usr/lib/vox \
  release-staging/deb-rpm-prime/usr/bin \
  release-staging/deb-rpm-prime/usr/share/applications \
  release-staging/deb-rpm-prime/usr/share/icons/hicolor/256x256/apps
cp Build/linux/vox release-staging/deb-rpm-prime/usr/lib/vox/
cp Build/linux/*.so release-staging/deb-rpm-prime/usr/lib/vox/ 2>/dev/null || true
cp packaging/deb-rpm/vox-wrapper.sh release-staging/deb-rpm-prime/usr/bin/vox
chmod 755 release-staging/deb-rpm-prime/usr/bin/vox \
  release-staging/deb-rpm-prime/usr/lib/vox/vox
cp packaging/deb-rpm/org.vox_browser.vox.desktop \
  release-staging/deb-rpm-prime/usr/share/applications/
cp packaging/Vox.png \
  release-staging/deb-rpm-prime/usr/share/icons/hicolor/256x256/apps/org.vox_browser.vox.png

# Pack (needs Go; nFPM resolves the version from packaging/version.txt):
go install github.com/goreleaser/nfpm/v2/cmd/nfpm@v2
export PATH="$PATH:$HOME/go/bin"
export VOX_VERSION="$(python3 -c "print(open('packaging/version.txt', encoding='utf-8-sig').read().strip())")"
nfpm package --config packaging/deb-rpm/nfpm.yaml --packager deb --target .
nfpm package --config packaging/deb-rpm/nfpm.yaml --packager rpm --target .
ls -la vox_*.deb vox-*.rpm

# Smoke-test without installing:
rm -rf deb-root && dpkg-deb -x vox_*.deb deb-root && ./deb-root/usr/bin/vox --headless-smoke && rm -rf deb-root
rm -rf rpm-root && mkdir rpm-root && (cd rpm-root && rpm2cpio ../vox-*.rpm | cpio -idm) && ./rpm-root/usr/bin/vox --headless-smoke && rm -rf rpm-root
```
