// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css
import dom

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

fn resolve_named_anchor_rect(state &LayoutState, box &Node, containing_state &UsedValues, name string) ?css.CSSPixelRect {
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

// https://drafts.csswg.org/css-anchor-position-1/#resolving-anchor
fn resolve_anchor_rect(state &LayoutState, box &Node, containing_state &UsedValues, anchor css.AnchorStyleValue) ?css.CSSPixelRect {
	styled := box.as_node_with_style() or { return none }
	name := anchor.anchor_name() or { styled.computed_values().position_anchor() or { return none } }
	return resolve_named_anchor_rect(state, box, containing_state, name)
}

struct SpanAllPositionArea {
	rect        css.CSSPixelRect
	anchor_rect css.CSSPixelRect
}

fn position_area_is_span_all(computed &css.ComputedValues) bool {
	value := unsafe { &css.ComputedProperties(computed) }.typed_property_value(.position_area) or {
		return false
	}
	if value is css.KeywordStyleValue {
		return value.keyword() == .span_all
	}
	if value is css.StyleValueList {
		values := value.values()
		if values.len != 2 {
			return false
		}
		for entry in values {
			if entry !is css.KeywordStyleValue {
				return false
			}
			if entry.to_keyword() != .span_all {
				return false
			}
		}
		return true
	}
	return false
}

// https://drafts.csswg.org/css-anchor-position-1/#valdef-position-area-span-all
fn span_all_position_area(state &LayoutState, box &Node, containing_state &UsedValues, computed &css.ComputedValues, original_rect css.CSSPixelRect) ?SpanAllPositionArea {
	if !position_area_is_span_all(computed) {
		return none
	}
	name := computed.position_anchor() or { return none }
	padding_relative_anchor := resolve_named_anchor_rect(state, box, containing_state, name) or {
		return none
	}
	anchor_rect := css.CSSPixelRect{
		x: padding_relative_anchor.x.minus(containing_state.padding_left)
		y: padding_relative_anchor.y.minus(containing_state.padding_top)
		width: padding_relative_anchor.width
		height: padding_relative_anchor.height
	}
	left := css_pixels_min(original_rect.left(), anchor_rect.left())
	top := css_pixels_min(original_rect.top(), anchor_rect.top())
	right := css_pixels_max(original_rect.right(), anchor_rect.right())
	bottom := css_pixels_max(original_rect.bottom(), anchor_rect.bottom())
	return SpanAllPositionArea{
		rect: css.CSSPixelRect{
			x: left
			y: top
			width: right.minus(left)
			height: bottom.minus(top)
		}
		anchor_rect: anchor_rect
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
fn resolve_anchor_for_inset(state &LayoutState, box &Node, containing_box &Node, containing_state &UsedValues, containing_start CSSPixels, containing_extent CSSPixels, anchor css.AnchorStyleValue, is_from_end bool, is_horizontal_axis bool) ?CSSPixels {
	if side := resolve_anchor_side(state, box, containing_box, containing_state, anchor, is_from_end, is_horizontal_axis) {
		padding := if is_horizontal_axis { containing_state.padding_left } else { containing_state.padding_top }
		relative_side := side.minus(padding).minus(containing_start)
		if is_from_end {
			return containing_extent.minus(relative_side)
		}
		return relative_side
	}
	fallback := anchor.fallback_value() or { return none }
	if fallback is css.AnchorStyleValue {
		return resolve_anchor_for_inset(state, box, containing_box, containing_state,
			containing_start, containing_extent, fallback, is_from_end, is_horizontal_axis)
	}
	if fallback is css.CalculatedStyleValue {
		return resolve_calculated_anchor_inset(state, box, containing_box, containing_state,
			containing_start, containing_extent, fallback, is_from_end, is_horizontal_axis)
	}
	return resolve_layout_size(box, css.Size.from_style_value(fallback), containing_extent)
}

// FormattingContext::compute_inline_containing_block_rect(). The inline
// formatting context derives the padding-box rectangle from the inline box's
// first and last line pieces; it is re-expressed in the coordinate system of
// the Box that the rest of layout stores as the abspos containing block.
fn compute_inline_containing_block_rect(mut state LayoutState, inline_node &InlineNode, abspos_containing_block &Box) ?css.CSSPixelRect {
	inline_as_node := unsafe { &Node(inline_node) }
	inline_root := inline_as_node.containing_block() or { return none }
	rect := inline_containing_block_padding_rect(inline_as_node, &state) or { return none }
	abspos_node := unsafe { &Node(abspos_containing_block) }
	mut root_offset := css.CSSPixelPoint{}
	mut ancestor := ?&Node(unsafe { &Node(inline_root) })
	for ancestor != none {
		current := ancestor or { break }
		if layout_nodes_same(current, abspos_node) {
			break
		}
		if styled := current.as_node_with_style() {
			if used := state.try_get(styled) {
				root_offset = root_offset.plus(used.offset)
			}
		}
		if containing_block := current.containing_block() {
			ancestor = unsafe { &Node(containing_block) }
		} else {
			ancestor = none
		}
	}
	return translate_css_pixel_rect(rect, root_offset)
}

fn resolved_inset(node &Node, property_id css.PropertyID, basis CSSPixels) ?CSSPixels {
	if property_is_auto(node.computed_values(), property_id) {
		return none
	}
	return resolve_layout_size(node, node.computed_values().size_value(property_id), basis)
}

struct AnchorInsetCalculationContext {
	state              &LayoutState = unsafe { nil }
	box                &Node        = unsafe { nil }
	containing_box     &Node        = unsafe { nil }
	containing_state   &UsedValues  = unsafe { nil }
	containing_start   CSSPixels
	containing_extent  CSSPixels
	is_from_end        bool
	is_horizontal_axis bool
}

fn resolve_anchor_for_calculation(context_pointer voidptr, anchor css.AnchorStyleValue) ?css.CSSPixels {
	if context_pointer == unsafe { nil } {
		return none
	}
	context := unsafe { &AnchorInsetCalculationContext(context_pointer) }
	return resolve_anchor_for_inset(context.state, context.box, context.containing_box,
		context.containing_state, context.containing_start, context.containing_extent, anchor,
		context.is_from_end, context.is_horizontal_axis)
}

fn resolve_calculated_anchor_inset(state &LayoutState, box &Node, containing_box &Node, containing_state &UsedValues, containing_start CSSPixels, basis CSSPixels, value css.CalculatedStyleValue, is_from_end bool, is_horizontal_axis bool) ?CSSPixels {
	context := AnchorInsetCalculationContext{
		state: state
		box: box
		containing_box: containing_box
		containing_state: containing_state
		containing_start: containing_start
		containing_extent: basis
		is_from_end: is_from_end
		is_horizontal_axis: is_horizontal_axis
	}
	length_context := layout_length_resolution_context(box)
	resolved := value.resolve_length(css.CalculationResolutionContext{
		percentage_basis: css.Length.make_css_px(basis)
		length_resolution_context: length_context
		anchor_resolver: resolve_anchor_for_calculation
		anchor_resolver_context: voidptr(&context)
	}) or { return none }
	return CSSPixels.truncated_value_for(resolved.to_px_without_rounding(length_context))
}

fn resolved_inset_with_anchors(state &LayoutState, box &Node, containing_box &Node, containing_state &UsedValues, computed &css.ComputedValues, property_id css.PropertyID, containing_start CSSPixels, basis CSSPixels, is_from_end bool, is_horizontal_axis bool) ?CSSPixels {
	value := unsafe { &css.ComputedProperties(computed) }.typed_property_value(property_id) or {
		return resolved_inset(box, property_id, basis)
	}
	if value is css.AnchorStyleValue {
		return resolve_anchor_for_inset(state, box, containing_box, containing_state,
			containing_start, basis, value, is_from_end, is_horizontal_axis)
	}
	if value is css.CalculatedStyleValue {
		return resolve_calculated_anchor_inset(state, box, containing_box, containing_state,
			containing_start, basis, value, is_from_end, is_horizontal_axis)
	}
	if property_is_auto(computed, property_id) {
		return none
	}
	return resolved_inset(box, property_id, basis)
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
	mut containing_rect := if inline_containing_block := box.inline_containing_block_if_applicable() {
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
	position_area := span_all_position_area(state, box, containing_state, computed, containing_rect)
	if area := position_area {
		containing_rect = area.rect
	}
	containing_width := containing_rect.width
	containing_height := containing_rect.height
	resolve_box_model_edges(computed, mut box_state, containing_width.to_double())

	left := resolved_inset_with_anchors(state, box, containing_box, containing_state,
		computed, .left, containing_rect.x, containing_width, false, true)
	right := resolved_inset_with_anchors(state, box, containing_box, containing_state,
		computed, .right, containing_rect.x, containing_width, true, true)
	top := resolved_inset_with_anchors(state, box, containing_box, containing_state,
		computed, .top, containing_rect.y, containing_height, false, false)
	bottom := resolved_inset_with_anchors(state, box, containing_box, containing_state,
		computed, .bottom, containing_rect.y, containing_height, true, false)
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
		// CSS ratio boxes transfer the border-box inline size before removing
		// block-axis edges, just as they do in normal flow. The resolved ratio
		// height supplies the existing percentage-size basis for descendants.
		size := chromium_concrete_ratio_block_size(replaced, box_state, abspos_available_space) or {
			compute_replaced_size(replaced, abspos_available_space)
		}
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
	if area := position_area {
		if left == none && right == none && computed.justify_self() in [.auto_, .normal] {
			static_position = css.CSSPixelPoint.new(area.anchor_rect.x.plus(area.anchor_rect.width.minus(box_state.margin_box_width()).divided_by_float(2)),
				static_position.y())
		}
		if top == none && bottom == none && computed.align_self() in [.auto_, .normal] {
			static_position = css.CSSPixelPoint.new(static_position.x(),
				area.anchor_rect.y.plus(area.anchor_rect.height.minus(box_state.margin_box_height()).divided_by_float(2)))
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
	align_block_contents(mut state, root)
	for child in root.children() {
		layout_absolutely_positioned_descendants(mut state, child)
	}
}
