module layout

import dom
import painting

// Compile with -d vox_scroll_raster_diagnostics for eligibility diagnostics.
@[inline]
fn reject_scroll_raster(reason string) bool {
	$if vox_scroll_raster_diagnostics ? {
		eprintln('VOX_SCROLL_RASTER_REJECT reason=${reason}')
	}
	return false
}

// Only ordinary translating leaves can reuse viewport pixels. Resource/effect
// inputs, independent media and non-translating visual contexts use complete
// replay. Check the whole property tree, including currently offscreen boxes.
pub fn viewport_scroll_raster_reusable(document &dom.Document, commands []PaintCommand,
	width f64, height f64) bool {
	result := document_layout_result(document) or { return reject_scroll_raster('missing-layout') }
	for node in result.visual_context_tree.nodes {
		if node.data is painting.ScrollVisualData {
			if node.data.is_sticky { return reject_scroll_raster('sticky') }
		} else if node.data is painting.ScrollCompensationVisualData {
			return reject_scroll_raster('scroll-compensation')
		} else if node.data is painting.PerspectiveVisualData {
			return reject_scroll_raster('perspective')
		}
	}
	mut in_command_group := false
	mut saw_scrollbar := false
	for command in commands {
		if command.scrollbar_axis != '' {
			if in_command_group { return reject_scroll_raster('scrollbar-in-group') }
			saw_scrollbar = true
			// Only trailing viewport overlays may be painted after caching.
			bounds := compatibility_affine_map_rect(command.transform,
				LayoutRect{command.x, command.y, command.width, command.height})
			if command.scrollbar_axis == 'vertical' {
				if bounds.x < width - 30 || bounds.x + bounds.width > width + 1 { return reject_scroll_raster('nonviewport-vertical-scrollbar') }
			} else if command.scrollbar_axis != 'horizontal' || bounds.y < height - 30 || bounds.y + bounds.height > height + 1 {
				return reject_scroll_raster('nonviewport-horizontal-scrollbar')
			}
			continue
		}
		if saw_scrollbar { return reject_scroll_raster('content-after-scrollbar') }
		if command.fixed_to_viewport { return reject_scroll_raster('fixed-command') }
		if command.blur != 0 { return reject_scroll_raster('blur') }
		if command.outer_shadow { return reject_scroll_raster('outer-shadow') }
		match command.kind {
			// Controls composite these translating primitives on one Skia
			// surface. Replay both boundaries before caching the final pixels.
			'begin_skia_command_group' {
				if in_command_group { return reject_scroll_raster('nested-group') }
				in_command_group = true
			}
			'end_skia_command_group' {
				if !in_command_group { return reject_scroll_raster('unmatched-group-end') }
				in_command_group = false
			}
			'fill_rect', 'fill_rounded_rect', 'stroke_rounded_rect', 'fill_ellipse',
			'stroke_ellipse', 'paint_uniform_border', 'draw_line', 'fill_polygon', 'draw_text',
			'paint_rounded_border_top', 'paint_rounded_border_right',
			'paint_rounded_border_bottom', 'paint_rounded_border_left',
			'draw_replaced_image', 'draw_background_image', 'draw_svg_path' {
			}
			else {
				$if vox_scroll_raster_diagnostics ? {
					eprintln('VOX_SCROLL_RASTER_COMMAND kind=${command.kind} bounds=${command.x},${command.y},${command.width},${command.height} transform=${command.transform}')
				}
				return reject_scroll_raster('unsupported-command')
			}
		}
	}
	if commands.len == 0 { return reject_scroll_raster('empty-commands') }
	if in_command_group { return reject_scroll_raster('unclosed-group') }
	return true
}
