module main

import layout
import math
import os

fn C.native_begin_scroll_raster(u64, u64, f64, f64, f64, f64, int, &f64, &f64, int, int) int
fn C.native_end_scroll_raster()
fn C.native_discard_scroll_raster()
fn C.native_set_scroll_damage_rects(rects &f32, count i32)

struct ScrollRasterDamage {
mut:
	reused              bool
	separate_scrollbars bool
	delta               f64
	width               f64
	height              f64
	unoptimized         bool
	// Viewport-space rectangles beyond the exposed strip whose content changed
	// since the retained frame; they are clipped and repainted with the strip.
	rects []layout.LayoutRect
	// Per-command replay decision for the current command list, when reused.
	skip_plan []bool
	// First command of the trailing viewport scrollbar run, replayed after
	// the ring stores the document pixels. Nested bars before it are content.
	scrollbar_start int
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
		damage.scrollbar_start = scroll_raster_scrollbar_start(app.paint_commands)
		$if vox_scroll_raster_diagnostics ? {
			marker := os.getenv('VOX_SCROLL_RASTER_INPUT_MARKER')
			input := marker != '' && os.exists(marker)
			eprintln('VOX_SCROLL_RASTER_GATE input=${input} eligible=${eligible} zoom=${app.page_zoom} culling_disabled=${app.paint_canvas_culling_disabled} viewport=${viewport.x},${viewport.y} scroll=${app.scroll_y} shared=${chromium_shared_recording_supported(app.paint_commands, app.chromium_raster_plan)} commands=${app.paint_commands.len}')
		}
		document_id := u64(app.document.unique_id().value())
		revision := app.document.paint_content_revision()
		// Deferred layer pictures publish their leaf rasters after the ring
		// stores this frame, so a deferred frame can neither store nor reuse.
		// The draw loop disables deferral once content is known eligible.
		ring_eligible := eligible && !app.scroll_raster_frame_deferred
		app.scroll_raster_content_eligible = eligible
		mut keys := []ScrollRasterCommandKey{}
		mut rects := []layout.LayoutRect{}
		// Reuse requires the content diff to reconcile this frame with the
		// retained one: it is the only path that repaints content which does
		// not translate with the viewport, such as fixed or sticky boxes.
		mut allow_reuse := 0
		mut stats := ScrollRasterDiffStats{}
		if ring_eligible {
			keys = scroll_raster_frame_keys(app.paint_commands, app.scroll_y,
				app.overlay_scrollbars.paint_opacity, damage.width, damage.height)
			if disable_scroll_raster_content_damage {
				stats.fallback = 'content-damage-disabled'
			} else if content := scroll_raster_content_damage(&app.scroll_raster_keys, keys,
				document_id, app.scroll_y, damage.width, damage.height, mut stats)
			{
				rects = content.clone()
				allow_reuse = 1
			}
		}
		flat := scroll_raster_flatten_rects(rects)
		flat_data := if flat.len > 0 { unsafe { &f64(flat.data) } } else { unsafe { &f64(nil) } }
		damage.reused = C.native_begin_scroll_raster(document_id, revision, app.scroll_y,
			app.page_top(), damage.width, damage.height, int(ring_eligible), &damage.delta, flat_data,
			rects.len, allow_reuse) != 0
		if damage.reused {
			damage.rects = rects
			mut region := scroll_raster_strip_region(damage.delta, damage.width, damage.height)
			region << rects
			damage.skip_plan = plan_scroll_raster_skips(app.paint_commands, keys, region,
				damage.unoptimized)
			// Leaf rasters crop to the clip rectangles they intersect rather
			// than to the bounding box Quartz reports for all of them.
			canvas_rects := scroll_raster_canvas_rects(region, app.page_top())
			C.native_set_scroll_damage_rects(unsafe { &f32(canvas_rects.data) }, i32(region.len))
		} else {
			C.native_set_scroll_damage_rects(unsafe { nil }, i32(0))
		}
		if scroll_raster_damage_diagnostics && revision != scroll_raster_dumped_revision {
			scroll_raster_dumped_revision = revision
			mut kinds := []string{cap: app.paint_commands.len}
			for index in 0 .. app.paint_commands.len { kinds << app.paint_commands[index].kind }
			eprintln('VOX_SCROLL_RASTER_KINDS revision=${revision} kinds=${kinds.join(',')}')
		}
		if scroll_raster_damage_diagnostics {
			mut skipped := 0
			for value in damage.skip_plan {
				if value { skipped++ }
			}
			eprintln('VOX_SCROLL_RASTER_DAMAGE eligible=${eligible} deferred=${app.scroll_raster_frame_deferred} reused=${damage.reused} revision=${revision} previous_valid=${app.scroll_raster_keys.valid} delta=${damage.delta} changed=${stats.changed} rects=${rects.len} skipped=${skipped}/${app.paint_commands.len} fallback=${stats.fallback}')
		}
		// Retain this frame's identities only when its pixels enter the ring:
		// a frame that paints without eligibility leaves no reusable pixels.
		if ring_eligible {
			app.scroll_raster_keys = ScrollRasterKeyFrame{
				valid:    true
				document: document_id
				scroll:   app.scroll_y
				width:    damage.width
				height:   damage.height
				keys:     keys
			}
		} else {
			app.scroll_raster_keys.valid = false
		}
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
	if damage.rects.len > 0 {
		if ink := layout.scroll_raster_leaf_ink_bounds(command) {
			if scroll_raster_ink_touches(ink, damage.rects) { return false }
		} else {
			return false
		}
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

// Replay decision for one command index of a reused frame: the group-aware
// plan when it exists for this command list, otherwise the strip test.
fn (damage &ScrollRasterDamage) skips_index(commands []layout.PaintCommand, index int) bool {
	if !damage.reused { return false }
	if damage.skip_plan.len == commands.len { return damage.skip_plan[index] }
	return damage.skips(&commands[index])
}

// Raster eligibility defers only the trailing viewport scrollbars. Find that
// suffix without walking the document commands again after painting it.
// Viewport rectangles as x, y, width, height in top-left canvas points.
fn scroll_raster_canvas_rects(region []layout.LayoutRect, page_top f64) []f32 {
	mut values := []f32{cap: region.len * 4}
	for rect in region {
		values << f32(rect.x)
		values << f32(page_top + rect.y)
		values << f32(rect.width)
		values << f32(rect.height)
	}
	return values
}

fn scroll_raster_scrollbar_start(commands []layout.PaintCommand) int {
	return layout.scroll_raster_trailing_scrollbar_start(commands)
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
