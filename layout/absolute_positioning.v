// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom

fn anchor_style_value_for_inset(computed &css.ComputedValues, property_id css.PropertyID) ?css.AnchorStyleValue {
	value := unsafe { &css.ComputedProperties(computed) }.typed_property_value(property_id) or {
		return none
	}
	if value is css.AnchorStyleValue {
		return value
	}
	return none
}

struct AnchorElementLookupContext {
	box              &Node = unsafe { nil }
	containing_block &Box = unsafe { nil }
	state            &LayoutState = unsafe { nil }
}

fn is_acceptable_anchor_element(target voidptr, candidate &dom.Element) bool {
	if target == unsafe { nil } {
		return false
	}
	context := unsafe { &AnchorElementLookupContext(target) }
	dom_layout_node := candidate.as_node().unsafe_layout_node() or { return false }
	if dom_layout_node.real_layout_handle() == unsafe { nil } {
		return false
	}
	anchor_node := unsafe { &Node(dom_layout_node.real_layout_handle()) }
	if layout_nodes_same(anchor_node, context.box) || anchor_node.as_box() == none {
		return false
	}
	anchor_styled := anchor_node.as_node_with_style() or { return false }
	if context.state.try_get(anchor_styled) == none {
		return false
	}
	mut ancestor := anchor_node.containing_block()
	for ancestor != none {
		current := ancestor or { break }
		if layout_nodes_same(unsafe { &Node(current) }, unsafe { &Node(context.containing_block) }) {
			return true
		}
		ancestor = unsafe { &Node(current) }.containing_block()
	}
	return false
}

// https://drafts.csswg.org/css-anchor-position-1/#resolving-anchor
fn resolve_anchor_rect(state &LayoutState, box &Node, containing_state &UsedValues, anchor css.AnchorStyleValue) ?css.CSSPixelRect {
	styled := box.as_node_with_style() or { return none }
	name := anchor.anchor_name() or { styled.computed_values().position_anchor() or { return none } }
	dom_node := box.dom_node() or { return none }
	element := dom_node.as_element() or { return none }
	containing_block := box.containing_block() or { return none }
	lookup_context := AnchorElementLookupContext{
		box: box
		containing_block: containing_block
		state: state
	}
	anchor_element := box.document().element_by_anchor_name(name, element.as_node(),
		dom.AnchorNameMapFilter{
			target: voidptr(&lookup_context)
			callback: is_acceptable_anchor_element
		}) or { return none }
	dom_anchor_layout_node := anchor_element.as_node().unsafe_layout_node() or { return none }
	if dom_anchor_layout_node.real_layout_handle() == unsafe { nil } {
		return none
	}
	anchor_layout_node := unsafe { &Node(dom_anchor_layout_node.real_layout_handle()) }
	if anchor_layout_node.as_box() == none {
		return none
	}
	anchor_styled := anchor_layout_node.as_node_with_style() or { return none }
	anchor_state := state.try_get(anchor_styled) or { return none }
	anchor_border_box_origin := anchor_state.cumulative_offset().minus(css.CSSPixelPoint.new(anchor_state.border_box_left(), anchor_state.border_box_top()))
	containing_block_padding_box_origin := containing_state.cumulative_offset().minus(css.CSSPixelPoint.new(containing_state.padding_left, containing_state.padding_top))
	origin := anchor_border_box_origin.minus(containing_block_padding_box_origin)
	return css.CSSPixelRect{
		x: origin.x()
		y: origin.y()
		width: anchor_state.border_box_width()
		height: anchor_state.border_box_height()
	}
}

