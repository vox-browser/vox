module main

import layout
import math

fn C.native_begin_scroll_raster(u64, u64, f64, f64, f64, f64, int, &f64) int
fn C.native_end_scroll_raster()
fn C.native_discard_scroll_raster()

struct ScrollRasterDamage {
mut:
	reused              bool
	separate_scrollbars bool
	delta               f64
	width               f64
	height              f64
}

fn (app &BrowserApp) begin_scroll_raster() ScrollRasterDamage {
	mut damage := ScrollRasterDamage{ width: app.viewport_width, height: app.viewport_height }
	$if macos {
		viewport := app.document.viewport_rect()
		// Shared SVG pictures finish after the font layer; their deferred
		// pixels must not be captured before that layer has been published.
		eligible := app.page_zoom == 1 && !app.paint_canvas_culling_disabled
			&& viewport.x == 0 && viewport.y == app.scroll_y
			&& !chromium_shared_recording_supported(app.paint_commands, app.chromium_raster_plan)
			&& layout.viewport_scroll_raster_reusable(app.document, app.paint_commands,
				damage.width, damage.height)
		damage.separate_scrollbars = eligible
		damage.reused = C.native_begin_scroll_raster(u64(app.document.unique_id().value()),
			app.document.paint_content_revision(), app.scroll_y, app.page_top(),
			damage.width, damage.height, int(eligible), &damage.delta) != 0
	}
	return damage
}

fn (damage &ScrollRasterDamage) skips(command &layout.PaintCommand) bool {
	if !damage.reused { return false }
	// Checkbox fills can defer their pixels to the following border draw.
	// Keep both operations so culling cannot pair an underlay with a later box.
	if command.underlays_next || command.kind == 'stroke_rounded_rect' { return false }
	// Replaced images resolve their destination from a separate paintable;
	// background tiles resolve it from their origin and clip. Let the native
	// image renderer test its final bounds against the damage clip.
	if command.kind in ['draw_replaced_image', 'draw_background_image'] { return false }
	if damage.delta == 0 { return true }
	top := if damage.delta < 0 {
		0.0
	} else {
		damage.height - math.min(damage.height, damage.delta)
	}
	return layout.paint_leaf_is_outside_canvas(command, 0, -top,
		damage.width, math.min(damage.height, math.abs(damage.delta)))
}

fn (mut app BrowserApp) draw_scroll_raster_scrollbars(page_y f32, window_height int) {
	for index, command in app.paint_commands {
		if command.scrollbar_axis == '' { continue }
		if index < app.chromium_raster_plan.command_layers.len {
			app.select_chromium_raster_layer(app.chromium_raster_plan.command_layers[index])
		}
		app.draw_command(command, 0, page_y, window_height)
	}
}
