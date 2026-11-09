// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

struct FlexLine {
mut:
	items             []&Node
	bases             []CSSPixels
	minimums          []CSSPixels
	deferred_minimums []bool
	maximums          []CSSPixels
	hypotheticals     []CSSPixels
	targets           []CSSPixels
}

fn new_flex_line(capacity int) FlexLine {
	return FlexLine{
		items: []&Node{cap: capacity}
		bases: []CSSPixels{cap: capacity}
		minimums: []CSSPixels{cap: capacity}
		deferred_minimums: []bool{cap: capacity}
		maximums: []CSSPixels{cap: capacity}
		hypotheticals: []CSSPixels{cap: capacity}
		targets: []CSSPixels{cap: capacity}
	}
}

enum FlexCrossAlignment {
	// `normal` is kept apart from an explicit `stretch` even though both stretch an
	// auto-sized item: only `normal` follows a wrap-reverse container's swapped cross-start
	// and cross-end directions. See cross_alignment_offset().
	normal
	start
	end
	self_start
	self_end
	center
	stretch
	baseline
}

// CSSPixels stores 1/64px fixed-point values. Its C++ integer division
// operators divide the raw representation and truncate; routing these steps
// through f64 and nearest_value_for shifts tie cases by one subpixel.
fn flex_divide_by_integer(value CSSPixels, divisor int) CSSPixels {
	if divisor == 0 {
		return CSSPixels.new(0)
	}
	return CSSPixels.from_raw(value.raw_value() / divisor)
}

// CSS permits a maximum smaller than the minimum. Keep the ordering from
// Layout::css_clamp() instead of using a clamp helper that rejects that case.
fn css_clamp(value CSSPixels, minimum CSSPixels, maximum CSSPixels) CSSPixels {
	return css_pixels_max(minimum, css_pixels_min(value, maximum))
}

// The row and column layout algorithms operate on physical X and Y axes.
// Project the authored logical direction once, including its start edge.
fn flex_physical_direction(container &Node) css.FlexDirection {
 computed := container.computed_values()
 logical := computed.effective_flex_direction()
 inline_main := logical in [.row,.row_reverse]
 horizontal := layout_inline_axis_is_horizontal(computed.writing_mode()) == inline_main
 mut reversed := if inline_main {
  layout_inline_axis_is_reverse(computed.writing_mode(),computed.direction())
 } else { layout_block_axis_is_reverse(computed.writing_mode()) }
 if logical in [.row_reverse,.column_reverse] { reversed = !reversed }
 return if horizontal {
  if reversed { css.FlexDirection.row_reverse } else { css.FlexDirection.row }
 } else { if reversed { css.FlexDirection.column_reverse } else { css.FlexDirection.column } }
}

fn flex_direction_is_reverse(container &Node) bool {
 return flex_physical_direction(container) in [.row_reverse,.column_reverse]
}

fn ordered_flex_items(container &Node) []&Node {
	// FlexFormattingContext::generate_anonymous_flex_items() groups children by
	// `order` and sorts only the distinct keys. Avoid insertion-sorting the
	// growing item array, which made equal-order containers quadratic.
	mut items := []&Node{cap: container.children().len}
	mut first_order := 0
	mut all_same_order := true
	for child in container.children() {
		if !child.is_box() || child.is_absolutely_positioned() {
			continue
		}
		skippable_text_run := can_skip_anonymous_text_run(child)
		if skippable_text_run {
			continue
		}
		mut mutable_child := unsafe { &Node(child) }
		mutable_child.set_flex_item(true)
		order := child.computed_values().order()
		if items.len == 0 {
			first_order = order
		} else if order != first_order {
			all_same_order = false
		}
		items << child
	}
	// Almost all real-world flex containers leave every item at the initial
	// `order: 0`. Preserve their source order without allocating a map, a key
	// array, and nested bucket arrays for every container.
	if all_same_order {
		return items
	}
	mut order_item_buckets := [][]&Node{}
	mut bucket_indices := map[int]int{}
	mut keys := []int{}
	for item in items {
		order := item.computed_values().order()
		bucket_number := bucket_indices[order] or {
			order_item_buckets << []&Node{}
			keys << order
			bucket_indices[order] = order_item_buckets.len
			order_item_buckets.len
		}
		order_item_buckets[bucket_number - 1] << item
	}
	// C++ sorts the distinct order keys descending for a reverse direction rather than
	// reversing the item list, because the positioning code already lays a reverse line out
	// from the far edge. Sorting ascending here would place `order` groups the wrong way
	// round: `row-reverse` with order:2 then order:1 puts the order:2 item at the far edge.
	if flex_direction_is_reverse(container) {
		keys.sort(a > b)
	} else {
		keys.sort()
	}
	mut ordered_items := []&Node{cap: items.len}
	for key in keys {
		bucket_number := bucket_indices[key] or { continue }
		for item in order_item_buckets[bucket_number - 1] {
			ordered_items << item
		}
	}
	return ordered_items
}

// FlexFormattingContext::main_gap()/cross_gap(). Percentages resolve against
// the corresponding inner dimension of the flex container, not unconditionally
// against its inline size.
fn flex_formatting_context_main_gap(container &Node, inner_main_size CSSPixels, row_axis bool) CSSPixels {
	property_id := if container.computed_values().effective_flex_direction() in [.row,.row_reverse] { css.PropertyID.column_gap } else { css.PropertyID.row_gap }
	_ = row_axis
	return resolve_layout_gap(container, property_id, inner_main_size)
}

fn flex_formatting_context_cross_gap(container &Node, inner_cross_size CSSPixels, row_axis bool) CSSPixels {
	property_id := if container.computed_values().effective_flex_direction() in [.row,.row_reverse] { css.PropertyID.row_gap } else { css.PropertyID.column_gap }
	_ = row_axis
	return resolve_layout_gap(container, property_id, inner_cross_size)
}

// FlexFormattingContext::run() avoids the potentially expensive automatic
// minimum-size intrinsic layout when a definite, single-line container cannot
// need to shrink any of its definite-sized items.
fn should_skip_automatic_minimum_size_clamp(state &LayoutState, container &Node, container_state &UsedValues, layout_mode LayoutMode, items []&Node, bases []CSSPixels, row_axis bool, available_main_size CSSPixels) bool {
	if layout_mode == .intrinsic_sizing || container.computed_values().flex_wrap() != .nowrap {
		return false
	}
	if row_axis {
		if !container_state.has_definite_width() {
			return false
		}
	} else if !container_state.has_definite_height() {
		return false
	}
	mut sum_of_flex_base_sizes := CSSPixels.new(0)
	for index, item in items {
		if index >= bases.len {
			return false
		}
		styled := item.as_node_with_style() or { return false }
		item_state := state.try_get(styled) or { return false }
		if (row_axis && !item_state.has_definite_width())
			|| (!row_axis && !item_state.has_definite_height()) {
			return false
		}
		sum_of_flex_base_sizes = sum_of_flex_base_sizes.plus(bases[index])
	}
	return sum_of_flex_base_sizes.raw_value() <= available_main_size.raw_value()
}

// FlexFormattingContext::run() also proves the hypothetical automatic minimum
// redundant for individual items whose definite flex basis is exactly their
// specified-size suggestion. The real minimum is still needed later if the
// item remains unfrozen while resolving flexible-length violations.
fn flex_used_basis_is_definite(item &Node, container_state &UsedValues, row_axis bool) bool {
	basis := item.computed_values().flex_basis()
	if basis.is_content {
		return false
	}
	mut size := basis.size
	if size.is_auto() {
		size = item.computed_values().size_value(if row_axis {
			css.PropertyID.width
		} else {
			css.PropertyID.height
		})
		if size.is_auto() {
			return false
		}
	}
	// anchor-size() currently computes to Size::none while anchor sizing is
	// unresolved. Like auto and intrinsic sizing keywords, that is not a
	// definite flex basis and must not enter the definite-size path.
	if size.is_none() || size.is_intrinsic_sizing_constraint() {
		return false
	}
	if size.is_length() {
		return true
	}
	can_resolve_percentages := if row_axis {
		container_state.has_definite_width()
	} else {
		container_state.has_definite_height()
	}
	if size.is_calculated() {
		calculated := size.calculated()
		if calculated.resolves_to_percentage() {
			return can_resolve_percentages
		}
		if calculated.resolves_to_length() {
			return !calculated.contains_percentage() || can_resolve_percentages
		}
		return false
	}
	return size.is_percentage() && can_resolve_percentages
}

fn flex_formatting_context_specified_size_suggestion(item &Node, item_state &UsedValues, row_axis bool, available_main_size ?CSSPixels) ?CSSPixels {
	has_definite_main_size := if row_axis {
		item_state.has_definite_width()
	} else {
		item_state.has_definite_height()
	}
	if !has_definite_main_size {
		return none
	}
	preferred_property := if row_axis { css.PropertyID.width } else { css.PropertyID.height }
	preferred := item.computed_values().size_value(preferred_property)
	if preferred.is_auto() || (preferred.contains_percentage() && available_main_size == none) {
		return none
	}
	return resolve_flex_main_size(item, preferred, available_main_size, item_state, row_axis)
}

fn can_skip_automatic_minimum_size_for_item(item &Node, item_state &UsedValues, container_state &UsedValues, flex_base_size CSSPixels, row_axis bool, available_main_size ?CSSPixels) bool {
	if flex_item_has_scrollable_main_overflow(item,row_axis) || item.is_replaced_box() {
		return false
	}
	box := item.as_box() or { return false }
	if box.has_preferred_aspect_ratio()
		|| !flex_used_basis_is_definite(item, container_state, row_axis) {
		return false
	}
	specified := flex_formatting_context_specified_size_suggestion(item, item_state, row_axis, available_main_size) or {
		return false
	}
	return flex_base_size.raw_value() == specified.raw_value()
}

fn flex_base_size_after_cross_constraints(item &Node, item_state &UsedValues, base CSSPixels, row_axis bool) CSSPixels {
	box := item.as_box() or { return base }
	if box.auto_content_box_size().aspect_ratio == none {
		return base
	}
	return flex_main_size_through_aspect_ratio(item, item_state, base, row_axis)
}

fn flex_base_size_for_definite_basis(item &Node, item_state &UsedValues, base CSSPixels, row_axis bool) CSSPixels {
	// Flexbox 9.2(A): a definite used basis is already the flex base size.
	// Blink applies cross-axis constraints when laying out the item, without
	// feeding them back through its natural ratio into this definite basis.
	if item.document().font_rendering_policy() == .chromium { return base }
	return flex_base_size_after_cross_constraints(item, item_state, base, row_axis)
}

fn flex_base_width(mut state LayoutState, item &Node, container_width CSSPixels, item_state &UsedValues) CSSPixels {
	computed := item.computed_values()
	basis := computed.flex_basis()
	if !basis.is_content && !basis.size.is_auto() {
		if value := resolve_layout_content_size(item, basis.size, container_width, item_state, true) {
			return flex_base_size_for_definite_basis(item, item_state, value, true)
		}
	}
	if basis.size.is_auto() {
		width := computed.size_value(.width)
		if value := resolve_layout_content_size(item, width, container_width, item_state, true) {
			return flex_base_size_for_definite_basis(item, item_state, value, true)
		}
	}
	if box := item.as_box() {
		used_basis_is_content := basis.is_content
			|| (basis.size.is_auto() && computed.size_value(.width).is_auto())
		if used_basis_is_content {
			if transferred := flex_formatting_context_transferred_size_suggestion(item, item_state, true) {
				return flex_base_size_after_cross_constraints(item, item_state, transferred, true)
			}
			auto_size := box.auto_content_box_size()
			if auto_size.aspect_ratio != none && auto_size.width == none && auto_size.height == none {
				return flex_base_size_after_cross_constraints(item, item_state, calculate_stretch_fit_width(box, AvailableSize.make_definite(container_width)), true)
			}
		}
		intrinsic_basis := if basis.size.is_auto() && !basis.is_content { computed.size_value(.width) } else { basis.size }
		if intrinsic_basis.is_min_content() {
			return flex_base_size_after_cross_constraints(item, item_state, calculate_min_content_width(mut state, box), true)
		}
		if intrinsic_basis.is_fit_content() {
			return flex_base_size_after_cross_constraints(item, item_state, calculate_fit_content_width(mut state, box, AvailableSize.make_definite(container_width)), true)
		}
		return flex_base_size_after_cross_constraints(item, item_state, calculate_max_content_width(mut state, box), true)
	}
	return CSSPixels.new(0)
}

