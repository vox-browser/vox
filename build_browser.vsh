#!/usr/bin/env -S v run

// Unified Vox build entrypoint.
//
// `v run build_browser.vsh` builds the browser for the current host through x.imp
// flows. macOS and Linux delegate to their existing shell builders; Windows uses
// tools/build_windows_browser.py (MinGW + installed native dependencies).
// `package-zip` produces a portable Windows zip; `package-installer` turns it
// into an NSIS setup executable.
import os
import x.imp

const repo_dir = @DIR

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

os.chdir(repo_dir) or { panic('imp: cannot enter ${repo_dir}: ${err}') }

target := browser_target()

if !imp.check_binary(['git', 'python3'], panic: true) {
	return
}

mut ctx := imp.new()
ctx.add_target(target)
ctx.add_flow(
	id:    'browser'
	help:  'build the production browser for the current host'
	// The shell builders are authoritative on macOS/Linux and always run,
	// exactly as today; imp only routes to them. On Windows the MinGW
	// helper (tools/build_windows_browser.py) does the equivalent work.
	check: .none
	flags: [
		imp.Flag{ id: 'prod', help: 'optimised V build' },
		imp.Flag{ id: 'no-parallel-cc', help: 'compile one sealed C unit' },
		imp.Flag{ id: 'parallel-cc', help: 'split C units, link with ThinLTO' },
		imp.Flag{ id: 'console', help: 'keep a console entry point (Windows)' },
	]
	flow:  fn (self imp.Flow) ! {
		os_name := os.user_os()
		if os_name == 'windows' {
			mut args := ['python3', 'tools/build_windows_browser.py',
				'--javascriptcore-dll', os.getenv_opt('VOX_JSC_DLL') or {
					return error('imp: set VOX_JSC_DLL to the JavaScriptCore DLL path')
				},
				'--output', 'Build/windows/vox.exe']
			if deps_root := os.getenv_opt('VOX_WINDOWS_DEPS_ROOT') {
				args << ['--deps-root', deps_root]
			}
			if self.flag('console') {
				args << '--console'
			}
			imp.system_args(args)!
			return
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
	help:  'package a portable Windows zip of the built browser'
	takes: [target]
	gives: ['Build/windows/vox-portable.zip']
	check: .none
	flow:  fn (_ imp.Flow) ! {
		if os.user_os() != 'windows' {
			return error('imp: package-zip is a Windows flow')
		}
		imp.system_args(['python3', 'tools/package_windows_zip.py'])!
	}
)
ctx.add_flow(
	id:    'package-installer'
	help:  'build an NSIS installer from the portable zip'
	takes: ['Build/windows/vox-portable.zip']
	gives: ['Build/windows/Vox-0.1.3-setup.exe']
	check: .none
	flow:  fn (_ imp.Flow) ! {
		if os.user_os() != 'windows' {
			return error('imp: package-installer is a Windows flow')
		}
		if !imp.check_binary(['makensis'], panic: false) {
			return error('imp: makensis (NSIS) is required; see https://nsis.sourceforge.io/')
		}
		imp.system_args(['makensis', 'packaging/windows/vox.nsi'])!
	}
)
ctx.add_auto_flow(.clean)
ctx.add_auto_flow(.run)
ctx.default(['browser'])
ctx.flow()
