# Snap packaging for Vox

This directory holds the Snap release scaffolding:

- `snapcraft.yaml` — the `snapcraft` manifest. It packs the prebuilt
  portable Linux tree (the supervised-build `Build/linux/vox` plus its
  bundled `*.so` libraries), so the Snap ships exactly the binary the
  tarball release publishes. App id: `org.vox_browser.vox` (the hyphen
  in `vox-browser.org` maps to an underscore, keeping a valid D-Bus /
  Flatpak-compatible reverse-DNS id).
- `org.vox_browser.vox.desktop` — the desktop entry installed in the Snap.
- `README.md` — this file.

The icon ships from the shared `packaging/Vox.png`; CI copies it to
`snap/gui/org.vox_browser.vox.png` and the manifest desktop entry to
`snap/gui/` before packing.

## Status: scaffolding, not submitted

What works today: `release-snap.yml` CI validates the scaffolding with
`tools/check_snap_manifest.py`, builds the Vox binary with the pinned
Linux toolchain, packs the `.snap`, smoke-tests the payload
(`--headless-smoke` on the unsquashed tree), and publishes the Snap to
GitHub Releases on `v*` tags.

What is still needed before a Snap Store submission:

1. **Runtime closure.** The Snap bundles the supervised-build binary and
   its `*.so` files but relies on the host for system libraries
   (JavaScriptCoreGTK, GLib, Fontconfig, …). Vendor the closure via
   `stage-packages` (names pinned against Ubuntu 24.04 `core24`) or a
   content snap before publishing to the store.
2. **Confinement review.** The Snap uses `classic` confinement (a
   JIT-compiling browser engine with multi-process sandboxing does not
   fit `strict` without further work). Store publication needs classic
   approval; a future iteration may move to `strict` with the audio,
   GPU, network, and removable-media plugs exercised here.
3. **Store testing.** Install with `snap install --classic --dangerous`
   on a clean 24.04 session, exercise navigation, file pickers, and
   video playback, then request publication.

## Manual build

```sh
# From the repository root, after building the Linux browser:
sh build-prod-browser.sh
test -x Build/linux/vox

# Stage the prebuilt tree exactly like CI does:
rm -rf release-staging snap
mkdir -p release-staging/snap-prime/bin snap/gui
cp Build/linux/vox release-staging/snap-prime/bin/
cp Build/linux/*.so release-staging/snap-prime/bin/ 2>/dev/null || true
cp packaging/snap/snapcraft.yaml snap/snapcraft.yaml
cp packaging/snap/org.vox_browser.vox.desktop snap/gui/
cp packaging/Vox.png snap/gui/org.vox_browser.vox.png

# Pack (needs snapd/LXD, same as CI's snapcore/action-build):
snapcraft pack --project-dir .
ls -la vox_*.snap

# Smoke-test without installing:
sudo apt-get install -y squashfs-tools
rm -rf squashfs-root
unsquashfs -d squashfs-root vox_*.snap bin
./squashfs-root/bin/vox --headless-smoke
rm -rf squashfs-root
```