fn flex_base_height(mut state LayoutState, item &Node, container_height ?CSSPixels, laid_out_height CSSPixels, item_state &UsedValues) CSSPixels {
	computed := item.computed_values()
	basis := computed.flex_basis()
	if !basis.is_content && !basis.size.is_auto() {
		if height := container_height {
			if value := resolve_layout_content_size(item, basis.size, height, item_state, false) {
				return flex_base_size_for_definite_basis(item, item_state, value, false)
			}
		} else if !basis.size.contains_percentage() {
			if value := resolve_layout_content_size(item, basis.size, CSSPixels.new(0), item_state, false) {
				return flex_base_size_for_definite_basis(item, item_state, value, false)
			}
		}
	}
	if basis.size.is_auto() {
		height_size := computed.size_value(.height)
		if height := container_height {
			if value := resolve_layout_content_size(item, height_size, height, item_state, false) {
				return flex_base_size_for_definite_basis(item, item_state, value, false)
			}
		} else if !height_size.contains_percentage() {
			if value := resolve_layout_content_size(item, height_size, CSSPixels.new(0), item_state, false) {
				return flex_base_size_for_definite_basis(item, item_state, value, false)
			}
		}
	}
	used_basis_is_content := basis.is_content
		|| (basis.size.is_auto() && computed.size_value(.height).is_auto())
		|| (basis.size.contains_percentage() && container_height == none)
	if used_basis_is_content {
		if transferred := flex_formatting_context_transferred_size_suggestion(item, item_state, false) {
			return flex_base_size_after_cross_constraints(item, item_state, transferred, false)
		}
	}
	if box := item.as_box() {
		if used_basis_is_content {
			return flex_base_size_after_cross_constraints(item, item_state, calculate_max_content_height(mut state, box, item_state.content_width()), false)
		}
		if basis.size.is_min_content() {
			return flex_base_size_after_cross_constraints(item, item_state, calculate_min_content_height(mut state, box, item_state.content_width()), false)
		}
		if basis.size.is_max_content() {
			return flex_base_size_after_cross_constraints(item, item_state, calculate_max_content_height(mut state, box, item_state.content_width()), false)
		}
		if basis.size.is_fit_content() {
			available := if height := container_height {
				AvailableSize.make_definite(height)
			} else {
				AvailableSize.make_indefinite()
			}
			return flex_base_size_after_cross_constraints(item, item_state, calculate_fit_content_height(mut state, box, item_state.content_width(), available), false)
		}
	}
	return flex_base_size_after_cross_constraints(item, item_state, laid_out_height, false)
}

fn flex_item_is_scroll_container(item &Node) bool {
 return flex_item_has_scrollable_main_overflow(item,true) || flex_item_has_scrollable_main_overflow(item,false)
}

fn flex_item_has_scrollable_main_overflow(item &Node,row_axis bool) bool {
 computed := item.computed_values()
 overflow := if row_axis { computed.overflow_x() } else { computed.overflow_y() }
 return overflow !in [.visible,.clip]
}

fn flex_item_has_aspect_ratio_without_natural_dimensions(item &Node) bool {
	box := item.as_box() or { return false }
	auto_size := box.auto_content_box_size()
	return auto_size.aspect_ratio != none && auto_size.width == none && auto_size.height == none
}

fn flex_fit_content_cross_width(mut state LayoutState, item &Node, available_width CSSPixels) CSSPixels {
	box := item.as_box() or { return CSSPixels.new(0) }
	minimum := calculate_min_content_width(mut state, box)
	maximum := calculate_max_content_width(mut state, box)
	return css_pixels_max(minimum, css_pixels_min(maximum, available_width))
}

fn resolve_flex_main_size(item &Node, size css.Size, percentage_basis ?CSSPixels, item_state &UsedValues, row_axis bool) ?CSSPixels {
	if size.contains_percentage() && percentage_basis == none {
		return none
	}
	basis := percentage_basis or { CSSPixels.new(0) }
	return resolve_layout_content_size(item, size, basis, item_state, row_axis)
}

fn flex_intrinsic_main_size(mut state LayoutState, item &Node, item_state &UsedValues, row_axis bool, minimum bool) CSSPixels {
	box := item.as_box() or { return CSSPixels.new(0) }
	if row_axis {
		return if minimum {
			calculate_min_content_width(mut state, box)
		} else {
			calculate_max_content_width(mut state, box)
		}
	}
	return if minimum {
		calculate_min_content_height(mut state, box, item_state.content_width())
	} else {
		calculate_max_content_height(mut state, box, item_state.content_width())
	}
}

fn flex_main_size_for_constraint(mut state LayoutState, item &Node, size css.Size, item_state &UsedValues, row_axis bool, available_main_size ?CSSPixels) ?CSSPixels {
	if resolved := resolve_flex_main_size(item, size, available_main_size, item_state, row_axis) {
		return resolved
	}
	box := item.as_box() or { return none }
	if size.is_min_content() {
		return flex_intrinsic_main_size(mut state, item, item_state, row_axis, true)
	}
	if size.is_max_content() {
		return flex_intrinsic_main_size(mut state, item, item_state, row_axis, false)
	}
	if size.is_fit_content() {
		available := if basis := available_main_size {
			AvailableSize.make_definite(basis)
		} else {
			AvailableSize.make_indefinite()
		}
		if row_axis {
			return calculate_fit_content_width(mut state, box, available)
		}
		return calculate_fit_content_height(mut state, box, item_state.content_width(), available)
	}
	return none
}

fn flex_cross_size_after_min_max(item &Node, item_state &UsedValues, cross_size CSSPixels, row_axis bool) CSSPixels {
	computed := item.computed_values()
	containing := item_state.containing_block_used_values()
	percentage_basis := if values := containing {
		if row_axis { values.content_height() } else { values.content_width() }
	} else {
		CSSPixels.new(0)
	}
	min_property := if row_axis { css.PropertyID.min_height } else { css.PropertyID.min_width }
	max_property := if row_axis { css.PropertyID.max_height } else { css.PropertyID.max_width }
	edges := if row_axis {
		item_state.border_top.plus(item_state.padding_top).plus(item_state.padding_bottom).plus(item_state.border_bottom)
	} else {
		item_state.border_left.plus(item_state.padding_left).plus(item_state.padding_right).plus(item_state.border_right)
	}
	adjustment := if computed.box_sizing() == .border_box { edges } else { CSSPixels.new(0) }
	mut result := cross_size
	if specified_max := computed.length_percentage_to_px(max_property, percentage_basis.to_double()) {
		maximum := css_pixels_max(CSSPixels.new(0), css_px(specified_max).minus(adjustment))
		result = css_pixels_min(result, maximum)
	}
	min_size := computed.size_value(min_property)
	container_cross_size_is_definite := if values := containing {
		if row_axis { values.has_definite_height() } else { values.has_definite_width() }
	} else {
		false
	}
	// An unresolved percentage minimum cannot transfer a cross-axis constraint
	// through an aspect ratio into the flex base size.
	if !min_size.is_auto()
		&& (!min_size.contains_percentage() || container_cross_size_is_definite) {
		if specified_min := computed.length_percentage_to_px(min_property, percentage_basis.to_double()) {
			minimum := css_pixels_max(CSSPixels.new(0), css_px(specified_min).minus(adjustment))
			result = css_pixels_max(result, minimum)
		}
	}
	return result
}

fn flex_main_size_through_aspect_ratio(item &Node, item_state &UsedValues, main_size CSSPixels, row_axis bool) CSSPixels {
	box := item.as_box() or { return main_size }
	ratio := box.preferred_aspect_ratio() or { return main_size }
	cross_size := if row_axis {
		main_size.divided_by_fraction(ratio)
	} else {
		main_size.times_fraction(ratio)
	}
	clamped_cross_size := flex_cross_size_after_min_max(item, item_state, cross_size, row_axis)
	if clamped_cross_size.raw_value() == cross_size.raw_value() {
		return main_size
	}
	return if row_axis {
		clamped_cross_size.times_fraction(ratio)
	} else {
		clamped_cross_size.divided_by_fraction(ratio)
	}
}

fn flex_formatting_context_transferred_size_suggestion(item &Node, item_state &UsedValues, row_axis bool) ?CSSPixels {
	box := item.as_box() or { return none }
	ratio := box.preferred_aspect_ratio() or { return none }
	// Blink transfers only a cross size that is definite from style or from
	// stretching. A replaced item's height left by an earlier layout pass
	// would otherwise round-trip its width through the ratio.
	if item.is_replaced_box() && item.document().font_rendering_policy() == .chromium
		&& item.computed_values().size_value(if row_axis { css.PropertyID.height } else { css.PropertyID.width }).is_auto() {
		container := item.parent() or { return none }
		if effective_flex_cross_alignment(container, item) !in [.stretch, .normal] { return none }
	}
	has_definite_cross_size := if row_axis {
		item_state.has_definite_height()
	} else {
		item_state.has_definite_width()
	}
	if !has_definite_cross_size {
		return none
	}
	cross_size := flex_cross_size_after_min_max(item, item_state, if row_axis {
		item_state.content_height()
	} else {
		item_state.content_width()
	}, row_axis)
	return if row_axis {
		cross_size.times_fraction(ratio)
	} else {
		cross_size.divided_by_fraction(ratio)
	}
}

// Blink's content size suggestion is the replaced item's own min-content
// size: its natural width, or a width transferred from its block size.
// Percentage compression applies only to min-content contributions, so a
// percentage width or max-width does not collapse this suggestion to zero.
fn flex_chromium_replaced_min_content_width(mut state LayoutState, item &Node) ?CSSPixels {
	if !item.is_replaced_box() || item.document().font_rendering_policy() != .chromium {
		return none
	}
	box := item.as_box() or { return none }
	if transferred := calculate_transferred_width_for_replaced_element(mut state, box) {
		return transferred
	}
	return box.auto_content_box_size().width
}

// https://drafts.csswg.org/css-flexbox-1/#min-size-auto
fn flex_formatting_context_automatic_minimum_size(mut state LayoutState, item &Node, item_state &UsedValues, row_axis bool, available_main_size ?CSSPixels) CSSPixels {
	if flex_item_has_scrollable_main_overflow(item,row_axis) {
		return CSSPixels.new(0)
	}
	// Blink resolves this suggestion only while laying items out in a definite
	// container. Intrinsic container sizing sums plain min-content
	// contributions, where a percentage-sized replaced item still contributes 0.
	mut content_suggestion := if row_axis && available_main_size != none {
		flex_chromium_replaced_min_content_width(mut state, item) or {
			flex_intrinsic_main_size(mut state, item, item_state, row_axis, true)
		}
	} else {
		flex_intrinsic_main_size(mut state, item, item_state, row_axis, true)
	}
	content_suggestion = flex_main_size_through_aspect_ratio(item, item_state, content_suggestion, row_axis)
	mut minimum := content_suggestion
	if transferred := flex_formatting_context_transferred_size_suggestion(item, item_state, row_axis) {
		minimum = if item.is_replaced_box() {
			css_pixels_min(minimum, transferred)
		} else {
			css_pixels_max(minimum, transferred)
		}
	}
	preferred_property := if row_axis { css.PropertyID.width } else { css.PropertyID.height }
	preferred := item.computed_values().size_value(preferred_property)
	if !preferred.is_auto() {
		if specified := resolve_flex_main_size(item, preferred, available_main_size, item_state, row_axis) {
			minimum = css_pixels_min(minimum, specified)
		}
	}
	max_property := if row_axis { css.PropertyID.max_width } else { css.PropertyID.max_height }
	if maximum := flex_main_size_for_constraint(mut state, item, item.computed_values().size_value(max_property), item_state, row_axis, available_main_size) {
		minimum = css_pixels_min(minimum, maximum)
	}
	return minimum
}

