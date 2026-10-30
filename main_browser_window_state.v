module main

$if macos {
	import browsersettings
	import os

	#include "native_browser_window_state_darwin.m"
}

fn C.native_prepare_browser_window_state(path &char)
fn C.native_restore_browser_window_state(window voidptr)
fn C.native_finish_browser_window_state()

fn browser_window_state_enabled(options LaunchOptions, arguments []string) bool {
	if options.screenshot != '' || options.headless_smoke || options.headless_layout_tree
		|| options.restore_tab != '' {
		return false
	}
	for argument in arguments {
		if argument in ['--window-width', '--window-height']
			|| argument.starts_with('--window-width=') || argument.starts_with('--window-height=') {
			return false
		}
	}
	return true
}

fn prepare_browser_window_state(options LaunchOptions) {
	$if macos {
		if browser_window_state_enabled(options, os.args[1..]) {
			path := os.join_path(os.dir(browsersettings.default_path()), 'window-state.plist')
			C.native_prepare_browser_window_state(path.str)
		}
	}
}
