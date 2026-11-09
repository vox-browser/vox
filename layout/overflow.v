// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// Translation of LayoutState.cpp's scrollable-overflow commit pass.
type ContainedLayoutBoxes = map[u32][]&Node

struct PhysicalOverflowDirections {
	horizontal_axis_is_positive bool = true
	vertical_axis_is_positive   bool = true
}

fn measure_document_scrollable_overflow(mut state LayoutState, root &Node) {
	// LayoutState.cpp builds a hash map from each containing block to the boxes
	// it contains. Keeping the same shape is important for large flat documents:
	// scanning one document-wide list once per box makes this pass quadratic.
	mut contained_boxes := ContainedLayoutBoxes{}
	collect_contained_layout_boxes(root, state, mut contained_boxes)
	measure_scrollable_overflow_for_subtree(mut state, root, contained_boxes)
}

fn collect_contained_layout_boxes(node &Node, state &LayoutState, mut boxes ContainedLayoutBoxes) {
	if node.is_box() {
		if styled := node.as_node_with_style() {
			if used := state.try_get(styled) {
				if !used.svg_rendering_disabled() {
					if containing_block := node.containing_block() {
						containing_block_node := unsafe { &Node(containing_block) }
						if containing_block_styled := containing_block_node.as_node_with_style() {
							key := containing_block_styled.layout_index()
							mut contained := boxes[key] or { []&Node{} }
							contained << node
							boxes[key] = contained
						}
					}
				}
			}
		}
	}
	for child in node.children() {
		collect_contained_layout_boxes(child, state, mut boxes)
	}
}

fn measure_scrollable_overflow_for_subtree(mut state LayoutState, node &Node, contained_boxes ContainedLayoutBoxes) {
	if node.is_box() {
		measure_scrollable_overflow(mut state, node, contained_boxes)
	}
	for child in node.children() {
		measure_scrollable_overflow_for_subtree(mut state, child, contained_boxes)
	}
}