fn resolve_anchor_side(state &LayoutState, box &Node, containing_box &Node, containing_state &UsedValues, anchor css.AnchorStyleValue, is_from_end bool, is_horizontal_axis bool) ?CSSPixels {
	rect := resolve_anchor_rect(state, box, containing_state, anchor) or {
		return none
	}
	side := anchor.anchor_side()
	if side.is_keyword() {
		return match side.to_keyword() {
			.top {
				if is_horizontal_axis { none } else { rect.top() }
			}
			.bottom {
				if is_horizontal_axis { none } else { rect.bottom() }
			}
			.left {
				if is_horizontal_axis { rect.left() } else { none }
			}
			.right {
				if is_horizontal_axis { rect.right() } else { none }
			}
			.center {
				if is_horizontal_axis {
					rect.left().plus(rect.width.divided_by_float(2))
				} else {
					rect.top().plus(rect.height.divided_by_float(2))
				}
			}
			.start, .end_ {
				is_start := side.to_keyword() == .start
				if is_horizontal_axis {
					use_left := (containing_box.computed_values().direction() == .ltr) == is_start
					if use_left { rect.left() } else { rect.right() }
				} else if is_start {
					rect.top()
				} else {
					rect.bottom()
				}
			}
			.self_start, .self_end {
				is_start := side.to_keyword() == .self_start
				if is_horizontal_axis {
					use_left := (box.computed_values().direction() == .ltr) == is_start
					if use_left { rect.left() } else { rect.right() }
				} else if is_start {
					rect.top()
				} else {
					rect.bottom()
				}
			}
			.inside, .outside {
				same_side := side.to_keyword() == .inside
				if is_horizontal_axis {
					if is_from_end == same_side { rect.right() } else { rect.left() }
				} else if is_from_end == same_side {
					rect.bottom()
				} else {
					rect.top()
				}
			}
			else { none }
		}
	}
	if side.is_percentage() {
		percentage := side.as_percentage().percentage().as_fraction()
		if is_horizontal_axis {
			if containing_box.computed_values().direction() == .ltr {
				return rect.left().plus(rect.width.times_float(percentage))
			}
			return rect.right().minus(rect.width.times_float(percentage))
		}
		return rect.top().plus(rect.height.times_float(percentage))
	}
	return none
}

// https://drafts.csswg.org/css-anchor-position-1/#anchor-pos
fn resolve_anchor_for_inset(state &LayoutState, box &Node, containing_box &Node, containing_state &UsedValues, containing_extent CSSPixels, anchor css.AnchorStyleValue, is_from_end bool, is_horizontal_axis bool) ?CSSPixels {
	if side := resolve_anchor_side(state, box, containing_box, containing_state, anchor, is_from_end, is_horizontal_axis) {
		if is_from_end {
			return containing_extent.minus(side)
		}
		return side
	}
	fallback := anchor.fallback_value() or { return none }
	if fallback is css.AnchorStyleValue {
		return resolve_anchor_for_inset(state, box, containing_box, containing_state, containing_extent, fallback, is_from_end, is_horizontal_axis)
	}
	return resolve_layout_size(box, css.Size.from_style_value(fallback), containing_extent)
}

struct InlineContainingBlockRectAccumulator {
mut:
	has_value bool
	rect      css.CSSPixelRect
}

fn (mut accumulator InlineContainingBlockRectAccumulator) include(rect css.CSSPixelRect) {
	if !accumulator.has_value {
		accumulator.has_value = true
		accumulator.rect = rect
		return
	}
	left := css_pixels_min(accumulator.rect.left(), rect.left())
	top := css_pixels_min(accumulator.rect.top(), rect.top())
	right := css_pixels_max(accumulator.rect.right(), rect.right())
	bottom := css_pixels_max(accumulator.rect.bottom(), rect.bottom())
	accumulator.rect = css.CSSPixelRect{
		x: left
		y: top
		width: right.minus(left)
		height: bottom.minus(top)
	}
}

fn collect_inline_containing_block_rect(state &LayoutState, node &Node, inline_dom_node &dom.Node, offset css.CSSPixelPoint, mut accumulator InlineContainingBlockRectAccumulator) {
	if styled := node.as_node_with_style() {
		if used := state.try_get(styled) {
			for line_box in used.line_boxes {
				for fragment in line_box.fragments_ {
					if fragment_dom := fragment.layout_node().dom_node() {
						if inline_dom_node.is_inclusive_ancestor_of(fragment_dom) {
							fragment_offset := fragment.offset().plus(offset)
							fragment_rect := css.CSSPixelRect{
								x: fragment_offset.x()
								y: fragment_offset.y()
								width: fragment.width()
								height: fragment.height()
							}
							accumulator.include(fragment_rect)
						}
					}
				}
			}
		}
	}

	for child in node.children() {
		if child.is_absolutely_positioned() || child.is_floating() {
			continue
		}
		mut child_offset := offset
		mut child_used := ?&UsedValues(none)
		if child_styled := child.as_node_with_style() {
			if used := state.try_get(child_styled) {
				child_used = used
				child_offset = child_offset.plus(used.offset)
			}
		}
		if child.is_box() && !child.is_anonymous() {
			child_dom := child.dom_node() or { continue }
			if !inline_dom_node.is_inclusive_ancestor_of(child_dom) {
				continue
			}
			if used := child_used {
				border_box_origin := child_offset.minus(css.CSSPixelPoint.new(used.border_left.plus(used.padding_left), used.border_top.plus(used.padding_top)))
				border_rect := css.CSSPixelRect{
					x: border_box_origin.x()
					y: border_box_origin.y()
					width: used.border_box_width()
					height: used.border_box_height()
				}
				accumulator.include(border_rect)
			}
		}
		collect_inline_containing_block_rect(state, child, inline_dom_node, child_offset, mut accumulator)
	}
}

