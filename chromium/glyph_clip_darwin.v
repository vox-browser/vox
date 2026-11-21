module main

import layout
import ggshape
import math
import os

const document_glyph_rectangle_clip = os.getenv('VOX_DIAGNOSTIC_GLYPH_RECTANGLE_CLIP') == '1'
const document_extended_glyph_color = os.getenv('VOX_DIAGNOSTIC_EXTENDED_GLYPH_COLOR') == '1'

fn document_glyph_requires_extended_blend(ink [4]f32) bool {
	return ink[3] == 1 && ink.all(math.is_finite(it))
		&& (ink[0] < 0 || ink[0] > 1 || ink[1] < 0 || ink[1] > 1 || ink[2] < 0 || ink[2] > 1)
}

fn chromium_glyph_rectangle_clip(command &layout.PaintCommand) ?[4]f32 {
	if !document_glyph_rectangle_clip || command.kind != 'draw_text' || !command.has_clip
		|| command.glyph_orientation != .horizontal || command.recording_clip != none
		|| command.clip_list == unsafe { nil } { return none }
	run := command.glyph_run or { return none }
	glyphs := run.glyph_indices()
	if glyphs.len == 0 || run.glyph_positions().len != glyphs.len * 2 { return none }
	return chromium_glyph_clip_bounds(command.clip_list.items)
}

// Axis-aligned rectangles intersect geometrically before their coverage is
// rasterized. Other clips remain active on the native destination.
fn chromium_glyph_clip_bounds(clips []layout.PaintClip) ?[4]f32 {
	if clips.len == 0 { return none }
	mut selected := false
	mut bounds := [f64(0), 0, 0, 0]!
	for clip in clips {
		if !chromium_transferable_glyph_clip(clip) { continue }
		m := normalized_paint_transform(clip.transform)
		r := clip.rect
		b := [m[0] * r.x + m[4], m[3] * r.y + m[5],
			m[0] * (r.x + r.width) + m[4], m[3] * (r.y + r.height) + m[5]]!
		if b.any(!math.is_finite(it) || !math.is_finite(f64(f32(it)))) { return none }
		if !selected {
			bounds = b
			selected = true
		} else {
			bounds[0] = math.max(bounds[0], b[0])
			bounds[1] = math.max(bounds[1], b[1])
			bounds[2] = math.min(bounds[2], b[2])
			bounds[3] = math.min(bounds[3], b[3])
		}
	}
	if !selected { return none }
	if bounds[2] <= bounds[0] || bounds[3] <= bounds[1] { return [f32(0), 0, 0, 0]! }
	return [f32(bounds[0]), f32(bounds[1]), f32(bounds[2]), f32(bounds[3])]!
}

fn chromium_transferable_glyph_clip(clip layout.PaintClip) bool {
	if !chromium_ordinary_rectangle_clip(clip) { return false }
	m := normalized_paint_transform(clip.transform)
	return m[0] > 0 && m[3] > 0 && m[1] == 0 && m[2] == 0
}

fn document_glyph_device_clip(bounds [4]f32, geometry [7]i32,
	scale_x f32, scale_y f32, page_x f32, page_y f32, scroll_y f32) [4]f32 {
	return [(bounds[0] + page_x - f32(geometry[0])) * scale_x,
		(bounds[1] + page_y - scroll_y - f32(geometry[1])) * scale_y,
		(bounds[2] + page_x - f32(geometry[0])) * scale_x,
		(bounds[3] + page_y - scroll_y - f32(geometry[1])) * scale_y]!
}

fn native_restore_document_glyph_clips(command &layout.PaintCommand,
	page_x f32, page_y f32, scroll_y f32, canvas_height f32) {
	for clip in command.clip_list.items {
		if !chromium_transferable_glyph_clip(clip) { continue }
		m := normalized_paint_transform(clip.transform)
		C.native_add_corner_rounded_clip(f32(clip.rect.x), f32(clip.rect.y), f32(clip.rect.width),
			f32(clip.rect.height), 0, 0, 0, 0, 0, 0, 0, 0, f32(m[0]), f32(m[1]),
			f32(m[2]), f32(m[3]), f32(m[4]), f32(m[5]), page_x, page_y, scroll_y, canvas_height)
	}
}


