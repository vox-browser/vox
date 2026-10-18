// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// Literal debug serialization of the paintables materialized by LayoutState::commit(). This is a
// debug/test representation; the native shell's display-list transport remains BlockBox.
pub fn dump_typed_paint_tree(root &Node, state &LayoutState) string {
	mut lines := []string{}
	append_typed_paintables(root, state, 0, mut lines)
	return lines.join('\n').trim_right('\n')
}

fn append_typed_paintables(node &Node, state &LayoutState, depth int, mut lines []string) {
	paintable_count := layout_debug_paintable_count(node, state)
	if paintable_count == 0 {
		return
	}
	for paintable_index in 0 .. paintable_count {
		if paintable_index > 0 {
			lines << ''
		}
		paintable_class := layout_debug_paintable_class(node)
		mut line := '${'  '.repeat(depth)}${paintable_class} (${layout_debug_node_description(node)})'
		if layout_debug_paintable_is_box(paintable_class) {
			if rect := layout_debug_paintable_border_rect(node, state, paintable_index) {
				line += ' ${layout_debug_css_rect(rect)}'
			}
			if styled := node.as_node_with_style() {
				if used := state.try_get(styled) {
					if used.has_scrollable_overflow() {
						if overflow_rect := used.scrollable_overflow_rect() {
							line += ' overflow: ${layout_debug_css_rect(overflow_rect)}'
						}
					}
				}
			}
		}
		lines << line
		if paintable_index == 0 {
			for child in node.children() {
				// dump_tree(Paintable) is called once for every attached paintable, and
				// each call enumerates every paintable owned by that layout node. A
				// multi-line InlineNode therefore deliberately appears N×N times.
				for _ in 0 .. layout_debug_paintable_count(child, state) {
					append_typed_paintables(child, state, depth + 1, mut lines)
				}
			}
		}
	}
}

fn layout_debug_paintable_count(node &Node, state &LayoutState) int {
	return layout_debug_paintable_count_with_inline_geometry(node, state, none)
}

fn layout_debug_paintable_count_with_inline_geometry(node &Node, state &LayoutState,
	inline_has_geometry ?bool) int {
	if node.is_text_node() {
		return if layout_debug_text_node_has_fragment(node, state) { 1 } else { 0 }
	}
	if node.is_break_node() || (!node.is_box() && !node.is_inline_node()) {
		return 0
	}
	if layout_debug_node_suppresses_paintable(node) {
		return 0
	}
	if node.display().is_table_column_group() || node.display().is_table_column() {
		return 0
	}
	if node.is_inline_node() {
		line_indices := layout_debug_inline_line_indices(node, state)
		if line_indices.len > 0 {
			return line_indices.len
		}
		if has_geometry := inline_has_geometry { return if has_geometry { 1 } else { 0 } }
		return if layout_debug_inline_metrics(node, state) != none { 1 } else { 0 }
	}
	styled := node.as_node_with_style() or { return 0 }
	used := state.try_get(styled) or { return 0 }
	return if used.svg_rendering_disabled() { 0 } else { 1 }
}

fn layout_debug_node_suppresses_paintable(node &Node) bool {
	if node.is_svg_clip_box() || node.is_svg_mask_box() || node.is_svg_pattern_box() {
		// These paintables form disconnected resource subtrees and are not children
		// of the document's ViewportPaintable tree.
		return true
	}
	parent := node.parent() or { return false }
	skip_anonymous_item := (parent.display().is_flex_inside() || parent.display().is_grid_inside())
		&& can_skip_anonymous_text_run(node)
		&& !(parent.display().is_grid_inside() && parent.display().is_inline_outside())
		&& !(parent.display().is_flex_inside() && parent.display().is_inline_outside()
			&& node.next_sibling() == none)
	if skip_anonymous_item {
		return true
	}
	return ignorable_table_whitespace(node)
		&& (parent.display().is_table_inside() || parent.display().is_table_row_group()
			|| parent.display().is_table_header_group()
			|| parent.display().is_table_footer_group()
			|| parent.display().is_table_row()) && !is_trailing_whitespace_of_inline_table(node)
}

