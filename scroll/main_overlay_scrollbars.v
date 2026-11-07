module main

import time

fn C.native_prefers_overlay_scrollbars() int

const overlay_scrollbar_hold_ns = i64(600_000_000)
const overlay_scrollbar_fade_ns = i64(300_000_000)

struct BrowserOverlayScrollbars {
mut:
	enabled          bool
	active           bool
	hovered          bool
	dragging         bool
	last_activity_ns i64
	paint_opacity    f64 = 1
}

fn (mut bars BrowserOverlayScrollbars) activity(now_ns i64) {
	bars.active = true
	bars.last_activity_ns = now_ns
}

fn (bars &BrowserOverlayScrollbars) opacity_at(now_ns i64) f64 {
	if !bars.enabled { return 1 }
	if bars.hovered || bars.dragging { return 1 }
	if !bars.active { return 0 }
	elapsed := now_ns - bars.last_activity_ns
	if elapsed <= overlay_scrollbar_hold_ns { return 1 }
	if elapsed >= overlay_scrollbar_hold_ns + overlay_scrollbar_fade_ns { return 0 }
	return 1 - f64(elapsed - overlay_scrollbar_hold_ns) / f64(overlay_scrollbar_fade_ns)
}

fn (mut app BrowserApp) overlay_scrollbar_activity() {
	if !app.overlay_scrollbars.enabled { return }
	app.overlay_scrollbars.activity(time.sys_mono_now())
	$if macos {
		if app.ctx != unsafe { nil } && app.ctx.native_rendering {
			C.native_wake_browser_after(600)
		}
	}
}

fn (mut app BrowserApp) prepare_overlay_scrollbars() {
	mut enabled := false
	$if macos {
		enabled = app.document != unsafe { nil }
			&& app.document.font_rendering_policy() == .chromium
			&& C.native_prefers_overlay_scrollbars() != 0
	}
	app.overlay_scrollbars.enabled = enabled
	app.overlay_scrollbars.paint_opacity = app.overlay_scrollbars.opacity_at(time.sys_mono_now())
	// Match the isolated Chromium reference capture's hidden scrollbars. A
	// background screenshot window can still receive incidental hover events.
	if enabled && app.screenshot_path != '' {
		app.overlay_scrollbars.paint_opacity = 0
		return
	}
	if enabled && app.overlay_scrollbars.paint_opacity > 0 && !app.overlay_scrollbars.hovered
		&& !app.overlay_scrollbars.dragging
		&& time.sys_mono_now() - app.overlay_scrollbars.last_activity_ns >= overlay_scrollbar_hold_ns {
		$if macos {
			if app.ctx != unsafe { nil } && app.ctx.native_rendering {
				// Continue the fade through its final completely hidden frame.
				C.native_wake_browser_after(16)
			}
		}
	}
}
