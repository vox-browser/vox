// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// FormattingContext.cpp's file-local margin_box_rect(). Negative margins do
// not extend this local rectangle beyond the content box.
$if test {
	fn margin_box_rect(used_values &UsedValues) css.CSSPixelRect {
		zero := CSSPixels.new(0)
		left := css_pixels_max(used_values.margin_box_left(), zero)
		top := css_pixels_max(used_values.margin_box_top(), zero)
		right := css_pixels_max(used_values.margin_box_right(), zero)
		bottom := css_pixels_max(used_values.margin_box_bottom(), zero)
		return css.CSSPixelRect{
			x: left.negated()
			y: top.negated()
			width: left.plus(used_values.content_width()).plus(right)
			height: top.plus(used_values.content_height()).plus(bottom)
		}
	}
}

// The inline ancestor whose per-line paintable owns a line-box fragment.
// Atomic inline ancestors terminate the search because their descendants are
// painted through the atomic box instead.
fn fragment_inline_paintable_target(fragment_node &Node) ?&Node {
	mut ancestor := fragment_node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if current.is_atomic_inline() || current.is_block_container() {
			return none
		}
		if current.is_inline_node() {
			return current
		}
		ancestor = current.parent()
	}
	return none
}

// FormattingContext::can_skip_is_anonymous_text_run(). Anonymous flex/grid
// children containing only collapsible text whitespace do not generate an
// item. The empty anonymous button content box is covered by the vacuous case.
fn can_skip_anonymous_text_run(box &Node) bool {
	if !box.is_anonymous() || box.is_generated_for_pseudo_element() {
		return false
	}
	for child in box.children() {
		if child.is_block_container() {
			return false
		}
	}
	mut pending := box.children()
	for pending.len > 0 {
		node := pending.pop()
		if text := node.as_text_node() {
			if !string_is_ascii_whitespace(text.source_text_) {
				return false
			}
			continue
		}
		return false
	}
	return true
}

fn layout_length_resolution_context(node &Node) css.LengthResolutionContext {
	computed := node.computed_values()
	mut context := css.LengthResolutionContext.for_document(node.document())
	font_size := computed.font_size()
	font_metrics := layout_font_metrics_for_node(node)
	context.font_metrics.font_size = font_size
	context.font_metrics.x_height = CSSPixels.nearest_value_for(f64(font_metrics.x_height))
	context.font_metrics.cap_height = font_size.scaled(0.75)
	context.font_metrics.zero_advance =
		CSSPixels.nearest_value_for(f64(font_metrics.advance_of_ascii_zero))
	context.font_metrics.line_height = computed.line_height()
	return context
}

fn resolve_layout_size(node &Node, size css.Size, percentage_basis CSSPixels) ?CSSPixels {
	if !size.is_length() && !size.is_percentage() && !size.is_calculated() {
		return none
	}
	if size.is_calculated() {
		context := layout_length_resolution_context(node)
		length := size.calculated().resolve_length(css.CalculationResolutionContext{
			percentage_basis:css.Length.make_css_px(percentage_basis)
			length_resolution_context:context
		}) or { return none }
		return css_px(length.to_px_without_rounding(context))
	}
	// Absolute lengths and plain percentages do not read font or viewport
	// metrics. Keep the existing size resolver and its payload/rounding rules.
	if value := size.length_percentage_ {
		if value.is_length() && value.length().is_absolute()
			&& node.document().font_rendering_policy() == .chromium {
			// Blink constructs a LayoutUnit from the final float length. The
			// nearest-pixel conversion used by the upstream policy rounds early.
			return CSSPixels.truncated_value_for(value.length().absolute_length_to_px_without_rounding())
		}
		if value.is_percentage() || (value.is_length() && value.length().is_absolute()) {
			return size.to_px(css.LengthResolutionContext{}, percentage_basis)
		}
	}
	return size.to_px(layout_length_resolution_context(node), percentage_basis)
}