fn layout_debug_paintable_class(node &Node) string {
	if node.is_viewport() {
		return 'ViewportPaintable'
	}
	if node.is_navigable_container_viewport() {
		return 'NavigableContainerViewportPaintable'
	}
	if node.is_fieldset_box() {
		return 'FieldSetPaintable'
	}
	if node.is_list_item_marker_box() {
		return 'MarkerPaintable'
	}
	if node.is_svg_foreign_object_box() {
		return 'SVGForeignObjectPaintable'
	}
	if node.is_svg_svg_box() {
		return 'SVGSVGPaintable'
	}
	if node.is_svg_geometry_box() || node.is_svg_text_box() || node.is_svg_text_path_box() {
		return 'SVGPathPaintable'
	}
	if node.is_svg_graphics_box() {
		return 'SVGGraphicsPaintable'
	}
	if node.is_svg_image_box() || node.is_image_box() {
		return 'ImagePaintable'
	}
	if node.is_text_node() {
		return 'TextPaintable'
	}
	if node.is_inline_node() || node.is_block_container() {
		return 'PaintableWithLines'
	}
	if node.is_replaced_box() {
		dom_node := node.dom_node() or { return 'PaintableBox' }
		element := dom_node.as_element() or { return 'PaintableBox' }
		return match element.local_name().to_lower() {
			'canvas' {
				'CanvasPaintable'
			}
			'video' {
				'VideoPaintable'
			}
			'input' {
				match element.get_attribute_value('type').to_lower() {
					'checkbox' { 'CheckBoxPaintable' }
					'radio' { 'RadioButtonPaintable' }
					'image' { 'ImagePaintable' }
					else { 'PaintableBox' }
				}
			}
			else {
				'PaintableBox'
			}
		}
	}
	return 'PaintableBox'
}

fn layout_debug_paintable_is_box(class_name string) bool {
	return class_name != 'TextPaintable'
}

fn layout_debug_node_description(node &Node) string {
	mut description := layout_debug_class_name(node)
	if dom_node := node.dom_node() {
		description += '<${dom_node.node_name()}>'
		if element := dom_node.as_element() {
			if id := element.id() {
				description += '#${id}'
			}
			for class_name in element.get_attribute_value('class').fields() {
				description += '.${class_name}'
			}
		}
	} else {
		description += '(anonymous)'
	}
	return description
}

fn layout_debug_paintable_border_rect(node &Node, state &LayoutState, paintable_index int) ?css.CSSPixelRect {
	if node.is_inline_node() {
		line_indices := layout_debug_inline_line_indices(node, state)
		line_index := if line_indices.len > 0 && paintable_index < line_indices.len {
			line_indices[paintable_index]
		} else {
			0
		}
		metrics := layout_debug_inline_metrics_for_line(node, state, line_index) or {
			layout_debug_inline_metrics(node, state) or { return none }
		}
		styled := node.as_node_with_style() or { return none }
		used := state.try_get(styled) or { return none }
		return layout_debug_border_rect(metrics.position, metrics.width, metrics.height, used)
	}
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	position := layout_offset_in_svg_user_space(node, state, used)
	return layout_debug_border_rect(position, used.content_width(), used.content_height(), used)
}

fn layout_debug_border_rect(position css.CSSPixelPoint, width CSSPixels, height CSSPixels, used &UsedValues) css.CSSPixelRect {
	border_left := used.border_left_collapsed()
	border_right := used.border_right_collapsed()
	border_top := used.border_top_collapsed()
	border_bottom := used.border_bottom_collapsed()
	left := border_left.plus(used.padding_left)
	top := border_top.plus(used.padding_top)
	return css.CSSPixelRect{
		x: position.x().minus(left)
		y: position.y().minus(top)
		width: width.plus(left).plus(used.padding_right).plus(border_right)
		height: height.plus(top).plus(used.padding_bottom).plus(border_bottom)
	}
}

