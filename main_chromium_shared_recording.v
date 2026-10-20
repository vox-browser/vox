module main

import layout
import painting

fn C.native_set_chromium_shared_recording(i32, i32, i32)

// The shared recording currently covers simple root-layer drawing. Effects,
// clips, nested documents and interleaved compositor layers keep their existing
// replay path until their complete scope can be represented in the picture.
fn chromium_shared_recording_supported(commands []layout.PaintCommand,
	plan layout.ChromiumRasterLayerPlan) bool {
	if plan.layers.len == 0 || plan.layers[0].legacy_raster
		|| plan.command_layers.len != commands.len {
		return false
	}
	mut left_root := false
	mut has_vectors := false
	for index, command in commands {
		if plan.command_layers[index] != 0 {
			left_root = true
			continue
		}
		if left_root || command.has_clip || command.clip_list != unsafe { nil }
			|| command.clip_outs.len > 0 || command.blur != 0 || command.outer_shadow {
			return false
		}
		match command.kind {
			'fill_rect', 'fill_rounded_rect', 'paint_uniform_border', 'stroke_rounded_rect',
			'fill_ellipse', 'stroke_ellipse', 'draw_text', 'draw_replaced_image', 'draw_svg_image' {
			}
			'draw_svg_path' {
				has_vectors = true
				// Read the payload directly: an accessor call on the loop's copy of
				// the command makes current V move that copy to the heap.
				if command.svg_data != unsafe { nil } {
					data := command.svg_data
					if data.svg_gradient_data != none || data.fill_pattern != none
						|| data.stroke_pattern != none || data.stroke_dasharray.len > 0 {
						return false
					}
				}
			}
			'paint_nested_display_list' {
				paintable := command.nested_viewport_paintable or { return false }
				if !chromium_svg_image_can_share_recording(command)
					|| paintable.border_radii != painting.BorderRadiiData{} {
					return false
				}
				has_vectors = true
			}
			else { return false }
		}
		if command.image_data != unsafe { nil } {
			url := command.image_data.image_url.to_lower()
			if url.starts_with('data:image/svg+xml') || url.all_before('?').ends_with('.svg') {
				has_vectors = true
			}
		}
	}
	return has_vectors
}
