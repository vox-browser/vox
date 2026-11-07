module main

import browserui
import browsersettings
import json2
import os
import platform
import strconv

$if macos {
	#include "@VMODROOT/native_browser_window_state_darwin.m"
	fn C.native_window_snapshot(voidptr, &f64, &i32)
	fn C.native_window_screens(&f64, i32) i32
	fn C.native_window_screen_index(voidptr) i32
	fn C.native_window_set_frame(voidptr, f64, f64, f64, f64)
	fn C.native_window_action(voidptr, i32)
	fn C.native_host_read_plist(&char) &char
	fn C.native_host_write_plist(&char, &u8, i32) i32
	fn C.native_window_observe(voidptr, voidptr, fn (voidptr, i32, &f64, &i32))
	fn C.native_window_stop_observing()
	fn C.native_window_register_indexing_default()
	fn C.free(voidptr)
}

struct SavedBrowserWindow {
	version      int
	normal_frame string @[json: 'normalFrame']
	maximized    bool
	fullscreen   bool
}

fn decode_browser_window_state(encoded string) ?SavedBrowserWindow {
	fields := json2.decode[map[string]json2.Any](encoded) or { return none }
	version := fields['version'] or { return none }
	frame := fields['normalFrame'] or { return none }
	maximized := fields['maximized'] or { return none }
	fullscreen := fields['fullscreen'] or { return none }
	if version !is i64 && version !is int && version !is f64 { return none }
	if version.f64() != 1 || frame !is string || maximized !is bool || fullscreen !is bool {
		return none
	}
	return SavedBrowserWindow{ version: 1, normal_frame: frame.str(), maximized: maximized.bool(), fullscreen: fullscreen.bool() }
}

fn saved_browser_window_frame(encoded string) ?browserui.Frame {
	parts := encoded.replace('{', '').replace('}', '').replace(' ', '').split(',')
	if parts.len != 4 { return none }
	frame := browserui.Frame{
		x:      strconv.atof64(parts[0]) or { return none }
		y:      strconv.atof64(parts[1]) or { return none }
		width:  strconv.atof64(parts[2]) or { return none }
		height: strconv.atof64(parts[3]) or { return none }
	}
	if !frame.valid() { return none }
	return frame
}

struct BrowserWindowOwner {
mut:
	path   string
	window voidptr
	state  browserui.WindowState
}

const browser_window_owner = &BrowserWindowOwner{}

fn browser_window_state_enabled(options LaunchOptions, arguments []string) bool {
	if options.screenshot != '' || options.headless_smoke || options.headless_layout_tree || options.restore_tab != '' {
		return false
	}
	for argument in arguments {
		if argument in ['--window-width', '--window-height'] || argument.starts_with('--window-width=') || argument.starts_with('--window-height=') {
			return false
		}
	}
	return true
}

fn prepare_browser_window_state(options LaunchOptions) {
	if !browser_window_state_enabled(options, os.args[1..]) { return }
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut owner := unsafe { browser_window_owner }
	owner.path = os.join_path(os.dir(browsersettings.default_path()), 'window-state.plist')
}

fn browser_window_displays() []browserui.Frame {
	mut result := []browserui.Frame{}
	$if macos {
		mut values := [64]f64{}
		count := int(C.native_window_screens(&values[0], 16))
		for i in 0 .. count {
			result << browserui.Frame{ x: values[i * 4], y: values[i * 4 + 1], width: values[i * 4 + 2], height: values[i * 4 + 3] }
		}
	}
	return result
}

fn browser_window_frame(values &f64) browserui.Frame {
	unsafe {
		return browserui.Frame{ x: values[0], y: values[1], width: values[2], height: values[3] }
	}
}

fn restore_browser_window_state(window voidptr) {
	$if macos {
		mut owner := unsafe { browser_window_owner }
		if owner.path == '' || owner.window != unsafe { nil } { return }
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		owner.window = window
		owner.state.restoring = true
		mut restore_fullscreen := false
		mut values := [6]f64{}
		mut flags := [3]i32{}
		C.native_window_snapshot(window, &values[0], &flags[0])
		owner.state.normal = browser_window_frame(&values[0])
		raw := C.native_host_read_plist(owner.path.str)
		if raw != unsafe { nil } {
			encoded := unsafe { cstring_to_vstring(raw) }
			C.free(raw)
			if saved := decode_browser_window_state(encoded) {
				if frame := saved_browser_window_frame(saved.normal_frame) {
					visible := browserui.visible_frame(frame, browser_window_displays(), int(C.native_window_screen_index(window)), values[4], values[5], os.getenv('VOX_TEST_WINDOW') == '1')
					C.native_window_set_frame(window, visible.x, visible.y, visible.width, visible.height)
					owner.state.normal = visible
					if saved.maximized {
						C.native_window_action(window, 0)
						owner.state.maximized = true
					}
					restore_fullscreen = saved.fullscreen
				}
			}
		}
		owner.state.restoring = false
		C.native_window_observe(window, owner, browser_window_event)
		if restore_fullscreen { C.native_window_action(window, 1) }
	}
}

fn browser_window_event(context voidptr, kind i32, values &f64, flags &i32) {
	$if macos {
		mut owner := unsafe { &BrowserWindowOwner(context) }
		if !owner.state.update(int(kind), browser_window_frame(values), unsafe { flags[0] != 0 }, unsafe { flags[2] != 0 }) {
			return
		}
		scratch := platform.begin_thread_scratch('window state serialization')
		defer { scratch.finish() }
		frame := owner.state.normal
		saved := SavedBrowserWindow{ version: 1, normal_frame: '{{${frame.x}, ${frame.y}}, {${frame.width}, ${frame.height}}}', maximized: owner.state.maximized, fullscreen: owner.state.fullscreen }
		os.mkdir_all(os.dir(owner.path)) or { return }
		// Struct encoding caches field metadata on first use. A move can be
		// that first use, so keep every allocation local to this scratch scope
		// by encoding JSON values without publishing a struct metadata cache.
		encoded := json2.encode(map[string]json2.Any{
			'version':     json2.Any(saved.version)
			'normalFrame': json2.Any(saved.normal_frame)
			'maximized':   json2.Any(saved.maximized)
			'fullscreen':  json2.Any(saved.fullscreen)
		})
		C.native_host_write_plist(owner.path.str, encoded.str, i32(encoded.len))
	}
}

fn finish_browser_window_state() {
	$if macos {
		mut owner := unsafe { browser_window_owner }
		if owner.window != unsafe { nil } {
			mut values := [6]f64{}
			mut flags := [3]i32{}
			C.native_window_snapshot(owner.window, &values[0], &flags[0])
			browser_window_event(owner, 5, &values[0], &flags[0])
		}
		C.native_window_stop_observing()
		owner.window = unsafe { nil }
	}
}
