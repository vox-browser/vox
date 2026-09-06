// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// FormattingContext::compute_inline_containing_block_rect(). The returned
// padding-box rectangle is expressed in the coordinate system of the Box that
// the rest of layout stores as the abspos containing block.
fn compute_inline_containing_block_rect(mut state LayoutState, inline_node &InlineNode, abspos_containing_block &Box) ?css.CSSPixelRect {
	inline_as_node := unsafe { &Node(inline_node) }
	mut block_container := ?&Node(none)
	mut ancestor := inline_as_node.parent()
	for ancestor != none {
		candidate := ancestor or { break }
		if candidate.is_block_container() || candidate.display().is_flex_inside()
			|| candidate.display().is_grid_inside() {
			block_container = candidate
			break
		}
		ancestor = candidate.parent()
	}
	container := block_container or { return none }
	container_styled := container.as_node_with_style() or { return none }
	container_state := state.try_get(container_styled) or { return none }
	mut bounding_rect := ?css.CSSPixelRect(none)
	for line_box in container_state.line_boxes {
		for fragment in line_box.fragments_ {
			mut belongs_to_inline := false
			mut fragment_ancestor := ?&Node(fragment.layout_node())
			for fragment_ancestor != none {
				candidate := fragment_ancestor or { break }
				if candidate == inline_as_node {
					belongs_to_inline = true
					break
				}
				if candidate == container {
					break
				}
				fragment_ancestor = candidate.parent()
			}
			if !belongs_to_inline {
				continue
			}
			fragment_rect := css.CSSPixelRect{
				x:      fragment.offset().x()
				y:      fragment.offset().y()
				width:  fragment.width()
				height: fragment.height()
			}
			if existing := bounding_rect {
				left := css_pixels_min(existing.left(), fragment_rect.left())
				top := css_pixels_min(existing.top(), fragment_rect.top())
				right := css_pixels_max(existing.right(), fragment_rect.right())
				bottom := css_pixels_max(existing.bottom(), fragment_rect.bottom())
				bounding_rect = css.CSSPixelRect{
					x:      left
					y:      top
					width:  right.minus(left)
					height: bottom.minus(top)
				}
			} else {
				bounding_rect = fragment_rect
			}
		}
	}
	mut rect := bounding_rect or { return none }
	if inline_styled := inline_as_node.as_node_with_style() {
		if inline_state := state.try_get(inline_styled) {
			rect.x = rect.x.minus(inline_state.padding_left)
			rect.y = rect.y.minus(inline_state.padding_top)
			rect.width = rect.width.plus(inline_state.padding_left).plus(inline_state.padding_right)
			rect.height =
				rect.height.plus(inline_state.padding_top).plus(inline_state.padding_bottom)
		}
	}
	mut offset := CSSPixelPoint.new(CSSPixels.new(0), CSSPixels.new(0))
	mut current := ?&Node(container)
	abspos_node := unsafe { &Node(abspos_containing_block) }
	for current != none {
		candidate := current or { break }
		if candidate == abspos_node {
			break
		}
		if styled := candidate.as_node_with_style() {
			if used := state.try_get(styled) {
				offset = offset.plus(used.offset)
			}
		}
		current = candidate.parent()
	}
	rect.x = rect.x.plus(offset.x())
	rect.y = rect.y.plus(offset.y())
	return rect
}

fn resolved_inset(node &Node, property_id css.PropertyID, basis CSSPixels) ?CSSPixels {
	if property_is_auto(node.computed_values(), property_id) {
		return none
	}
	return resolve_layout_size(node, node.computed_values().size_value(property_id), basis)
}

