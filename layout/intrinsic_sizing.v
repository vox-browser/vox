// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// FormattingContext::calculate_min_content_width() and
// calculate_max_content_width(). Intrinsic measurement is a real subtree
// layout in a throwaway LayoutState; it must not read geometry left behind by
// the normal layout pass.
fn calculate_min_content_width(mut state LayoutState, box &Box) CSSPixels {
	if unsafe { &Node(box) }.is_replaced_box() {
		computed := box.computed_values()
		width := computed.size_value(.width)
		if width.is_percentage() {
			return width.to_px(layout_length_resolution_context(unsafe { &Node(box) }), CSSPixels.new(0))
		}
		max_width := computed.size_value(.max_width)
		if max_width.is_percentage() {
			return max_width.to_px(layout_length_resolution_context(unsafe { &Node(box) }), CSSPixels.new(0))
		}
	}
	if auto_width := box.auto_content_box_size().width {
		return auto_width
	}
	if !unsafe { &Node(box) }.has_children() {
		return CSSPixels.new(0)
	}
	mut mutable_box := unsafe { &Box(box) }
	mut cache := mutable_box.cached_intrinsic_sizes()
	if cached := cache.min_content_width {
		return cached
	}
	result := calculate_content_width_with_constraint(mut state, box, .min_content)
	cache = mutable_box.cached_intrinsic_sizes()
	cache.min_content_width = result
	return result
}

fn calculate_max_content_width(mut state LayoutState, box &Box) CSSPixels {
	if auto_width := box.auto_content_box_size().width {
		return auto_width
	}
	if !unsafe { &Node(box) }.has_children() {
		return CSSPixels.new(0)
	}
	mut mutable_box := unsafe { &Box(box) }
	mut cache := mutable_box.cached_intrinsic_sizes()
	if cached := cache.max_content_width {
		return cached
	}
	result := calculate_content_width_with_constraint(mut state, box, .max_content)
	cache = mutable_box.cached_intrinsic_sizes()
	cache.max_content_width = result
	return result
}

fn min_content_width_for_node(mut state LayoutState, node &Node) CSSPixels {
	box := node.as_box() or { return CSSPixels.new(0) }
	return calculate_min_content_width(mut state, box)
}

fn max_content_width_for_node(mut state LayoutState, node &Node) CSSPixels {
	box := node.as_box() or { return CSSPixels.new(0) }
	return calculate_max_content_width(mut state, box)
}

// FormattingContext::should_treat_max_width_as_none(). In particular, a
// percentage max-width that is cyclic during intrinsic sizing must not be
// resolved against the zero placeholder width of the throwaway state.
fn should_treat_max_width_as_none(state &LayoutState, box &Node, available_width AvailableSize) bool {
	max_width := box.computed_values().size_value(.max_width)
	if max_width.is_none() {
		return true
	}
	if available_width.is_max_content() && max_width.is_max_content() {
		return true
	}
	if max_width.contains_percentage() {
		if available_width.is_max_content() {
			return true
		}
		if available_width.is_min_content() {
			return !box.is_replaced_box()
		}
		mut containing_block := box.containing_block()
		for containing_block != none {
			candidate := unsafe { &Node(containing_block or { break }) }
			if !candidate.is_anonymous() || candidate.display().is_table_cell() {
				break
			}
			containing_block = candidate.containing_block()
		}
		containing := containing_block or { return true }
		containing_styled := unsafe { &Node(containing) }.as_node_with_style() or { return true }
		containing_values := state.try_get(containing_styled) or { return true }
		if !containing_values.has_definite_width() {
			return true
		}
	}
	if max_width.is_fit_content() && available_width.is_intrinsic_sizing_constraint() {
		return true
	}
	if max_width.is_max_content() && available_width.is_max_content() {
		return true
	}
	if max_width.is_min_content() && available_width.is_min_content() {
		return true
	}
	return false
}

// Intrinsic-sizing throwaway states must contain the full containing-block
// chain. An abspos descendant can select an ancestor above the measured
// subtree root as its containing block.
fn populate_intrinsic_containing_block_chain(mut throwaway LayoutState, mut source LayoutState, node &Node) {
	mut ancestor := node.containing_block()
	for ancestor != none {
		ancestor_node := ancestor or { break }
		ancestor_styled := unsafe { &Node(ancestor_node) }.as_node_with_style() or { break }
		if source.try_get(ancestor_styled) == none {
			break
		}
		throwaway.populate_node_from(mut source, ancestor_styled)
		ancestor = unsafe { &Node(ancestor_node) }.containing_block()
	}
}