fn document_glyph_mask_samples(width int, height int, geometry [7]i32, scale_x f32, scale_y f32,
	page_x f32, page_y f32, scroll_y f32) i32 {
	return document_image_sample_count(i32(math.round((f32(geometry[0]) - page_x) * scale_x)),
		i32(math.round((f32(geometry[1]) - page_y + scroll_y) * scale_y)), i32(width), i32(height))
}

// Whether merge_clipped_glyph_edges() would keep no pixel of the clipped draw:
// the clip covers every pixel of the raster box, so the unclipped interior is
// the whole result.
fn document_glyph_clip_covers_raster(clip [4]f32, width int, height int) bool {
	if width <= 0 || height <= 0 || clip.any(!math.is_finite(f64(it))) { return false }
	left := int(math.ceil(math.max(f64(0), math.min(f64(width), f64(clip[0])))))
	top := int(math.ceil(math.max(f64(0), math.min(f64(height), f64(clip[1])))))
	right := int(math.floor(math.max(f64(0), math.min(f64(width), f64(clip[2])))))
	bottom := int(math.floor(math.max(f64(0), math.min(f64(height), f64(clip[3])))))
	return left == 0 && top == 0 && right == width && bottom == height
}

// draw_document_glyph_mask()'s acceptance without its draw, for a clip that
// covers the raster box.
fn document_glyph_mask_drawable(pixels []u8, width int, height int, mask []u8, ink [4]f32,
	clip [4]f32, geometry [7]i32, scale_x f32, scale_y f32, page_x f32, page_y f32, scroll_y f32) bool {
	samples := document_glyph_mask_samples(width, height, geometry, scale_x, scale_y, page_x,
		page_y, scroll_y)
	if samples == 0 { return false }
	return ggshape.clipped_glyph_mask_drawable(pixels.data, i32(width), i32(height), i32(width * 4),
		mask, ink, clip, int(samples))
}

fn draw_document_glyph_mask(mut pixels []u8, width int, height int, mask []u8,
	ink [4]f32, bounds ?[4]f32, geometry [7]i32, scale_x f32, scale_y f32,
	page_x f32, page_y f32, scroll_y f32) bool {
	samples := document_glyph_mask_samples(width, height, geometry, scale_x, scale_y, page_x,
		page_y, scroll_y)
	if samples == 0 { return false }
	clip := if selected := bounds {
		document_glyph_device_clip(selected, geometry, scale_x, scale_y, page_x, page_y, scroll_y)
	} else { [f32(0), 0, f32(width), f32(height)]! }
	swap_document_raster_channels(pixels.data, i32(width), i32(height), i32(width * 4))
	drawn := ggshape.draw_clipped_glyph_mask(pixels.data, i32(width), i32(height), i32(width * 4),
		geometry[4], mask, ink, clip, int(samples)) != 0
	swap_document_raster_channels(pixels.data, i32(width), i32(height), i32(width * 4))
	return drawn
}


// Fully covered pixels need no clip operation. Preserve the established
// glyph blitter there; use floating point clip blending for the boundary.
fn merge_clipped_glyph_edges(mut pixels []u8, clipped []u8, width int, height int, clip [4]f32) bool {
	if width <= 0 || height <= 0 || pixels.len != width * height * 4 || clipped.len != pixels.len
		|| clip.any(!math.is_finite(f64(it))) { return false }
	left := int(math.ceil(math.max(f64(0), math.min(f64(width), f64(clip[0])))))
	top := int(math.ceil(math.max(f64(0), math.min(f64(height), f64(clip[1])))))
	right := int(math.floor(math.max(f64(0), math.min(f64(width), f64(clip[2])))))
	bottom := int(math.floor(math.max(f64(0), math.min(f64(height), f64(clip[3])))))
	for y in 0 .. height {
		row := y * width * 4
		if y < top || y >= bottom || left >= right {
			unsafe { vmemcpy(&pixels[row], &clipped[row], width * 4) }
		} else {
			if left > 0 { unsafe { vmemcpy(&pixels[row], &clipped[row], left * 4) } }
			if right < width {
				at := row + right * 4
				unsafe { vmemcpy(&pixels[at], &clipped[at], (width - right) * 4) }
			}
		}
	}
	return true
}
