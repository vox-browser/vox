#!/usr/bin/env -S v run

// Unified Vox build entrypoint.
//
// `v run build_browser.vsh` builds the browser for the current host through x.imp
// flows. macOS and Linux delegate to their existing shell builders; the
// Windows `browser` flow reports that the native build is not supported
// yet. See docs/WINDOWS.md for the release plan.
import json2
import os
import x.imp

const repo_dir = @DIR

struct RegexManifestFile {
	path   string
	sha256 string
}

struct RegexManifest {
	files           []RegexManifestFile
	upstream_commit string
}

// host_triplet names the Build/libregex output directory used by
// tools/build_regex_backend.py (platform.system().lower() there).
fn host_triplet() string {
	if os.user_os() == 'macos' {
		return 'darwin'
	}
	return os.user_os()
}

// browser_target is the production binary for the current host.
fn browser_target() string {
	os_name := os.user_os()
	if os_name == 'windows' {
		return 'Build/windows/vox.exe'
	}
	if os_name == 'linux' {
		return 'Build/linux/vox'
	}
	return 'Build/v/Vox.app/Contents/MacOS/Vox'
}

// regex_takes lists the pinned backend inputs so content edits defeat the
// skip check. Falls back to coarser paths when the manifest is unreadable;
// the builder itself re-verifies its content fingerprint on every run.
fn regex_takes() []string {
	manifest_path := os.join_path(repo_dir, 'libregex', 'native', 'manifest.json')
	content := os.read_file(manifest_path) or { return ['libregex/native'] }
	manifest := json2.decode[RegexManifest](content) or {
		return ['libregex/native', 'tools/build_regex_backend.py']
	}
	mut takes := ['tools/build_regex_backend.py', 'libregex/native/manifest.json',
		'libregex/native/unicode.rs']
	for record in manifest.files {
		takes << os.join_path('libregex', 'native', record.path)
	}
	return takes
}

os.chdir(repo_dir) or { panic('imp: cannot enter ${repo_dir}: ${err}') }

target := browser_target()
triplet := host_triplet()

if !imp.check_binary(['git', 'python3'], panic: true) {
	return
}

mut ctx := imp.new()
ctx.add_target(target)
ctx.add_flow(
	id:    'regex-backend'
	help:  'build the pinned LibRegex Rust backend'
	takes: regex_takes()
	gives: ['Build/libregex/${triplet}/libregex_native.a']
	flow:  fn (_ imp.Flow) ! {
		imp.system_args(['python3', 'tools/build_regex_backend.py'])!
	}
)
ctx.add_flow(
	id:    'browser'
	help:  'build the production browser for the current host'
	// The shell builders are authoritative and always run, exactly as
	// today; imp only routes to them.
	check: .none
	flags: [
		imp.Flag{ id: 'prod', help: 'optimised V build' },
		imp.Flag{ id: 'no-parallel-cc', help: 'compile one sealed C unit' },
		imp.Flag{ id: 'parallel-cc', help: 'split C units, link with ThinLTO' },
	]
	flow:  fn (self imp.Flow) ! {
		os_name := os.user_os()
		if os_name == 'windows' {
			return error('imp: native Windows build is not supported yet, see docs/WINDOWS.md')
		}
		mut args := if os_name == 'linux' {
			['sh', 'build-linux-browser.sh']
		} else {
			['sh', 'build-prod-browser.sh']
		}
		for flag in ['prod', 'no-parallel-cc', 'parallel-cc'] {
			if self.flag(flag) {
				args << '--${flag}'
			}
		}
		imp.system_args(args)!
	}
)
ctx.add_flow(
	id:    'package-zip'
	help:  'package a portable Windows zip (not implemented yet)'
	takes: [target]
	gives: ['Build/windows/vox-portable.zip']
	check: .none
	flow:  fn (_ imp.Flow) ! {
		return error('imp: Windows packaging lands with Phase 4, see docs/WINDOWS.md')
	}
)
ctx.add_auto_flow(.clean)
ctx.add_auto_flow(.run)
ctx.default(['regex-backend', 'browser'])
ctx.flow()
