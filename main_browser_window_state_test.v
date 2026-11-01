module main

import browserui
import json2
import os
import time

$if vox_ui2 ? {
	#include "native_address_bar_test_darwin.h"
	fn C.native_test_address_window() voidptr
	fn C.native_test_address_close(voidptr)
}

fn test_window_state_restoration_respects_launch_modes_and_explicit_sizes() {
	assert browser_window_state_enabled(LaunchOptions{}, [])
	assert browser_window_state_enabled(LaunchOptions{ source: 'https://example.com' }, [])
	for arguments in [
		['--window-width', '800'],
		['--window-height', '600'],
		['--window-width=800'],
		['--window-height=600'],
	] {
		options := parse_launch_options(arguments)!
		assert !browser_window_state_enabled(options, arguments)
	}
	for arguments in [
		['--screenshot', 'out.png'],
		['--headless-smoke'],
		['--headless=layout-tree'],
		['--restore-tab', '/tmp/tab.json'],
	] {
		options := parse_launch_options(arguments)!
		assert !browser_window_state_enabled(options, arguments)
	}
}

fn test_saved_window_schema_rejects_malformed_types_and_geometry() {
	valid := '{"version":1,"normalFrame":"{{100, 80}, {800, 600}}","maximized":false,"fullscreen":true}'
	saved := decode_browser_window_state(valid)?
	assert saved.fullscreen && !saved.maximized
	assert saved_browser_window_frame(saved.normal_frame)?.width == 800
	for malformed in ['invalid', '{}', valid.replace('"version":1', '"version":2'),
		valid.replace('"maximized":false', '"maximized":[]'),
		valid.replace('"fullscreen":true', '"fullscreen":"true"')] {
		assert decode_browser_window_state(malformed) == none
	}
	for frame in ['{{NaN, 0}, {800, 600}}', '{{0, 0}, {inf, 600}}', '{{bad, 0}, {800, 600}}',
		'{{0, 0}, {0, 600}}', '1,2,3'] {
		assert saved_browser_window_frame(frame) == none
	}
}

fn test_window_state_restores_and_persists_legacy_plist_through_the_v_owner() {
	$if vox_ui2 ? {
		path := os.join_path(os.temp_dir(), 'vox-ui2-window-${os.getpid()}-${time.sys_mono_now()}', 'window-state.plist')
		os.mkdir_all(os.dir(path))!
		window := C.native_test_address_window()
		mut owner := unsafe { browser_window_owner }
		owner.path = path
		owner.state = browserui.WindowState{}
		defer {
			finish_browser_window_state()
			owner.path = ''
			C.native_test_address_close(window)
			os.rmdir_all(os.dir(path)) or {}
		}
		encoded := json2.encode(SavedBrowserWindow{ version: 1, normal_frame: '{{100, 100}, {720, 520}}' })
		assert C.native_host_write_plist(path.str, encoded.str, i32(encoded.len)) != 0
		restore_browser_window_state(window)
		mut values := [6]f64{}
		mut flags := [3]i32{}
		C.native_window_snapshot(window, &values[0], &flags[0])
		assert values[2] == 720 && values[3] == 520
		C.native_window_set_frame(window, values[0], values[1], 760, 540)
		C.native_window_snapshot(window, &values[0], &flags[0])
		browser_window_event(owner, 0, &values[0], &flags[0])
		finish_browser_window_state()
		raw := C.native_host_read_plist(path.str)
		assert raw != unsafe { nil }
		saved := decode_browser_window_state(unsafe { cstring_to_vstring(raw) })?
		C.free(raw)
		frame := saved_browser_window_frame(saved.normal_frame)?
		assert frame.width == 760 && frame.height == 540
		assert !saved.fullscreen && !saved.maximized
	}
}
