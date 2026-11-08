module main

import browserui
import json2
import os
import platform
import time

$if macos {
	import browserwindow
}

$if vox_ui2 ? {
	#include "@VMODROOT/native/include/native_address_bar_test_darwin.h"
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

fn test_window_movement_saves_survive_first_use_and_scratch_reuse() {
	$if vox_ui2 ? {
		// Keep this before any SavedBrowserWindow struct encoding: warming its
		// process-wide JSON metadata would hide the production first-move bug.
		path := os.join_path(os.temp_dir(), 'vox-ui2-moves-${os.getpid()}-${time.sys_mono_now()}', 'window-state.plist')
		mut owner := BrowserWindowOwner{ path: path }
		defer { os.rmdir_all(os.dir(path)) or {} }
		mut moved := browserwindow.Snapshot{}
		for i in 0 .. 24 {
			moved = browserwindow.Snapshot{
				frame: browserwindow.Frame{ x: 100 + f64(i), y: 100 + f64(i % 3), width: 760, height: 540 }
			}
			// Deliver normal-window geometry through the notification callback,
			// then reuse the retired workspace before the next move.
			browser_window_event(&owner, browserwindow.event_changed, moved)
			reuse := platform.begin_thread_scratch('reuse window state serialization')
			_ = []u8{len: 128 * 1024, init: 0xa5}
			reuse.finish()
			encoded := browserwindow.read_plist_json(path) or { panic('move ${i}: no saved state') }
			saved := decode_browser_window_state(encoded)?
			frame := saved_browser_window_frame(saved.normal_frame)?
			assert frame.x == moved.frame.x && frame.y == moved.frame.y, 'move ${i}: saved=${saved.normal_frame}, native=(${moved.frame.x}, ${moved.frame.y})'
			assert frame.width == moved.frame.width && frame.height == moved.frame.height
			assert !saved.maximized && !saved.fullscreen
		}
		browser_window_event(&owner, browserwindow.event_closing, moved)
		assert os.is_file(path)
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
		assert browserwindow.write_plist_json(path, encoded)
		restore_browser_window_state(window)
		restored := browserwindow.snapshot(window).frame
		assert restored.width == 720 && restored.height == 520
		browserwindow.set_frame(window, browserwindow.Frame{ x: restored.x, y: restored.y, width: 760, height: 540 })
		browser_window_event(owner, browserwindow.event_changed, browserwindow.snapshot(window))
		finish_browser_window_state()
		saved := decode_browser_window_state(browserwindow.read_plist_json(path) or { panic('no saved state') })?
		frame := saved_browser_window_frame(saved.normal_frame)?
		assert frame.width == 760 && frame.height == 540
		assert !saved.fullscreen && !saved.maximized
	}
}
