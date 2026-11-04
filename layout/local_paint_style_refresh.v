module layout

import css
import dom
import platform

// Background, text color and underline changes leave geometry, visual contexts and
// paint order intact. Retain those plans and unrelated PaintableBox phase
// caches instead of rebuilding every SVG/image transport in the document.
// A style update whose only changes are `transform` and `opacity` (a script
// sampling a progress bar's scaleX every frame) patches the
// retained tree like a compositor animation sample. The refresh still falls
// back to a full rebuild when stacking, surface or opacity categories change.
fn paint_style_update_is_compositor_only(node &Node, previous &css.ComputedValues, current &css.ComputedProperties) bool {
	if voidptr(previous) == voidptr(current) || previous.has_animated_properties()
		|| !compositor_style_refresh_supports_node(node)
		|| previous.raw_property_count() != current.raw_property_count() {
		return false
	}
	mut changed := false
	for index in 0 .. previous.raw_property_count() {
		before := previous.raw_property_at_index(index)
		after := current.raw_property_at_index(index)
		if before == after { continue }
		property := unsafe { css.PropertyID(int(css.first_longhand_property_id()) + index) }
		if property == .transform || property == .opacity {
			changed = true
			continue
		}
		// These are refreshed by the box's local paint update, which the
		// compositor refresh does not run.
		match property {
			.background_color, .text_decoration_line, .cursor, .color, .outline_color, .outline_width,
			.outline_style, .outline_offset {
				return false
			}
			else {}
		}
		old_value := if before == unsafe { nil } { ?&dom.StyleValue(none) } else { ?&dom.StyleValue(before) }
		new_value := if after == unsafe { nil } { ?&dom.StyleValue(none) } else { ?&dom.StyleValue(after) }
		if !css.compute_property_invalidation(property, old_value, new_value).is_none() { return false }
	}
	return changed
}

fn paint_style_update_can_be_local(node &Node, previous &css.ComputedValues, current &css.ComputedProperties) bool {
	if voidptr(previous) == voidptr(current) || previous.has_animated_properties()
		|| !local_paint_style_refresh_supports_node(node, current) {
		return false
	}
	if previous.raw_property_count() != current.raw_property_count() { return false }
	for index in 0 .. previous.raw_property_count() {
		before := previous.raw_property_at_index(index)
		property := unsafe { css.PropertyID(int(css.first_longhand_property_id()) + index) }
		if property == .background_color || property == .text_decoration_line
			|| property == .cursor { continue }
		after := current.raw_property_at_index(index)
		if before == after { continue
		 }
		if property == .outline_color || property == .outline_width
			|| property == .outline_style || property == .outline_offset {
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

// Animated styles can be refreshed locally only when CSS has checked which
// sampled values changed: a raw property diff cannot see them.
fn local_paint_style_refresh_supports_node(node &Node, current &css.ComputedProperties) bool {
	return !current.has_animated_properties() && local_paint_style_refresh_supports_box(node)
}

fn local_paint_style_refresh_supports_box(node &Node) bool {
	if node.is_generated_for_pseudo_element()
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
			name := value.local_name()
			if name == 'html' || name == 'body' { return false }
		}
	}
	return true
}

// Transform resolution allocates temporaries for every animated box on every
// frame. They and the changed-box list live in this arena, which is reset once
// the refresh has used them; the boxes keep only plain values.
__global paint_style_refresh_scratch_ = &platform.Arena(unsafe { nil })

fn refresh_local_paint_styles(mut result DocumentLayoutResult) {
	if paint_style_refresh_scratch_ == unsafe { nil } {
		persistent := platform.enter_persistent()
		paint_style_refresh_scratch_ = platform.new_arena('paint style refresh')
		platform.leave_persistent(persistent)
	}
	mut scratch := paint_style_refresh_scratch_
	// Nested documents refresh from their own update; only the outermost
	// refresh uses the arena.
	use_scratch := !platform.transient_arena_entered()
	mut compositor := CompositorPaintStyleRefresh{}
	if use_scratch {
		entry := scratch.enter()
		refresh_compositor_paint_styles_in_box(mut result.paint_tree, result.state,
			&result.paint_style_update_compositor_handles, layout_to_css_transform(result.document), mut compositor)
		scratch.leave(entry)
	} else {
		refresh_compositor_paint_styles_in_box(mut result.paint_tree, result.state,
			&result.paint_style_update_compositor_handles, layout_to_css_transform(result.document), mut compositor)
	}
	mut ordinary_changes := &result.paint_style_update_ordinary_handles
	mut line_changes := &result.paint_style_update_line_handles
	ordinary_changes.clear()
	line_changes.clear()
	for handle in result.paint_style_update_handles.items {
		if !result.paint_style_update_compositor_handles.contains(handle) {
			ordinary_changes.add(handle)
			if result.paint_style_update_text_handles.contains(handle) {
				line_changes.add(handle)
			}
		}
	}
	mut changed_boxes := []&BlockBox{}
	refresh_local_paint_styles_in_box(mut result.paint_tree, result.state,
		ordinary_changes, line_changes, mut changed_boxes)
	ordinary_changes.clear()
	line_changes.clear()
	result.paint_style_update_text_handles.clear()
	for box in changed_boxes { viewport_invalidate_box_paint_cache(mut result, box) }
	if compositor.changed {
		// Opacity zero and singular transforms also change paint-step membership,
		// and cached commands carry cumulative opacity. Rebuild those plans from
		// the retained boxes, keeping resource snapshots.
		if compositor.invalidates_paint_plan
			|| (compositor.entry_opacities_changed && !refresh_paint_order_opacities(mut result, use_scratch)) {
			viewport_invalidate_compositor_stacking_context(voidptr(&result))
		}
		// The samples keep box categories, so normally only node values change.
		if !patch_compositor_visual_contexts(mut result.visual_context_tree, compositor.boxes) {
			rebuild_compatibility_visual_contexts(mut result)
		}
		result.scroll_state.invalidate()
	}
	if use_scratch {
		compositor = CompositorPaintStyleRefresh{}
		scratch.reset()
	}
	result.paint_tree_needs_style_update = false
	result.paint_style_update_handles.clear()
	result.paint_style_update_compositor_handles.clear()
	result.display_list = unsafe { nil }
	result.needs_repaint = true
	mut document := unsafe { &dom.Document(result.document) }
	document.invalidate_display_list()
}

// Update the retained paint order's cumulative opacities after opacity
// samples that leave paint-step membership unchanged. Returns false when the
// order itself differs, so the plan has to be rebuilt.
fn refresh_paint_order_opacities(mut result DocumentLayoutResult, in_scratch bool) bool {
	if !result.stacking_context_tree_is_valid {
		return true
	}
	mut scratch := paint_style_refresh_scratch_
	mut entry := platform.ArenaEntry{}
	if in_scratch {
		entry = scratch.enter()
	}
	fresh := result.paint_tree.paint_order_entries()
	mut same_order := fresh.len == result.paint_order.len
	if same_order {
		for index, current in fresh {
			if voidptr(current.box) != voidptr(result.paint_order[index].box) {
				same_order = false
				break
			}
		}
	}
	if same_order {
		for index, current in fresh {
			result.paint_order[index] = current
		}
	}
	if in_scratch {
		scratch.leave(entry)
	}
	return same_order
}

fn line_style_depends_on_changed_node(box &BlockBox, changed &HandleSet) bool {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.layout_handle == unsafe { nil } { continue
			 }
			mut node := unsafe { &Node(fragment.layout_handle) }
			for {
				if changed.contains(u64(voidptr(node))) { return true }
				node = node.parent() or { break }
			}
		}
	}
	return false
}