fn flex_used_main_minimum(mut state LayoutState, item &Node, item_state &UsedValues, row_axis bool, available_main_size ?CSSPixels, skip_automatic_minimum bool) CSSPixels {
	min_property := if row_axis { css.PropertyID.min_width } else { css.PropertyID.min_height }
	min_size := item.computed_values().size_value(min_property)
	if !min_size.is_auto() {
		if minimum := flex_main_size_for_constraint(mut state, item, min_size, item_state, row_axis, available_main_size) {
			return minimum
		}
	}
	if skip_automatic_minimum {
		return CSSPixels.new(0)
	}
	return flex_formatting_context_automatic_minimum_size(mut state, item, item_state, row_axis, available_main_size)
}

fn flex_used_main_maximum(mut state LayoutState, item &Node, item_state &UsedValues, row_axis bool, available_main_size ?CSSPixels) CSSPixels {
	max_property := if row_axis { css.PropertyID.max_width } else { css.PropertyID.max_height }
	max_size := item.computed_values().size_value(max_property)
	return flex_main_size_for_constraint(mut state, item, max_size, item_state, row_axis, available_main_size) or { CSSPixels.max() }
}

fn flex_hypothetical_main_size(base CSSPixels, minimum CSSPixels, maximum CSSPixels) CSSPixels {
	return css_pixels_max(CSSPixels.new(0), css_clamp(base, minimum, maximum))
}

fn flex_abs_pixels(value CSSPixels) CSSPixels {
	return if value.raw_value() < 0 { value.negated() } else { value }
}

fn resolve_flexible_lengths(mut state LayoutState, line FlexLine, container_main_size CSSPixels, item_edges []CSSPixels, gap CSSPixels, available_main_size ?CSSPixels, row_axis bool) []CSSPixels {
	mut targets := line.bases.clone()
	mut frozen := []bool{len: line.items.len}
	mut hypothetical_sum := gap.scaled(f64(if line.items.len > 0 {
		line.items.len - 1
	} else {
		0
	}))
	for index in 0 .. line.items.len {
		hypothetical_sum = hypothetical_sum.plus(line.hypotheticals[index]).plus(item_edges[index])
	}
	use_grow_factor := hypothetical_sum.raw_value() < container_main_size.raw_value()
	mut all_frozen := true
	for index, item in line.items {
		factor := if use_grow_factor {
			f64(item.computed_values().flex_grow())
		} else {
			f64(item.computed_values().flex_shrink())
		}
		if factor == 0 || (use_grow_factor
			&& line.bases[index].raw_value() > line.hypotheticals[index].raw_value())
			|| (!use_grow_factor
				&& line.bases[index].raw_value() < line.hypotheticals[index].raw_value()) {
			frozen[index] = true
			targets[index] = line.hypotheticals[index]
		} else {
			all_frozen = false
		}
	}
	// Frozen items already have their final hypothetical sizes.
	if all_frozen {
		return targets
	}
	mut minimums := line.minimums.clone()
	mut deferred_minimums := line.deferred_minimums.clone()
	calculate_free_space := fn [line, item_edges, gap, container_main_size] (targets []CSSPixels, frozen []bool) CSSPixels {
		mut occupied := gap.scaled(f64(if line.items.len > 0 {
			line.items.len - 1
		} else {
			0
		}))
		for index in 0 .. line.items.len {
			occupied = occupied.plus(if frozen[index] {
				targets[index]
			} else {
				line.bases[index]
			}).plus(item_edges[index])
		}
		return container_main_size.minus(occupied)
	}
	initial_free_space := calculate_free_space(targets, frozen)
	mut iteration := 0
	for iteration < line.items.len + 1 {
		iteration++
		mut has_unfrozen_item := false
		for is_frozen in frozen {
			if !is_frozen {
				has_unfrozen_item = true
				break
			}
		}
		if !has_unfrozen_item {
			break
		}
		mut remaining_free_space := calculate_free_space(targets, frozen)
		mut factor_sum := 0.0
		for index, item in line.items {
			if !frozen[index] {
				factor_sum += if use_grow_factor {
					f64(item.computed_values().flex_grow())
				} else {
					f64(item.computed_values().flex_shrink())
				}
			}
		}
		if factor_sum < 1 {
			scaled_initial := initial_free_space.scaled(factor_sum)
			if flex_abs_pixels(scaled_initial).raw_value() < flex_abs_pixels(remaining_free_space).raw_value() {
				remaining_free_space = scaled_initial
			}
		}
		if use_grow_factor {
			mut cumulative_factor := 0.0
			mut assigned := CSSPixels.new(0)
			for index, item in line.items {
				if frozen[index] {
					continue
				}
				ratio := if factor_sum != 0 {
					f64(item.computed_values().flex_grow()) / factor_sum
				} else {
					0.0
				}
				cumulative_factor += ratio
				cumulative := remaining_free_space.scaled(cumulative_factor)
				targets[index] = line.bases[index].plus(cumulative.minus(assigned))
				assigned = cumulative
			}
		} else {
			mut scaled_shrink_sum := 0.0
			for index, item in line.items {
				if !frozen[index] {
					scaled_shrink_sum += f64(item.computed_values().flex_shrink()) * line.bases[index].to_double()
				}
			}
			for index, item in line.items {
				if frozen[index] {
					continue
				}
				scaled_factor := f64(item.computed_values().flex_shrink()) * line.bases[index].to_double()
				ratio := if scaled_shrink_sum != 0 {
					scaled_factor / scaled_shrink_sum
				} else {
					1.0
				}
				targets[index] =
					line.bases[index].minus(flex_abs_pixels(remaining_free_space).scaled(ratio))
			}
		}
		mut total_violation := CSSPixels.new(0)
		mut min_violations := []bool{len: line.items.len}
		mut max_violations := []bool{len: line.items.len}
		for index in 0 .. line.items.len {
			if frozen[index] {
				continue
			}
			if index < deferred_minimums.len && deferred_minimums[index] {
				item := line.items[index]
				styled := item.as_node_with_style() or { continue }
				item_state := state.get(styled)
				minimums[index] = flex_used_main_minimum(mut state, item, item_state, row_axis, available_main_size, false)
				deferred_minimums[index] = false
			}
			original := targets[index]
			targets[index] = css_pixels_max(CSSPixels.new(0), css_clamp(targets[index], minimums[index], line.maximums[index]))
			if targets[index].raw_value() > original.raw_value() {
				min_violations[index] = true
			} else if targets[index].raw_value() < original.raw_value() {
				max_violations[index] = true
			}
			total_violation = total_violation.plus(targets[index].minus(original))
		}
		if total_violation.raw_value() == 0 {
			for index in 0 .. frozen.len {
				frozen[index] = true
			}
		} else if total_violation.raw_value() > 0 {
			for index in 0 .. frozen.len {
				if min_violations[index] {
					frozen[index] = true
				}
			}
		} else {
			for index in 0 .. frozen.len {
				if max_violations[index] {
					frozen[index] = true
				}
			}
		}
	}
	return targets
}

// https://drafts.csswg.org/css-flexbox/#intrinsic-main-size
// calculate_intrinsic_main_size_of_flex_container(), for the block axis of a column
// container whose main size is indefinite. The row axis already runs this in
// calculate_intrinsic_flex_width(); the column path used to just add up the outer
// hypothetical main sizes, which ignores flexibility. `flex: 1 1 0` and `flex: 2 1 0` items
// whose contents are 20px and 30px tall need a 60px container, not a 50px one, because the
// second item has to end up twice the first for both to reach their contributions.
fn flex_intrinsic_main_size_of_column_container(mut state LayoutState, items []&Node, bases []CSSPixels, edges []CSSPixels, contributions []CSSPixels, gap CSSPixels) CSSPixels {
	mut desired_fractions := []f64{cap: items.len}
	mut sum_grow := 0.0
	mut sum_shrink := 0.0
	for index, item in items {
		if index >= bases.len || index >= contributions.len {
			break
		}
		computed := item.computed_values()
		grow := f64(computed.flex_grow())
		shrink := f64(computed.flex_shrink())

		// 1. Subtract the outer flex base size from the max-content contribution, then
		//    divide by the flex grow factor if it is >= 1 or multiply by it if it is < 1;
		//    a negative result is divided by the scaled flex shrink factor instead.
		mut difference := contributions[index].minus(bases[index].plus(edges[index]))
		scaled_shrink := shrink * bases[index].to_double()
		if difference.raw_value() > 0 {
			difference = if grow >= 1 {
				difference.divided_by_float(grow)
			} else {
				difference.scaled(grow)
			}
		} else if difference.raw_value() < 0 {
			difference = if scaled_shrink == 0 {
				CSSPixels.min()
			} else {
				difference.divided_by_float(scaled_shrink)
			}
		}
		desired_fractions << difference.to_double()
		sum_grow += grow
		sum_shrink += shrink
	}

	// 2./3. The line's chosen flex fraction is the greatest desired flex fraction, adjusted
	//       when the line's grow or shrink factors do not add up to a whole one.
	mut chosen := 0.0
	for fraction in desired_fractions {
		if fraction > chosen {
			chosen = fraction
		}
	}
	if chosen > 0 && sum_grow < 1 && sum_grow > 0 {
		chosen /= sum_grow
	} else if chosen < 0 && sum_shrink < 1 {
		chosen *= sum_shrink
	}

	// 4. Add each item's flex base size to the product of its flex factor and the chosen
	//    flex fraction, clamped by the item's own main min/max sizes. The outer size is
	//    summed so items with main-axis margins, borders, or padding do not overflow.
	mut total := CSSPixels.new(0)
	for index, item in items {
		if index >= desired_fractions.len {
			break
		}
		computed := item.computed_values()
		product := if desired_fractions[index] > 0 {
			chosen * f64(computed.flex_grow())
		} else if desired_fractions[index] < 0 {
			chosen * f64(computed.flex_shrink()) * bases[index].to_double()
		} else {
			0.0
		}
		mut result := bases[index].plus(CSSPixels.nearest_value_for(product))
		styled := item.as_node_with_style() or { continue }
		item_state := state.get(styled)
		minimum := flex_used_main_minimum(mut state, item, item_state, false, none, false)
		maximum := flex_used_main_maximum(mut state, item, item_state, false, none)
		result = css_clamp(result, minimum, maximum)
		total = total.plus(result).plus(edges[index])
	}

	// 5. CSS-FLEXBOX-2: account for the gap between flex items.
	if items.len > 1 {
		total = total.plus(gap.scaled(f64(items.len - 1)))
	}
	return total
}

fn flex_justify_offsets(justify css.JustifyContent, free_space CSSPixels, item_count int) (CSSPixels, CSSPixels) {
	if item_count == 0 {
		return CSSPixels.new(0), CSSPixels.new(0)
	}
	positive_free := css_pixels_max(free_space, CSSPixels.new(0))
	return match justify {
		.end_, .flex_end, .right {
			free_space, CSSPixels.new(0)
		}
		.center {
			flex_divide_by_integer(free_space, 2), CSSPixels.new(0)
		}
		.space_between {
			CSSPixels.new(0), if item_count > 1 {
				flex_divide_by_integer(positive_free, item_count - 1)
			} else {
				CSSPixels.new(0)
			}
		}
		.space_around {
			between := flex_divide_by_integer(positive_free, item_count)
			flex_divide_by_integer(between, 2), between
		}
		.space_evenly {
			between := flex_divide_by_integer(positive_free, item_count + 1)
			between, between
		}
		else {
			CSSPixels.new(0), CSSPixels.new(0)
		}
	}
}

