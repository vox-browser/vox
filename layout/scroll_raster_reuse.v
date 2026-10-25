module layout

import dom
import painting

// Only ordinary translating leaves can reuse viewport pixels. Resource/effect
// inputs, independent media and non-translating visual contexts use complete
// replay. Check the whole property tree, including currently offscreen boxes.
pub fn viewport_scroll_raster_reusable(document &dom.Document, commands []PaintCommand,
	width f64, height f64) bool {
	result := document_layout_result(document) or { return false }
	for node in result.visual_context_tree.nodes {
		if node.data is painting.ScrollVisualData {
			if node.data.is_sticky { return false }
		} else if node.data is painting.ScrollCompensationVisualData
			|| node.data is painting.PerspectiveVisualData {
			return false
		}
	}
	mut in_command_group := false
	mut saw_scrollbar := false
	for command in commands {
		if command.scrollbar_axis != '' {
			if in_command_group { return false }
			saw_scrollbar = true
			// Only trailing viewport overlays may be painted after caching.
			bounds := compatibility_affine_map_rect(command.transform,
				LayoutRect{command.x, command.y, command.width, command.height})
			if command.scrollbar_axis == 'vertical' {
				if bounds.x < width - 30 || bounds.x + bounds.width > width + 1 { return false }
			} else if command.scrollbar_axis != 'horizontal' || bounds.y < height - 30 || bounds.y + bounds.height > height + 1 {
				return false
			}
			continue
		}
		if saw_scrollbar { return false }
		if command.fixed_to_viewport || command.blur != 0 || command.outer_shadow { return false }
		match command.kind {
			// Controls composite these translating primitives on one Skia
			// surface. Replay both boundaries before caching the final pixels.
			'begin_skia_command_group' {
				if in_command_group { return false }
				in_command_group = true
			}
			'end_skia_command_group' {
				if !in_command_group { return false }
				in_command_group = false
			}
			'fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect', 'fill_ellipse',
			'stroke_ellipse', 'paint_uniform_border', 'draw_line', 'fill_polygon', 'draw_text',
			'draw_replaced_image', 'draw_background_image', 'draw_svg_path' {
			}
			else { return false }
		}
	}
	return commands.len > 0 && !in_command_group
}
