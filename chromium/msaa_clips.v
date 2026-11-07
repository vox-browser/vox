module main

import layout

fn chromium_msaa_clip_list_has_empty_clip(clips &layout.PaintClipList) bool {
	if clips == unsafe { nil } { return false }
	for clip in clips.items {
		// SVG masks have their own resource geometry and replay protocol.
		if clip.is_svg_mask || clip.is_svg_content_mask { continue }
		if clip.is_path {
			if chromium_msaa_path_clip_has_empty_bounds(clip.path_data) { return true }
		} else if clip.rect.width <= 0 || clip.rect.height <= 0 {
			return true
		}
	}
	return false
}

// An inset clip keeps its reference box even when its polygon collapses.
// Native clipping uses the packed path, so its reference box cannot establish
// visibility. Only straight paths with an empty axis are rejected here; curves
// retain the existing conservative trigger behavior.
fn chromium_msaa_path_clip_has_empty_bounds(data []f32) bool {
	stride := layout.compatibility_clip_path_segment_stride
	mut first_x := f32(0)
	mut first_y := f32(0)
	mut has_point := false
	mut varies_x := false
	mut varies_y := false
	for offset := 0; offset + stride <= data.len; offset += stride {
		kind := int(data[offset])
		if kind == 5 { continue }
		if kind != 0 && kind != 1 { return false }
		x := data[offset + 1]
		y := data[offset + 2]
		if !has_point {
			first_x = x
			first_y = y
			has_point = true
		} else {
			varies_x = varies_x || x != first_x
			varies_y = varies_y || y != first_y
			if varies_x && varies_y { return false }
		}
	}
	return true
}