fn flex_physical_leading_offset(container &Node, justify css.JustifyContent, free_space CSSPixels, logical_leading CSSPixels, distributed_gap CSSPixels, item_count int, row_axis bool, reversed bool, auto_margins_absorbed bool) CSSPixels {
	if auto_margins_absorbed {
		return CSSPixels.new(0)
	}
 computed := container.computed_values()
 inline_main := computed.effective_flex_direction() in [.row,.row_reverse]
 flow_reversed := if inline_main { layout_inline_axis_is_reverse(computed.writing_mode(),computed.direction()) } else { layout_block_axis_is_reverse(computed.writing_mode()) }
 match justify {
  .start { return if flow_reversed { free_space } else { CSSPixels.new(0) } }
  .end_ { return if flow_reversed { CSSPixels.new(0) } else { free_space } }
  .left { return CSSPixels.new(0) }
  .right { return if row_axis { free_space } else { CSSPixels.new(0) } }
  else {}
 }

	if !reversed || (justify == .center
		&& container.document().font_rendering_policy() == .chromium) {
		// Blink centers from the physical start using the truncated LayoutUnit
		// half-space. Mirroring an already truncated half gives its remainder
		// to the opposite edge and shifts an odd-subpixel row/column by 1/64px.
		return logical_leading
	}
	distributed_space := distributed_gap.scaled(f64(if item_count > 0 {
		item_count - 1
	} else {
		0
	}))
	return free_space.minus(logical_leading).minus(distributed_space)
}

// align_all_flex_lines(). C++ turns align-content into a starting cross edge, a distributed
// gap, and two direction flags, then walks the lines from that edge - *subtracting* each
// line's cross size for the keywords that place items backwards, rather than accumulating
// forwards from a leading offset.
//
// The distinction is not cosmetic. handle_align_content_stretch() grows each line by a
// truncated `remainder / line_count`, so the stretched line sizes can fall short of the
// container by a subpixel; three lines sharing 70px take 23.328125px each, 1/64px short of
// 160px. Accumulating forwards hands that residue to the last line placed, while starting
// from the container's far edge never sees it, because a line's own cross size cancels out
// of the centre calculation.
struct FlexLinePlacement {
mut:
	start_of_current_line   CSSPixels
	gap_size                CSSPixels
	place_items_backwards   bool
	iterate_lines_backwards bool
}

fn flex_line_placement(align css.AlignContent, cross_size_of_flex_container CSSPixels, sum_of_flex_line_cross_sizes CSSPixels, line_count int, reverse_cross_axis bool) FlexLinePlacement {
	mut placement := FlexLinePlacement{}
	if line_count == 0 {
		return placement
	}
	leftover_free_space := cross_size_of_flex_container.minus(sum_of_flex_line_cross_sizes)
	centered_start := flex_divide_by_integer(cross_size_of_flex_container, 2).minus(flex_divide_by_integer(sum_of_flex_line_cross_sizes, 2))
	match align {
		.start {
			placement.iterate_lines_backwards = reverse_cross_axis
		}
		.end_ {
			placement.start_of_current_line = cross_size_of_flex_container
			placement.place_items_backwards = true
			placement.iterate_lines_backwards = !reverse_cross_axis
		}
		.flex_start {
			if reverse_cross_axis {
				placement.start_of_current_line = cross_size_of_flex_container
				placement.place_items_backwards = true
			}
		}
		.flex_end {
			placement.iterate_lines_backwards = true
			if !reverse_cross_axis {
				placement.start_of_current_line = cross_size_of_flex_container
				placement.place_items_backwards = true
			}
		}
		.center {
			placement.iterate_lines_backwards = reverse_cross_axis
			placement.start_of_current_line = centered_start
		}
		.space_between {
			if reverse_cross_axis {
				placement.start_of_current_line = cross_size_of_flex_container
				placement.place_items_backwards = true
			}
			if leftover_free_space.raw_value() >= 0 && line_count > 1 {
				placement.gap_size = flex_divide_by_integer(leftover_free_space, line_count - 1)
			}
		}
		.space_around {
			placement.iterate_lines_backwards = reverse_cross_axis
			// "If the leftover free-space is negative this value is identical to center."
			if leftover_free_space.raw_value() < 0 {
				placement.start_of_current_line = centered_start
			} else {
				placement.gap_size = flex_divide_by_integer(leftover_free_space, line_count)
				// Half the inter-line spacing sits between the edges and the first/last line.
				placement.start_of_current_line = flex_divide_by_integer(placement.gap_size, 2)
			}
		}
		.space_evenly {
			placement.iterate_lines_backwards = reverse_cross_axis
			if leftover_free_space.raw_value() < 0 {
				placement.start_of_current_line = centered_start
			} else {
				placement.gap_size = flex_divide_by_integer(leftover_free_space, line_count + 1)
				// The edge spacing matches the inter-line spacing.
				placement.start_of_current_line = placement.gap_size
			}
		}
		else {
			// `normal` and `stretch`: the lines were already grown to fill the container.
			if reverse_cross_axis {
				placement.start_of_current_line = cross_size_of_flex_container
				placement.place_items_backwards = true
			}
		}
	}
	return placement
}

fn flex_formatting_cross_axis_is_reversed(container &Node) bool {
	computed := container.computed_values()
	is_row_layout := computed.effective_flex_direction() in [.row, .row_reverse]
	mut reverse := if is_row_layout {
		layout_block_axis_is_reverse(computed.writing_mode())
	} else {
		layout_inline_axis_is_reverse(computed.writing_mode(), computed.direction())
	}
	if computed.flex_wrap() == .wrap_reverse {
		reverse = !reverse
	}
	return reverse
}

fn flex_align_content_offsets(align css.AlignContent, free_space CSSPixels, line_count int, wrap_reverse bool) (CSSPixels, CSSPixels, CSSPixels) {
	if line_count == 0 {
		return CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0)
	}
	positive_free := css_pixels_max(free_space, CSSPixels.new(0))
	mut effective := align
	if wrap_reverse {
		effective = match align {
			.start, .flex_start { css.AlignContent.end_ }
			.end_, .flex_end { css.AlignContent.start }
			else { align }
		}
	}
	// align_all_flex_lines(): for space-around and space-evenly, "if the leftover free-space
	// is negative this value is identical to center". Distributing the clamped, non-negative
	// free space instead left overflowing lines at the cross-start edge rather than
	// overflowing evenly on both sides.
	if free_space.raw_value() < 0 && effective in [css.AlignContent.space_around, .space_evenly] {
		return flex_divide_by_integer(free_space, 2), CSSPixels.new(0), CSSPixels.new(0)
	}
	return match effective {
		.end_, .flex_end {
			free_space, CSSPixels.new(0), CSSPixels.new(0)
		}
		.center {
			flex_divide_by_integer(free_space, 2), CSSPixels.new(0), CSSPixels.new(0)
		}
		.space_between {
			CSSPixels.new(0), if line_count > 1 {
				flex_divide_by_integer(positive_free, line_count - 1)
			} else {
				CSSPixels.new(0)
			}, CSSPixels.new(0)
		}
		.space_around {
			between := flex_divide_by_integer(positive_free, line_count)
			flex_divide_by_integer(between, 2), between, CSSPixels.new(0)
		}
		.space_evenly {
			between := flex_divide_by_integer(positive_free, line_count + 1)
			between, between, CSSPixels.new(0)
		}
		.normal, .stretch {
			CSSPixels.new(0), CSSPixels.new(0), flex_divide_by_integer(positive_free, line_count)
		}
		else {
			CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0)
		}
	}
}

fn effective_flex_cross_alignment(container &Node, item &Node) FlexCrossAlignment {
	if value := item.computed_values().property(.align_self,.yes) {
		if value.css_text == 'last baseline' { return .baseline }
	}
	self := item.computed_values().align_self()
	match self {
		.end_, .self_end {
			return .self_end
		}
		.flex_end {
			return .end
		}
		.center {
			return .center
		}
		.stretch {
			return .stretch
		}
		.normal {
			return .normal
		}
		.baseline {
			return .baseline
		}
		.start, .self_start {
			return .self_start
		}
		.flex_start {
			return .start
		}
		else {}
	}
	if value := container.computed_values().property(.align_items,.yes) {
		if value.css_text == 'last baseline' { return .baseline }
	}
	return match container.computed_values().align_items() {
		.end_, .self_end { .self_end }
		.flex_end { .end }
		.center { .center }
		.baseline { .baseline }
		.start, .self_start { .self_start }
		.flex_start { .start }
		.stretch { .stretch }
		else { .normal }
	}
}

// align_all_flex_items_along_the_cross_axis(). Only `normal` consults flex-wrap:
// https://drafts.csswg.org/css-flexbox/#flex-wrap-property says wrap-reverse swaps the
// cross-start and cross-end directions, and C++ applies that swap to the `normal` case
// alone. Every explicit keyword names a fixed edge of the line, so `flex-start` stays at the
// line's cross-start edge and `flex-end` at its cross-end edge whichever way the container
// wraps, and the inline `direction` does not enter into it either.
fn cross_alignment_offset(alignment FlexCrossAlignment, cross_size CSSPixels, item_size CSSPixels, wrap_reverse bool) CSSPixels {
	return match alignment {
		.normal {
			if wrap_reverse {
				cross_size.minus(item_size)
			} else {
				CSSPixels.new(0)
			}
		}
		.start, .self_start, .stretch, .baseline {
			CSSPixels.new(0)
		}
		.end, .self_end {
			cross_size.minus(item_size)
		}
		.center {
			flex_divide_by_integer(cross_size.minus(item_size), 2)
		}
	}
}

fn flex_line_max_baseline(state &LayoutState, container &Node, line FlexLine) CSSPixels {
	mut maximum := CSSPixels.new(0)
	for item in line.items {
		if flex_item_participates_in_baseline_alignment(container, item) {
			maximum = css_pixels_max(maximum, grid_baseline_from_low(state,container,item,flex_physical_direction(container) in [.column,.column_reverse],.first,0))
		}
	}
	return maximum
}

fn flex_item_participates_in_baseline_alignment(container &Node, item &Node) bool {
	row_axis := flex_physical_direction(container) in [.row, .row_reverse]
	return effective_flex_cross_alignment(container, item) == .baseline
		&& !property_is_auto(item.computed_values(), if row_axis { .margin_top } else { .margin_left })
		&& !property_is_auto(item.computed_values(), if row_axis { .margin_bottom } else { .margin_right })
}

fn flex_line_row_baseline_cross_size(state &LayoutState, container &Node, line FlexLine) CSSPixels {
 mut size := CSSPixels.new(0)
 for preference in [BaselineSet.first,.last] {
  mut ascent,mut descent := CSSPixels.new(0),CSSPixels.new(0)
  for item in line.items {
   if !flex_item_participates_in_baseline_alignment(container,item) || flex_baseline_preference(container,item) != preference { continue }
   used := state.get(item.as_node_with_style() or { continue })
   baseline := grid_baseline_from_low(state,container,item,false,preference,0)
   ascent = css_pixels_max(ascent,baseline)
   descent = css_pixels_max(descent,used.margin_box_height().minus(baseline))
  }
  size = css_pixels_max(size,ascent.plus(descent))
 }
 return size
}

fn flex_static_main_axis_alignment(container &Node, direction css.FlexDirection) StaticPositionAlignment {
	reversed := direction in [.row_reverse,.column_reverse]
	return match container.computed_values().justify_content() {
		.start, .left {
			StaticPositionAlignment.start
		}
		.end_, .right {
			StaticPositionAlignment.end
		}
		.normal, .stretch, .flex_start, .space_between {
			if reversed {
				StaticPositionAlignment.end
			} else {
				StaticPositionAlignment.start
			}
		}
		.flex_end {
			if reversed {
				StaticPositionAlignment.start
			} else {
				StaticPositionAlignment.end
			}
		}
		.center, .space_around, .space_evenly {
			StaticPositionAlignment.center
		}
	}
}

