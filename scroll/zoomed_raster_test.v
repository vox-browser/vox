module main

import dom
import html
import layout
import math
import painting

// Page zoom keeps the recorded commands in CSS pixels and projects them at
// replay. Scroll reuse keys them in that same CSS space and scales only the
// rectangles it hands to the native ring.
fn test_zoomed_scroll_raster_uses_css_viewport_space() {
	unzoomed := scroll_raster_css_space(70.5, 1701, 948, 1)
	assert unzoomed.scroll == 70.5 && unzoomed.width == 1701 && unzoomed.height == 948
	zoomed := scroll_raster_css_space(70.5, 1701, 948, 1.75)
	// The document viewport origin is set with the same division.
	assert zoomed.scroll == 70.5 / 1.75
	assert zoomed.width == 1701 / 1.75
	assert zoomed.height == 948 / 1.75
}

fn test_zoomed_scroll_raster_widens_rects_to_whole_view_pixels() {
	rects := [layout.LayoutRect{10, 20.5, 30, 40}, layout.LayoutRect{0, 0, 972, 4}]
	// Without zoom the rectangles pass through untouched.
	assert scroll_raster_view_rects(rects, 1) == rects
	scaled := scroll_raster_view_rects(rects, 1.75)
	// 17.5..70 x 35.875..105.875 widens outward to whole view pixels.
	assert scaled[0] == layout.LayoutRect{17, 35, 53, 71}
	assert scaled[1] == layout.LayoutRect{0, 0, 1701, 7}
	for rect in scaled {
		for value in [rect.x, rect.y, rect.width, rect.height] {
			assert value == f64(i64(value))
		}
	}
}

fn zoomed_raster_affine(left [6]f64, right [6]f64) [6]f64 {
	return [left[0] * right[0] + left[2] * right[1], left[1] * right[0] + left[3] * right[1],
		left[0] * right[2] + left[2] * right[3], left[1] * right[2] + left[3] * right[3],
		left[0] * right[4] + left[2] * right[5] + left[4],
		left[1] * right[4] + left[3] * right[5] + left[5]]!
}

// The recorded offset rounds through f32 exactly as the scroll state snapshot
// does; without zoom it is the viewport scroll itself.
fn test_recorded_viewport_scroll_matches_the_scroll_state_snapshot() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	for view_scroll in [0.0, 2, 4, 70.5, 140, 1234.5, 17320, 29998] {
		for zoom in [1.0, 1.75, 1.1, 0.9] {
			css := view_scroll / zoom
			document.set_viewport_rect(dom.Rect{0, css, 972, 542})
			mut frame := painting.ScrollFrame{}
			frame.set_own_offset(painting.Point{0, -document.layout_viewport_rect().y})
			snapshot := painting.ScrollStateSnapshot.create([frame], 1.0)
			recorded := layout.scroll_raster_recorded_viewport_scroll(document)
			assert recorded == -snapshot.device_offset_for_index(0).y / 2
			if zoom == 1 {
				assert recorded == view_scroll
			}
		}
	}
}

// Wheel scrolling moves the view by whole device pixels, so a zoomed CSS
// offset is a fractional quotient whose recorded translation keeps an f32
// rounding. Keys that remove that recorded offset identify unchanged content
// on every frame, including a box transformed about its own origin (Old
// Reddit's sidebar flag dots use scale(0.33)), whose translation is not a
// round number.
fn test_zoomed_scroll_raster_keys_match_across_fractional_css_offsets() {
	mut document := html.parse_document('<!doctype html><div></div>')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	zoom := 1.75
	// Commands are in layout (device) pixels under the root 1/2 scale.
	base := [
		layout.PaintCommand{ kind: 'fill_rect', x: 60, y: 120, width: 40, height: 40, color: 'red' },
		layout.PaintCommand{ kind: 'draw_text', x: 24.5, y: 75, width: 160, height: 28, text: 'comment',
			color: 'black' },
		layout.PaintCommand{ kind: 'fill_rect', x: 0, y: 600, width: 800, height: 4, color: 'gray',
			has_clip: true, clip_x: 0, clip_y: 0, clip_width: 400, clip_height: 500 },
		layout.PaintCommand{ kind: 'fill_gradient', x: 2, y: 2, width: 30, height: 30, color: 'blue',
			radius: 15 },
	]
	flag := zoomed_raster_affine(zoomed_raster_affine([f64(1), 0, 0, 1, 1711.25, 883.75]!,
		[f64(0.33), 0, 0, 0.33, 0, 0]!), [f64(1), 0, 0, 1, -17.0, -17.0]!)
	// Two view pixels are 8/7 CSS pixels: almost no offset is exact in f32,
	// the rounding changes sign from frame to frame, and deep in the document
	// it far exceeds the 1/1024 quantization of every hashed coordinate.
	mut view_scroll := 0.0
	mut previous_keys, mut previous_scroll := zoomed_raster_frame(mut document, base, flag,
		view_scroll, zoom)
	for view_scroll < 30000 {
		view_scroll += 2
		keys, scroll := zoomed_raster_frame(mut document, base, flag, view_scroll, zoom)
		css := scroll_raster_css_space(view_scroll, 1701, 948, zoom)
		previous := ScrollRasterKeyFrame{
			valid:    true
			document: 7
			scroll:   previous_scroll
			width:    css.width
			height:   css.height
			keys:     previous_keys
		}
		mut stats := ScrollRasterDiffStats{}
		rects := scroll_raster_content_damage(&previous, keys, 7, scroll, css.width, css.height, mut
			stats) or { panic('unchanged zoomed frames must reconcile at ${view_scroll}: ${stats.fallback}') }
		assert stats.changed == 0, 'changed at ${view_scroll}'
		assert rects.len == 0
		previous_keys = keys.clone()
		previous_scroll = scroll
	}
}

