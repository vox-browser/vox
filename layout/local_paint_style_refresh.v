module layout

import css
import dom

// Background, text color and underline changes leave geometry, visual contexts and
// paint order intact. Retain those plans and unrelated PaintableBox phase
// caches instead of rebuilding every SVG/image transport in the document.
fn paint_style_update_can_be_local(node &Node, previous &css.ComputedValues, current &css.ComputedProperties) bool {
	if voidptr(previous) == voidptr(current) || previous.has_animated_properties()
		|| !local_paint_style_refresh_supports_node(node, current) {
		return false
	}
	if previous.raw_property_count() != current.raw_property_count() { return false }
	for index in 0 .. previous.raw_property_count() {
		before := previous.raw_property_at_index(index)
		property := unsafe { css.PropertyID(int(css.first_longhand_property_id()) + index) }
		if property in [.background_color, .text_decoration_line, .cursor] { continue
		 }
		after := current.raw_property_at_index(index)
		if before == after { continue
		 }
		if property in [.outline_color, .outline_width, .outline_style, .outline_offset] {
			if !current.filter().is_none() || !current.backdrop_filter().is_none() { return false }
			continue
		}
		if property == .color {
			// Filter colors also live in accumulated effect contexts. Keep their
			// full refresh until that context update has a local equivalent.
			if !current.filter().is_none() || !current.backdrop_filter().is_none() { return false }
			continue
		}
		old_value := if before == unsafe { nil } {
			?&dom.StyleValue(none)
		} else {
			?&dom.StyleValue(before)
		}
		new_value := if after == unsafe { nil } {
			?&dom.StyleValue(none)
		} else {
			?&dom.StyleValue(after)
		}
		if !css.compute_property_invalidation(property, old_value, new_value).is_none() {
			return false
		}
	}
	return true
}

fn local_paint_style_refresh_supports_node(node &Node, current &css.ComputedProperties) bool {
	if current.has_animated_properties() || node.is_generated_for_pseudo_element()
		|| node.is_svg_box() || node.is_svg_svg_box() || node.is_svg_foreign_object_box()
		|| node.is_viewport() || node.display().is_internal_table()
		|| node.display().is_table_inside() {
		return false
	}
	if metrics := node.as_node_with_style_and_box_model_metrics() {
		if metrics.continuation_of_node() != none { return false }
	}
	if element := node.dom_node() {
		if value := element.as_element() {
			if value.local_name() in ['html', 'body'] { return false }
		}
	}
	return true
}

fn refresh_local_paint_styles(mut result DocumentLayoutResult) {
	mut compositor := CompositorPaintStyleRefresh{}
	refresh_compositor_paint_styles_in_box(mut result.paint_tree, result.state,
		result.paint_style_update_compositor_handles, [6]f64{}, mut compositor)
	mut ordinary_changes := map[u64]bool{}
	for handle, _ in result.paint_style_update_handles {
		if handle !in result.paint_style_update_compositor_handles {
			ordinary_changes[handle] = true
		}
	}
	mut changed_boxes := []&BlockBox{}
	refresh_local_paint_styles_in_box(mut result.paint_tree, result.state, ordinary_changes, mut
		changed_boxes)
	for box in changed_boxes {
		viewport_invalidate_box_paint_cache(mut result, box)
	}
	if compositor.changed {
		// Opacity zero and singular transforms also change paint-step membership,
		// and cached commands carry cumulative opacity. Rebuild those plans from
		// the retained boxes, keeping resource snapshots.
		if compositor.invalidates_paint_plan {
			viewport_invalidate_compositor_stacking_context(voidptr(&result))
		}
		// The samples keep box categories, so normally only node values change.
		if !patch_compositor_visual_contexts(mut result.visual_context_tree, compositor.boxes) {
			rebuild_compatibility_visual_contexts(mut result)
		}
		result.scroll_state.invalidate()
	}
	result.paint_tree_needs_style_update = false
	result.paint_style_update_handles.clear()
	result.paint_style_update_compositor_handles.clear()
	result.display_list = unsafe { nil }
	result.needs_repaint = true
	mut document := unsafe { &dom.Document(result.document) }
	document.invalidate_display_list()
}

fn line_style_depends_on_changed_node(box &BlockBox, changed map[u64]bool) bool {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle == unsafe { nil } { continue
			 }
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
	if changed.len == 0 { return }
	mut did_change := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if u64(box.layout_handle) in changed {
			// Resolve currentColor in borders, shadows, outlines and image layers
			// exactly as a full transport rebuild does. Retain box addresses,
			// children, geometry and accumulated visual/scroll context indices.
			fresh := block_box_from_typed_layout_shallow(node, state, [6]f64{})
			box.background_color = fresh.background_color
			box.text_color = fresh.text_color
			box.border_color = fresh.border_color
			box.border_colors = fresh.border_colors
			box.outline_color = fresh.outline_color
			box.outline_width = fresh.outline_width
			box.outline_style = fresh.outline_style
			box.outline_offset = fresh.outline_offset
			box.outline_is_auto = fresh.outline_is_auto
			box.shadow = fresh.shadow
			box.shadows = fresh.shadows
			box.background_gradient = fresh.background_gradient
			box.background_images = fresh.background_images
			did_change = true
		}
		if line_style_depends_on_changed_node(&box, changed) {
			if styled := node.as_node_with_style() {
				if used := state.try_get(styled) {
					box.lines = text_lines_from_typed_layout(node, used, state, paint_cumulative_offset(node,
						state, used))
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