fn set_flex_abspos_static_positions(mut state LayoutState, container &Node, container_state &UsedValues, direction css.FlexDirection) {
	row_axis := direction in [.row, .row_reverse]
	main_alignment := flex_static_main_axis_alignment(container, direction)
	cross_reversed := flex_formatting_cross_axis_is_reversed(container)
	for child in container.children() {
		if !child.is_absolutely_positioned() {
			continue
		}
		styled := child.as_node_with_style() or { continue }
		cross_alignment := match effective_flex_cross_alignment(container, child) {
			.end, .self_end {
				if cross_reversed {
					StaticPositionAlignment.start
				} else {
					StaticPositionAlignment.end
				}
			}
			.center {
				StaticPositionAlignment.center
			}
			else {
				if cross_reversed {
					StaticPositionAlignment.end
				} else {
					StaticPositionAlignment.start
				}
			}
		}
		mut child_state := state.mutable_internal_box_values(styled)
		child_state.set_static_position_rect(StaticPositionRect{
			rect: css.CSSPixelRect.new(0, 0, container_state.content_width().to_double(), container_state.content_height().to_double())
			horizontal_alignment: if row_axis { main_alignment } else { cross_alignment }
			vertical_alignment: if row_axis { cross_alignment } else { main_alignment }
		})
	}
}

fn clear_intrinsic_flex_item_line_boxes(mut state LayoutState, node &Node) {
	if styled := node.as_node_with_style() {
		if mut values := state.values_for_line_disposal(styled) {
			// Descendants may have been laid out in normal mode even though
			// this ancestor is an intrinsic probe. Their flex/grid baselines
			// must survive removal of the descendant text lines too.
			if node.display().is_flex_inside() || node.display().is_grid_inside() {
				cache_intrinsic_flex_baselines(mut state, node, values, .intrinsic_sizing)
			}
			values.clear_line_boxes()
		}
	}
	for child in node.children() {
		clear_intrinsic_flex_item_line_boxes(mut state, child)
	}
}

// Intrinsic measurement of an inline flex container also supplies its atomic
// inline block size and baseline to the parent IFC. Resolve an automatic block
// size before the alignment phases, so min/max-height affect justify-content
// and align-content rather than being applied only after item placement.
fn resolve_inline_flex_auto_block_size_for_alignment(state &LayoutState, container &Node, container_state &UsedValues, available_space AvailableSpace, automatic_size CSSPixels) CSSPixels {
	if !container.display().is_inline_outside() || !available_space.height.is_indefinite() {
		return automatic_size
	}
	box := container.as_box() or { return automatic_size }
	if !should_treat_height_as_auto(state, box, available_space) {
		return automatic_size
	}
	return clamp_layout_content_size(container, automatic_size,
		available_space.height.to_px_or_zero(), container_state, false)
}

// Block flex boxes also export baselines through enclosing inline blocks,
// including a button's anonymous flex wrapper. Preserve both sets before an
// intrinsic run discards descendant line boxes.
fn cache_intrinsic_flex_baselines(mut state LayoutState, container &Node, container_state &UsedValues, layout_mode LayoutMode) {
	if layout_mode != .intrinsic_sizing {
		return
	}
	first := layout_box_baseline(state, container, .first).minus(container_state.margin_box_top())
	last := layout_box_baseline(state, container, .last).minus(container_state.margin_box_top())
	mut mutable_container_state := state.mutable_internal_box_values(container.as_node_with_style() or { return })
	mutable_container_state.set_derived_baselines(first, last)
}

// Promoting an unchanged used height to a definite percentage basis only
// requires inside-layout again when some descendant consumes that basis.
// Cache this tree property within the layout state, whose styles stay fixed.
fn flex_grid_has_only_implicit_auto_rows(node &Node) bool {
	computed := node.computed_values()
	if !computed.grid_template_rows().is_empty() {
		return false
	}
	for track in computed.grid_auto_rows().track_list() {
		value := track.value_
		if value !is css.GridSize {
			return false
		}
		grid_size := value as css.GridSize
		if !grid_size.is_auto(AvailableSize.make_definite(CSSPixels.new(0))) {
			return false
		}
	}
	return true
}

fn flex_subtree_depends_on_definite_height(mut state LayoutState, node &Node) bool {
	styled := node.as_node_with_style() or { return false }
	key := styled.layout_index()
	if cached := state.cached_definite_height_dependency(key) {
		return cached
	}
	computed := node.computed_values()
	// With unchanged content dimensions, implicit automatic grid rows have
	// the same contributions and free space. Their descendants still undergo
	// the dependency walk below. Explicit, percentage, flexible and subgrid
	// rows retain the conservative inside-layout pass.
	mut depends := node.is_absolutely_positioned()
		|| (node.display().is_grid_inside() && !flex_grid_has_only_implicit_auto_rows(node))
		|| computed.writing_mode() != .horizontal_tb
	for property_id in [css.PropertyID.height, .min_height, .max_height, .top, .bottom] {
		if computed.size_value(property_id).contains_percentage() {
			depends = true
		}
	}
	mut basis_depends_on_height := computed.flex_basis().size.contains_percentage()
	if basis_depends_on_height {
		if parent := node.parent() {
			parent_computed := parent.computed_values()
			if parent.display().is_flex_inside()
				&& parent_computed.writing_mode() == .horizontal_tb
				&& parent_computed.effective_flex_direction() in [.row, .row_reverse] {
				basis_depends_on_height = false
			}
		}
	}
	if basis_depends_on_height
		|| computed.gap_value(.row_gap).length_percentage.contains_percentage() {
		depends = true
	}
	if node.is_flex_item() && property_is_auto(computed, .height) {
		if box := node.as_box() {
			if box.has_preferred_aspect_ratio() {
				depends = true
			}
		}
	}
	// A descendant with its own definite length height already supplies the
	// percentage basis below it. Its children cannot depend on a higher item's
	// transition from an automatic to a definite used height.
	height := computed.size_value(.height)
	has_independent_height := height.is_length_percentage() && !height.contains_percentage()
	if !depends && !has_independent_height {
		for child in node.children() {
			if flex_subtree_depends_on_definite_height(mut state, child) {
				depends = true
				break
			}
		}
	}
	state.cache_definite_height_dependency(key, depends)
	return depends
}

