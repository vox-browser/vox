module main

import layout
import math

fn chromium_compositor_gap_has_balanced_scopes(commands []layout.PaintCommand,
	start int, end int) bool {
	mut scopes := []u64{}
	mut kinds := []string{}
	for index in start .. end {
		command := unsafe { &commands[index] }
		if command.kind.starts_with('begin_') {
			layer := command.visual_layer_data or { return false }
			if layer.scope_id == 0 { return false }
			scopes << u64(layer.scope_id)
			kinds << command.kind.all_after('begin_')
		} else if command.kind.starts_with('end_') {
			layer := command.visual_layer_data or { return false }
			if scopes.len == 0 || scopes.last() != u64(layer.scope_id)
				|| kinds.last() != command.kind.all_after('end_') {
				return false
			}
			scopes.delete_last()
			kinds.delete_last()
		} else if command.visual_layer_data != none {
			return false
		}
	}
	return scopes.len == 0
}

// Mirror draw_command's vertical shadow rejection before asking whether the
// leaf can join a complete picture. No filter or resource scope is skipped.
fn chromium_compositor_leaf_is_culled(command &layout.PaintCommand,
	viewport layout.LayoutRect) bool {
	if command.visual_layer_data != none || command.kind.starts_with('begin_')
		|| command.kind.starts_with('end_') {
		return false
	}
	if command.has_clip && (command.clip_width <= 0 || command.clip_height <= 0) { return true }
	if command.kind !in ['paint_outer_box_shadow', 'paint_inner_box_shadow', 'draw_text_shadow'] {
		return false
	}
	if command.blur < 0 || math.is_nan(command.blur) || math.is_inf(command.blur, 0) {
		return false
	}
	mut normalized := layout.PaintCommand{ ...*command, kind: 'fill_rect', blur: 0, outer_shadow: false }
	if command.kind == 'paint_inner_box_shadow' {
		data := command.box_shadow_data
		if data == unsafe { nil } { return false }
		r := data.content_rect
		normalized.x = r.x
		normalized.y = r.y
		normalized.width = r.width
		normalized.height = r.height
	} else {
		margin := command.blur * 2
		normalized.x -= margin
		normalized.y -= margin
		normalized.width += margin * 2
		normalized.height += margin * 2
	}
	ink := layout.paint_leaf_native_ink_bounds(&normalized) or { return false }
	return ink.y + ink.height < -3 || ink.y > viewport.height + 3
}