fn layout_debug_css_rect(rect css.CSSPixelRect) string {
	return '[${layout_debug_pixels(rect.x)},${layout_debug_pixels(rect.y)} ${layout_debug_pixels(rect.width)}x${layout_debug_pixels(rect.height)}]'
}

fn layout_debug_text_node_has_fragment(node &Node, state &LayoutState) bool {
	containing_block := node.containing_block() or { return false }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return false }
	containing_used := state.try_get(containing_styled) or { return false }
	for line_box in containing_used.line_boxes {
		for fragment in line_box.fragments() {
			if layout_nodes_same(fragment.layout_node(), node) {
				return true
			}
		}
	}
	return false
}

fn layout_debug_inline_line_indices(node &Node, state &LayoutState) []int {
	containing_block := node.containing_block() or { return []int{} }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return []int{} }
	containing_used := state.try_get(containing_styled) or { return []int{} }
	mut indices := []int{}
	for line_index, line_box in containing_used.line_boxes {
		for fragment in line_box.fragments() {
			target := fragment_inline_paintable_target(fragment.layout_node()) or { continue }
			if layout_nodes_same(target, node) {
				indices << line_index
				break
			}
		}
	}
	return indices
}

fn layout_debug_inline_metrics_for_line(node &Node, state &LayoutState, line_index int) ?LayoutDebugInlineMetrics {
	containing_block := node.containing_block() or { return none }
	containing_node := unsafe { &Node(containing_block) }
	containing_styled := containing_node.as_node_with_style() or { return none }
	containing_used := state.try_get(containing_styled) or { return none }
	if line_index < 0 || line_index >= containing_used.line_boxes.len {
		return none
	}
	container_position := paint_cumulative_offset(containing_node, state, containing_used)
	line_box := containing_used.line_boxes[line_index]
	mut left := ?CSSPixels(none)
	mut right := ?CSSPixels(none)
	mut top := ?CSSPixels(none)
	mut direct_top := ?CSSPixels(none)
	mut height := CSSPixels.new(0)
	for fragment in line_box.fragments() {
		if !layout_debug_fragment_is_in_inline_subtree(fragment.layout_node(), node) {
			continue
		}
		relative_offset := inline_relative_offset(fragment.layout_node(), state)
		leading, trailing := inline_descendant_horizontal_edges(fragment.layout_node(), node, state)
		fragment_left := fragment.offset().x().plus(relative_offset.x()).minus(leading)
		fragment_right :=
			fragment.offset().x().plus(relative_offset.x()).plus(fragment.width()).plus(trailing)
		fragment_top := fragment.offset().y().plus(relative_offset.y())
		if direct_top == none {
			if target := fragment_inline_paintable_target(fragment.layout_node()) {
				if layout_nodes_same(target, node) {
					direct_top = fragment_top
				}
			}
		}
		if current := left {
			if fragment_left.raw_value() < current.raw_value() {
				left = fragment_left
			}
		} else {
			left = fragment_left
		}
		if current := right {
			if fragment_right.raw_value() > current.raw_value() {
				right = fragment_right
			}
		} else {
			right = fragment_right
		}
		if current := top {
			if fragment_top.raw_value() < current.raw_value() {
				top = fragment_top
			}
		} else {
			top = fragment_top
		}
		height = css_pixels_max(height, fragment.block_length())
	}
	left_value := left or {
		// A per-line paintable that only hosts an interrupting block has no
		// content of its own; LayoutState::commit() places it at the block
		// fragment's offset with an empty content size.
		for fragment in line_box.fragments() {
			if layout_debug_interrupting_block_is_in_inline_subtree(fragment.layout_node(), node) {
				relative_offset := inline_relative_offset(fragment.layout_node(), state)
				return LayoutDebugInlineMetrics{
					position: css.CSSPixelPoint.new(container_position.x().plus(fragment.offset().x()).plus(relative_offset.x()),
						container_position.y().plus(fragment.offset().y()).plus(relative_offset.y()))
					width: CSSPixels.new(0)
					height: CSSPixels.new(0)
				}
			}
		}
		return none
	}
	right_value := right or { return none }
	top_value := direct_top or { top or { return none } }
	return LayoutDebugInlineMetrics{
		position: css.CSSPixelPoint.new(container_position.x().plus(left_value), container_position.y().plus(top_value))
		width: right_value.minus(left_value)
		height: height
	}
}