fn run_uncached_flex_formatting_context_with_mode(mut state LayoutState, container &Node, mut container_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	mut geometry_scratch := begin_nested_geometry_scratch(container.document(), layout_mode)
	defer { geometry_scratch.finish() }
	container_state.set_derived_baselines(none, none)
	container_state.set_derived_vertical_baselines(none,none)
	direction := flex_physical_direction(container)
	if direction in [.column, .column_reverse] {
		result := run_column_flex_formatting_context(mut state, container, mut container_state, layout_mode, available_space)
		cache_intrinsic_flex_baselines(mut state, container, container_state, layout_mode)
		if layout_mode == .intrinsic_sizing {
			for child in container.children() {
				clear_intrinsic_flex_item_line_boxes(mut state, child)
			}
		}
		return result
	}
	items := ordered_flex_items(container)
	container_width := container_state.content_width()
	column_gap := flex_formatting_context_main_gap(container, container_width, true)
	row_gap := flex_formatting_context_cross_gap(container, container_state.content_height(), true)
	mut bases := []CSSPixels{cap: items.len}
	mut edges := []CSSPixels{cap: items.len}
	for item in items {
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.mutable_internal_box_values(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, container_width.to_double())
		// Definite-size rule: before determining flex bases, a stretched item in
		// a single-line container with a definite cross size gets the container's
		// inner cross size, clamped by its own cross-axis constraints.
		if container.computed_values().flex_wrap() == .nowrap
			&& container_state.has_definite_height()
			&& effective_flex_cross_alignment(container, item) in [.stretch, .normal]
			&& property_is_auto(item.computed_values(), .height)
			&& !property_is_auto(item.computed_values(), .margin_top)
			&& !property_is_auto(item.computed_values(), .margin_bottom) {
			inner_cross_size :=
				container_state.content_height().minus(item_state.margin_top).minus(item_state.margin_bottom).minus(item_state.padding_top).minus(item_state.padding_bottom).minus(item_state.border_top).minus(item_state.border_bottom)
			stretched_cross_size := clamp_layout_content_size(item, css_pixels_max(CSSPixels.new(0), inner_cross_size), container_state.content_height(), item_state, false)
			item_state.set_content_height(stretched_cross_size)
			item_state.set_has_definite_height(true)
		}
		base := flex_base_width(mut state, item, container_width, item_state)
		bases << base
		edges << flex_or_grid_item_outer_inline_edges(item_state)
	}
	skip_automatic_minimum := should_skip_automatic_minimum_size_clamp(state, container, container_state, layout_mode, items, bases, true, available_space.width.to_px_or_zero())
	mut minimums := []CSSPixels{cap: items.len}
	mut deferred_minimums := []bool{cap: items.len}
	mut maximums := []CSSPixels{cap: items.len}
	mut hypotheticals := []CSSPixels{cap: items.len}
	for index, item in items {
		styled := item.as_node_with_style() or { continue }
		item_state := state.get(styled)
		item_can_skip_automatic_minimum := can_skip_automatic_minimum_size_for_item(item, item_state, container_state, bases[index], true, container_width)
		defer_automatic_minimum := (skip_automatic_minimum
			|| item_can_skip_automatic_minimum)
			&& item.computed_values().size_value(.min_width).is_auto()
		minimum := flex_used_main_minimum(mut state, item, item_state, true, container_width, defer_automatic_minimum)
		maximum := flex_used_main_maximum(mut state, item, item_state, true, container_width)
		minimums << minimum
		deferred_minimums << defer_automatic_minimum
		maximums << maximum
		hypotheticals << flex_hypothetical_main_size(bases[index], minimum, maximum)
	}

	wraps := container.computed_values().flex_wrap() != .nowrap
	mut lines := []FlexLine{cap: if wraps { 4 } else { 1 }}
	mut line := new_flex_line(if wraps { 8 } else { items.len })
	mut occupied := CSSPixels.new(0)
	for index, item in items {
		outer := hypotheticals[index].plus(edges[index])
		addition := if line.items.len > 0 { outer.plus(column_gap) } else { outer }
		if wraps && line.items.len > 0
			&& occupied.plus(addition).raw_value() > container_width.raw_value() {
			lines << line
			line = new_flex_line(8)
			occupied = CSSPixels.new(0)
		}
		line.items << item
		line.bases << bases[index]
		line.minimums << minimums[index]
		line.deferred_minimums << deferred_minimums[index]
		line.maximums << maximums[index]
		line.hypotheticals << hypotheticals[index]
		occupied = if line.items.len > 1 { occupied.plus(column_gap).plus(outer) } else { outer }
	}
	if line.items.len > 0 {
		lines << line
	}

	mut automatic_width := CSSPixels.new(0)
	mut line_cross_sizes := []CSSPixels{cap: lines.len}
	for line_index in 0 .. lines.len {
		mut current_line := lines[line_index]
		mut line_edges := []CSSPixels{cap: current_line.items.len}
		for item in current_line.items {
			styled := item.as_node_with_style() or { continue }
			item_state := state.get(styled)
			line_edges << flex_or_grid_item_outer_inline_edges(item_state)
		}
		current_line.targets = resolve_flexible_lengths(mut state, current_line, container_width, line_edges, column_gap, container_width, true)
		lines[line_index] = current_line
		mut cross_size := CSSPixels.new(0)
		mut used_main := column_gap.scaled(f64(if current_line.items.len > 0 {
			current_line.items.len - 1
		} else {
			0
		}))
		for index, item in current_line.items {
			mut natural_cross := ?CSSPixels(none)
			if item.computed_values().size_value(.height).is_stretch() && !container_state.has_definite_height() {
				if box := item.as_box() {
					natural_cross = calculate_max_content_height(mut state, box, current_line.targets[index])
				}
			}
			item_state := layout_independent_child(mut state, item, mut container_state, container_width, if container_state.has_definite_height() {
				container_state.content_height()
			} else {
				none
			}, current_line.targets[index], natural_cross)
			cross_size = css_pixels_max(cross_size, item_state.margin_box_height())
			used_main = used_main.plus(item_state.margin_box_width())
		}
		// Baseline alignment can shift a shorter item below the tallest one.
		// The line must enclose the largest ascent and descent independently.
		cross_size = css_pixels_max(cross_size, flex_line_row_baseline_cross_size(state,
			container, current_line))
		// calculate_cross_size_of_each_flex_line(): "If the flex container is single-line and
		// has a definite cross size, the cross size of the flex line is the flex container's
		// inner cross size." is_single_line() is `flex-wrap: nowrap`, not "only one line came
		// out of collection" - a wrapping container that happens to fit on one line still
		// sizes that line to its items, which is what lets align-content move it.
		if container.computed_values().flex_wrap() == .nowrap {
			if container_state.has_definite_height() {
				cross_size = container_state.content_height()
			} else if available_space.height.is_definite() {
				// A parent relayout caused by a resolved min-height constrains the
				// flex line without making percentage descendants definite.
				cross_size = available_space.height.to_px_or_zero()
			}
		}
		line_cross_sizes << cross_size
		automatic_width = css_pixels_max(automatic_width, used_main)
	}
	mut total_cross_size := row_gap.scaled(f64(if line_cross_sizes.len > 0 {
		line_cross_sizes.len - 1
	} else {
		0
	}))
	for cross_size in line_cross_sizes {
		total_cross_size = total_cross_size.plus(cross_size)
	}
	resolved_automatic_cross_size := resolve_inline_flex_auto_block_size_for_alignment(state, container,
		container_state, available_space, total_cross_size)
	// https://drafts.csswg.org/css-flexbox-1/#definite-sizes
	// Once the line cross sizes of an auto-height row flex container are known,
	// each item's used cross size is definite for laying out its descendants.
	// This second inside-layout pass is observable when an item's authored
	// percentage height was initially unresolved: its own used height remains
	// content-derived, but nested percentage heights now resolve against it.
	if !container_state.has_definite_height() && layout_mode != .intrinsic_sizing {
		for current_line in lines {
			for item_index, item in current_line.items {
				styled := item.as_node_with_style() or { continue }
				mut item_state := state.mutable_internal_box_values(styled)
				if item_state.has_definite_height() {
					continue
				}
				if !flex_subtree_depends_on_definite_height(mut state, item) {
					item_state.set_has_definite_height(true)
					continue
				}
				layout_independent_child(mut state, item, mut container_state, container_width,
					none, current_line.targets[item_index], item_state.content_height())
			}
		}
	}
	reverse_cross_axis := flex_formatting_cross_axis_is_reversed(container)
	available_cross_size := if container_state.has_definite_height() {
		container_state.content_height()
	} else if available_space.height.is_definite() {
		available_space.height.to_px_or_zero()
	} else {
		resolved_automatic_cross_size
	}
	_, _, stretched_cross_space := flex_align_content_offsets(container.computed_values().align_content(), available_cross_size.minus(total_cross_size), line_cross_sizes.len, reverse_cross_axis)
	// handle_align_content_stretch(): grow every line by an equal, truncated share so their
	// sum reaches the container's inner cross size.
	if stretched_cross_space.raw_value() > 0 {
		for index in 0 .. line_cross_sizes.len {
			line_cross_sizes[index] = line_cross_sizes[index].plus(stretched_cross_space)
		}
		total_cross_size = total_cross_size.plus(stretched_cross_space.scaled(f64(line_cross_sizes.len)))
	}
	mut placement := flex_line_placement(container.computed_values().align_content(), available_cross_size, total_cross_size, lines.len, reverse_cross_axis)
	distributed_cross_space := placement.gap_size

	mut line_order := []int{cap: lines.len}
	for index in 0 .. lines.len {
		line_order << index
	}
	if placement.iterate_lines_backwards {
		line_order.reverse_in_place()
	}
	main_reversed := direction == .row_reverse
	for visual_line_index, line_index in line_order {
		current_line := lines[line_index]
		cross_size := line_cross_sizes[line_index]
		mut total_main := column_gap.scaled(f64(if current_line.items.len > 0 {
			current_line.items.len - 1
		} else {
			0
		}))
		for item in current_line.items {
			styled := item.as_node_with_style() or { continue }
			total_main = total_main.plus(state.get(styled).margin_box_width())
		}
		mut auto_main_margin_count := 0
		for item in current_line.items {
			if property_is_auto(item.computed_values(), .margin_left) {
				auto_main_margin_count++
			}
			if property_is_auto(item.computed_values(), .margin_right) {
				auto_main_margin_count++
			}
		}
		main_free_space := container_width.minus(total_main)
		mut absorbed_main_space := false
		if main_free_space.raw_value() > 0 && auto_main_margin_count > 0 {
			mut margin_index := 0
			for item in current_line.items {
				styled := item.as_node_with_style() or { continue }
				mut item_state := state.mutable_internal_box_values(styled)
				if property_is_auto(item.computed_values(), .margin_left) {
					item_state.margin_left = flex_fractional_share(main_free_space,margin_index,auto_main_margin_count)
					margin_index++
				}
				if property_is_auto(item.computed_values(), .margin_right) {
					item_state.margin_right = flex_fractional_share(main_free_space,margin_index,auto_main_margin_count)
					margin_index++
				}
			}
			absorbed_main_space = true
		}
		mut leading := CSSPixels.new(0)
		mut distributed_gap := CSSPixels.new(0)
		if !absorbed_main_space {
			leading, distributed_gap = flex_justify_offsets(container.computed_values().justify_content(), main_free_space, current_line.items.len)
		}
		mut cursor := flex_physical_leading_offset(container, container.computed_values().justify_content(), main_free_space, leading, distributed_gap, current_line.items.len, true, main_reversed, absorbed_main_space)
		mut indexes := []int{cap: current_line.items.len}
		for index in 0 .. current_line.items.len {
			indexes << index
		}
		if main_reversed {
			indexes.reverse_in_place()
		}
		for visual_index, item_index in indexes {
			item := current_line.items[item_index]
			styled := item.as_node_with_style() or { continue }
			mut item_state := state.mutable_internal_box_values(styled)
			alignment := effective_flex_cross_alignment(container, item)
			top_margin_auto := property_is_auto(item.computed_values(), .margin_top)
			bottom_margin_auto := property_is_auto(item.computed_values(), .margin_bottom)
			if constrained := flex_cross_size_with_stretch_constraints(mut state, item, item_state, container_state.content_height(), cross_size, false) {
				item_state = layout_independent_child_with_resolved_height(mut state, item, mut container_state, container_width, if container_state.has_definite_height() { container_state.content_height() } else { none }, current_line.targets[item_index], constrained)
			}
			if item.computed_values().size_value(.height).is_stretch()
				|| (alignment in [.stretch, .normal] && property_is_auto(item.computed_values(), .height)
				&& !top_margin_auto && !bottom_margin_auto) {
				stretched := if item.computed_values().size_value(.height).is_stretch() {
					clamp_layout_content_size(item, stretch_fit_content_size(item, item_state, cross_size, false), cross_size, item_state, false)
				} else { clamp_layout_content_size_with_stretch_basis(item, cross_size.minus(flex_or_grid_item_outer_block_edges(item_state)), container_state.content_height(), cross_size, item_state, false) }
				if stretched == item_state.content_height()
					&& (item_state.has_definite_height()
						|| !flex_subtree_depends_on_definite_height(mut state, item)) {
					item_state.set_has_definite_height(true)
				} else {
					item_state = layout_independent_child_with_resolved_height(mut state, item, mut container_state, container_width, if container_state.has_definite_height() {
						container_state.content_height()
					} else {
						none
					}, current_line.targets[item_index], stretched)
				}
			}
			cross_free_space := cross_size.minus(item_state.margin_box_height())
			mut cross_delta := CSSPixels.new(0)
			if cross_free_space.raw_value() > 0 && top_margin_auto && bottom_margin_auto {
				item_state.margin_top = flex_divide_by_integer(cross_free_space, 2)
				item_state.margin_bottom = flex_divide_by_integer(cross_free_space, 2)
			} else if cross_free_space.raw_value() > 0 && top_margin_auto {
				item_state.margin_top = cross_free_space
			} else if cross_free_space.raw_value() > 0 && bottom_margin_auto {
				item_state.margin_bottom = cross_free_space
			} else {
				cross_delta = cross_alignment_offset(alignment, cross_size, item_state.margin_box_height(), reverse_cross_axis)
				if flex_item_participates_in_baseline_alignment(container, item) {
					// Baseline-aligned items start at the line's cross-start edge, so the
					// baseline shift always runs towards cross-end.
					cross_delta = cross_delta.plus(flex_row_baseline_alignment_delta(state,container,item,current_line,cross_size))
				}
			}
			item_state.set_content_x(cursor.plus(item_state.margin_box_left()))
			line_cross_start := if placement.place_items_backwards {
				placement.start_of_current_line.minus(cross_size)
			} else {
				placement.start_of_current_line
			}
			item_state.set_content_y(line_cross_start.plus(cross_delta).plus(item_state.margin_box_top()))
			cursor = cursor.plus(item_state.margin_box_width())
			// The flex algorithm consumes resolved main-axis auto margins while
			// positioning, then the item's normal inside-layout pass exposes the
			// computed auto margins as zero in UsedValues. Keep the consumed space
			// in the cursor but mirror that final upstream state in the dump.
			if property_is_auto(item.computed_values(), .margin_left) {
				item_state.margin_left = CSSPixels.new(0)
			}
			if property_is_auto(item.computed_values(), .margin_right) {
				item_state.margin_right = CSSPixels.new(0)
			}
			if property_is_auto(item.computed_values(), .margin_top) {
				item_state.margin_top = CSSPixels.new(0)
			}
			if property_is_auto(item.computed_values(), .margin_bottom) {
				item_state.margin_bottom = CSSPixels.new(0)
			}
			if visual_index + 1 < indexes.len {
				cursor = cursor.plus(column_gap).plus(distributed_gap)
				if !absorbed_main_space {
					cursor = cursor.plus(flex_distribution_remainder(container.computed_values().justify_content(),main_free_space,indexes.len,visual_index,distributed_gap))
				}
			}
		}
		if placement.place_items_backwards {
			placement.start_of_current_line = placement.start_of_current_line.minus(cross_size).minus(distributed_cross_space).minus(row_gap)
		} else {
			placement.start_of_current_line = placement.start_of_current_line.plus(cross_size).plus(distributed_cross_space).plus(row_gap)
		}
		if container.computed_values().align_content() == .space_between && visual_line_index+1 < lines.len {
			adjustment := flex_distribution_remainder(.space_between,available_cross_size.minus(total_cross_size),lines.len,visual_line_index,distributed_cross_space)
			placement.start_of_current_line = if placement.place_items_backwards { placement.start_of_current_line.minus(adjustment) } else { placement.start_of_current_line.plus(adjustment) }
		}
		_ = visual_line_index
	}
	publish_flex_content_baselines(mut state,container,mut container_state,lines,true)
	chromium_align_text_control_placeholder(mut state, container)
	set_flex_abspos_static_positions(mut state, container, container_state, direction)
	result := FormattingContextResult{
		automatic_content_width: automatic_width
		automatic_content_height: if container_state.has_definite_height() {
			container_state.content_height()
		} else {
			resolved_automatic_cross_size
		}
	}
	cache_intrinsic_flex_baselines(mut state, container, container_state, layout_mode)
	if layout_mode == .intrinsic_sizing {
		for child in container.children() {
			clear_intrinsic_flex_item_line_boxes(mut state, child)
		}
	}
	return result
}