// Anonymous table fixup and hoisted abspos boxes can give a descendant a
// containing block outside the measured subtree even when that containing
// block is not on the subtree root's own chain. Seed every such external
// containing block before intrinsic traversal begins.
fn populate_intrinsic_external_containing_blocks(mut throwaway LayoutState, mut source LayoutState, subtree_root &Node, node &Node) {
	mut containing_block := node.containing_block()
	for containing_block != none {
		candidate_box := containing_block or { break }
		candidate := unsafe { &Node(candidate_box) }
		if !subtree_root.is_inclusive_ancestor_of(candidate) {
			if styled := candidate.as_node_with_style() {
				if throwaway.try_get(styled) == none && source.try_get(styled) != none {
					throwaway.populate_node_from(mut source, styled)
				}
			}
		}
		containing_block = candidate.containing_block()
	}
	for child in node.children() {
		populate_intrinsic_external_containing_blocks(mut throwaway, mut source, subtree_root, child)
	}
}

fn calculate_content_width_with_constraint(mut source_state LayoutState, box &Box, constraint SizeConstraint) CSSPixels {
	box_node := unsafe { &Node(box) }
	box_styled := box_node.as_node_with_style() or { return CSSPixels.new(0) }
	mut throwaway := LayoutState.new_for_subtree(box_styled)
	populate_intrinsic_containing_block_chain(mut throwaway, mut source_state, box_node)
	populate_intrinsic_external_containing_blocks(mut throwaway, mut source_state, box_node, box_node)
	mut box_state := throwaway.get_mutable(box_styled)
	box_state.width_constraint = constraint
	box_state.set_indefinite_content_width()
	available_width := if constraint == .min_content {
		AvailableSize.make_min_content()
	} else {
		AvailableSize.make_max_content()
	}
	available_height := if box_state.has_definite_height() {
		AvailableSize.make_definite(box_state.content_height())
	} else {
		AvailableSize.make_indefinite()
	}

	if box_node.display().is_table_inside() {
		percentage_basis := if containing := box_state.containing_block_used_values() {
			containing.content_width()
		} else {
			CSSPixels.new(0)
		}
		return calculate_table_grid_intrinsic_width(mut throwaway, box_node, percentage_basis, constraint)
	}
	if box_node.display().is_flex_inside() {
		return calculate_intrinsic_flex_width(mut throwaway, box_node, constraint)
	}
	if box_node.display().is_grid_inside() {
		result := layout_inside_independent_formatting_context(mut throwaway, box_node, mut box_state, AvailableSpace.new(available_width, available_height))
		return clamp_to_max_dimension_value(result.automatic_content_width)
	}
	if box_node.children_are_inline() {
		if block_container := box_node.as_block_container() {
			result := run_inline_formatting_context(mut throwaway, block_container, mut box_state, .intrinsic_sizing, AvailableSpace.new(available_width, available_height))
			// InlineFormattingContext asks its parent BFC for automatic width so
			// floated inline-level children participate. The standalone intrinsic
			// context has no parent object, so include those children explicitly.
			mut automatic_width := result.automatic_content_width
			for child in box_node.children() {
				if !child.is_floating() {
					continue
				}
				child_box := child.as_box() or { continue }
				automatic_width = css_pixels_max(automatic_width, intrinsic_outer_width_contribution(mut throwaway, child_box, constraint))
			}
			return clamp_to_max_dimension_value(automatic_width)
		}
	}

	// BlockFormattingContext::automatic_content_width() is the greatest
	// child width when the root has block children. Its float-side state keeps
	// the occupied widths of left and right floats on the same row, so a
	// max-content measurement includes adjacent floats rather than only the
	// widest individual float.
	mut greatest := CSSPixels.new(0)
	mut left_floating_width := CSSPixels.new(0)
	mut right_floating_width := CSSPixels.new(0)
	for child in box_node.children() {
		if child.is_absolutely_positioned() {
			continue
		}
		child_box := child.as_box() or { continue }
		contribution := intrinsic_outer_width_contribution(mut throwaway, child_box, constraint)
		if child.is_floating() {
			if constraint == .max_content {
				clear := child.computed_values().clear()
				direction := box_node.computed_values().direction()
				if clear_applies_to_float(clear, .left, direction) {
					left_floating_width = CSSPixels.new(0)
				}
				if clear_applies_to_float(clear, .right, direction) {
					right_floating_width = CSSPixels.new(0)
				}
				if float_side_is_left(child.computed_values().float_(), direction) {
					left_floating_width = left_floating_width.plus(contribution)
				} else {
					right_floating_width = right_floating_width.plus(contribution)
				}
				greatest = css_pixels_max(greatest, left_floating_width.plus(right_floating_width))
			} else {
				greatest = css_pixels_max(greatest, contribution)
			}
			continue
		}
		greatest = css_pixels_max(greatest, contribution)
	}
	return clamp_to_max_dimension_value(greatest)
}