// Resolve an authored preferred size to the content-box size consumed by the
// formatting-context handshake. CSS lengths name the border box when
// box-sizing:border-box, while UsedValues always stores content dimensions.
fn resolve_layout_content_size(node &Node, size css.Size, percentage_basis CSSPixels, used_values &UsedValues, width bool) ?CSSPixels {
	if size.is_stretch() { return stretch_fit_content_size(node, used_values, percentage_basis, width) }
	mut resolved := resolve_layout_size(node, size, percentage_basis) or { return none }
	if node.computed_values().box_sizing() == .border_box {
		edges := if used_values.is_collapsed_borders_table_box() {
			if width {
				used_values.border_box_left().plus(used_values.border_box_right())
			} else {
				used_values.border_box_top().plus(used_values.border_box_bottom())
			}
		} else if width {
			used_values.border_left.plus(used_values.padding_left).plus(used_values.padding_right).plus(used_values.border_right)
		} else {
			used_values.border_top.plus(used_values.padding_top).plus(used_values.padding_bottom).plus(used_values.border_bottom)
		}
		resolved = resolved.minus(edges)
	}
	return css_pixels_max(CSSPixels.new(0), resolved)
}

fn clamp_layout_content_size(node &Node, value CSSPixels, percentage_basis CSSPixels, used_values &UsedValues, width bool) CSSPixels {
	return clamp_layout_content_size_with_stretch_basis(node, value, percentage_basis, percentage_basis, used_values, width)
}

fn clamp_layout_content_size_with_stretch_basis(node &Node, value CSSPixels, percentage_basis CSSPixels, stretch_basis CSSPixels, used_values &UsedValues, width bool) CSSPixels {
	edges := if used_values.is_collapsed_borders_table_box() {
		if width {
			used_values.border_box_left().plus(used_values.border_box_right())
		} else {
			used_values.border_box_top().plus(used_values.border_box_bottom())
		}
	} else if width {
		used_values.border_left.plus(used_values.padding_left).plus(used_values.padding_right).plus(used_values.border_right)
	} else {
		used_values.border_top.plus(used_values.padding_top).plus(used_values.padding_bottom).plus(used_values.border_bottom)
	}
	mut result := css_px(clamp_box_content_to_min_max(node.computed_values(), if width {
		.min_width
	} else {
		.min_height
	}, if width {
		.max_width
	} else {
		.max_height
	}, value.to_double(), percentage_basis.to_double(), edges.to_double()))
	computed := node.computed_values()
	constraint := if width { used_values.width_constraint } else { used_values.height_constraint }
	if constraint != .none { return result }
	maximum_limit := computed.size_value(if width { .max_width } else { .max_height })
	if maximum_limit.is_stretch() {
		result = css_pixels_min(result, resolve_calc_size_for_box(computed, used_values, maximum_limit, width,
			stretch_fit_content_size(node, used_values, stretch_basis, width), percentage_basis))
	}
	minimum_limit := computed.size_value(if width { .min_width } else { .min_height })
	if minimum_limit.is_stretch() {
		result = css_pixels_max(result, resolve_calc_size_for_box(computed, used_values, minimum_limit, width,
			stretch_fit_content_size(node, used_values, stretch_basis, width), percentage_basis))
	}
	minimum_size := computed.size_value(if width { .min_width } else { .min_height })
	if !minimum_size.is_stretch() {
		if minimum := resolve_layout_content_size(node, minimum_size, percentage_basis, used_values, width) {
			result = css_pixels_max(result, minimum)
		}
	}
	return result
}

fn resolve_layout_gap(node &Node, property_id css.PropertyID, percentage_basis CSSPixels) CSSPixels {
	gap := node.computed_values().gap_value(property_id)
	if gap.is_normal {
		return CSSPixels.new(0)
	}
	context := layout_length_resolution_context(node)
	if gap.length_percentage.is_length()
		&& node.document().font_rendering_policy() == .chromium {
		// Blink constructs the gap's LayoutUnit from the resolved float length.
		// Rounding here can enlarge a shrink-to-fit flex item by one unit and
		// shift its end-aligned contents across a glyph rasterization boundary.
		return CSSPixels.truncated_value_for(gap.length_percentage.length().to_px_without_rounding(context))
	}
	return gap.length_percentage.to_px(context, percentage_basis)
}

// LayoutNG converts a fixed relative offset with LayoutUnit(float), which
// truncates toward zero instead of rounding to the nearest unit.
fn relative_inset_to_px(node &NodeWithStyle, size css.Size, percentage_basis CSSPixels) CSSPixels {
	context := layout_length_resolution_context(unsafe { &Node(node) })
	if size.is_length() && unsafe { &Node(node) }.document().font_rendering_policy() == .chromium {
		return CSSPixels.truncated_value_for(size.length().to_px_without_rounding(context))
	}
	return size.to_px(context, percentage_basis)
}

