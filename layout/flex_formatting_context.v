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

enum FlexCrossAlignment {
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

fn ordered_flex_items(container &Node) []&Node {
	// FlexFormattingContext::generate_anonymous_flex_items() groups children by
	// `order` and sorts only the distinct keys. Avoid insertion-sorting the
	// growing item array, which made equal-order containers quadratic.
	mut order_item_buckets := [][]&Node{}
	mut bucket_indices := map[int]int{}
	mut keys := []int{}
	mut item_count := 0
	parent := container.parent()
	is_button_wrapper := if candidate := parent {
		node_uses_button_layout(candidate)
	} else {
		false
	}
	for child in container.children() {
		if !child.is_box() || child.is_absolutely_positioned() {
			continue
		}
		skippable_text_run := can_skip_anonymous_text_run(child)
		if skippable_text_run && !is_button_wrapper && !child.is_button_content_box_ {
			continue
		}
		if !skippable_text_run {
			mut mutable_child := unsafe { &Node(child) }
			mutable_child.set_flex_item(true)
		}
		order := child.computed_values().order()
		bucket_number := bucket_indices[order] or {
			order_item_buckets << []&Node{}
			keys << order
			bucket_indices[order] = order_item_buckets.len
			order_item_buckets.len
		}
		order_item_buckets[bucket_number - 1] << child
		item_count++
	}
	keys.sort()
	mut items := []&Node{cap: item_count}
	for key in keys {
		bucket_number := bucket_indices[key] or { continue }
		for item in order_item_buckets[bucket_number - 1] {
			items << item
		}
	}
	return items
}

// FlexFormattingContext::main_gap()/cross_gap(). Percentages resolve against
// the corresponding inner dimension of the flex container, not unconditionally
// against its inline size.
fn flex_formatting_context_main_gap(container &Node, inner_main_size CSSPixels, row_axis bool) CSSPixels {
	property_id := if row_axis { css.PropertyID.column_gap } else { css.PropertyID.row_gap }
	return resolve_layout_gap(container, property_id, inner_main_size)
}

fn flex_formatting_context_cross_gap(container &Node, inner_cross_size CSSPixels, row_axis bool) CSSPixels {
	property_id := if row_axis { css.PropertyID.row_gap } else { css.PropertyID.column_gap }
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
	if size.is_intrinsic_sizing_constraint() {
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
	if flex_item_is_scroll_container(item) || item.is_replaced_box() {
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

fn flex_base_width(mut state LayoutState, item &Node, container_width CSSPixels, item_state &UsedValues) CSSPixels {
	computed := item.computed_values()
	basis := computed.flex_basis()
	if !basis.is_content && !basis.size.is_auto() {
		if value := resolve_layout_content_size(item, basis.size, container_width, item_state, true) {
			return flex_base_size_after_cross_constraints(item, item_state, value, true)
		}
	}
	if basis.size.is_auto() {
		width := computed.size_value(.width)
		if value := resolve_layout_content_size(item, width, container_width, item_state, true) {
			return flex_base_size_after_cross_constraints(item, item_state, value, true)
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
		if basis.size.is_min_content() {
			return flex_base_size_after_cross_constraints(item, item_state, calculate_min_content_width(mut state, box), true)
		}
		if basis.size.is_fit_content() {
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
				return flex_base_size_after_cross_constraints(item, item_state, value, false)
			}
		} else if !basis.size.contains_percentage() {
			if value := resolve_layout_content_size(item, basis.size, CSSPixels.new(0), item_state, false) {
				return flex_base_size_after_cross_constraints(item, item_state, value, false)
			}
		}
	}
	if basis.size.is_auto() {
		height_size := computed.size_value(.height)
		if height := container_height {
			if value := resolve_layout_content_size(item, height_size, height, item_state, false) {
				return flex_base_size_after_cross_constraints(item, item_state, value, false)
			}
		} else if !height_size.contains_percentage() {
			if value := resolve_layout_content_size(item, height_size, CSSPixels.new(0), item_state, false) {
				return flex_base_size_after_cross_constraints(item, item_state, value, false)
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
	computed := item.computed_values()
	return computed.overflow_x() !in [.visible, .clip] || computed.overflow_y() !in [
		.visible,
		.clip,
	]
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
	return css_px(clamp_box_content_to_min_max(computed, min_property, max_property, cross_size.to_double(), percentage_basis.to_double(), edges.to_double()))
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

// https://drafts.csswg.org/css-flexbox-1/#min-size-auto
fn flex_formatting_context_automatic_minimum_size(mut state LayoutState, item &Node, item_state &UsedValues, row_axis bool, available_main_size ?CSSPixels) CSSPixels {
	if flex_item_is_scroll_container(item) {
		return CSSPixels.new(0)
	}
	mut content_suggestion := flex_intrinsic_main_size(mut state, item, item_state, row_axis, true)
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
	return css_pixels_max(CSSPixels.new(0), css_pixels_max(minimum, css_pixels_min(base, maximum)))
}

fn flex_abs_pixels(value CSSPixels) CSSPixels {
	return if value.raw_value() < 0 { value.negated() } else { value }
}

fn resolve_flexible_lengths(mut state LayoutState, line FlexLine, container_main_size CSSPixels, item_edges []CSSPixels, gap CSSPixels, available_main_size ?CSSPixels, row_axis bool) []CSSPixels {
	mut targets := line.bases.clone()
	mut minimums := line.minimums.clone()
	mut deferred_minimums := line.deferred_minimums.clone()
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
		}
	}
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
			for index, item in line.items {
				if frozen[index] {
					continue
				}
				ratio := if factor_sum != 0 {
					f64(item.computed_values().flex_grow()) / factor_sum
				} else {
					0.0
				}
				targets[index] = line.bases[index].plus(remaining_free_space.scaled(ratio))
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
			targets[index] = css_pixels_max(CSSPixels.new(0), css_pixels_max(minimums[index], css_pixels_min(targets[index], line.maximums[index])))
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
	if row_axis {
		rtl := container.computed_values().direction() == .rtl
		match justify {
			.start {
				return if rtl { free_space } else { CSSPixels.new(0) }
			}
			.end_ {
				return if rtl { CSSPixels.new(0) } else { free_space }
			}
			.left {
				return CSSPixels.new(0)
			}
			.right {
				return free_space
			}
			else {}
		}
	} else {
		match justify {
			// CSS Box Alignment's physical left/right keywords only select a
			// horizontal side. On a column main axis both use the left cursor in
			// FlexFormattingContext::distribute_any_remaining_free_space().
			.start, .left, .right {
				return CSSPixels.new(0)
			}
			.end_ {
				return free_space
			}
			else {}
		}
	}
	if !reversed {
		return logical_leading
	}
	distributed_space := distributed_gap.scaled(f64(if item_count > 0 {
		item_count - 1
	} else {
		0
	}))
	return free_space.minus(logical_leading).minus(distributed_space)
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
	return match container.computed_values().align_items() {
		.end_, .self_end { .self_end }
		.flex_end { .end }
		.center { .center }
		.baseline { .baseline }
		.start, .self_start { .self_start }
		.flex_start { .start }
		else { .stretch }
	}
}

fn cross_alignment_offset(alignment FlexCrossAlignment, cross_size CSSPixels, item_size CSSPixels, reversed bool) CSSPixels {
	return match alignment {
		.start {
			if reversed {
				cross_size.minus(item_size)
			} else {
				CSSPixels.new(0)
			}
		}
		.end {
			if reversed {
				CSSPixels.new(0)
			} else {
				cross_size.minus(item_size)
			}
		}
		.self_start {
			CSSPixels.new(0)
		}
		.self_end {
			cross_size.minus(item_size)
		}
		.center {
			flex_divide_by_integer(cross_size.minus(item_size), 2)
		}
		.stretch {
			if reversed {
				cross_size.minus(item_size)
			} else {
				CSSPixels.new(0)
			}
		}
		.baseline {
			if reversed {
				cross_size.minus(item_size)
			} else {
				CSSPixels.new(0)
			}
		}
	}
}

fn flex_line_max_baseline(state &LayoutState, container &Node, line FlexLine) CSSPixels {
	mut maximum := CSSPixels.new(0)
	for item in line.items {
		if effective_flex_cross_alignment(container, item) == .baseline {
			maximum = css_pixels_max(maximum, layout_box_baseline(state, item))
		}
	}
	return maximum
}

fn flex_static_main_axis_alignment(container &Node, direction css.FlexDirection) StaticPositionAlignment {
	reversed := if direction in [.column, .column_reverse] {
		direction == .column_reverse
	} else {
		(direction == .row_reverse) != (container.computed_values().direction() == .rtl)
	}
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
	cross_reversed := if row_axis {
		container.computed_values().flex_wrap() == .wrap_reverse
	} else {
		(container.computed_values().direction() == .rtl) != (container.computed_values().flex_wrap() == .wrap_reverse)
	}
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
		mut child_state := state.get_mutable(styled)
		child_state.set_static_position_rect(StaticPositionRect{
			rect: css.CSSPixelRect.new(0, 0, container_state.content_width().to_double(), container_state.content_height().to_double())
			horizontal_alignment: if row_axis { main_alignment } else { cross_alignment }
			vertical_alignment: if row_axis { cross_alignment } else { main_alignment }
		})
	}
}

fn run_flex_formatting_context(mut state LayoutState, container &Node, mut container_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	return run_flex_formatting_context_with_mode(mut state, container, mut container_state, .normal, available_space)
}

fn clear_intrinsic_flex_item_line_boxes(mut state LayoutState, node &Node) {
	if styled := node.as_node_with_style() {
		if mut values := state.try_get_mutable(styled) {
			values.line_boxes.clear()
		}
	}
	for child in node.children() {
		clear_intrinsic_flex_item_line_boxes(mut state, child)
	}
}

fn run_flex_formatting_context_with_mode(mut state LayoutState, container &Node, mut container_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	// During intrinsic sizing a nested flex container whose dimensions were
	// both resolved by its parent has no intrinsic constraint of its own. The
	// parent has already determined its size, so rerunning flex layout here is
	// both redundant and can trigger expensive intrinsic subtree measurement.
	if layout_mode == .intrinsic_sizing
		&& !available_space.width.is_intrinsic_sizing_constraint()
		&& !available_space.height.is_intrinsic_sizing_constraint() {
		return FormattingContextResult{
			automatic_content_width: container_state.content_width()
			automatic_content_height: container_state.content_height()
		}
	}
	// Anonymous whitespace-only flex children are not flex items, but TreeBuilder
	// still created layout nodes for them. LayoutState keeps zero geometry for
	// those nodes just as upstream does, so dumps and DOM geometry can observe
	// their containing-block-relative origin.
	for child in container.children() {
		if can_skip_anonymous_text_run(child) {
			if styled := child.as_node_with_style() {
				mut skipped_state := state.get_mutable(styled)
				skipped_state.set_containing_block_used_values(container_state)
			}
		}
	}
	direction := container.computed_values().flex_direction()
	if direction in [.column, .column_reverse] {
		result := run_column_flex_formatting_context(mut state, container, mut container_state, layout_mode, available_space)
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
		mut item_state := state.get_mutable(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, container_width.to_double())
		// Definite-size rule: before determining flex bases, a stretched item in
		// a single-line container with a definite cross size gets the container's
		// inner cross size, clamped by its own cross-axis constraints.
		if container.computed_values().flex_wrap() == .nowrap
			&& container_state.has_definite_height()
			&& effective_flex_cross_alignment(container, item) == .stretch
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

	mut lines := []FlexLine{}
	mut line := FlexLine{}
	mut occupied := CSSPixels.new(0)
	wraps := container.computed_values().flex_wrap() != .nowrap
	for index, item in items {
		outer := hypotheticals[index].plus(edges[index])
		addition := if line.items.len > 0 { outer.plus(column_gap) } else { outer }
		if wraps && line.items.len > 0
			&& occupied.plus(addition).raw_value() > container_width.raw_value() {
			lines << line
			line = FlexLine{}
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
	mut line_cross_sizes := []CSSPixels{}
	for line_index in 0 .. lines.len {
		mut current_line := lines[line_index]
		mut line_edges := []CSSPixels{}
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
			item_state := layout_independent_child(mut state, item, mut container_state, container_width, if container_state.has_definite_height() {
				container_state.content_height()
			} else {
				none
			}, current_line.targets[index], none)
			cross_size = css_pixels_max(cross_size, item_state.margin_box_height())
			used_main = used_main.plus(item_state.margin_box_width())
		}
		if lines.len == 1 {
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
	wrap_reverse := container.computed_values().flex_wrap() == .wrap_reverse
	available_cross_size := if container_state.has_definite_height() {
		container_state.content_height()
	} else if available_space.height.is_definite() {
		available_space.height.to_px_or_zero()
	} else {
		total_cross_size
	}
	leading_cross_space, distributed_cross_space, stretched_cross_space := flex_align_content_offsets(container.computed_values().align_content(), available_cross_size.minus(total_cross_size), line_cross_sizes.len, wrap_reverse)
	if stretched_cross_space.raw_value() > 0 {
		for index in 0 .. line_cross_sizes.len {
			line_cross_sizes[index] = line_cross_sizes[index].plus(stretched_cross_space)
		}
	}
	mut cross_offset := leading_cross_space

	mut line_order := []int{}
	for index in 0 .. lines.len {
		line_order << index
	}
	if wrap_reverse {
		line_order.reverse_in_place()
	}
	main_reversed := (direction == .row_reverse) != (container.computed_values().direction() == .rtl)
	for visual_line_index, line_index in line_order {
		current_line := lines[line_index]
		cross_size := line_cross_sizes[line_index]
		max_baseline := flex_line_max_baseline(state, container, current_line)
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
			each_margin := flex_divide_by_integer(main_free_space, auto_main_margin_count)
			for item in current_line.items {
				styled := item.as_node_with_style() or { continue }
				mut item_state := state.get_mutable(styled)
				if property_is_auto(item.computed_values(), .margin_left) {
					item_state.margin_left = each_margin
				}
				if property_is_auto(item.computed_values(), .margin_right) {
					item_state.margin_right = each_margin
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
		mut indexes := []int{}
		for index in 0 .. current_line.items.len {
			indexes << index
		}
		if main_reversed {
			indexes.reverse_in_place()
		}
		for visual_index, item_index in indexes {
			item := current_line.items[item_index]
			styled := item.as_node_with_style() or { continue }
			mut item_state := state.get_mutable(styled)
			alignment := effective_flex_cross_alignment(container, item)
			top_margin_auto := property_is_auto(item.computed_values(), .margin_top)
			bottom_margin_auto := property_is_auto(item.computed_values(), .margin_bottom)
			if alignment == .stretch && property_is_auto(item.computed_values(), .height)
				&& !top_margin_auto && !bottom_margin_auto {
				stretched := cross_size.minus(flex_or_grid_item_outer_block_edges(item_state))
				item_state = layout_independent_child(mut state, item, mut container_state, container_width, if container_state.has_definite_height() {
					container_state.content_height()
				} else {
					none
				}, current_line.targets[item_index], stretched)
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
				cross_delta = cross_alignment_offset(alignment, cross_size, item_state.margin_box_height(), wrap_reverse)
				if alignment == .baseline {
					adjustment := max_baseline.minus(layout_box_baseline(state, item))
					cross_delta = cross_delta.plus(if wrap_reverse {
						adjustment.negated()
					} else {
						adjustment
					})
				}
			}
			item_state.set_content_x(cursor.plus(item_state.margin_box_left()))
			item_state.set_content_y(cross_offset.plus(cross_delta).plus(item_state.margin_box_top()))
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
			}
		}
		cross_offset = cross_offset.plus(cross_size)
		if visual_line_index + 1 < line_order.len {
			cross_offset = cross_offset.plus(row_gap).plus(distributed_cross_space)
		}
	}
	set_flex_abspos_static_positions(mut state, container, container_state, direction)
	result := FormattingContextResult{
		automatic_content_width: automatic_width
		automatic_content_height: if container_state.has_definite_height() {
			container_state.content_height()
		} else {
			cross_offset
		}
	}
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
	container_height := if container_state.has_definite_height() {
		?CSSPixels(container_state.content_height())
	} else if available_space.height.is_definite() {
		?CSSPixels(available_space.height.to_px_or_zero())
	} else {
		?CSSPixels(none)
	}
	if container.computed_values().flex_wrap() != .nowrap {
		if definite_height := container_height {
			return run_wrapping_column_flex_formatting_context(mut state, container, mut container_state, items, container_width, definite_height, layout_mode)
		}
	}
	row_gap := flex_formatting_context_main_gap(container, container_height or {
		CSSPixels.new(0)
	}, false)
	mut bases := []CSSPixels{}
	mut edges := []CSSPixels{}
	for item in items {
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, container_width.to_double())
		alignment := effective_flex_cross_alignment(container, item)
		has_auto_cross_margin := property_is_auto(item.computed_values(), .margin_left)
			|| property_is_auto(item.computed_values(), .margin_right)
		mut forced_width := if alignment == .stretch
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
			?CSSPixels(none)
		}
		if width := forced_width {
			forced_width = clamp_layout_content_size(item, width, container_width, item_state, true)
		}
		laid_out := layout_independent_child(mut state, item, mut container_state, container_width, container_height, forced_width, none)
		base := flex_base_height(mut state, item, container_height, laid_out.content_height(), laid_out)
		bases << base
		edges << flex_or_grid_item_outer_block_edges(laid_out)
	}
	skip_automatic_minimum := should_skip_automatic_minimum_size_clamp(state, container, container_state, layout_mode, items, bases, false, available_space.height.to_px_or_zero())
	mut minimums := []CSSPixels{}
	mut deferred_minimums := []bool{}
	mut maximums := []CSSPixels{}
	mut hypotheticals := []CSSPixels{}
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
	main_size := container_height or {
		mut natural := row_gap.scaled(f64(if items.len > 0 { items.len - 1 } else { 0 }))
		// With an indefinite main size, the flex container's intrinsic main
		// size is formed from the outer hypothetical main sizes.  In
		// particular, an item's min-height can enlarge its hypothetical size
		// beyond its flex base size.
		for index in 0 .. hypotheticals.len {
			natural = natural.plus(hypotheticals[index]).plus(edges[index])
		}
		natural
	}

	line.targets = resolve_flexible_lengths(mut state, line, main_size, edges, row_gap, container_height, false)
	mut total_main := row_gap.scaled(f64(if items.len > 0 { items.len - 1 } else { 0 }))
	for index, item in items {
		styled := item.as_node_with_style() or { continue }
		current := state.get(styled)
		alignment := effective_flex_cross_alignment(container, item)
		has_auto_cross_margin := property_is_auto(item.computed_values(), .margin_left)
			|| property_is_auto(item.computed_values(), .margin_right)
		mut forced_width := if alignment == .stretch
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
			?CSSPixels(none)
		}
		if width := forced_width {
			forced_width = clamp_layout_content_size(item, width, container_width, current, true)
		}
		item_state := layout_independent_child(mut state, item, mut container_state, container_width, container_height, forced_width, line.targets[index])
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
		each_margin := flex_divide_by_integer(main_free_space, auto_main_margin_count)
		for item in items {
			styled := item.as_node_with_style() or { continue }
			mut item_state := state.get_mutable(styled)
			if property_is_auto(item.computed_values(), .margin_top) {
				item_state.margin_top = each_margin
			}
			if property_is_auto(item.computed_values(), .margin_bottom) {
				item_state.margin_bottom = each_margin
			}
		}
		absorbed_main_space = true
	}
	mut leading := CSSPixels.new(0)
	mut distributed_gap := CSSPixels.new(0)
	if !absorbed_main_space {
		leading, distributed_gap = flex_justify_offsets(container.computed_values().justify_content(), main_free_space, items.len)
	}
	mut indexes := []int{}
	for index in 0 .. items.len {
		indexes << index
	}
	if container.computed_values().flex_direction() == .column_reverse {
		indexes.reverse_in_place()
	}
	main_reversed := container.computed_values().flex_direction() == .column_reverse
	mut cursor := flex_physical_leading_offset(container, container.computed_values().justify_content(), main_free_space, leading, distributed_gap, items.len, false, main_reversed, absorbed_main_space)
	max_baseline := flex_line_max_baseline(state, container, line)
	for visual_index, item_index in indexes {
		item := items[item_index]
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
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
			cross_delta = cross_alignment_offset(alignment, container_width, item_state.margin_box_width(), container.computed_values().direction() == .rtl)
			if alignment == .baseline {
				adjustment := max_baseline.minus(layout_box_baseline(state, item))
				cross_delta = cross_delta.plus(if container.computed_values().direction() == .rtl {
					adjustment.negated()
				} else {
					adjustment
				})
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
		}
	}
	set_flex_abspos_static_positions(mut state, container, container_state, container.computed_values().flex_direction())
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
		mut item_state := state.get_mutable(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, container_width.to_double())
		mut forced_width := if property_is_auto(item.computed_values(), .width) {
			?CSSPixels(flex_fit_content_cross_width(mut state, item, container_width))
		} else {
			?CSSPixels(none)
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

	mut lines := []FlexLine{}
	mut line := FlexLine{}
	mut occupied := CSSPixels.new(0)
	for index, item in items {
		outer := hypotheticals[index].plus(main_edges[index])
		addition := if line.items.len > 0 { outer.plus(row_gap) } else { outer }
		if line.items.len > 0 && occupied.plus(addition).raw_value() > main_size.raw_value() {
			lines << line
			line = FlexLine{}
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
			forced_width := if property_is_auto(item.computed_values(), .width) {
				?CSSPixels(current.content_width())
			} else {
				?CSSPixels(none)
			}
			item_state := layout_independent_child(mut state, item, mut container_state, container_width, main_size, forced_width, current_line.targets[item_index])
			cross_size = css_pixels_max(cross_size, item_state.margin_box_width())
		}
		line_cross_sizes << cross_size
	}
	if lines.len == 1 && line_cross_sizes.len == 1 {
		line_cross_sizes[0] = container_width
	}

	mut total_cross_size := column_gap.scaled(f64(if lines.len > 0 { lines.len - 1 } else { 0 }))
	for cross_size in line_cross_sizes {
		total_cross_size = total_cross_size.plus(cross_size)
	}
	leading_cross, distributed_cross, stretched_cross := flex_align_content_offsets(container.computed_values().align_content(), container_width.minus(total_cross_size), lines.len, false)
	if stretched_cross.raw_value() > 0 {
		for index in 0 .. line_cross_sizes.len {
			line_cross_sizes[index] = line_cross_sizes[index].plus(stretched_cross)
		}
		total_cross_size = total_cross_size.plus(stretched_cross.scaled(f64(lines.len)))
	}
	cross_reversed := (container.computed_values().direction() == .rtl) != (container.computed_values().flex_wrap() == .wrap_reverse)
	mut line_indexes := []int{cap: lines.len}
	for index in 0 .. lines.len {
		line_indexes << index
	}
	if cross_reversed {
		line_indexes.reverse_in_place()
	}
	mut cross_cursor := flex_physical_leading_offset(container, .flex_start, container_width.minus(total_cross_size), leading_cross, distributed_cross, lines.len, false, cross_reversed, false)
	// `start`/`end` are tied to the inline writing direction, unlike
	// `flex-start`/`flex-end`, which follow a wrap-reversed cross axis.
	match container.computed_values().align_content() {
		.start {
			cross_cursor = if container.computed_values().direction() == .rtl {
				container_width.minus(total_cross_size)
			} else {
				CSSPixels.new(0)
			}
		}
		.end_ {
			cross_cursor = if container.computed_values().direction() == .rtl {
				CSSPixels.new(0)
			} else {
				container_width.minus(total_cross_size)
			}
		}
		else {}
	}

	main_reversed := container.computed_values().flex_direction() == .column_reverse
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
			each_margin := flex_divide_by_integer(main_free_space, auto_main_margin_count)
			for item in current_line.items {
				styled := item.as_node_with_style() or { continue }
				mut item_state := state.get_mutable(styled)
				if property_is_auto(item.computed_values(), .margin_top) {
					item_state.margin_top = each_margin
				}
				if property_is_auto(item.computed_values(), .margin_bottom) {
					item_state.margin_bottom = each_margin
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
			mut item_state := state.get_mutable(styled)
			alignment := effective_flex_cross_alignment(container, item)
			left_margin_auto := property_is_auto(item.computed_values(), .margin_left)
			right_margin_auto := property_is_auto(item.computed_values(), .margin_right)
			if alignment == .stretch && property_is_auto(item.computed_values(), .width)
				&& !left_margin_auto && !right_margin_auto {
				stretched_width := clamp_layout_content_size(item, cross_size.minus(flex_or_grid_item_outer_inline_edges(item_state)), container_width, item_state, true)
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
				cross_delta = cross_alignment_offset(alignment, cross_size, item_state.margin_box_width(), cross_reversed)
				if alignment == .baseline {
					adjustment := max_baseline.minus(layout_box_baseline(state, item))
					cross_delta = cross_delta.plus(if cross_reversed {
						adjustment.negated()
					} else {
						adjustment
					})
				}
			}
			item_state.set_content_x(cross_cursor.plus(cross_delta).plus(item_state.margin_box_left()))
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
			}
		}
		cross_cursor = cross_cursor.plus(cross_size)
		if visual_line_index + 1 < line_indexes.len {
			cross_cursor = cross_cursor.plus(column_gap).plus(distributed_cross)
		}
	}
	set_flex_abspos_static_positions(mut state, container, container_state, container.computed_values().flex_direction())
	return FormattingContextResult{
		automatic_content_width: if layout_mode == .intrinsic_sizing {
			total_cross_size
		} else {
			container_width
		}
		automatic_content_height: main_size
	}
}