fn intrinsic_outer_width_contribution(mut state LayoutState, box &Box, constraint SizeConstraint) CSSPixels {
	node := unsafe { &Node(box) }
	styled := node.as_node_with_style() or { return CSSPixels.new(0) }
	mut values := state.get_mutable(styled)
	containing_width := if containing := values.containing_block_used_values() {
		containing.content_width()
	} else {
		CSSPixels.new(0)
	}
	resolve_box_model_edges(styled.computed_values(), mut values, containing_width.to_double())
	return intrinsic_outer_width_contribution_with_resolved_box_model(mut state, box, constraint, values, containing_width)
}

// FormattingContext::intrinsic_width_contribution() consumes box-model metrics
// already resolved by its formatting context. TableFormattingContext resolves
// all four cell edges once in compute_cell_measures(), then computes both the
// min- and max-content measures from that same state.
fn intrinsic_outer_width_contribution_with_resolved_box_model(mut state LayoutState, box &Box, constraint SizeConstraint, values &UsedValues, containing_width CSSPixels) CSSPixels {
	node := unsafe { &Node(box) }
	styled := node.as_node_with_style() or { return CSSPixels.new(0) }
	mut inner := if constraint == .min_content {
		calculate_min_content_width(mut state, box)
	} else {
		calculate_max_content_width(mut state, box)
	}
	preferred := styled.computed_values().size_value(.width)
	// A cyclic percentage preferred size behaves as auto during intrinsic
	// sizing. It must not be resolved against an otherwise unrelated definite
	// ancestor merely because that ancestor was copied into the throwaway
	// state.
	if preferred.is_min_content() {
		inner = css_pixels_max(inner, calculate_min_content_width(mut state, box))
	} else if preferred.is_max_content() {
		inner = css_pixels_max(inner, calculate_max_content_width(mut state, box))
	} else if preferred.is_fit_content() {
		inner = css_pixels_max(inner, calculate_fit_content_width(mut state, box, AvailableSize.make_definite(containing_width)))
	} else if !preferred.contains_percentage() {
		if resolved := resolve_layout_content_size(node, preferred, containing_width, values, true) {
			// A definite preferred width determines the box's content width in
			// the intrinsic-layout pass. Its descendants do not floor that width;
			// overflow is deliberately excluded from the parent's contribution.
			inner = resolved
		}
	}
	available_width := if constraint == .min_content {
		AvailableSize.make_min_content()
	} else {
		AvailableSize.make_max_content()
	}
	if !should_treat_max_width_as_none(state, node, available_width) {
		max_width := styled.computed_values().size_value(.max_width)
		if max_width.is_min_content() {
			inner = css_pixels_min(inner, calculate_min_content_width(mut state, box))
		} else if max_width.is_max_content() {
			inner = css_pixels_min(inner, calculate_max_content_width(mut state, box))
		} else if max_width.is_fit_content() {
			inner = css_pixels_min(inner, calculate_fit_content_width(mut state, box, available_width))
		} else if maximum := styled.computed_values().length_percentage_to_px(.max_width, containing_width.to_double()) {
			inner = css_pixels_min(inner, css_px(maximum))
		}
	}
	min_width := styled.computed_values().size_value(.min_width)
	if min_width.is_min_content() {
		inner = css_pixels_max(inner, calculate_min_content_width(mut state, box))
	} else if min_width.is_max_content() {
		inner = css_pixels_max(inner, calculate_max_content_width(mut state, box))
	} else if min_width.is_fit_content() {
		inner = css_pixels_max(inner, calculate_fit_content_width(mut state, box, available_width))
	} else if minimum := styled.computed_values().length_percentage_to_px(.min_width, containing_width.to_double()) {
		inner = css_pixels_max(inner, css_px(minimum))
	}
	return inner.plus(flex_or_grid_item_outer_inline_edges(values))
}