fn resolve_relative_inset_axis(node &NodeWithStyle, start_property css.PropertyID, end_property css.PropertyID, percentage_basis CSSPixels, percentages_are_auto bool) (CSSPixels, CSSPixels) {
	computed := node.computed_values()
	start_size := computed.size_value(start_property)
	end_size := computed.size_value(end_property)
	start_auto := property_is_auto(computed, start_property)
		|| (percentages_are_auto && start_size.contains_percentage())
	end_auto := property_is_auto(computed, end_property)
		|| (percentages_are_auto && end_size.contains_percentage())
	start := if start_auto {
		CSSPixels.new(0)
	} else {
		relative_inset_to_px(node, start_size, percentage_basis)
	}
	end := if end_auto {
		CSSPixels.new(0)
	} else {
		relative_inset_to_px(node, end_size, percentage_basis)
	}
	if start_auto && end_auto {
		return CSSPixels.new(0), CSSPixels.new(0)
	}
	if start_auto {
		return end.negated(), end
	}
	return start, start.negated()
}

// https://www.w3.org/TR/css-position-3/#relpos-insets
fn compute_relative_inset_for_node(node &NodeWithStyle, mut used_values UsedValues, containing_block_used_values &UsedValues) {
	if node.computed_values().position() != .relative {
		return
	}
	width_basis := used_values.relative_inset_basis_width() or {
		containing_block_used_values.content_width()
	}

	height_basis_override := used_values.relative_inset_basis_height()
	height_basis := height_basis_override or {
		containing_block_used_values.content_height()
	}

	left, right := resolve_relative_inset_axis(node, .left, .right, width_basis, false)
	top, bottom := resolve_relative_inset_axis(node, .top, .bottom, height_basis, height_basis_override == none
		&& !containing_block_used_values.has_definite_height())
	used_values.inset_left = left
	used_values.inset_right = right
	used_values.inset_top = top
	used_values.inset_bottom = bottom
}

fn resolve_relative_insets(mut state LayoutState, root &Node) {
	resolve_relative_insets_in(mut state, root, state.in_reused_subtree(root, false))
}

// A subtree restored by incremental_layout.v already carries its insets.
fn resolve_relative_insets_in(mut state LayoutState, root &Node, parent_reused bool) {
	if !parent_reused {
		resolve_own_relative_insets(mut state, root)
	}
	reused := subtree_layout_reused_below(state, root, parent_reused)
	for child in root.children() {
		resolve_relative_insets_in(mut state, child, reused)
	}
}

fn resolve_own_relative_insets(mut state LayoutState, root &Node) {
	if styled := root.as_node_with_style() {
		// Nodes which did not participate in layout (for example anonymous text
		// wrappers below an SVG viewport) have no UsedValues to adjust.
		if styled.computed_values().position() == .relative {
			if existing := state.try_get(styled) {
				if containing := existing.containing_block_used_values() {
					mut used_values := state.mutable_box_values(styled)
					compute_relative_inset_for_node(styled, mut used_values, containing)
				}
			}
		}
	}
}

// Lay out a formatting-context child whose parent has already chosen an
// optional content width/height. This is the shared parent/child handshake used
// by flex, grid, table, and replaced-with-children formatting contexts.
fn layout_independent_child(mut state LayoutState, child &Node, mut containing_state UsedValues, containing_width CSSPixels, containing_height ?CSSPixels, forced_width ?CSSPixels, forced_height ?CSSPixels) &UsedValues {
	return layout_independent_child_with_height_mode(mut state, child, mut containing_state, containing_width, containing_height, forced_width, forced_height, false, true, false)
}

// The parent already applied min/max constraints using its final flex line.
// Keep the original containing block for percentage descendants and avoid
// applying the same stretch constraint again against that different size.
fn layout_independent_child_with_resolved_height(mut state LayoutState, child &Node, mut containing_state UsedValues, containing_width CSSPixels, containing_height ?CSSPixels, forced_width ?CSSPixels, forced_height CSSPixels) &UsedValues {
	return layout_independent_child_with_height_mode(mut state, child, mut containing_state, containing_width, containing_height, forced_width, forced_height, false, true, true)
}