fn layout_absolutely_positioned_box(mut state LayoutState, box &Node) {
	containing_box := box.containing_block() or { return }
	containing_styled := unsafe { &Node(containing_box) }.as_node_with_style() or { return }
	mut containing_state := state.get_mutable(containing_styled)
	styled := box.as_node_with_style() or { return }
	computed := styled.computed_values()
	mut box_state := state.get_mutable(styled)
	box_state.set_containing_block_used_values(containing_state)
	// FormattingContext::resolve_abspos_containing_block_info(). The ordinary
	// containing rectangle is the positioned ancestor's padding box, expressed
	// relative to its content box. Grid replaces it with the resolved grid area.
	grid_containing_rect := box_state.abspos_containing_block_rect()
	containing_rect := if inline_containing_block := box.inline_containing_block_if_applicable() {
		compute_inline_containing_block_rect(mut state, inline_containing_block, containing_box) or {
			css.CSSPixelRect.new(-containing_state.padding_left.to_double(),
				-containing_state.padding_top.to_double(),
				containing_state.padding_left.plus(containing_state.content_width()).plus(containing_state.padding_right).to_double(),
				containing_state.padding_top.plus(containing_state.content_height()).plus(containing_state.padding_bottom).to_double())
		}
	} else {
		grid_containing_rect or {
			css.CSSPixelRect.new(-containing_state.padding_left.to_double(),
				-containing_state.padding_top.to_double(),
				containing_state.padding_left.plus(containing_state.content_width()).plus(containing_state.padding_right).to_double(),
				containing_state.padding_top.plus(containing_state.content_height()).plus(containing_state.padding_bottom).to_double())
		}
	}
	containing_width := containing_rect.width
	containing_height := containing_rect.height
	resolve_box_model_edges(computed, mut box_state, containing_width.to_double())

	left := resolved_inset(box, .left, containing_width)
	right := resolved_inset(box, .right, containing_width)
	top := resolved_inset(box, .top, containing_height)
	bottom := resolved_inset(box, .bottom, containing_height)
	mut forced_width := resolve_layout_content_size(box, computed.size_value(.width),
		containing_width, box_state, true)
	mut forced_height := resolve_layout_content_size(box, computed.size_value(.height),
		containing_height, box_state, false)
	preferred_width := computed.size_value(.width)
	preferred_height := computed.size_value(.height)
	// FormattingContext::compute_width_for_absolutely_positioned_element() and
	// compute_height_for_absolutely_positioned_element() both select the replaced
	// algorithm through box_is_sized_as_replaced_element(), so a non-replaced box
	// with a preferred aspect ratio and one specified axis is sized by it too.
	abspos_available_space := AvailableSpace.new(AvailableSize.make_definite(containing_width),
		AvailableSize.make_definite(containing_height))
	if box_is_sized_as_replaced_element(state, box, abspos_available_space) {
		replaced := box.as_box() or { return }
		size := compute_replaced_size(replaced, abspos_available_space)
		if forced_width == none {
			forced_width = size.width()
		}
		if forced_height == none {
			forced_height = size.height()
		}
	}
	if forced_width == none && preferred_width.is_intrinsic_sizing_constraint() {
		if box_as_box := box.as_box() {
			forced_width = intrinsic_width_for_size(mut state, box_as_box, preferred_width,
				AvailableSize.make_definite(containing_width))
		}
	}
	if forced_width == none && preferred_width.is_auto() && !box.is_table_wrapper() {
		if left_value := left {
			if right_value := right {
				forced_width = css_pixels_max(CSSPixels.new(0), css_px(
					containing_width.to_double() - left_value.to_double() -
					right_value.to_double() -
					flex_or_grid_item_outer_inline_edges(box_state).to_double()))
			}
		}
	}
	if forced_width == none {
		if box_as_box := box.as_box() {
			// CSS 2.2 10.3.7 rules 1 and 3 use the space left by a
			// specified inset as the stretch-fit limit for shrink-to-fit.
			mut fit_available_width := containing_width
			if left_value := left {
				fit_available_width = fit_available_width.minus(left_value)
			}
			if right_value := right {
				fit_available_width = fit_available_width.minus(right_value)
			}
			fit_available_width = css_pixels_max(CSSPixels.new(0), fit_available_width)
			forced_width = calculate_fit_content_width(mut state, box_as_box,
				AvailableSize.make_definite(fit_available_width))
		}
	}
	if forced_height == none && preferred_height.is_auto() && !box.is_table_wrapper() {
		if top_value := top {
			if bottom_value := bottom {
				forced_height = css_pixels_max(CSSPixels.new(0), css_px(
					containing_height.to_double() - top_value.to_double() -
					bottom_value.to_double() -
					flex_or_grid_item_outer_block_edges(box_state).to_double()))
			}
		}
	}
	if width := forced_width {
		forced_width = clamp_layout_content_size(box, width, containing_width, box_state, true)
	}
	if height := forced_height {
		forced_height = clamp_layout_content_size(box, height, containing_height, box_state, false)
	}
	box_state = layout_independent_child(mut state, box, mut containing_state, containing_width,
		containing_height, forced_width, forced_height)

	// CSS 2.2 10.3.7: with both insets specified and a definite width,
	// auto margins absorb the remaining space (equally when both are auto).
	if left_value := left {
		if right_value := right {
			left_auto_margin := property_is_auto(computed, .margin_left)
			right_auto_margin := property_is_auto(computed, .margin_right)
			remaining := containing_width.minus(left_value).minus(right_value).minus(box_state.border_box_width()).minus(if left_auto_margin {
				CSSPixels.new(0)
			} else {
				box_state.margin_left
			}).minus(if right_auto_margin {
				CSSPixels.new(0)
			} else {
				box_state.margin_right
			})
			if left_auto_margin && right_auto_margin {
				box_state.margin_left = CSSPixels.from_raw(remaining.raw_value() / 2)
				box_state.margin_right = CSSPixels.from_raw(remaining.raw_value() / 2)
			} else if left_auto_margin {
				box_state.margin_left = remaining
			} else if right_auto_margin {
				box_state.margin_right = remaining
			}
		}
	}
	// The table wrapper is the abspos principal box. Its auto block size is the
	// laid-out table border box, and auto vertical margins absorb the remaining
	// space when both block-axis insets are specified.
	if top_value := top {
		if bottom_value := bottom {
			top_auto_margin := property_is_auto(computed, .margin_top)
			bottom_auto_margin := property_is_auto(computed, .margin_bottom)
			remaining := containing_height.minus(top_value).minus(bottom_value).minus(box_state.border_box_height()).minus(if top_auto_margin {
				CSSPixels.new(0)
			} else {
				box_state.margin_top
			}).minus(if bottom_auto_margin {
				CSSPixels.new(0)
			} else {
				box_state.margin_bottom
			})
			if top_auto_margin && bottom_auto_margin {
				box_state.margin_top = CSSPixels.from_raw(remaining.raw_value() / 2)
				box_state.margin_bottom = CSSPixels.from_raw(remaining.raw_value() / 2)
			} else if top_auto_margin {
				box_state.margin_top = remaining
			} else if bottom_auto_margin {
				box_state.margin_bottom = remaining
			}
		}
	}

	// FormattingContext::layout_absolutely_positioned_element(): the IFC/BFC which calculated the
	// static position can use a different containing block from the absolute-positioned box.
	mut static_position := box_state.static_position()
	if grid_containing_rect == none {
		if static_position_box := box.static_position_containing_block() {
			if voidptr(static_position_box) != voidptr(containing_box) {
				if static_styled := unsafe { &Node(static_position_box) }.as_node_with_style() {
					static_used := state.get(static_styled)
					offset :=
						static_used.cumulative_offset().minus(containing_state.cumulative_offset())
					static_position = static_position.plus(offset)
				}
			}
		}
	}

	mut x := CSSPixels.new(0)
	if left_value := left {
		x = containing_rect.x.plus(left_value).plus(box_state.margin_box_left())
	} else if right_value := right {
		x =
			containing_rect.x.plus(containing_width).minus(right_value).minus(box_state.margin_box_right()).minus(box_state.content_width())
	} else {
		x = static_position.x().plus(box_state.margin_box_left())
	}
	mut y := CSSPixels.new(0)
	if top_value := top {
		y = containing_rect.y.plus(top_value).plus(box_state.margin_box_top())
	} else if bottom_value := bottom {
		y =
			containing_rect.y.plus(containing_height).minus(bottom_value).minus(box_state.margin_box_bottom()).minus(box_state.content_height())
	} else {
		y = static_position.y().plus(box_state.margin_box_top())
	}
	box_state.set_content_offset(CSSPixelPoint.new(x, y))
}

fn layout_absolutely_positioned_descendants(mut state LayoutState, root &Node) {
	if root.is_absolutely_positioned() {
		layout_absolutely_positioned_box(mut state, root)
	}
	for child in root.children() {
		layout_absolutely_positioned_descendants(mut state, child)
	}
}