fn flex_formatting_context_adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints(mut state LayoutState, item &Node, item_state &UsedValues, cross_size CSSPixels, row_axis bool, available_main_size ?CSSPixels) CSSPixels {
	box := item.as_box() or { return cross_size }
	ratio := box.preferred_aspect_ratio() or { return cross_size }
	mut main_size := if row_axis {
		cross_size.times_fraction(ratio)
	} else {
		cross_size.divided_by_fraction(ratio)
	}
	min_property := if row_axis { css.PropertyID.min_width } else { css.PropertyID.min_height }
	max_property := if row_axis { css.PropertyID.max_width } else { css.PropertyID.max_height }
	if minimum := flex_main_size_for_constraint(mut state, item, item.computed_values().size_value(min_property), item_state, row_axis, available_main_size) {
		main_size = css_pixels_max(main_size, minimum)
	}
	if maximum := flex_main_size_for_constraint(mut state, item, item.computed_values().size_value(max_property), item_state, row_axis, available_main_size) {
		main_size = css_pixels_min(main_size, maximum)
	}
	return if row_axis {
		main_size.divided_by_fraction(ratio)
	} else {
		main_size.times_fraction(ratio)
	}
}

fn flex_cross_width_behaves_as_auto(item &Node, item_state &UsedValues, constraint SizeConstraint) bool {
	preferred := item.computed_values().size_value(.width)
	if preferred.is_auto() {
		return true
	}
	if preferred.contains_percentage() {
		return constraint == .max_content || !item.is_replaced_box()
	}
	box := item.as_box() or { return false }
	if box.has_preferred_aspect_ratio() && preferred.is_intrinsic_sizing_constraint() {
		auto_size := box.auto_content_box_size()
		return auto_size.height == none || item_state.has_definite_height()
	}
	return false
}

fn flex_cross_intrinsic_width_contribution(mut state LayoutState, item &Node, constraint SizeConstraint, resolve_percentage_min_max_sizes bool, percentage_basis CSSPixels, available_main_size ?CSSPixels) CSSPixels {
	box := item.as_box() or { return CSSPixels.new(0) }
	styled := item.as_node_with_style() or { return CSSPixels.new(0) }
	item_state := state.get(styled)
	cross_size_auto := flex_cross_width_behaves_as_auto(item, item_state, constraint)
	mut size := if cross_size_auto {
		if constraint == .min_content {
			calculate_min_content_width(mut state, box)
		} else {
			calculate_max_content_width(mut state, box)
		}
	} else {
		preferred := item.computed_values().size_value(.width)
		if preferred.is_min_content() {
			calculate_min_content_width(mut state, box)
		} else if preferred.is_max_content() {
			calculate_max_content_width(mut state, box)
		} else if preferred.is_fit_content() {
			calculate_fit_content_width(mut state, box, AvailableSize.make_definite(percentage_basis))
		} else {
			resolve_layout_content_size(item, preferred, percentage_basis, item_state, true) or {
				if constraint == .min_content {
					calculate_min_content_width(mut state, box)
				} else {
					calculate_max_content_width(mut state, box)
				}
			}
		}
	}
	if cross_size_auto && box.has_preferred_aspect_ratio() {
		size = flex_formatting_context_adjust_cross_size_through_aspect_ratio_for_main_size_min_max_constraints(mut state, item, item_state, size, false, available_main_size)
	}

	min_size := item.computed_values().size_value(.min_width)
	mut minimum := CSSPixels.new(0)
	if !min_size.is_auto()
		&& (resolve_percentage_min_max_sizes || !min_size.contains_percentage()) {
		minimum = flex_main_size_for_constraint(mut state, item, min_size, item_state, true, percentage_basis) or { CSSPixels.new(0) }
	}
	max_size := item.computed_values().size_value(.max_width)
	mut maximum := CSSPixels.max()
	available_cross_size := if constraint == .min_content {
		AvailableSize.make_min_content()
	} else {
		AvailableSize.make_max_content()
	}
	if !should_treat_max_width_as_none(state, item, available_cross_size)
		&& (resolve_percentage_min_max_sizes || !max_size.contains_percentage()) {
		maximum = flex_main_size_for_constraint(mut state, item, max_size, item_state, true, percentage_basis) or { CSSPixels.max() }
	}
	size = css_pixels_max(minimum, css_pixels_min(size, maximum))
	return size.plus(flex_or_grid_item_outer_inline_edges(item_state))
}

