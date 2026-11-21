// vtest build: macos
module main

import layout
import math

fn test_glyph_rectangle_clips_intersect_in_document_space_before_aa_rasterization() {
	clip := layout.PaintClip{rect: layout.LayoutRect{10.25, 20.5, 40.5, 30},
		transform: [f64(0.5), 0, 0, 0.5, 10, 5]!}
	other := layout.PaintClip{rect: layout.LayoutRect{17.5, 0, 100, 100}}
	bounds := chromium_glyph_clip_bounds([clip, other, clip]) or { panic('missing rectangular clip') }
	assert bounds == [f32(17.5), 15.25, 35.375, 30.25]!
	empty := chromium_glyph_clip_bounds([clip,
		layout.PaintClip{rect: layout.LayoutRect{100, 100, 10, 10}}]) or { panic('missing empty intersection') }
	assert empty == [f32(0), 0, 0, 0]!
	assert chromium_glyph_clip_bounds([]) == none
	for unsupported in [
		layout.PaintClip{...clip, is_path: true},
		layout.PaintClip{...clip, is_svg_mask: true},
		layout.PaintClip{...clip, is_svg_content_mask: true},
		layout.PaintClip{...clip, corner_radii: layout.BoxRadii{top_left: layout.CornerRadius{1, 1}}},
		layout.PaintClip{...clip, transform: [f64(1), 0.1, 0, 1, 0, 0]!},
		layout.PaintClip{...clip, transform: [f64(-1), 0, 0, 1, 0, 0]!},
	] {
		assert chromium_glyph_clip_bounds([unsupported]) == none
		mixed := chromium_glyph_clip_bounds([clip, unsupported]) or { panic('missing ordinary clip') }
		assert mixed == [f32(15.125), 15.25, 35.375, 30.25]!
	}
}

fn test_glyph_rectangle_clip_device_bounds_apply_page_scroll_and_raster_scale_once() {
	geometry := [i32(10), 20, 80, 60, 1, 80, 60]!
	clip := document_glyph_device_clip([f32(17.5), 15.25, 35.375, 30.25]!,
		geometry, 2, 0.5, 3, 7, 2)
	assert clip == [f32(21), 0.125, 56.75, 7.625]!
}

fn test_clipped_glyph_edges_preserve_only_fully_covered_pixel_squares() {
	mut pixels := []u8{len: 6 * 4 * 4, init: 10}
	clipped := []u8{len: pixels.len, init: 50}
	assert merge_clipped_glyph_edges(mut pixels, clipped, 6, 4, [f32(1.5), 0.5, 4.5, 2.5]!)
	for y in 0 .. 4 {
		for x in 0 .. 6 {
			expected := if y == 1 && x in [2, 3] { u8(10) } else { u8(50) }
			for channel in 0 .. 4 { assert pixels[(y * 6 + x) * 4 + channel] == expected }
		}
	}
	mut unchanged := []u8{len: 16, init: 25}
	assert merge_clipped_glyph_edges(mut unchanged, []u8{len: 16, init: 90}, 2, 2, [f32(-1), -1, 3, 3]!)
	assert unchanged == []u8{len: 16, init: 25}
}

// A clip whose edges cross no glyph coverage leaves the merge nothing to take
// from the clipped draw, so such a run skips the GPU draw; coverage on a
// pixel the clip does not fully cover keeps it.
fn test_clip_edges_without_glyph_coverage_need_no_clipped_draw() {
	blank := []u8{len: 6 * 4}
	mut inner := []u8{len: 6 * 4}
	inner[1 * 6 + 2] = 200
	inner[2 * 6 + 3] = 9
	for clip in [[f32(0), 0, 6, 4]!, [f32(-3), -0.5, 6.25, 9]!, [f32(1.5), 0.5, 4.5, 3]!] {
		assert document_glyph_clip_edges_are_blank(clip, blank, 6, 4)
		assert document_glyph_clip_edges_are_blank(clip, inner, 6, 4)
		mut pixels := []u8{len: 6 * 4 * 4, init: 10}
		mut clipped := []u8{len: pixels.len, init: 10}
		// The clipped draw changes only covered pixels; blank edges keep the backdrop.
		for index, coverage in inner {
			if coverage != 0 { clipped[index * 4] = 77 }
		}
		pixels[(1 * 6 + 2) * 4] = 99
		pixels[(2 * 6 + 3) * 4] = 99
		expected := pixels.clone()
		assert merge_clipped_glyph_edges(mut pixels, clipped, 6, 4, clip)
		assert pixels == expected
	}
	mut edge := inner.clone()
	edge[0] = 1
	assert !document_glyph_clip_edges_are_blank([f32(1.5), 0.5, 4.5, 3]!, edge, 6, 4)
	assert document_glyph_clip_edges_are_blank([f32(0), 0, 6, 4]!, edge, 6, 4)
	// The interior pixel (3, 2) is not fully covered by a clip ending at 3.5.
	assert !document_glyph_clip_edges_are_blank([f32(1.5), 0.5, 3.5, 3]!, inner, 6, 4)
	for clip in [[f32(0), 0, f32(math.inf(1)), 4]!, [f32(0), f32(math.nan()), 6, 4]!] {
		assert !document_glyph_clip_edges_are_blank(clip, blank, 6, 4)
	}
	assert !document_glyph_clip_edges_are_blank([f32(0), 0, 6, 4]!, []u8{len: 5}, 6, 4)
}