fn layout_independent_child_with_forced_height_definiteness(mut state LayoutState, child &Node, mut containing_state UsedValues, containing_width CSSPixels, containing_height ?CSSPixels, forced_width ?CSSPixels, forced_height ?CSSPixels, forced_height_is_definite bool) &UsedValues {
	return layout_independent_child_with_height_mode(mut state, child, mut containing_state,
		containing_width, containing_height, forced_width, forced_height, false,
		forced_height_is_definite, false)
}

// TableFormattingContext::compute_table_height() initially uses a definite
// cell height to lay out descendants, then replaces the cell's content height
// with the independent formatting context's automatic height. The authored
// height remains a row minimum and vertical alignment supplies the difference.
fn layout_independent_child_using_automatic_height(mut state LayoutState, child &Node, mut containing_state UsedValues, containing_width CSSPixels, containing_height ?CSSPixels, forced_width ?CSSPixels, available_content_height ?CSSPixels) &UsedValues {
	return layout_independent_child_with_height_mode(mut state, child, mut containing_state, containing_width, containing_height, forced_width, available_content_height, true, true, false)
}

fn measure_automatic_button_content_height(mut source_state LayoutState, button &Node, button_state &UsedValues) CSSPixels {
	styled := button.as_node_with_style() or { return CSSPixels.new(0) }
	mut throwaway := source_state.new_measurement_for_subtree(styled)
	defer { throwaway.release_measurement() }
	populate_intrinsic_containing_block_chain(mut throwaway, mut source_state, button)
	populate_intrinsic_external_containing_blocks(mut throwaway, mut source_state, button,
		button)
	mut values := throwaway.get_mutable(styled)
	values.set_content_width(button_state.content_width())
	values.set_has_definite_width(true)
	values.set_indefinite_content_height()
	result := layout_inside_independent_formatting_context_with_mode(mut throwaway, button,
		mut values, .intrinsic_sizing, AvailableSpace.new(AvailableSize.make_definite(
		button_state.content_width()), AvailableSize.make_indefinite()))
	return result.automatic_content_height
}

// The anonymous column-flex wrapper inside an HTML button has `height: 100%`.
// Give that percentage a definite basis only when the button's final used
// content height is larger than its natural contents, so alignment can center
// those contents without making intrinsic keyword heights spuriously definite.
fn make_button_content_box_definite(mut state LayoutState, button &Node, mut button_state UsedValues, containing_height ?CSSPixels) bool {
	if !node_uses_button_layout(button) || button.display().is_flex_inside()
		|| button.display().is_grid_inside() || button_state.has_definite_height() {
		return false
	}
	computed := button.computed_values()
	if computed.size_value(.height).is_auto() && computed.size_value(.min_height).is_auto() {
		return false
	}
	_ = button.as_box() or { return false }
	styled := button.as_node_with_style() or { return false }
	natural_content_height := measure_automatic_button_content_height(mut state, button,
		button_state)
	containing_height_value := if height := containing_height { ?f64(height.to_double()) } else { none }
	mut used_height := if resolved := resolve_content_height_for_node(mut state,
		styled, button_state, containing_height_value) {
		css_px(resolved)
	} else {
		natural_content_height
	}
	used_height = clamp_content_height_for_node(mut state,
		styled, button_state, used_height,
		containing_height_value)
	if used_height.raw_value() <= natural_content_height.raw_value() {
		return false
	}
	button_state.set_content_height(used_height)
	button_state.set_has_definite_height(true)
	return true
}

