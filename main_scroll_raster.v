module main

import layout
import math
import os

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
	unoptimized         bool
	page_switch         bool
	page_damage         []layout.LayoutRect
}

fn (mut app BrowserApp) begin_scroll_raster() ScrollRasterDamage {
	mut damage := ScrollRasterDamage{
		width:       app.viewport_width
		height:      app.viewport_height
		unoptimized: os.getenv('VOX_DISABLE_SCROLL_RASTER_DAMAGE_OPTIMIZATIONS') != ''
	}
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
		if app.fast_page_switch.to != '' && os.getenv('VOX_PAGE_SWITCH_DIAGNOSTICS') == '1' {
			eprintln('VOX_PAGE_SWITCH_GATE eligible=${eligible} zoom=${app.page_zoom} culling_disabled=${app.paint_canvas_culling_disabled} viewport=${viewport.x},${viewport.y} scroll=${app.scroll_y} shared=${chromium_shared_recording_supported(app.paint_commands, app.chromium_raster_plan)} commands=${app.paint_commands.len}')
		}
		$if vox_scroll_raster_diagnostics ? {
			marker := os.getenv('VOX_SCROLL_RASTER_INPUT_MARKER')
			input := marker != '' && os.exists(marker)
			eprintln('VOX_SCROLL_RASTER_GATE input=${input} eligible=${eligible} zoom=${app.page_zoom} culling_disabled=${app.paint_canvas_culling_disabled} viewport=${viewport.x},${viewport.y} scroll=${app.scroll_y} shared=${chromium_shared_recording_supported(app.paint_commands, app.chromium_raster_plan)} commands=${app.paint_commands.len}')
		}
		if rects := app.begin_fast_page_switch(eligible) {
			damage.reused = true
			damage.page_switch = true
			damage.page_damage = rects
			return damage
		}
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
	// Use retained image/clip geometry below, before decoding or uploading an
	// image whose pixels already came from the scroll cache.
	if damage.unoptimized && command.kind in ['draw_replaced_image', 'draw_background_image'] {
		return false
	}
	if damage.page_switch {
		for rect in damage.page_damage {
			if !layout.paint_leaf_is_outside_canvas(command, -rect.x, -rect.y, rect.width, rect.height) {
				return false
			}
		}
		return true
	}
	if damage.delta == 0 { return true }
	top := if damage.delta < 0 {
		0.0
	} else {
		damage.height - math.min(damage.height, damage.delta)
	}
	return layout.paint_leaf_is_outside_canvas(command, 0, -top,
		damage.width, math.min(damage.height, math.abs(damage.delta)))
}

// Raster eligibility permits only trailing viewport scrollbars. Find that
// suffix without walking the document commands again after painting it.
fn scroll_raster_scrollbar_start(commands []layout.PaintCommand) int {
	mut start := commands.len
	for start > 0 && commands[start - 1].scrollbar_axis != '' {
		start--
	}
	return start
}

fn (mut app BrowserApp) draw_scroll_raster_scrollbars(page_y f32, window_height int) {
	start := if os.getenv('VOX_DISABLE_SCROLLBAR_TAIL_REPLAY') != '' {
		0
	} else {
		scroll_raster_scrollbar_start(app.paint_commands)
	}
	for index in start .. app.paint_commands.len {
		command := app.paint_commands[index]
		if command.scrollbar_axis == '' { continue }
		if index < app.chromium_raster_plan.command_layers.len {
			app.select_chromium_raster_layer(app.chromium_raster_plan.command_layers[index])
		}
		app.draw_command(command, 0, page_y, window_height)
	}
}