struct LayoutDebugStackingContext {
	node       &Node = unsafe { nil }
	tree_index int
	parent     int = -1
}

fn layout_debug_used_z_index(node &Node) ?int {
	if !node.is_positioned() && !node.is_flex_item() && !node.is_grid_item() {
		return none
	}
	return node.computed_values().z_index()
}

fn dump_typed_stacking_context_tree(root &Node, state &LayoutState) string {
	mut contexts := [LayoutDebugStackingContext{
		node: root
	}]
	collect_typed_stacking_contexts(root, state, 0, mut contexts)
	mut lines := []string{}
	append_typed_stacking_context(0, contexts, state, 0, mut lines)
	return lines.join('\n').trim_right('\n')
}

fn collect_typed_stacking_contexts(node &Node, state &LayoutState, enclosing_index int, mut contexts []LayoutDebugStackingContext) {
	mut child_enclosing_index := enclosing_index
	if !layout_nodes_same(node, contexts[enclosing_index].node)
		&& layout_debug_paintable_count(node, state) > 0
		&& layout_debug_paintable_is_box(layout_debug_paintable_class(node))
		&& node.establishes_stacking_context() {
		child_enclosing_index = contexts.len
		contexts << LayoutDebugStackingContext{
			node: node
			tree_index: contexts.len
			parent: enclosing_index
		}
	}
	for child in node.children() {
		collect_typed_stacking_contexts(child, state, child_enclosing_index, mut contexts)
	}
}

fn layout_debug_stacking_context_children(context_index int, contexts []LayoutDebugStackingContext) []int {
	mut children := []int{}
	for index, context in contexts {
		if context.parent == context_index {
			children << index
		}
	}
	children.sort_with_compare(fn [contexts] (a &int, b &int) int {
		a_context := contexts[*a]
		b_context := contexts[*b]
		a_z_index := layout_debug_used_z_index(a_context.node) or { 0 }
		b_z_index := layout_debug_used_z_index(b_context.node) or { 0 }
		if a_z_index != b_z_index {
			return a_z_index - b_z_index
		}
		return a_context.tree_index - b_context.tree_index
	})
	return children
}

fn append_typed_stacking_context(context_index int, contexts []LayoutDebugStackingContext, state &LayoutState, depth int, mut lines []string) {
	context := contexts[context_index]
	node := context.node
	styled := node.as_node_with_style() or { return }
	used := state.try_get(styled) or { return }
	children := layout_debug_stacking_context_children(context_index, contexts)
	position := layout_offset_in_svg_user_space(node, state, used)
	rect := css.CSSPixelRect{
		x: position.x()
		y: position.y()
		width: used.content_width()
		height: used.content_height()
	}
	z_index := if value := layout_debug_used_z_index(node) { value.str() } else { 'auto' }
	mut line := '${' '.repeat(depth)}SC for ${layout_debug_node_description(node)} ${layout_debug_css_rect(rect)} (z-index: ${z_index})'
	computed := node.computed_values()
	if computed.transformations().len > 0 || computed.rotate() != none
		|| computed.translate() != none || computed.scale() != none {
		line += ', has_transform'
	}
	lines << line
	for child in children {
		append_typed_stacking_context(child, contexts, state, depth + 1, mut lines)
	}
}
