HOW TO RUN VOX ON macOS

Vox does not have an Apple Developer ID code signing certificate yet and is
not notarized by Apple. It has an ad-hoc signature for macOS runtime support,
but that signature does not verify the developer's identity. macOS may block
the first launch of this download as an app from an unidentified developer.

Install and open Vox

1. Drag Vox.app into the Applications folder. The Applications shortcut in
   this disk image is provided for that purpose.
2. Eject the Vox disk image, then open Vox from Applications.
3. If macOS blocks the launch, dismiss the alert without moving Vox to Trash.
4. Open the Apple menu > System Settings > Privacy & Security.
5. Scroll to Security and click Open Anyway next to the message about Vox.
   Authenticate if asked, then confirm Open. You may need to try opening Vox
   again before this option appears.
6. Later launches can use the normal Applications or Dock icon.

Only approve the Vox copy you obtained from https://vox-browser.org.

If Open Anyway is unavailable, a Terminal alternative for this app only is:

    xattr -dr com.apple.quarantine /Applications/Vox.app
    open /Applications/Vox.app

These commands remove the download quarantine flag from the installed Vox
bundle. They do not disable Gatekeeper for other apps. If you installed Vox
somewhere else, substitute its actual path (in quotes if it contains spaces).

Apple's instructions:
https://support.apple.com/en-us/102445