fn layout_independent_child_with_height_mode(mut state LayoutState, child &Node, mut containing_state UsedValues, containing_width CSSPixels, containing_height ?CSSPixels, forced_width ?CSSPixels, forced_height ?CSSPixels, use_automatic_height bool, forced_height_is_definite bool, parent_resolved_height bool) &UsedValues {
	styled := child.as_node_with_style() or { panic('formatting-context child must have style') }
	computed := styled.computed_values()
	mut child_state := state.get_mutable(styled)
	child_state.set_containing_block_used_values(containing_state)
	resolve_box_model_edges(computed, mut child_state, containing_width.to_double())
	if child.is_replaced_box() && forced_width == none && forced_height == none {
		box := child.as_box() or { panic('replaced node must be a box') }
		// A ratio-only replaced box stretch-fits into the available margin-box
		// space. Its tentative content width therefore excludes the resolved
		// margins, borders, and padding already occupying that space.
		replaced_available_width := containing_width.minus(flex_or_grid_item_outer_inline_edges(child_state))
		size := compute_replaced_size(box, AvailableSpace.new(AvailableSize.make_definite(replaced_available_width), if height := containing_height {
			AvailableSize.make_definite(height)
		} else {
			AvailableSize.make_indefinite()
		}))
		child_state.set_content_width(size.width())
		child_state.set_content_height(size.height())
		child_state.set_has_definite_width(true)
		child_state.set_has_definite_height(true)
		return child_state
	} else if width := forced_width {
		child_state.set_content_width(width)
		// The parent formatting context has resolved this item's used inline
		// size. Upstream copies that definite FlexItem/GridItem dimension into
		// UsedValues before laying out the item's independent formatting context.
		child_state.set_has_definite_width(true)
	} else if child_state.has_definite_width() {
		// Flex/grid/table/independent formatting contexts consume the definite
		// width initialized from the computed size. They do not apply the CSS
		// 2.1 normal-flow block equation that expands the ignored end margin to
		// fill the containing block.
	} else {
		compute_block_used_width_for_node(mut state, styled, mut child_state, AvailableSize.make_definite(containing_width))
	}

	mut definite_height := forced_height
	mut height_establishes_definite_containing_block := definite_height != none
		&& forced_height_is_definite
	if definite_height == none && !use_automatic_height {
		mut containing_block_height := ?f64(none)
		if height := containing_height {
			containing_block_height = height.to_double()
		}
		if resolved := resolve_content_height_for_node(mut state, styled, child_state, containing_block_height) {
			definite_height = css_px(resolved)
			height_establishes_definite_containing_block =
				computed_height_establishes_definite_containing_block_height(computed.size_value(.height))
		}
	}
	if resolved_height := definite_height {
		if !use_automatic_height && !parent_resolved_height {
			mut containing_block_height := ?f64(none)
			if height := containing_height {
				containing_block_height = height.to_double()
			}
			definite_height = clamp_content_height_for_node(mut state, styled, child_state, resolved_height, containing_block_height)
		}
	}
	if make_button_content_box_definite(mut state, child, mut child_state, containing_height) {
		definite_height = child_state.content_height()
		height_establishes_definite_containing_block = true
	}
	available_height := if height := definite_height {
		// Descendants must see a parent-resolved flex/grid/table block size as
		// definite during this layout pass, not only after it has completed.
		child_state.set_content_height(height)
		if height_establishes_definite_containing_block {
			child_state.set_has_definite_height(true)
			AvailableSize.make_definite(height)
		} else {
			AvailableSize.make_indefinite()
		}
	} else {
		AvailableSize.make_indefinite()
	}
	// The anonymous button content box may acquire a post-flexing height smaller
	// than the button. Percentages inside it still resolve against the button's
	// content height, including while the content box is being measured. The V
	// layout tree has an extra anonymous flex wrapper between the two, so recover
	// the definite button basis directly when that wrapper's auto height did not
	// carry it through the flex-item call.
	child_available_height := if child.is_button_content_box_ {
		mut button_height := ?CSSPixels(none)
		if wrapper := child.parent() {
			if button := wrapper.parent() {
				if button_styled := button.as_node_with_style() {
					if button_state := state.try_get(button_styled) {
						if button_state.has_definite_height() {
							button_height = button_state.content_height()
						}
					}
				}
			}
		}
		if height := button_height {
			AvailableSize.make_definite(height)
		} else {
			AvailableSize.make_indefinite()
		}
	} else {
		available_height
	}
	inside := layout_inside_independent_formatting_context(mut state, child, mut child_state, AvailableSpace.new(AvailableSize.make_definite(child_state.content_width()), child_available_height))
	mut height := if use_automatic_height {
		inside.automatic_content_height
	} else if resolved := definite_height {
		resolved
	} else {
		inside.automatic_content_height
	}
	if !use_automatic_height && !parent_resolved_height {
		height = clamp_content_height_for_node(mut state, styled, child_state, height, if basis := containing_height {
			basis.to_double()
		} else {
			none
		})
	}
	if !use_automatic_height && definite_height == none
		&& height.raw_value() > inside.automatic_content_height.raw_value() {
		// An auto-sized independent context constrained upward by min-height is
		// rerun with that constrained size as its available block size. Flex and
		// grid descendants then resolve stretch/alignment against the real used
		// size rather than the unconstrained measurement. The root box itself
		// remains indefinite: min-height does not make percentage child heights
		// definite.
		layout_inside_independent_formatting_context(mut state, child, mut child_state, AvailableSpace.new(AvailableSize.make_definite(child_state.content_width()), AvailableSize.make_definite(height)))
	}
	child_state.set_content_height(height)
	if height_establishes_definite_containing_block {
		child_state.set_has_definite_height(true)
	}
	return child_state
}