fn flex_formatting_context_calculate_cross_min_content_contribution(mut state LayoutState, item &Node, resolve_percentage_min_max_sizes bool, percentage_basis CSSPixels, available_main_size ?CSSPixels) CSSPixels {
	return flex_cross_intrinsic_width_contribution(mut state, item, .min_content, resolve_percentage_min_max_sizes, percentage_basis, available_main_size)
}

fn flex_formatting_context_calculate_cross_max_content_contribution(mut state LayoutState, item &Node, resolve_percentage_min_max_sizes bool, percentage_basis CSSPixels, available_main_size ?CSSPixels) CSSPixels {
	return flex_cross_intrinsic_width_contribution(mut state, item, .max_content, resolve_percentage_min_max_sizes, percentage_basis, available_main_size)
}

fn calculate_intrinsic_column_flex_width(mut state LayoutState, container &Node, items []&Node, constraint SizeConstraint) CSSPixels {
	container_styled := container.as_node_with_style() or { return CSSPixels.new(0) }
	mut container_state := state.get_mutable(container_styled)
	initial_basis := container_state.content_width()
	available_main_size := if container_state.has_definite_height() {
		?CSSPixels(container_state.content_height())
	} else {
		?CSSPixels(none)
	}
	for item in items {
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, initial_basis.to_double())
	}
	// A wrapped column's max-content cross size is the sum of the cross sizes
	// of the lines produced under the definite main size. Use the largest item
	// contribution as the available cross space while laying those lines out.
	if constraint == .max_content && container.computed_values().flex_wrap() != .nowrap {
		mut largest := CSSPixels.new(0)
		for item in items {
			largest = css_pixels_max(largest, flex_formatting_context_calculate_cross_max_content_contribution(mut state, item, false, initial_basis, available_main_size))
		}
		if main_size := available_main_size {
			container_state.set_content_width(largest)
			result := run_wrapping_column_flex_formatting_context(mut state, container, mut container_state, items, largest, main_size, .intrinsic_sizing)
			return result.automatic_content_width
		}
		return largest
	}
	mut first_pass := CSSPixels.new(0)
	for item in items {
		contribution := if constraint == .min_content {
			flex_formatting_context_calculate_cross_min_content_contribution(mut state, item, false, initial_basis, available_main_size)
		} else {
			flex_formatting_context_calculate_cross_max_content_contribution(mut state, item, false, initial_basis, available_main_size)
		}
		first_pass = css_pixels_max(first_pass, contribution)
	}
	container_state.set_content_width(first_pass)
	mut second_pass := CSSPixels.new(0)
	for item in items {
		contribution := if constraint == .min_content {
			flex_formatting_context_calculate_cross_min_content_contribution(mut state, item, true, first_pass, available_main_size)
		} else {
			flex_formatting_context_calculate_cross_max_content_contribution(mut state, item, true, first_pass, available_main_size)
		}
		second_pass = css_pixels_max(second_pass, contribution)
	}
	return second_pass
}

