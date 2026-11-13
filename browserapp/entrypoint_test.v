// vtest build: macos
module main

import os
import time

// Exercise the actual startup path, including its mandatory browser
// smoke contracts. Explicit CLI arguments also permit windowed diagnostics
// from this focused binary while the managed production worker is occupied.
fn test_browser_startup_smoke() {
	previous_profile := os.getenv_opt('VOX_PROFILE_DIR')
	previous_cache := os.getenv_opt('LADYBIRD_CACHE_DIR')
	profile := if os.getenv('VOX_PROFILE_DIR') == '' {
		directory := os.join_path(os.temp_dir(), 'vox-startup-check-${os.getpid()}-${time.sys_mono_now()}')
		os.mkdir_all(directory) or { panic('${err}') }
		directory
	} else {
		''
	}
	if profile != '' {
		os.setenv('VOX_PROFILE_DIR', profile, true)
		os.setenv('LADYBIRD_CACHE_DIR', os.join_path(profile, 'cache'), true)
	}
	defer {
		if profile != '' {
			if value := previous_profile {
				os.setenv('VOX_PROFILE_DIR', value, true)
			} else {
				os.unsetenv('VOX_PROFILE_DIR')
			}
			if value := previous_cache {
				os.setenv('LADYBIRD_CACHE_DIR', value, true)
			} else {
				os.unsetenv('LADYBIRD_CACHE_DIR')
			}
			os.rmdir_all(profile) or {}
		}
	}
	arguments := if os.args.len > 1 { os.args } else { [os.args[0], '--headless-smoke'] }
	run_browser(arguments)
}