fn flex_or_grid_item_outer_inline_edges(state &UsedValues) CSSPixels {
	return state.margin_left.plus(state.border_left).plus(state.padding_left).plus(state.padding_right).plus(state.border_right).plus(state.margin_right)
}

fn flex_or_grid_item_outer_block_edges(state &UsedValues) CSSPixels {
	return state.margin_top.plus(state.border_top).plus(state.padding_top).plus(state.padding_bottom).plus(state.border_bottom).plus(state.margin_bottom)
}

enum BaselineSet {
	first
	last
}

// FormattingContext::box_child_to_derive_baseline_from(). Find the last
// in-flow block child which has a baseline of its own, either directly from a
// line box or recursively from one of its descendants.
fn layout_box_child_to_derive_baseline_from(state &LayoutState, box &Node, baseline_set BaselineSet) ?&Node {
	if !box.has_children() || box.children_are_inline() {
		return none
	}
	children := box.children()
	mut index := if baseline_set == .first { 0 } else { children.len - 1 }
	for index >= 0 && index < children.len {
		child := children[index]
		if !child.is_box() || child.is_out_of_flow() || (box.is_fieldset_box() && child.is_legend_box()) {
			index += if baseline_set == .first { 1 } else { -1 }
			continue
		}
		styled := child.as_node_with_style() or {
			index += if baseline_set == .first { 1 } else { -1 }
			continue
		}
		child_state := state.try_get(styled) or {
			index += if baseline_set == .first { 1 } else { -1 }
			continue
		}
		if child_state.is_invisible_for_line_clamp() {
			index += if baseline_set == .first { 1 } else { -1 }
			continue
		}
		if child_state.line_boxes.len > 0
			|| child_state.derived_first_baseline() != none
			|| child_state.derived_last_baseline() != none
			|| layout_box_child_to_derive_baseline_from(state, child, baseline_set) != none {
			return child
		}
		index += if baseline_set == .first { 1 } else { -1 }
	}
	return none
}