// CSS Flexbox intrinsic main/cross sizing. This is the main-axis algorithm
// used for row flex containers; column containers expose the largest cross
// contribution as their intrinsic width.
fn calculate_intrinsic_flex_width(mut state LayoutState, container &Node, constraint SizeConstraint) CSSPixels {
	items := ordered_flex_items(container)
	if items.len == 0 {
		return CSSPixels.new(0)
	}
	if container.computed_values().flex_direction() in [.column, .column_reverse] {
		return calculate_intrinsic_column_flex_width(mut state, container, items, constraint)
	}
	if constraint == .min_content && container.computed_values().flex_wrap() != .nowrap {
		mut largest := CSSPixels.new(0)
		for item in items {
			box := item.as_box() or { continue }
			largest = css_pixels_max(largest, intrinsic_outer_width_contribution(mut state, box, .min_content))
		}
		return largest
	}

	mut bases := []CSSPixels{}
	mut edges := []CSSPixels{}
	mut contributions := []CSSPixels{}
	mut desired_fractions := []f64{}
	mut sum_grow := 0.0
	mut sum_shrink := 0.0
	container_styled := container.as_node_with_style() or { return CSSPixels.new(0) }
	container_state := state.get(container_styled)
	for item in items {
		box := item.as_box() or { continue }
		styled := item.as_node_with_style() or { continue }
		mut item_state := state.get_mutable(styled)
		item_state.set_containing_block_used_values(container_state)
		resolve_box_model_edges(styled.computed_values(), mut item_state, 0)
		// A single-line flex container with a definite cross size gives stretched
		// items that definite cross size before their flex base is determined.
		// This lets a content flex basis transfer the size through an intrinsic
		// aspect ratio, exactly as the full FlexFormattingContext does in step 2.
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
		edge := flex_or_grid_item_outer_inline_edges(item_state)
		basis_value := styled.computed_values().flex_basis()
		mut base := CSSPixels.new(0)
		preferred_width := styled.computed_values().size_value(.width)
		// used_flex_basis_for_item(): auto first retrieves width, and a
		// percentage flex basis becomes content when the intrinsically-sized
		// container has no definite main size.
		basis_depends_on_indefinite_container :=
			(!basis_value.is_content && basis_value.size.contains_percentage())
				|| (basis_value.size.is_auto() && preferred_width.contains_percentage())
		used_basis_is_content := basis_value.is_content
			|| (basis_value.size.is_auto() && preferred_width.is_auto())
			|| basis_depends_on_indefinite_container
		if used_basis_is_content {
			if transferred := flex_formatting_context_transferred_size_suggestion(item, item_state, true) {
				base = transferred
			} else {
				base = if constraint == .min_content {
					calculate_min_content_width(mut state, box)
				} else {
					calculate_max_content_width(mut state, box)
				}
			}
		} else if !basis_value.is_content && !basis_value.size.is_auto() {
			base = resolve_layout_size(item, basis_value.size, CSSPixels.new(0)) or {
				calculate_max_content_width(mut state, box)
			}
		} else if basis_value.size.is_auto() {
			base = resolve_layout_size(item, styled.computed_values().size_value(.width), CSSPixels.new(0)) or { calculate_max_content_width(mut state, box) }
		} else {
			base = calculate_max_content_width(mut state, box)
		}
		contribution := intrinsic_outer_width_contribution(mut state, box, constraint)
		outer_base := base.plus(edge)
		mut difference := contribution.minus(outer_base)
		grow := f64(styled.computed_values().flex_grow())
		shrink := f64(styled.computed_values().flex_shrink())
		scaled_shrink := shrink * base.to_double()
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
		bases << base
		edges << edge
		contributions << contribution
		desired_fractions << difference.to_double()
		sum_grow += grow
		sum_shrink += shrink
	}
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
	mut total := CSSPixels.new(0)
	for index, item in items {
		if index >= bases.len {
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
		minimum := flex_used_main_minimum(mut state, item, item_state, true, none, false)
		maximum := flex_used_main_maximum(mut state, item, item_state, true, none)
		result = css_pixels_max(minimum, css_pixels_min(result, maximum))
		total = total.plus(result).plus(edges[index])
	}
	gap := resolve_layout_gap(container, .column_gap, total)
	if items.len > 1 {
		total = total.plus(gap.scaled(f64(items.len - 1)))
	}
	return clamp_to_max_dimension_value(total)
}

fn calculate_stretch_fit_width(box &Box, available_width AvailableSize) CSSPixels {
	if !available_width.is_definite() {
		return CSSPixels.new(0)
	}
	// calculate_fit_content_width() can be called after a tentative block-width
	// equation has put all over-constraint space into the end margin. LibWeb
	// resolves the authored box-model edges for the fit-content calculation;
	// that synthetic end margin must not reduce the stretch-fit size.
	mut measurement := UsedValues{}
	resolve_box_model_edges(box.computed_values(), mut measurement, available_width.to_px_or_zero().to_double())
	return available_width.to_px_or_zero().minus(measurement.margin_left).minus(measurement.margin_right).minus(measurement.padding_left).minus(measurement.padding_right).minus(measurement.border_left).minus(measurement.border_right)
}

fn calculate_fit_content_width(mut state LayoutState, box &Box, available_width AvailableSize) CSSPixels {
	if available_width.is_definite() {
		minimum := calculate_min_content_width(mut state, box)
		maximum := calculate_max_content_width(mut state, box)
		stretch := calculate_stretch_fit_width(box, available_width)
		return css_pixels_max(minimum, css_pixels_min(maximum, stretch))
	}
	if available_width.is_min_content() {
		return calculate_min_content_width(mut state, box)
	}
	return calculate_max_content_width(mut state, box)
}

// CSS Sizing intrinsic block sizes. For block containers, tables and inline
// boxes the min-content block size is the max-content block size.
fn calculate_min_content_height(mut state LayoutState, box &Box, width CSSPixels) CSSPixels {
	node := unsafe { &Node(box) }
	if node.is_block_container() || node.display().is_table_inside() {
		return calculate_max_content_height(mut state, box, width)
	}
	if auto_size := box.auto_content_box_size().height {
		if ratio := box.auto_content_box_size().aspect_ratio {
			return width.divided_by_fraction(ratio)
		}
		return auto_size
	}
	if !node.has_children() {
		return CSSPixels.new(0)
	}
	mut mutable_box := unsafe { &Box(box) }
	mut cache := mutable_box.cached_intrinsic_sizes()
	key := width.raw_value()
	if cached := cache.min_content_height[key] {
		return cached
	}
	result := calculate_content_height_with_constraint(mut state, box, width, .min_content)
	cache = mutable_box.cached_intrinsic_sizes()
	cache.min_content_height[key] = result
	return result
}

fn calculate_max_content_height(mut state LayoutState, box &Box, width CSSPixels) CSSPixels {
	if ratio := box.preferred_aspect_ratio() {
		return width.divided_by_fraction(ratio)
	}
	if auto_height := box.auto_content_box_size().height {
		return auto_height
	}
	node := unsafe { &Node(box) }
	if !node.has_children() {
		return CSSPixels.new(0)
	}
	mut mutable_box := unsafe { &Box(box) }
	mut cache := mutable_box.cached_intrinsic_sizes()
	key := width.raw_value()
	if cached := cache.max_content_height[key] {
		return cached
	}
	result := calculate_content_height_with_constraint(mut state, box, width, .max_content)
	cache = mutable_box.cached_intrinsic_sizes()
	cache.max_content_height[key] = result
	return result
}

fn calculate_content_height_with_constraint(mut source_state LayoutState, box &Box, width CSSPixels, constraint SizeConstraint) CSSPixels {
	node := unsafe { &Node(box) }
	styled := node.as_node_with_style() or { return CSSPixels.new(0) }
	mut throwaway := LayoutState.new_for_subtree(styled)
	populate_intrinsic_containing_block_chain(mut throwaway, mut source_state, node)
	populate_intrinsic_external_containing_blocks(mut throwaway, mut source_state, node, node)
	mut values := throwaway.get_mutable(styled)
	values.height_constraint = constraint
	values.set_indefinite_content_height()
	values.set_content_width(width)
	available_height := if constraint == .min_content {
		AvailableSize.make_min_content()
	} else {
		AvailableSize.make_max_content()
	}
	result := layout_inside_independent_formatting_context_with_mode(mut throwaway, node, mut values, .intrinsic_sizing, AvailableSpace.new(AvailableSize.make_definite(width), available_height))
	return clamp_to_max_dimension_value(result.automatic_content_height)
}

fn calculate_stretch_fit_height(box_state &UsedValues, available_height AvailableSize) CSSPixels {
	return available_height.to_px_or_zero().minus(box_state.margin_top).minus(box_state.margin_bottom).minus(box_state.padding_top).minus(box_state.padding_bottom).minus(box_state.border_top).minus(box_state.border_bottom)
}

fn calculate_fit_content_height(mut state LayoutState, box &Box, width CSSPixels, available_height AvailableSize) CSSPixels {
	if available_height.is_definite() {
		styled := unsafe { &Node(box) }.as_node_with_style() or { return CSSPixels.new(0) }
		box_state := state.get(styled)
		minimum := calculate_min_content_height(mut state, box, width)
		maximum := calculate_max_content_height(mut state, box, width)
		stretch := calculate_stretch_fit_height(box_state, available_height)
		return css_pixels_max(minimum, css_pixels_min(maximum, stretch))
	}
	if available_height.is_min_content() {
		return calculate_min_content_height(mut state, box, width)
	}
	return calculate_max_content_height(mut state, box, width)
}

// Resolve the box's preferred block size to a used content-box size before
// inside layout. Unlike the legacy length-only helper, this handles intrinsic
// sizing keywords and the ratio-dependent auto axis.
fn resolve_content_height_for_node(mut state LayoutState, node &NodeWithStyle, used_values &UsedValues, containing_block_height ?f64) ?f64 {
	computed := node.computed_values()
	size := computed.size_value(.height)
	box := unsafe { &Node(node) }.as_box() or {
		return resolve_definite_content_height(computed, containing_block_height)
	}
	if size.is_auto() {
		if ratio := box.preferred_aspect_ratio() {
			return used_values.content_width().divided_by_fraction(ratio).to_double()
		}
		return none
	}
	if size.contains_percentage() && containing_block_height == none {
		// An unresolved percentage block size is treated as auto. If the box
		// has a preferred ratio, that automatic size is transferred from the
		// already-resolved inline size.
		if ratio := box.preferred_aspect_ratio() {
			return used_values.content_width().divided_by_fraction(ratio).to_double()
		}
		return none
	}
	if size.is_min_content() {
		return calculate_min_content_height(mut state, box, used_values.content_width()).to_double()
	}
	if size.is_max_content() {
		return calculate_max_content_height(mut state, box, used_values.content_width()).to_double()
	}
	if size.is_fit_content() {
		available_height := if height := containing_block_height {
			AvailableSize.make_definite(css_px(height))
		} else {
			AvailableSize.make_indefinite()
		}
		return calculate_fit_content_height(mut state, box, used_values.content_width(), available_height).to_double()
	}
	resolved := resolve_definite_content_height(computed, containing_block_height) or {
		return none
	}
	return content_height_for_box_sizing(computed, used_values, resolved)
}

fn clamp_content_height_for_node(mut state LayoutState, node &NodeWithStyle, used_values &UsedValues, value CSSPixels, containing_block_height ?f64) CSSPixels {
	block_edges :=
		used_values.border_top.plus(used_values.padding_top).plus(used_values.padding_bottom).plus(used_values.border_bottom)
	computed := node.computed_values()
	adjustment := if computed.box_sizing() == .border_box {
		block_edges.to_double()
	} else {
		0.0
	}
	mut result := value
	max_size_for_clamp := computed.size_value(.max_height)
	if !(max_size_for_clamp.contains_percentage() && containing_block_height == none) {
		if specified_max := computed.length_percentage_to_px(.max_height, containing_block_height or {
			0
		}) {
			maximum := css_px(if specified_max > adjustment {
				specified_max - adjustment
			} else {
				0.0
			})
			result = css_pixels_min(result, maximum)
		}
	}
	min_size_for_clamp := computed.size_value(.min_height)
	if !(min_size_for_clamp.contains_percentage() && containing_block_height == none) {
		if specified_min := computed.length_percentage_to_px(.min_height, containing_block_height or {
			0
		}) {
			minimum := css_px(if specified_min > adjustment {
				specified_min - adjustment
			} else {
				0.0
			})
			result = css_pixels_max(result, minimum)
		}
	}
	box := unsafe { &Node(node) }.as_box() or { return result }
	available_height := if height := containing_block_height {
		AvailableSize.make_definite(css_px(height))
	} else {
		AvailableSize.make_indefinite()
	}
	max_size := computed.size_value(.max_height)
	if max_size.is_min_content() {
		result = css_pixels_min(result, calculate_min_content_height(mut state, box, used_values.content_width()))
	} else if max_size.is_max_content() {
		result = css_pixels_min(result, calculate_max_content_height(mut state, box, used_values.content_width()))
	} else if max_size.is_fit_content() {
		result = css_pixels_min(result, calculate_fit_content_height(mut state, box, used_values.content_width(), available_height))
	}
	min_size := computed.size_value(.min_height)
	if min_size.is_min_content() {
		result = css_pixels_max(result, calculate_min_content_height(mut state, box, used_values.content_width()))
	} else if min_size.is_max_content() {
		result = css_pixels_max(result, calculate_max_content_height(mut state, box, used_values.content_width()))
	} else if min_size.is_fit_content() {
		result = css_pixels_max(result, calculate_fit_content_height(mut state, box, used_values.content_width(), available_height))
	}
	return result
}