fn measure_scrollable_overflow(mut state LayoutState, box &Node, contained_boxes ContainedLayoutBoxes) css.CSSPixelRect {
	styled := box.as_node_with_style() or { return css.CSSPixelRect{} }
	used := state.try_get(styled) or { return css.CSSPixelRect{} }
	if existing := used.scrollable_overflow_rect() {
		return existing
	}
	if used.svg_rendering_disabled() {
		return css.CSSPixelRect{}
	}

	position := layout_offset_in_svg_user_space(box, state, used)
	content_box := css.CSSPixelRect{
		x: position.x()
		y: position.y()
		width: used.content_width()
		height: used.content_height()
	}
	padding_box := css.CSSPixelRect{
		x: position.x().minus(used.padding_left)
		y: position.y().minus(used.padding_top)
		width: used.content_width().plus(used.padding_left).plus(used.padding_right)
		height: used.content_height().plus(used.padding_top).plus(used.padding_bottom)
	}
	mut scrollable_overflow_rect := padding_box
	mut in_flow_and_floated_content_bounds := content_box
	// Replaced and nested SVG viewports clip their content to the viewport.
	if box.is_svg_svg_box() {
		mut mutable_used := state.mutable_box_values(styled)
		mutable_used.scrollable_overflow_rect_ = scrollable_overflow_rect
		mutable_used.has_scrollable_overflow_ = false
		return scrollable_overflow_rect
	}

	// All line fragments which remain on this BlockContainer's PaintableWithLines.
	if box.is_block_container() {
		for line_box in used.line_boxes {
			for fragment in line_box.fragments() {
				if fragment.is_fully_truncated() {
					continue
				}
				if fragment_inline_paintable_target(fragment.layout_node()) != none {
					continue
				}
				fragment_position := css_pixel_point_add(css_pixel_point_add(position, fragment.offset()), inline_relative_offset(fragment.layout_node(), state))
				fragment_rect := css.CSSPixelRect{
					x: fragment_position.x()
					y: fragment_position.y()
					width: fragment.width()
					height: fragment.height()
				}
				scrollable_overflow_rect = overflow_rect_united(scrollable_overflow_rect, fragment_rect)
				in_flow_and_floated_content_bounds = overflow_rect_united(in_flow_and_floated_content_bounds, fragment_rect)
			}
		}
	}
	overflow_directions := physical_overflow_directions(box)

	if contained := contained_boxes[styled.layout_index()] {
		for child in contained {
			if child.is_fixed_position() {
				continue
			}
			if child_styled := child.as_node_with_style() {
				if child_used := state.try_get(child_styled) {
					if child_used.is_invisible_for_line_clamp() {
						continue
					}
				}
			}
			raw_child_rect := overflow_box_border_rect(child, state) or { continue }
			child_rect := overflow_transformed_border_rect(child, state, raw_child_rect)
			wholly_in_unreachable_horizontal_axis := if overflow_directions.horizontal_axis_is_positive {
				child_rect.right().raw_value() < padding_box.left().raw_value()
			} else {
				child_rect.left().raw_value() > padding_box.right().raw_value()
			}
			wholly_in_unreachable_vertical_axis := if overflow_directions.vertical_axis_is_positive {
				child_rect.bottom().raw_value() < padding_box.top().raw_value()
			} else {
				child_rect.top().raw_value() > padding_box.bottom().raw_value()
			}
			// Alignment bounds use the normal-flow margin box, before relative
			// positioning, and remain relevant outside the reachable scroll area.
			if !child.is_absolutely_positioned() {
				if child_style := child.as_node_with_style() {
					if child_used := state.try_get(child_style) {
						dx := if child.computed_values().position() == .relative { child_used.inset_left } else { CSSPixels.new(0) }
						dy := if child.computed_values().position() == .relative { child_used.inset_top } else { CSSPixels.new(0) }
						// Normal block width balancing may put overconstraint into
						// the used end margin. Overflow retains the authored margin.
						basis := if box.computed_values().writing_mode() == .horizontal_tb { used.content_width() } else { used.content_height() }
						edges := child.computed_values().resolved_box_model_edges(basis.to_double())
						left_margin := if property_is_auto(child.computed_values(),.margin_left) { child_used.margin_left } else { edges.margin_left }
						right_margin := if property_is_auto(child.computed_values(),.margin_right) { child_used.margin_right } else { edges.margin_right }
      bottom_margin := child_used.collapsed_flow_margin_bottom() or { child_used.margin_bottom }
						bounds := css.CSSPixelRect{
							x:raw_child_rect.x.minus(dx).minus(left_margin)
							y:raw_child_rect.y.minus(dy).minus(child_used.margin_top)
							width:raw_child_rect.width.plus(left_margin).plus(right_margin)
							height:raw_child_rect.height.plus(child_used.margin_top).plus(bottom_margin)
						}
						in_flow_and_floated_content_bounds = overflow_rect_united(in_flow_and_floated_content_bounds,bounds)
					}
				}
			}
			// An unreachable box in one axis can still enlarge the other axis.
			// Zero area in one dimension likewise preserves the other extent.
			if !overflow_rect_is_empty(child_rect) {
				if !wholly_in_unreachable_horizontal_axis { scrollable_overflow_rect = overflow_rect_united_horizontally(scrollable_overflow_rect,child_rect) }
				if !wholly_in_unreachable_vertical_axis { scrollable_overflow_rect = overflow_rect_united_vertically(scrollable_overflow_rect,child_rect) }
			}
			if child.has_layout_containment() || child.has_paint_containment() {
				continue
			}
			if child.computed_values().overflow_x() == .visible
				|| child.computed_values().overflow_y() == .visible {
				child_overflow := measure_scrollable_overflow(mut state, child, contained_boxes)
				if !overflow_rect_is_empty(child_overflow) {
					if child.computed_values().overflow_x() == .visible && !wholly_in_unreachable_horizontal_axis {
						scrollable_overflow_rect = overflow_rect_united_horizontally(scrollable_overflow_rect, child_overflow)
					}
					if child.computed_values().overflow_y() == .visible && !wholly_in_unreachable_vertical_axis {
						scrollable_overflow_rect = overflow_rect_united_vertically(scrollable_overflow_rect, child_overflow)
					}
				}
			}
		}
	}

	if box.is_scroll_container() {
		padded_content_bounds := padding_inflated_scrollable_overflow(content_box, padding_box, in_flow_and_floated_content_bounds, used, overflow_directions)
		scrollable_overflow_rect = overflow_rect_united(scrollable_overflow_rect, padded_content_bounds)
	}

	// Content past the scroll origin is unreachable. Which physical edge is the
	// origin depends on writing mode, direction, and flex axis reversal.
	left := if overflow_directions.horizontal_axis_is_positive {
		css_pixels_max(scrollable_overflow_rect.left(), padding_box.left())
	} else {
		scrollable_overflow_rect.left()
	}
	top := if overflow_directions.vertical_axis_is_positive {
		css_pixels_max(scrollable_overflow_rect.top(), padding_box.top())
	} else {
		scrollable_overflow_rect.top()
	}
	right := if overflow_directions.horizontal_axis_is_positive {
		scrollable_overflow_rect.right()
	} else {
		css_pixels_min(scrollable_overflow_rect.right(), padding_box.right())
	}
	bottom := if overflow_directions.vertical_axis_is_positive {
		scrollable_overflow_rect.bottom()
	} else {
		css_pixels_min(scrollable_overflow_rect.bottom(), padding_box.bottom())
	}
	scrollable_overflow_rect = css.CSSPixelRect{
		x: left
		y: top
		width: css_pixels_max(right.minus(left), CSSPixels.new(0))
		height: css_pixels_max(bottom.minus(top), CSSPixels.new(0))
	}
	has_scrollable_overflow := box.is_scroll_container()
		&& !overflow_rect_contains(padding_box, scrollable_overflow_rect)

	mut mutable_used := state.mutable_box_values(styled)
	mutable_used.scrollable_overflow_rect_ = scrollable_overflow_rect
	mutable_used.has_scrollable_overflow_ = has_scrollable_overflow
	return scrollable_overflow_rect
}