fn run_column_flex_formatting_context(mut state LayoutState, container &Node, mut container_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	items := ordered_flex_items(container)
	container_width := container_state.content_width()
	mut container_height := if container_state.has_definite_height() {
		?CSSPixels(container_state.content_height())
	} else if available_space.height.is_definite() {
		?CSSPixels(available_space.height.to_px_or_zero())
	} else {
		?CSSPixels(none)
	}
	if container.computed_values().flex_wrap() != .nowrap {
		if container_height == none {
			// A definite max-height bounds line collection even when height is auto.
			maximum := container.computed_values().size_value(.max_height)
			if maximum.is_length() || (maximum.is_calculated() && !maximum.contains_percentage()) {
				container_height = resolve_flex_main_size(container,maximum,none,container_state,false)
			}
		}
		if definite_height := container_height {
			return run_wrapping_column_flex_formatting_context(mut state, container, mut container_state, items, container_width, definite_height, layout_mode)
		}
	}
	row_gap := flex_formatting_context_main_gap(container, container_height or {
		CSSPixels.new(0)
	}, false)
	mut bases := []CSSPixels{cap: items.len}
	mut edges := []CSSPixels{cap: items.len}
	mut contributions := []CSSPixels{cap: items.len}
	for item in items {
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.mutable_internal_box_values(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, container_width.to_double())
		alignment := effective_flex_cross_alignment(container, item)
		has_auto_cross_margin := property_is_auto(item.computed_values(), .margin_left)
			|| property_is_auto(item.computed_values(), .margin_right)
		mut forced_width := if item.computed_values().size_value(.width).is_stretch() {
			?CSSPixels(stretch_fit_content_size(item, item_state, container_width, true))
		} else if alignment in [.stretch, .normal]
			&& property_is_auto(item.computed_values(), .width) && !has_auto_cross_margin {
			?CSSPixels(container_width.minus(flex_or_grid_item_outer_inline_edges(item_state)))
		} else if property_is_auto(item.computed_values(), .width) {
			// A definite block size plus a preferred aspect ratio transfers an
			// automatic cross size before falling back to max-content.
			?CSSPixels(flex_formatting_context_transferred_size_suggestion(item, item_state, true) or {
				if flex_item_has_aspect_ratio_without_natural_dimensions(item) {
					calculate_stretch_fit_width(item.as_box() or {
						panic('flex item must be a box')
					}, AvailableSize.make_definite(container_width))
				} else {
					flex_fit_content_cross_width(mut state, item, container_width)
				}
			})
		} else {
			resolve_layout_content_size(item, item.computed_values().size_value(.width), container_width, item_state, true)
		}
		if width := forced_width {
			forced_width = clamp_layout_content_size(item, width, container_width, item_state, true)
		}
		laid_out := layout_independent_child(mut state, item, mut container_state, container_width, container_height, forced_width, none)
		base := flex_base_height(mut state, item, container_height, laid_out.content_height(), laid_out)
		bases << base
		edges << flex_or_grid_item_outer_block_edges(laid_out)
		// Laid out without a main-size target, so this is the item's outer max-content
		// contribution in the block axis - what the intrinsic main size below needs.
		contributions << laid_out.margin_box_height()
	}
	skip_automatic_minimum := should_skip_automatic_minimum_size_clamp(state, container, container_state, layout_mode, items, bases, false, available_space.height.to_px_or_zero())
	mut minimums := []CSSPixels{cap: items.len}
	mut deferred_minimums := []bool{cap: items.len}
	mut maximums := []CSSPixels{cap: items.len}
	mut hypotheticals := []CSSPixels{cap: items.len}
	for index, item in items {
		styled := item.as_node_with_style() or { continue }
		item_state := state.get(styled)
		item_can_skip_automatic_minimum := can_skip_automatic_minimum_size_for_item(item, item_state, container_state, bases[index], false, container_height)
		defer_automatic_minimum := (skip_automatic_minimum
			|| item_can_skip_automatic_minimum)
			&& item.computed_values().size_value(.min_height).is_auto()
		minimum := flex_used_main_minimum(mut state, item, item_state, false, container_height, defer_automatic_minimum)
		maximum := flex_used_main_maximum(mut state, item, item_state, false, container_height)
		minimums << minimum
		deferred_minimums << defer_automatic_minimum
		maximums << maximum
		hypotheticals << flex_hypothetical_main_size(bases[index], minimum, maximum)
	}
	mut line := FlexLine{
		items: items
		bases: bases
		minimums: minimums
		deferred_minimums: deferred_minimums
		maximums: maximums
		hypotheticals: hypotheticals
	}
	mut main_size := container_height or {
		flex_intrinsic_main_size_of_column_container(mut state, items, bases, edges, contributions, row_gap)
	}
	main_size = resolve_inline_flex_auto_block_size_for_alignment(state, container, container_state,
		available_space, main_size)

	line.targets = resolve_flexible_lengths(mut state, line, main_size, edges, row_gap, container_height, false)
	mut total_main := row_gap.scaled(f64(if items.len > 0 { items.len - 1 } else { 0 }))
	for index, item in items {
		styled := item.as_node_with_style() or { continue }
		current := state.get(styled)
		alignment := effective_flex_cross_alignment(container, item)
		has_auto_cross_margin := property_is_auto(item.computed_values(), .margin_left)
			|| property_is_auto(item.computed_values(), .margin_right)
		mut forced_width := if item.computed_values().size_value(.width).is_stretch() {
			?CSSPixels(stretch_fit_content_size(item, current, container_width, true))
		} else if alignment in [.stretch, .normal]
			&& property_is_auto(item.computed_values(), .width) && !has_auto_cross_margin {
			?CSSPixels(container_width.minus(flex_or_grid_item_outer_inline_edges(current)))
		} else if property_is_auto(item.computed_values(), .width) {
			?CSSPixels(flex_formatting_context_transferred_size_suggestion(item, current, true) or {
				if flex_item_has_aspect_ratio_without_natural_dimensions(item) {
					calculate_stretch_fit_width(item.as_box() or {
						panic('flex item must be a box')
					}, AvailableSize.make_definite(container_width))
				} else {
					flex_fit_content_cross_width(mut state, item, container_width)
				}
			})
		} else {
			resolve_layout_content_size(item, item.computed_values().size_value(.width), container_width, current, true)
		}
		if width := forced_width {
			forced_width = clamp_layout_content_size(item, width, container_width, current, true)
		}
		// The first pass already laid out this item at its natural main size.
		// Repeating unchanged inside-layout at every nested column multiplies
		// the work. Promote the used height to a definite basis in place when
		// no descendant consumes that transition; changed sizes still rerun.
		reuse_geometry := current.content_height() == line.targets[index]
			&& (if width := forced_width { width == current.content_width() } else { true })
			&& (current.has_definite_height()
				|| !flex_subtree_depends_on_definite_height(mut state, item))
		item_state := if reuse_geometry {
			mut reused := state.mutable_internal_box_values(styled)
			reused.set_has_definite_height(true)
			reused
		} else {
			layout_independent_child(mut state, item, mut container_state, container_width, container_height, forced_width, line.targets[index])
		}
		total_main = total_main.plus(item_state.margin_box_height())
	}
	mut auto_main_margin_count := 0
	for item in items {
		if property_is_auto(item.computed_values(), .margin_top) {
			auto_main_margin_count++
		}
		if property_is_auto(item.computed_values(), .margin_bottom) {
			auto_main_margin_count++
		}
	}
	main_free_space := main_size.minus(total_main)
	mut absorbed_main_space := false
	if main_free_space.raw_value() > 0 && auto_main_margin_count > 0 {
		mut margin_index := 0
		for item in items {
			styled := item.as_node_with_style() or { continue }
			mut item_state := state.mutable_internal_box_values(styled)
			if property_is_auto(item.computed_values(), .margin_top) {
				item_state.margin_top = flex_fractional_share(main_free_space,margin_index,auto_main_margin_count)
				margin_index++
			}
			if property_is_auto(item.computed_values(), .margin_bottom) {
				item_state.margin_bottom = flex_fractional_share(main_free_space,margin_index,auto_main_margin_count)
				margin_index++
			}
		}
		absorbed_main_space = true
	}
	mut leading := CSSPixels.new(0)
	mut distributed_gap := CSSPixels.new(0)
	if !absorbed_main_space {
		leading, distributed_gap = flex_justify_offsets(container.computed_values().justify_content(), main_free_space, items.len)
	}
	mut indexes := []int{cap: items.len}
	for index in 0 .. items.len {
		indexes << index
	}
	if flex_physical_direction(container) == .column_reverse {
		indexes.reverse_in_place()
	}
	main_reversed := flex_physical_direction(container) == .column_reverse
	mut cursor := flex_physical_leading_offset(container, container.computed_values().justify_content(), main_free_space, leading, distributed_gap, items.len, false, main_reversed, absorbed_main_space)
	max_baseline := flex_line_max_baseline(state, container, line)
	for visual_index, item_index in indexes {
		item := items[item_index]
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.mutable_internal_box_values(styled)
		alignment := effective_flex_cross_alignment(container, item)
		left_margin_auto := property_is_auto(item.computed_values(), .margin_left)
		right_margin_auto := property_is_auto(item.computed_values(), .margin_right)
		cross_free_space := container_width.minus(item_state.margin_box_width())
		mut cross_delta := CSSPixels.new(0)
		if cross_free_space.raw_value() > 0 && left_margin_auto && right_margin_auto {
			item_state.margin_left = flex_divide_by_integer(cross_free_space, 2)
			item_state.margin_right = flex_divide_by_integer(cross_free_space, 2)
		} else if cross_free_space.raw_value() > 0 && left_margin_auto {
			item_state.margin_left = cross_free_space
		} else if cross_free_space.raw_value() > 0 && right_margin_auto {
			item_state.margin_right = cross_free_space
		} else {
			cross_delta = cross_alignment_offset(alignment, container_width, item_state.margin_box_width(), flex_formatting_cross_axis_is_reversed(container))
			if flex_item_participates_in_baseline_alignment(container, item) {
				cross_delta = cross_delta.plus(max_baseline.minus(grid_baseline_from_low(state,container,item,true,.first,0)))
			}
		}
		item_state.set_content_x(cross_delta.plus(item_state.margin_box_left()))
		item_state.set_content_y(cursor.plus(item_state.margin_box_top()))
		cursor = cursor.plus(item_state.margin_box_height())
		if property_is_auto(item.computed_values(), .margin_top) {
			item_state.margin_top = CSSPixels.new(0)
		}
		if property_is_auto(item.computed_values(), .margin_bottom) {
			item_state.margin_bottom = CSSPixels.new(0)
		}
		if property_is_auto(item.computed_values(), .margin_left) {
			item_state.margin_left = CSSPixels.new(0)
		}
		if property_is_auto(item.computed_values(), .margin_right) {
			item_state.margin_right = CSSPixels.new(0)
		}
		if visual_index + 1 < indexes.len {
			cursor = cursor.plus(row_gap).plus(distributed_gap)
			if !absorbed_main_space {
				cursor = cursor.plus(flex_distribution_remainder(container.computed_values().justify_content(),main_free_space,indexes.len,visual_index,distributed_gap))
			}
		}
	}
	publish_flex_content_baselines(mut state,container,mut container_state,[FlexLine{items:items}],false)
	set_flex_abspos_static_positions(mut state, container, container_state, flex_physical_direction(container))
	return FormattingContextResult{
		automatic_content_width: container_width
		automatic_content_height: if container_height != none { main_size } else { total_main }
	}
}