// FormattingContext::compute_inline_containing_block_rect(). The returned
// padding-box rectangle is expressed in the coordinate system of the Box that
// the rest of layout stores as the abspos containing block. Split inline boxes
// are collected from every continuation below their real block container.
fn compute_inline_containing_block_rect(mut state LayoutState, inline_node &InlineNode, abspos_containing_block &Box) ?css.CSSPixelRect {
	inline_as_node := unsafe { &Node(inline_node) }
	inline_dom_node := inline_as_node.dom_node() or { return none }
	outer_block := inline_as_node.non_anonymous_containing_block() or { return none }
	abspos_node := unsafe { &Node(abspos_containing_block) }
	mut outer_offset := css.CSSPixelPoint{}
	mut ancestor := ?&Node(unsafe { &Node(outer_block) })
	for ancestor != none {
		current := ancestor or { break }
		if current == abspos_node {
			break
		}
		if styled := current.as_node_with_style() {
			if used := state.try_get(styled) {
				outer_offset = outer_offset.plus(used.offset)
			}
		}
		ancestor = current.parent()
	}
	mut accumulator := InlineContainingBlockRectAccumulator{}
	collect_inline_containing_block_rect(&state, unsafe { &Node(outer_block) }, inline_dom_node, outer_offset, mut accumulator)
	if !accumulator.has_value {
		return none
	}
	mut rect := accumulator.rect
	if inline_styled := inline_as_node.as_node_with_style() {
		if inline_state := state.try_get(inline_styled) {
			rect.x = rect.x.minus(inline_state.padding_left)
			rect.y = rect.y.minus(inline_state.padding_top)
			rect.width = rect.width.plus(inline_state.padding_left).plus(inline_state.padding_right)
			rect.height =
				rect.height.plus(inline_state.padding_top).plus(inline_state.padding_bottom)
		}
	}
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

	left := if anchor := anchor_style_value_for_inset(computed, .left) {
		resolve_anchor_for_inset(state, box, containing_box, containing_state, containing_width, anchor, false, true)
	} else {
		resolved_inset(box, .left, containing_width)
	}
	right := if anchor := anchor_style_value_for_inset(computed, .right) {
		resolve_anchor_for_inset(state, box, containing_box, containing_state, containing_width, anchor, true, true)
	} else {
		resolved_inset(box, .right, containing_width)
	}
	top := if anchor := anchor_style_value_for_inset(computed, .top) {
		resolve_anchor_for_inset(state, box, containing_box, containing_state, containing_height, anchor, false, false)
	} else {
		resolved_inset(box, .top, containing_height)
	}
	bottom := if anchor := anchor_style_value_for_inset(computed, .bottom) {
		resolve_anchor_for_inset(state, box, containing_box, containing_state, containing_height, anchor, true, false)
	} else {
		resolved_inset(box, .bottom, containing_height)
	}
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
	box_state = layout_independent_child_with_forced_height_definiteness(mut state, box,
		mut containing_state, containing_width, containing_height, forced_width, forced_height,
		computed_height_establishes_definite_containing_block_height(preferred_height))

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

	// compute_width_for_absolutely_positioned_non_replaced_element() and
	// compute_height_for_absolutely_positioned_non_replaced_element() record the
	// solved insets on the box's used values. getComputedStyle() reports those as
	// the resolved value of top/right/bottom/left whenever the specified inset is
	// a percentage, a calculation, or `auto`, so an `auto` side has to carry the
	// distance the layout actually produced rather than zero.
	box_state.inset_left = x.minus(box_state.margin_box_left()).minus(containing_rect.x)
	box_state.inset_right = containing_rect.x.plus(containing_width)
		.minus(x)
		.minus(box_state.content_width())
		.minus(box_state.margin_box_right())
	box_state.inset_top = y.minus(box_state.margin_box_top()).minus(containing_rect.y)
	box_state.inset_bottom = containing_rect.y.plus(containing_height)
		.minus(y)
		.minus(box_state.content_height())
		.minus(box_state.margin_box_bottom())
}

fn layout_absolutely_positioned_descendants(mut state LayoutState, root &Node) {
	if root.is_absolutely_positioned() {
		layout_absolutely_positioned_box(mut state, root)
	}
	for child in root.children() {
		layout_absolutely_positioned_descendants(mut state, child)
	}
}