fn physical_overflow_directions(box &Node) PhysicalOverflowDirections {
	computed := box.computed_values()
	writing_mode := computed.writing_mode()
	inline_is_horizontal := layout_inline_axis_is_horizontal(writing_mode)
	inline_is_reverse := layout_inline_axis_is_reverse(writing_mode, computed.direction())
	block_is_reverse := layout_block_axis_is_reverse(writing_mode)
	mut horizontal_is_reverse := if inline_is_horizontal {
		inline_is_reverse
	} else {
		block_is_reverse
	}
	mut vertical_is_reverse := if inline_is_horizontal {
		block_is_reverse
	} else {
		inline_is_reverse
	}
	if box.display().is_flex_inside() {
		direction := computed.effective_flex_direction()
		main_is_horizontal := if direction in [.row, .row_reverse] {
			inline_is_horizontal
		} else {
			!inline_is_horizontal
		}
		if direction in [.row_reverse, .column_reverse] {
			if main_is_horizontal {
				horizontal_is_reverse = !horizontal_is_reverse
			} else {
				vertical_is_reverse = !vertical_is_reverse
			}
		}
		if computed.flex_wrap() == .wrap_reverse {
			if main_is_horizontal {
				vertical_is_reverse = !vertical_is_reverse
			} else {
				horizontal_is_reverse = !horizontal_is_reverse
			}
		}
	}
	return PhysicalOverflowDirections{
		horizontal_axis_is_positive: !horizontal_is_reverse
		vertical_axis_is_positive: !vertical_is_reverse
	}
}

fn layout_inline_axis_is_horizontal(writing_mode css.WritingMode) bool {
	return writing_mode == .horizontal_tb
}

fn layout_inline_axis_is_reverse(writing_mode css.WritingMode, direction css.Direction) bool {
	return match writing_mode {
		.horizontal_tb, .vertical_rl, .vertical_lr, .sideways_rl { direction == .rtl }
		.sideways_lr { direction == .ltr }
	}
}

fn layout_block_axis_is_reverse(writing_mode css.WritingMode) bool {
	return writing_mode in [.vertical_rl, .sideways_rl]
}

fn padding_inflated_scrollable_overflow(content_box css.CSSPixelRect, padding_box css.CSSPixelRect, in_flow_bounds css.CSSPixelRect, used &UsedValues, directions PhysicalOverflowDirections) css.CSSPixelRect {
	mut left := in_flow_bounds.left()
	mut top := in_flow_bounds.top()
	mut right := in_flow_bounds.right()
	mut bottom := in_flow_bounds.bottom()
	if left.raw_value() < content_box.left().raw_value()
		|| right.raw_value() > content_box.right().raw_value() {
		if directions.horizontal_axis_is_positive
			&& right.raw_value() > content_box.right().raw_value() {
			right = right.plus(used.padding_right)
		} else if !directions.horizontal_axis_is_positive {
			left = css_pixels_min(left, padding_box.left()).minus(used.padding_left)
		}
	}
	if top.raw_value() < content_box.top().raw_value()
		|| bottom.raw_value() > content_box.bottom().raw_value() {
		if directions.vertical_axis_is_positive
			&& bottom.raw_value() > content_box.bottom().raw_value() {
			bottom = bottom.plus(used.padding_bottom)
		} else if !directions.vertical_axis_is_positive {
			top = css_pixels_min(top, padding_box.top()).minus(used.padding_top)
		}
	}
	return css.CSSPixelRect{
		x: left
		y: top
		width: right.minus(left)
		height: bottom.minus(top)
	}
}

