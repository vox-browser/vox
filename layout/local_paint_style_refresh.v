module layout

import css
import dom

// Background and underline hover changes leave geometry, visual contexts and
// paint order intact. Retain those plans and unrelated PaintableBox phase
// caches instead of rebuilding every SVG/image transport in the document.
fn paint_style_update_can_be_local(node &Node, previous &css.ComputedValues, current &css.ComputedProperties) bool {
	if voidptr(previous) == voidptr(current) || previous.animated_property_values_.len > 0
		|| current.animated_property_values_.len > 0 || node.is_generated_for_pseudo_element()
		|| node.is_svg_box() || node.is_svg_svg_box() || node.is_svg_foreign_object_box()
		|| node.is_viewport() || node.display().is_internal_table()
		|| node.display().is_table_inside() { return false }
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	if element := node.dom_node() {
		if value := element.as_element() {
			if value.local_name() in ['html', 'body'] { return false }
		}
	}
	if previous.property_values_.len != current.property_values_.len { return false }
	for index, before in previous.property_values_ {
		property := unsafe { css.PropertyID(int(css.first_longhand_property_id()) + index) }
		if property in [.background_color, .text_decoration_line, .cursor] { continue }
		after := current.property_values_[index]
		if before == after { continue }
		old_value := if before == unsafe { nil } { ?&dom.StyleValue(none) } else { ?&dom.StyleValue(before) }
		new_value := if after == unsafe { nil } { ?&dom.StyleValue(none) } else { ?&dom.StyleValue(after) }
		if !css.compute_property_invalidation(property, old_value, new_value).is_none() { return false }
	}
	return true
}

fn refresh_local_paint_styles(mut result DocumentLayoutResult) {
	mut changed_boxes := []&BlockBox{}
	refresh_local_paint_styles_in_box(mut result.paint_tree, result.state,
		result.paint_style_update_handles, mut changed_boxes)
	for box in changed_boxes { viewport_invalidate_box_paint_cache(mut result, box) }
	result.paint_tree_needs_style_update = false
	result.paint_style_update_handles.clear()
	result.display_list = unsafe { nil }
	result.needs_repaint = true
	mut document := unsafe { &dom.Document(result.document) }
	document.invalidate_display_list()
}

fn line_style_depends_on_changed_node(box &BlockBox, changed map[u64]bool) bool {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle == unsafe { nil } { continue }
			mut node := unsafe { &Node(fragment.layout_handle) }
			for {
				if u64(voidptr(node)) in changed { return true }
				node = node.parent() or { break }
			}
		}
	}
	return false
}

fn refresh_local_paint_styles_in_box(mut box BlockBox, state &LayoutState,
	changed map[u64]bool, mut changed_boxes []&BlockBox) {
	mut did_change := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if u64(box.layout_handle) in changed {
			box.background_color = node.computed_values().background_color()
			did_change = true
		}
		if line_style_depends_on_changed_node(&box, changed) {
			if styled := node.as_node_with_style() {
				if used := state.try_get(styled) {
					box.lines = text_lines_from_typed_layout(node, used, state, paint_cumulative_offset(node, state, used))
					did_change = true
				}
			}
		}
	}
	if did_change { changed_boxes << unsafe { &box } }
	for mut child in box.children {
		refresh_local_paint_styles_in_box(mut child, state, changed, mut changed_boxes)
	}
}
