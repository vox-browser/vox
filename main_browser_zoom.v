module main

import gg
import layout
import painting

const browser_zoom_levels = [f64(0.25), 0.33, 0.5, 0.67, 0.75, 0.8, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75,
	2.0, 2.5, 3.0, 4.0, 5.0]

fn browser_zoom_shortcut(key gg.KeyCode, modifier gg.Modifier) string {
	if modifier.has(.alt) { return '' }
	$if macos {
		if !modifier.has(.super) || modifier.has(.ctrl) { return '' }
	} $else {
		if !modifier.has(.ctrl) { return '' }
	}
	return match key {
		.equal, .kp_equal, .kp_add { 'zoom-in' }
		.minus, .kp_subtract {
			if modifier.has(.shift) { '' } else { 'zoom-out' }
		}
		._0, .kp_0 {
			if modifier.has(.shift) { '' } else { 'zoom-reset' }
		}
		else { '' }
	}
}

fn (mut app BrowserApp) activate_browser_zoom(action string) {
	mut zoom := app.page_zoom
	if action == 'zoom-reset' {
		zoom = 1
	} else if action == 'zoom-in' {
		for level in browser_zoom_levels {
			if level > zoom {
				zoom = level
				break
			}
		}
	} else if action == 'zoom-out' {
		for index := browser_zoom_levels.len - 1; index >= 0; index-- {
			if browser_zoom_levels[index] < zoom {
				zoom = browser_zoom_levels[index]
				break
			}
		}
	}
	if zoom == app.page_zoom { return }
	// Keep the same document position while changing the screen-pixel scale.
	app.scroll_y *= zoom / app.page_zoom
	app.page_zoom = zoom
	if app.page_model != unsafe { nil } {
		mut client := app.page_model.client()
		client.zoom_level_ = zoom
	}
	$if macos {
		if app.snapshot_visible { C.native_hide_cached_snapshot() }
	}
	app.snapshot_visible = false
	app.snapshot_hold = false
	app.snapshot_hold_until = 0
	app.snapshot_cached = false
	// Layout runs at the next frame boundary, including when a shortcut arrives
	// during navigation. The native field editor retains its text and selection.
	request_browser_frame()
}

// Display lists remain in CSS pixels. Project a copy at the replay boundary,
// including clips and masks, without changing the document's cached commands.
fn (app &BrowserApp) zoomed_paint_command(command layout.PaintCommand) layout.PaintCommand {
	if app.page_zoom == 1 { return command }
	return layout.paint_command_for_nested_viewport(command,
		[app.page_zoom, f64(0), 0, app.page_zoom, 0, 0]!, painting.IntPoint{}, 1)
}