// UsedValues::first_baseline of a laid-out box: the first baseline of its
// content relative to its content-box top, or none when no in-flow line or
// descendant supplies one. A list item's marker is laid out separately and
// never supplies its list item's baseline.
fn layout_box_first_content_baseline(state &LayoutState, box &Node) ?CSSPixels {
	styled := box.as_node_with_style() or { return none }
	box_state := state.try_get(styled) or { return none }
	if baseline := box_state.derived_first_baseline() {
		return baseline
	}
	for line in box_state.line_boxes {
		if line.is_empty() {
			continue
		}
		if !line.has_block_level_box() {
			return line.bottom().minus(line.block_length()).plus(line.baseline())
		}
		// A line hosting an interrupting block takes that block's baseline.
		block_child := line.fragments_[0].layout_node()
		block_child_styled := block_child.as_node_with_style() or { return none }
		block_child_state := state.try_get(block_child_styled) or { return none }
		child_baseline := layout_box_first_content_baseline(state, block_child) or { return none }
		return block_child_state.offset.y().plus(child_baseline)
	}
	if box.children_are_inline() {
		return none
	}
	for child in box.children() {
		if !child.is_box() || child.is_out_of_flow() || child.is_list_item_marker_box() {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		child_state := state.try_get(child_styled) or { continue }
		if baseline := layout_box_first_content_baseline(state, child) {
			return child_state.offset.y().plus(baseline)
		}
	}
	return none
}

// FormattingContext::box_baseline(). This is shared by inline, flex, grid and
// table layout; in particular, an atomic inline without an in-flow baseline
// uses the bottom margin edge rather than merely its content height.
fn layout_box_baseline(state &LayoutState, box &Node, requested_baseline_set BaselineSet) CSSPixels {
	return layout_box_baseline_in_context(state, box, requested_baseline_set, false, false)
}

// Blink's inline-block baseline propagation uses a descendant flex/grid box's
// first baseline as the enclosing block's last baseline. Ordinary flex/grid
// alignment still requests its own first or last set explicitly.
fn inline_baseline_source(box &Node) string {
 if value := box.computed_values().property(.baseline_source,.yes) { return value.css_text }
 return 'auto'
}

fn layout_box_baseline_for_inline(state &LayoutState, box &Node) CSSPixels {
 source := inline_baseline_source(box)
 return layout_box_baseline_in_context(state,box,if source == 'first' { .first } else { .last },false,source == 'auto' && box.document().font_rendering_policy() == .chromium)
}

// Ladybird a8cff13249e769020c4c102fdec51a9cf9dd1ac2.
fn content_baseline_with_button_scroll_clamp(box &Node, used &UsedValues, baseline CSSPixels) CSSPixels {
	if !node_uses_button_layout(box) || !box.is_scroll_container() { return baseline }
	border_top := used.margin_top
	return css_pixels_min(css_pixels_max(baseline, border_top), border_top.plus(used.border_box_height()))
}

// Chromium's text controls ignore the overflow of their internal editor when
// they act as inline blocks, so the editor's text supplies the control's
// baseline instead of the editor's bottom margin edge.
fn layout_box_baseline_in_context(state &LayoutState, box &Node, requested_baseline_set BaselineSet, ignores_overflow bool, inline_block_algorithm bool) CSSPixels {
	styled := box.as_node_with_style() or { return CSSPixels.new(0) }
	box_state := state.try_get(styled) or { return CSSPixels.new(0) }
	computed := box.computed_values()
	// Size containment suppresses content-derived baselines just as it
	// suppresses content contributions to the box's automatic size.
	if box.has_size_containment() { return box_state.margin_box_height() }
	if box.vertical_align_applies() {
		match computed.vertical_align() {
			.top {
				return box_state.border_box_top()
			}
			.middle {
				containing_font_metrics := if containing_block := box.containing_block() {
					layout_font_metrics_for_node(unsafe { &Node(containing_block) })
				} else {
					layout_font_metrics_for_node(box)
				}
				return CSSPixels.from_raw(box_state.margin_box_height().raw_value() / 2).plus(CSSPixels.nearest_value_for(f64(containing_font_metrics.x_height) / 2.0))
			}
			.bottom {
				return box_state.content_height().plus(box_state.margin_box_top())
			}
			.text_top {
				return computed.font_size()
			}
			.text_bottom {
				containing_font_metrics := if containing_block := box.containing_block() {
					layout_font_metrics_for_node(unsafe { &Node(containing_block) })
				} else {
					layout_font_metrics_for_node(box)
				}
				return box_state.margin_box_height().minus(CSSPixels.nearest_value_for(f64(containing_font_metrics.descent)))
			}
			else {}
		}
	}
	// A range input sits on its bottom border edge, independently of the
	// track and thumb geometry in its internal shadow tree.
	if box.is_range_input_box() {
		return box_state.margin_box_top().plus(box_state.content_height()).plus(box_state.border_box_bottom())
	}
	mut baseline_set := requested_baseline_set
	display := box.display()
	is_flex_or_grid_container := display.is_flex_inside() || display.is_grid_inside()
	source := inline_baseline_source(box)
	if source == 'auto' && is_flex_or_grid_container && (display.is_inline_outside() || inline_block_algorithm) {
		baseline_set = .first
	}

	// A table formatting context commits the baselines established by its
	// rows. Inline tables export their first row through the wrapper; other
	// table parts export the baseline set requested by their consumer.
	if box.is_table_wrapper() {
		selected := if source == 'first' || (source == 'auto' && display.is_inline_outside()) { BaselineSet.first } else { baseline_set }
		// Caption placement can update the table's offset after its baseline
		// cache is published. Read the final offset of the native table box.
		for child in box.children() {
			if !child.display().is_table_inside() { continue }
			if child_styled := child.as_node_with_style() {
				if child_values := state.try_get(child_styled) {
					baseline := if selected == .first { child_values.derived_first_baseline() } else { child_values.derived_last_baseline() }
					if value := baseline { return box_state.margin_box_top().plus(child_values.offset.y()).plus(value) }
				}
			}
		}
		if baseline := box_state.derived_first_baseline() { return box_state.margin_box_top().plus(baseline) }
	} else if baseline_set == .first {
		if baseline := box_state.derived_first_baseline() {
			return content_baseline_with_button_scroll_clamp(box, box_state, box_state.margin_box_top().plus(baseline))
		}
	} else {
		if baseline := box_state.derived_last_baseline() {
			return content_baseline_with_button_scroll_clamp(box, box_state, box_state.margin_box_top().plus(baseline))
		}
	}

	// CSS Align's legacy bottom-edge baseline applies to scroll containers.
	// `overflow: clip` is non-visible but does not establish one, so it keeps
	// the same content-derived baseline as visible overflow.
	derive_from_content := source != 'auto' || baseline_set == .first || is_flex_or_grid_container || line_clamp_is_active(computed)
		|| node_uses_button_layout(box) || ignores_overflow || !box.is_scroll_container()
	if derive_from_content && box_state.line_boxes.len > 0 {
		mut line_index := if baseline_set == .first { 0 } else { box_state.line_boxes.len - 1 }
		for index in 0 .. box_state.line_boxes.len {
			candidate := if baseline_set == .first {
				index
			} else {
				box_state.line_boxes.len - 1 - index
			}
			if !box_state.line_boxes[candidate].is_empty() {
				line_index = candidate
				break
			}
		}
		line := box_state.line_boxes[line_index]
		if !line.has_block_level_box() {
			line_top := line.bottom().minus(line.block_length())
			return content_baseline_with_button_scroll_clamp(box, box_state, box_state.margin_box_top().plus(line_top).plus(line.baseline()))
		}
		// A line hosting an interrupting block takes that block's baseline.
		block_child := line.fragments_[0].layout_node()
		block_child_styled := block_child.as_node_with_style() or {
			return box_state.margin_box_height()
		}
		block_child_state := state.try_get(block_child_styled) or {
			return box_state.margin_box_height()
		}
		child_offset_from_margin_edge :=
			block_child_state.offset.y().minus(block_child_state.margin_box_top())
		return content_baseline_with_button_scroll_clamp(box, box_state, box_state.margin_box_top().plus(child_offset_from_margin_edge).plus(layout_box_baseline_in_context(state,
			block_child, baseline_set, ignores_overflow, inline_block_algorithm)))
	}

	if child := layout_box_child_to_derive_baseline_from(state, box, baseline_set) {
		mut is_input := false
		if dom_node := box.dom_node() {
			if element := dom_node.as_element() {
				is_input = element.local_name() == 'input'
			}
		}
		if derive_from_content || is_input {
			child_styled := child.as_node_with_style() or { return box_state.margin_box_height() }
			child_state := state.try_get(child_styled) or { return box_state.margin_box_height() }
			child_offset_from_margin_edge :=
				child_state.offset.y().minus(child_state.margin_box_top())
			child_ignores_overflow := ignores_overflow
				|| (is_input && box.document().font_rendering_policy() == .chromium)
			return content_baseline_with_button_scroll_clamp(box, box_state, box_state.margin_box_top().plus(child_offset_from_margin_edge).plus(layout_box_baseline_in_context(state,
				child, baseline_set, child_ignores_overflow, inline_block_algorithm)))
		}
	}

	// Blink's themed check boxes and radio buttons sit on the baseline with
	// their border box; only their bottom margin hangs below it.
	if layout_box_is_chromium_toggle_control(box) {
		return box_state.margin_top.plus(box_state.border_box_height())
	}
	return box_state.margin_box_height()
}

fn layout_box_is_chromium_toggle_control(box &Node) bool {
	dom_node := box.dom_node() or { return false }
	element := dom_node.as_element() or { return false }
	if !element.is_html_element() || element.local_name() != 'input'
		|| box.document().font_rendering_policy() != .chromium
		|| box.computed_values().appearance() == .none_ {
		return false
	}
	return element.get_attribute_value('type').to_lower() in ['checkbox', 'radio']
}