// One frame's keys as the recorder produces them: the snapshot's f32 offset
// composed under the root 1/2 layout scale, the flag dot's own transform
// inside it, and accumulated clips in viewport space.
fn zoomed_raster_frame(mut document dom.Document, base []layout.PaintCommand, flag [6]f64,
	view_scroll f64, zoom f64) ([]ScrollRasterCommandKey, f64) {
	css := scroll_raster_css_space(view_scroll, 1701, 948, zoom)
	document.set_viewport_rect(dom.Rect{0, css.scroll, css.width, css.height})
	offset := f64(f32(-document.layout_viewport_rect().y) * f32(1.0))
	scrolled := zoomed_raster_affine([f64(0.5), 0, 0, 0.5, 0, 0]!, [f64(1), 0, 0, 1, 0, offset]!)
	mut commands := []layout.PaintCommand{}
	for command in base {
		transform := if command.kind == 'fill_gradient' {
			zoomed_raster_affine(scrolled, flag)
		} else {
			scrolled
		}
		commands << layout.PaintCommand{
			...command
			transform: transform
			clip_y:    command.clip_y + offset / 2
		}
	}
	scroll := layout.scroll_raster_recorded_viewport_scroll(document)
	return scroll_raster_frame_keys(commands, scroll, 1, css.width, css.height), scroll
}

// Content that genuinely moves still damages, without zoom and with it.
fn test_scroll_raster_keys_still_detect_subpixel_moves() {
	base := layout.PaintCommand{ kind: 'fill_rect', x: 30, y: 60, width: 20, height: 20, color: 'red' }
	at := fn [base] (scroll f64, shift f64) u64 {
		return scroll_raster_frame_keys([layout.PaintCommand{ ...base, transform: [f64(1), 0, 0, 1, 0,
			shift - scroll]! }], scroll, 1, 1024, 768)[0].hash
	}
	assert at(10.5, 0) == at(70, 0)
	assert at(10.5, 1.0 / 256) != at(70, 0)
	assert at(70.5 / 1.75, 1.0 / 256) != at(70.5 / 1.75, 0)
}

// A complete zoomed repaint rasterizes directly: its fractional rectangle
// edges would bounce the whole viewport between the GPU canvas and the CPU.
fn test_zoomed_scroll_raster_uses_gpu_canvas_only_for_reused_strips() {
	assert ScrollRasterDamage{}.gpu_canvas_permitted(1)
	assert ScrollRasterDamage{ reused: true }.gpu_canvas_permitted(1)
	assert ScrollRasterDamage{ reused: true }.gpu_canvas_permitted(1.75)
	assert !ScrollRasterDamage{}.gpu_canvas_permitted(1.75)
	assert !ScrollRasterDamage{}.gpu_canvas_permitted(0.9)
}

fn test_scroll_raster_keys_hash_negative_and_positive_zero_alike() {
	negative := math.copysign(0.0, -1.0)
	assert math.f64_bits(negative) != math.f64_bits(0.0)
	assert srk_f64(7, negative) == srk_f64(7, 0.0)
	// Values that quantize to zero from either side match too.
	assert srk_f64(7, -0.0001) == srk_f64(7, 0.0001)
	assert srk_f64(7, -0.01) != srk_f64(7, 0.0)
}
