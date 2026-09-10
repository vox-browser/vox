// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// Translation of LayoutState.cpp's scrollable-overflow commit pass.
type ContainedLayoutBoxes = map[u32][]&Node

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

	position := paint_cumulative_offset(box, state, used)
	padding_box := css.CSSPixelRect{
		x: position.x().minus(used.padding_left)
		y: position.y().minus(used.padding_top)
		width: used.content_width().plus(used.padding_left).plus(used.padding_right)
		height: used.content_height().plus(used.padding_top).plus(used.padding_bottom)
	}
	mut scrollable_overflow_rect := padding_box

	// All line fragments which remain on this BlockContainer's PaintableWithLines.
	if box.is_block_container() {
		for line_box in used.line_boxes {
			for fragment in line_box.fragments() {
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
			}
		}
	}
	mut content_overflow_rect := scrollable_overflow_rect

	if contained := contained_boxes[styled.layout_index()] {
		for child in contained {
			if child.is_fixed_position() {
				continue
			}
			child_rect := overflow_box_border_rect(child, state) or { continue }
			if child_rect.bottom().raw_value() < 0 || child_rect.right().raw_value() < 0 {
				continue
			}
			if !overflow_rect_is_empty(child_rect) {
				scrollable_overflow_rect = overflow_rect_united(scrollable_overflow_rect, child_rect)
				content_overflow_rect = overflow_rect_united(content_overflow_rect, child_rect)
			}
			if child.has_layout_containment() || child.has_paint_containment() {
				continue
			}
			if child.computed_values().overflow_x() == .visible
				|| child.computed_values().overflow_y() == .visible {
				child_overflow := measure_scrollable_overflow(mut state, child, contained_boxes)
				if !overflow_rect_is_empty(child_overflow) {
					if child.computed_values().overflow_x() == .visible {
						scrollable_overflow_rect = overflow_rect_united_horizontally(scrollable_overflow_rect, child_overflow)
					}
					if child.computed_values().overflow_y() == .visible {
						scrollable_overflow_rect = overflow_rect_united_vertically(scrollable_overflow_rect, child_overflow)
					}
				}
			}
		}
	}

	mut has_scrollable_overflow := !overflow_rect_contains(padding_box, scrollable_overflow_rect)
		&& box.is_scroll_container()
	if has_scrollable_overflow {
		padded_content_height := content_overflow_rect.height.plus(used.padding_bottom)
		if padded_content_height.raw_value() > scrollable_overflow_rect.height.raw_value() {
			scrollable_overflow_rect.height = padded_content_height
		}
	}

	if scrollable_overflow_rect.x.raw_value() < padding_box.x.raw_value()
		|| scrollable_overflow_rect.y.raw_value() < padding_box.y.raw_value() {
		negative_x := css_pixels_min(scrollable_overflow_rect.x.minus(padding_box.x), CSSPixels.new(0))
		negative_y := css_pixels_min(scrollable_overflow_rect.y.minus(padding_box.y), CSSPixels.new(0))
		scrollable_overflow_rect.width = css_pixels_max(scrollable_overflow_rect.width.plus(negative_x), CSSPixels.new(0))
		scrollable_overflow_rect.height = css_pixels_max(scrollable_overflow_rect.height.plus(negative_y), CSSPixels.new(0))
		scrollable_overflow_rect.x = css_pixels_max(scrollable_overflow_rect.x, padding_box.x)
		scrollable_overflow_rect.y = css_pixels_max(scrollable_overflow_rect.y, padding_box.y)
		has_scrollable_overflow = !overflow_rect_contains(padding_box, scrollable_overflow_rect)
			&& box.is_scroll_container()
	}

	mut mutable_used := state.get_mutable(styled)
	mutable_used.scrollable_overflow_rect_ = scrollable_overflow_rect
	mutable_used.has_scrollable_overflow_ = has_scrollable_overflow
	return scrollable_overflow_rect
}

fn overflow_box_border_rect(node &Node, state &LayoutState) ?css.CSSPixelRect {
	styled := node.as_node_with_style() or { return none }
	used := state.try_get(styled) or { return none }
	position := paint_cumulative_offset(node, state, used)
	border_left := if used.use_collapsing_borders_model() {
		css.css_pixels_round(used.border_left.divided_by_float(2.0))
	} else {
		used.border_left
	}
	border_right := if used.use_collapsing_borders_model() {
		css.css_pixels_round(used.border_right.divided_by_float(2.0))
	} else {
		used.border_right
	}
	border_top := if used.use_collapsing_borders_model() {
		css.css_pixels_round(used.border_top.divided_by_float(2.0))
	} else {
		used.border_top
	}
	border_bottom := if used.use_collapsing_borders_model() {
		css.css_pixels_round(used.border_bottom.divided_by_float(2.0))
	} else {
		used.border_bottom
	}
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
	return rect.width.raw_value() <= 0 || rect.height.raw_value() <= 0
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