fn run_wrapping_column_flex_formatting_context(mut state LayoutState, container &Node, mut container_state UsedValues, items []&Node, container_width CSSPixels, main_size CSSPixels, layout_mode LayoutMode) FormattingContextResult {
	row_gap := flex_formatting_context_main_gap(container, main_size, false)
	column_gap := flex_formatting_context_cross_gap(container, container_width, false)
	mut bases := []CSSPixels{cap: items.len}
	mut main_edges := []CSSPixels{cap: items.len}
	mut minimums := []CSSPixels{cap: items.len}
	mut deferred_minimums := []bool{cap: items.len}
	mut maximums := []CSSPixels{cap: items.len}
	mut hypotheticals := []CSSPixels{cap: items.len}
	for item in items {
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.mutable_internal_box_values(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, container_width.to_double())
		mut forced_width := if property_is_auto(item.computed_values(), .width) {
			?CSSPixels(flex_fit_content_cross_width(mut state, item, container_width))
		} else {
			resolve_layout_content_size(item, item.computed_values().size_value(.width), container_width, item_state, true)
		}
		if width := forced_width {
			forced_width = clamp_layout_content_size(item, width, container_width, item_state, true)
		}
		laid_out := layout_independent_child(mut state, item, mut container_state, container_width, main_size, forced_width, none)
		base := flex_base_height(mut state, item, main_size, laid_out.content_height(), laid_out)
		defer_automatic_minimum := can_skip_automatic_minimum_size_for_item(item, laid_out, container_state, base, false, main_size)
			&& item.computed_values().size_value(.min_height).is_auto()
		minimum := flex_used_main_minimum(mut state, item, laid_out, false, main_size, defer_automatic_minimum)
		maximum := flex_used_main_maximum(mut state, item, laid_out, false, main_size)
		bases << base
		main_edges << flex_or_grid_item_outer_block_edges(laid_out)
		minimums << minimum
		deferred_minimums << defer_automatic_minimum
		maximums << maximum
		hypotheticals << flex_hypothetical_main_size(base, minimum, maximum)
	}

	mut lines := []FlexLine{cap: 4}
	mut line := new_flex_line(8)
	mut occupied := CSSPixels.new(0)
	for index, item in items {
		outer := hypotheticals[index].plus(main_edges[index])
		addition := if line.items.len > 0 { outer.plus(row_gap) } else { outer }
		if line.items.len > 0 && occupied.plus(addition).raw_value() > main_size.raw_value() {
			lines << line
			line = new_flex_line(8)
			occupied = CSSPixels.new(0)
		}
		line.items << item
		line.bases << bases[index]
		line.minimums << minimums[index]
		line.deferred_minimums << deferred_minimums[index]
		line.maximums << maximums[index]
		line.hypotheticals << hypotheticals[index]
		occupied = if line.items.len > 1 { occupied.plus(row_gap).plus(outer) } else { outer }
	}
	if line.items.len > 0 {
		lines << line
	}

	mut line_cross_sizes := []CSSPixels{cap: lines.len}
	for line_index in 0 .. lines.len {
		mut current_line := lines[line_index]
		mut edges := []CSSPixels{cap: current_line.items.len}
		for item in current_line.items {
			styled := item.as_node_with_style() or { continue }
			item_state := state.get(styled)
			edges << flex_or_grid_item_outer_block_edges(item_state)
		}
		current_line.targets = resolve_flexible_lengths(mut state, current_line, main_size, edges, row_gap, main_size, false)
		lines[line_index] = current_line
		mut cross_size := CSSPixels.new(0)
		for item_index, item in current_line.items {
			styled := item.as_node_with_style() or { continue }
			current := state.get(styled)
			forced_width := if item.computed_values().size_value(.width).is_stretch() {
				?CSSPixels(current.content_width())
			} else if property_is_auto(item.computed_values(), .width) {
				?CSSPixels(current.content_width())
			} else {
				?CSSPixels(none)
			}
			item_state := layout_independent_child(mut state, item, mut container_state, container_width, main_size, forced_width, current_line.targets[item_index])
			cross_size = css_pixels_max(cross_size, item_state.margin_box_width())
		}
		line_cross_sizes << cross_size
	}

	// No is_single_line() rule here: this path only runs for a wrapping container, so a line
	// is always sized to its items even when collection produced just one of them.

	mut total_cross_size := column_gap.scaled(f64(if lines.len > 0 { lines.len - 1 } else { 0 }))
	for cross_size in line_cross_sizes {
		total_cross_size = total_cross_size.plus(cross_size)
	}
	_, _, stretched_cross := flex_align_content_offsets(container.computed_values().align_content(), container_width.minus(total_cross_size), lines.len, false)
	if stretched_cross.raw_value() > 0 {
		for index in 0 .. line_cross_sizes.len {
			line_cross_sizes[index] = line_cross_sizes[index].plus(stretched_cross)
		}
		total_cross_size = total_cross_size.plus(stretched_cross.scaled(f64(lines.len)))
	}
	// align_all_flex_lines(): the same per-keyword starting edge and direction flags the row
	// axis uses. `start`/`end` name the container's own cross edges here too - C++ never
	// consults the inline `direction` when placing the lines.
	mut placement := flex_line_placement(container.computed_values().align_content(), container_width, total_cross_size, lines.len, flex_formatting_cross_axis_is_reversed(container))
	distributed_cross := placement.gap_size
	mut line_indexes := []int{cap: lines.len}
	for index in 0 .. lines.len {
		line_indexes << index
	}
	if placement.iterate_lines_backwards {
		line_indexes.reverse_in_place()
	}

	main_reversed := flex_physical_direction(container) == .column_reverse
	for visual_line_index, line_index in line_indexes {
		current_line := lines[line_index]
		cross_size := line_cross_sizes[line_index]
		max_baseline := flex_line_max_baseline(state, container, current_line)
		mut total_main := row_gap.scaled(f64(if current_line.items.len > 0 {
			current_line.items.len - 1
		} else {
			0
		}))
		for item in current_line.items {
			styled := item.as_node_with_style() or { continue }
			total_main = total_main.plus(state.get(styled).margin_box_height())
		}
		mut auto_main_margin_count := 0
		for item in current_line.items {
			if property_is_auto(item.computed_values(), .margin_top) {
				auto_main_margin_count++
			}
			if property_is_auto(item.computed_values(), .margin_bottom) {
				auto_main_margin_count++
			}
		}
		main_free_space := main_size.minus(total_main)
		mut absorbed_main_space := false
		if main_free_space.raw_value() > 0 && auto_main_margin_count > 0 {
			mut margin_index := 0
			for item in current_line.items {
				styled := item.as_node_with_style() or { continue }
				mut item_state := state.mutable_internal_box_values(styled)
				if property_is_auto(item.computed_values(), .margin_top) {
					item_state.margin_top = flex_fractional_share(main_free_space,margin_index,auto_main_margin_count)
					margin_index++
				}
				if property_is_auto(item.computed_values(), .margin_bottom) {
					item_state.margin_bottom = flex_fractional_share(main_free_space,margin_index,auto_main_margin_count)
					margin_index++
				}
			}
			absorbed_main_space = true
		}
		mut leading_main := CSSPixels.new(0)
		mut distributed_main := CSSPixels.new(0)
		if !absorbed_main_space {
			leading_main, distributed_main = flex_justify_offsets(container.computed_values().justify_content(), main_free_space, current_line.items.len)
		}
		mut main_cursor := flex_physical_leading_offset(container, container.computed_values().justify_content(), main_free_space, leading_main, distributed_main, current_line.items.len, false, main_reversed, absorbed_main_space)
		mut item_indexes := []int{cap: current_line.items.len}
		for index in 0 .. current_line.items.len {
			item_indexes << index
		}
		if main_reversed {
			item_indexes.reverse_in_place()
		}
		for visual_item_index, item_index in item_indexes {
			item := current_line.items[item_index]
			styled := item.as_node_with_style() or { continue }
			mut item_state := state.mutable_internal_box_values(styled)
			alignment := effective_flex_cross_alignment(container, item)
			left_margin_auto := property_is_auto(item.computed_values(), .margin_left)
			right_margin_auto := property_is_auto(item.computed_values(), .margin_right)
			if constrained := flex_cross_size_with_stretch_constraints(mut state, item, item_state, container_width, cross_size, true) {
				item_state = layout_independent_child(mut state, item, mut container_state, container_width, main_size, constrained, current_line.targets[item_index])
			}
			if item.computed_values().size_value(.width).is_stretch()
				|| (alignment in [.stretch, .normal] && property_is_auto(item.computed_values(), .width)
				&& !left_margin_auto && !right_margin_auto) {
				stretched_width := if item.computed_values().size_value(.width).is_stretch() {
					clamp_layout_content_size(item, stretch_fit_content_size(item, item_state, cross_size, true), cross_size, item_state, true)
				} else { clamp_layout_content_size(item, cross_size.minus(flex_or_grid_item_outer_inline_edges(item_state)), container_width, item_state, true) }
				item_state = layout_independent_child(mut state, item, mut container_state, container_width, main_size, stretched_width, current_line.targets[item_index])
			}
			cross_free_space := cross_size.minus(item_state.margin_box_width())
			mut cross_delta := CSSPixels.new(0)
			if cross_free_space.raw_value() > 0 && left_margin_auto && right_margin_auto {
				item_state.margin_left = flex_divide_by_integer(cross_free_space, 2)
				item_state.margin_right = flex_divide_by_integer(cross_free_space, 2)
			} else if cross_free_space.raw_value() > 0 && left_margin_auto {
				item_state.margin_left = cross_free_space
			} else if cross_free_space.raw_value() > 0 && right_margin_auto {
				item_state.margin_right = cross_free_space
			} else {
				cross_delta = cross_alignment_offset(alignment, cross_size, item_state.margin_box_width(), flex_formatting_cross_axis_is_reversed(container))
				if flex_item_participates_in_baseline_alignment(container, item) {
					cross_delta = cross_delta.plus(max_baseline.minus(grid_baseline_from_low(state,container,item,true,.first,0)))
				}
			}
			line_cross_start := if placement.place_items_backwards {
				placement.start_of_current_line.minus(cross_size)
			} else {
				placement.start_of_current_line
			}
			item_state.set_content_x(line_cross_start.plus(cross_delta).plus(item_state.margin_box_left()))
			item_state.set_content_y(main_cursor.plus(item_state.margin_box_top()))
			main_cursor = main_cursor.plus(item_state.margin_box_height())
			if property_is_auto(item.computed_values(), .margin_top) {
				item_state.margin_top = CSSPixels.new(0)
			}
			if property_is_auto(item.computed_values(), .margin_bottom) {
				item_state.margin_bottom = CSSPixels.new(0)
			}
			if property_is_auto(item.computed_values(), .margin_left) {
				item_state.margin_left = CSSPixels.new(0)
			}
			if property_is_auto(item.computed_values(), .margin_right) {
				item_state.margin_right = CSSPixels.new(0)
			}
			if visual_item_index + 1 < item_indexes.len {
				main_cursor = main_cursor.plus(row_gap).plus(distributed_main)
				if !absorbed_main_space {
					main_cursor = main_cursor.plus(flex_distribution_remainder(container.computed_values().justify_content(),main_free_space,item_indexes.len,visual_item_index,distributed_main))
				}
			}
		}
		if placement.place_items_backwards {
			placement.start_of_current_line = placement.start_of_current_line.minus(cross_size).minus(distributed_cross).minus(column_gap)
		} else {
			placement.start_of_current_line = placement.start_of_current_line.plus(cross_size).plus(distributed_cross).plus(column_gap)
		}
		if container.computed_values().align_content() == .space_between && visual_line_index+1 < lines.len {
			adjustment := flex_distribution_remainder(.space_between,container_width.minus(total_cross_size),lines.len,visual_line_index,distributed_cross)
			placement.start_of_current_line = if placement.place_items_backwards { placement.start_of_current_line.minus(adjustment) } else { placement.start_of_current_line.plus(adjustment) }
		}
		_ = visual_line_index
	}
	publish_flex_content_baselines(mut state,container,mut container_state,lines,false)
	set_flex_abspos_static_positions(mut state, container, container_state, flex_physical_direction(container))
	return FormattingContextResult{
		automatic_content_width: if layout_mode == .intrinsic_sizing {
			total_cross_size
		} else {
			container_width
		}
		automatic_content_height: main_size
	}
}
