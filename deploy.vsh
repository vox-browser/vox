#!/usr/bin/env -S v -memory-limit 10G run

// Release Vox for macOS: commit packaging/Info.plist at the next patch version,
// build that commit in ../vox2-release (other sessions' uncommitted work is not
// compiled or disturbed), package the DMG, upload it to a new vox-browser/vox
// GitHub release tagged with that version and point vox-browser.org/version at it.
// Use --help for --version, --package-only, --no-publish and --website-only.
import os

fn main() {
	repository := os.dir(os.real_path(@FILE))
	exit(os.system_args(['python3', os.join_path(repository, 'tools', 'deploy_macos.py'),
		...os.args[1..]]))
}