fn overflow_box_border_rect(node &Node, state &LayoutState) ?css.CSSPixelRect {
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	position := layout_offset_in_svg_user_space(node, state, used)
	border_left := used.border_left_collapsed()
	border_right := used.border_right_collapsed()
	border_top := used.border_top_collapsed()
	border_bottom := used.border_bottom_collapsed()
	left := border_left.plus(used.padding_left)
	top := border_top.plus(used.padding_top)
	return css.CSSPixelRect{
		x: position.x().minus(left)
		y: position.y().minus(top)
		width: used.content_width().plus(left).plus(used.padding_right).plus(border_right)
		height: used.content_height().plus(top).plus(used.padding_bottom).plus(border_bottom)
	}
}

fn overflow_rect_is_empty(rect css.CSSPixelRect) bool {
	return rect.width.raw_value() <= 0 && rect.height.raw_value() <= 0
}

fn overflow_rect_contains(outer css.CSSPixelRect, inner css.CSSPixelRect) bool {
	return inner.left().raw_value() >= outer.left().raw_value()
		&& inner.top().raw_value() >= outer.top().raw_value()
		&& inner.right().raw_value() <= outer.right().raw_value()
		&& inner.bottom().raw_value() <= outer.bottom().raw_value()
}

fn overflow_rect_united(a css.CSSPixelRect, b css.CSSPixelRect) css.CSSPixelRect {
	left := css_pixels_min(a.left(), b.left())
	top := css_pixels_min(a.top(), b.top())
	right := css_pixels_max(a.right(), b.right())
	bottom := css_pixels_max(a.bottom(), b.bottom())
	return css.CSSPixelRect{
		x: left
		y: top
		width: right.minus(left)
		height: bottom.minus(top)
	}
}

fn overflow_rect_united_horizontally(a css.CSSPixelRect, b css.CSSPixelRect) css.CSSPixelRect {
	left := css_pixels_min(a.left(), b.left())
	right := css_pixels_max(a.right(), b.right())
	return css.CSSPixelRect{
		x: left
		y: a.y
		width: right.minus(left)
		height: a.height
	}
}

fn overflow_rect_united_vertically(a css.CSSPixelRect, b css.CSSPixelRect) css.CSSPixelRect {
	top := css_pixels_min(a.top(), b.top())
	bottom := css_pixels_max(a.bottom(), b.bottom())
	return css.CSSPixelRect{
		x: a.x
		y: top
		width: a.width
		height: bottom.minus(top)
	}
}

// Transform overflow includes both the pre-transform and transformed bounds.
fn overflow_transformed_border_rect(node &Node, state &LayoutState, rect css.CSSPixelRect) css.CSSPixelRect {
 computed := node.computed_values()
 if computed_transform_is_none(computed) { return rect }
 styled := node.as_node_with_style() or { return rect }
 used := state.try_get(styled) or { return rect }
 position := layout_offset_in_svg_user_space(node,state,used)
 reference := paintable_box_transform_reference_box(node,computed,used,position,state)
 matrix := resolved_computed_transform_4x4_matrix(computed,reference.x,reference.y,reference.width,reference.height)
 affine := css.project_plane_to_affine_transform(matrix) or { return rect }
 mut left,mut right := rect.left().to_double(),rect.right().to_double()
 mut top,mut bottom := rect.top().to_double(),rect.bottom().to_double()
 for x in [rect.left().to_double(),rect.right().to_double()] {
  for y in [rect.top().to_double(),rect.bottom().to_double()] {
   tx,ty := affine[0]*x+affine[2]*y+affine[4],affine[1]*x+affine[3]*y+affine[5]
   if tx<left { left=tx };if tx>right { right=tx }
   if ty<top { top=ty };if ty>bottom { bottom=ty }
  }
 }
 return css.CSSPixelRect.new(left,top,right-left,bottom-top)
}
