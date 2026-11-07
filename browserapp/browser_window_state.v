module main

import browserui
import browsersettings
import json2
import os
import platform
import strconv

$if macos {
	import browserwindow
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
		for screen in browserwindow.screen_frames() {
			result << browser_window_frame(screen)
		}
	}
	return result
}

$if macos {
	fn browser_window_frame(frame browserwindow.Frame) browserui.Frame {
		return browserui.Frame{ x: frame.x, y: frame.y, width: frame.width, height: frame.height }
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
		current := browserwindow.snapshot(window)
		owner.state.normal = browser_window_frame(current.frame)
		if encoded := browserwindow.read_plist_json(owner.path) {
			if saved := decode_browser_window_state(encoded) {
				if frame := saved_browser_window_frame(saved.normal_frame) {
					visible := browserui.visible_frame(frame, browser_window_displays(), browserwindow.screen_index(window), current.min_width, current.min_height, os.getenv('VOX_TEST_WINDOW') == '1')
					browserwindow.set_frame(window, browserwindow.Frame{ x: visible.x, y: visible.y, width: visible.width, height: visible.height })
					owner.state.normal = visible
					if saved.maximized {
						browserwindow.zoom(window)
						owner.state.maximized = true
					}
					restore_fullscreen = saved.fullscreen
				}
			}
		}
		owner.state.restoring = false
		browserwindow.observe(window, owner, browser_window_event)
		if restore_fullscreen { browserwindow.toggle_fullscreen(window) }
	}
}

$if macos {
	fn browser_window_event(context voidptr, kind int, snapshot browserwindow.Snapshot) {
		mut owner := unsafe { &BrowserWindowOwner(context) }
		if !owner.state.update(kind, browser_window_frame(snapshot.frame), snapshot.zoomed, snapshot.miniaturized) {
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
		browserwindow.write_plist_json(owner.path, encoded)
	}
}

fn finish_browser_window_state() {
	$if macos {
		mut owner := unsafe { browser_window_owner }
		if owner.window != unsafe { nil } {
			browser_window_event(owner, browserwindow.event_closing, browserwindow.snapshot(owner.window))
		}
		browserwindow.stop_observing()
		owner.window = unsafe { nil }
	}
}