// A box paints its own computed background color unless it is anonymous or
// its background propagates to the canvas.
fn box_background_color_refreshes_directly(node &Node) bool {
	if node.is_body() || node.is_root_element() || node.is_anonymous() {
		return false
	}
	element := node.dom_node() or { return false }
	return element.as_element() != none
}

// `line_changes` are the changed nodes whose text may paint differently;
// nodes whose only change is their background color keep their lines.
fn refresh_local_paint_styles_in_box(mut box BlockBox, state &LayoutState,
	changed &HandleSet, line_changes &HandleSet, mut changed_boxes []&BlockBox) {
	if changed.len() == 0 { return }
	mut did_change := false
	if box.layout_handle != unsafe { nil } {
		node := unsafe { &Node(box.layout_handle) }
		if changed.contains(u64(box.layout_handle)) && !line_changes.contains(u64(box.layout_handle))
			&& box_background_color_refreshes_directly(node) {
			// Only the background color changed (an animation sample): the other
			// box paint data, which a shallow rebuild would recompute together
			// with the text lines, is unchanged.
			if styled := node.as_node_with_style() {
				computed := styled.computed_values()
				box.background_color = computed.background_color()
				box.background_srgb_color = chromium_background_srgb_color(node, computed,
					box.background_color)
				did_change = true
			}
		} else if changed.contains(u64(box.layout_handle)) {
			// Resolve currentColor in borders, shadows, outlines and image layers
			// exactly as a full transport rebuild does. Retain box addresses,
			// children, geometry and accumulated visual/scroll context indices.
			fresh := block_box_from_typed_layout_shallow(node, state, [6]f64{})
			box.background_color = fresh.background_color
			box.background_srgb_color = fresh.background_srgb_color
			box.text_color = fresh.text_color
			box.border_color = fresh.border_color
			box.border_colors = fresh.border_colors
			box.outline_color = fresh.outline_color
			box.outline_style = fresh.outline_style
			box.outline_is_auto = fresh.outline_is_auto
			box.decoration_data = retained_block_box_decoration(BlockBoxDecorationData{
				...*box.decorations()
				corner_shapes: fresh.decorations().corner_shapes
				outline_width: fresh.decorations().outline_width
				outline_offset: fresh.decorations().outline_offset
				shadow: fresh.decorations().shadow
				shadows: fresh.decorations().shadows
				background_gradient: fresh.decorations().background_gradient
				background_images: fresh.decorations().background_images
			})
			did_change = true
		}
		if line_changes.len() > 0 && line_style_depends_on_changed_node(&box, line_changes) {
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
		refresh_local_paint_styles_in_box(mut child, state, changed, line_changes, mut changed_boxes)
	}
}
