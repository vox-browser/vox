# Flathub packaging for Vox

This directory holds the Flathub submission scaffolding:

- `org.vox_browser.vox.json` — the `flatpak-builder` manifest.
- `org.vox_browser.vox.metainfo.xml` — AppStream metadata.
- `org.vox_browser.vox.desktop` — the desktop entry installed in the sandbox.

## Status: scaffolding, not submitted

What works today: `flatpak.yml` CI validates the metainfo with
`appstreamcli` and cross-checks the manifest with
`tools/check_flatpak_manifest.py`.

What is still needed before a Flathub submission:

1. **A full local `flatpak-builder` run.** The manifest mirrors the Linux CI
   toolchain (pinned V, UI2 at HEAD, repo native scripts), but the V
   bootstrap, the native-dependency build inside `build_linux_native.py`,
   and the multi-hour build have not run inside a sandbox yet. Flathub's
   buildbot has no network access, so any download the scripts perform
   must become vendored manifest sources first.
2. **Sandbox testing.** The `finish-args` cover display, audio, GPU,
   network and downloads. File pickers, notifications, and multi-process
   behavior need a real session before submission.
3. **Listing assets.** Screenshots, `<releases>` entries (wired to
   `packaging/version.txt` once versions publish), and the OARS content
   rating questionnaire.
4. **The submission itself.** A PR to `flathub/flathub` plus reviewer
   rounds; that step needs a maintainer.

## Manual build

```sh
flatpak-builder --force-clean build-dir \
  packaging/flatpak/org.vox_browser.vox.json
flatpak-builder --run build-dir \
  packaging/flatpak/org.vox_browser.vox.json vox --headless-smoke
```
