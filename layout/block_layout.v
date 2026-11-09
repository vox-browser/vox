module layout

import processmetrics

import css
import platform

// Block layout algorithms shared by BlockFormattingContext and independent
// formatting contexts: used box-model edges, the CSS 2.1 width equation,
// intrinsic constraints, vertical sizing, and inside-context dispatch.

fn css_px(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(value)
}

// Whether `property_id`'s computed value is the `auto` keyword.
fn property_is_auto(computed &css.ComputedValues, property_id css.PropertyID) bool {
	return match property_id {
		.width { computed.width().is_auto() }
		.min_width { computed.min_width().is_auto() }
		.max_width { computed.max_width().is_auto() }
		.height { computed.height().is_auto() }
		.min_height { computed.min_height().is_auto() }
		.max_height { computed.max_height().is_auto() }
		.left { computed.inset().left().is_auto() }
		.top { computed.inset().top().is_auto() }
		.right { computed.inset().right().is_auto() }
		.bottom { computed.inset().bottom().is_auto() }
		.margin_left { computed.margin().left().is_auto() }
		.margin_top { computed.margin().top().is_auto() }
		.margin_right { computed.margin().right().is_auto() }
		.margin_bottom { computed.margin().bottom().is_auto() }
		else {
			value := css.ComputedProperties(*computed).property(property_id, .yes) or { return false }
			value.css_text.trim_space().to_lower() == 'auto'
		}
	}
}

// A resolved intrinsic keyword remains dependent on child layout. Its used
// height therefore does not establish a percentage-height containing block.
fn computed_height_establishes_definite_containing_block_height(size css.Size) bool {
	return !size.is_intrinsic_sizing_constraint()
}

// The used border width for one side: 0 if that side's border-style is none/hidden (CSS 2.1 §8.5.3),
// otherwise the resolved border-width.
fn resolve_used_border_width(computed &css.ComputedValues, width_property css.PropertyID) f64 {
	return computed.border_data(width_property).width.to_double()
}

// Resolve the used margin/border/padding edges from `computed` into `used_values`. `containing_block_width`
// is the percentage basis. `auto` margins resolve to 0 here (compute_block_used_width may reassign them).
fn resolve_box_model_edges_by_property(computed &css.ComputedValues, mut used_values UsedValues, containing_block_width f64) {
	used_values.padding_left = css_px(computed.length_percentage_to_px(.padding_left, containing_block_width) or { 0.0 })
	used_values.padding_right = css_px(computed.length_percentage_to_px(.padding_right, containing_block_width) or { 0.0 })
	used_values.padding_top = css_px(computed.length_percentage_to_px(.padding_top, containing_block_width) or { 0.0 })
	used_values.padding_bottom = css_px(computed.length_percentage_to_px(.padding_bottom, containing_block_width) or { 0.0 })

	// CSS 2.1 §8.5.3: the used border width is 0 when the border style is none or hidden.
	used_values.border_left = css_px(resolve_used_border_width(computed, .border_left_width))
	used_values.border_right = css_px(resolve_used_border_width(computed, .border_right_width))
	used_values.border_top = css_px(resolve_used_border_width(computed, .border_top_width))
	used_values.border_bottom = css_px(resolve_used_border_width(computed, .border_bottom_width))

	// auto margins resolve to 0 for now (width computation reassigns them for centering).
	used_values.margin_left = css_px(computed.length_percentage_to_px(.margin_left, containing_block_width) or { 0.0 })
	used_values.margin_right = css_px(computed.length_percentage_to_px(.margin_right, containing_block_width) or { 0.0 })
	used_values.margin_top = css_px(computed.length_percentage_to_px(.margin_top, containing_block_width) or { 0.0 })
	used_values.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom, containing_block_width) or { 0.0 })
}

// CSS 2.1 §10.3.3: compute the used content width (and resolve auto margins) of a normal-flow block-level
// box, given its containing block's width. Assumes resolve_box_model_edges already ran.
fn compute_block_used_width(computed &css.ComputedValues, mut used_values UsedValues, containing_block_width f64) {
	compute_block_used_width_with_override(computed, mut used_values, containing_block_width, none)
}

fn compute_block_used_width_with_override(computed &css.ComputedValues, mut used_values UsedValues, containing_block_width f64, intrinsic_width ?CSSPixels) {
	// Non-content horizontal edges (border + padding).
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() + used_values.padding_right.to_double() + used_values.border_right.to_double()

	width_is_auto := property_is_auto(computed, .width) && intrinsic_width == none
	margin_left_auto := property_is_auto(computed, .margin_left)
	margin_right_auto := property_is_auto(computed, .margin_right)

	// §10.3.3 tentative content width.
	mut width := 0.0
	if width_is_auto {
		// auto width fills the containing block; auto margins are treated as 0.
		margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
		margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
		width = containing_block_width - margin_left - margin_right - edges
		if width < 0.0 {
			width = 0.0
		}
		if margin_left_auto {
			used_values.margin_left = css_px(0.0)
		}
		if margin_right_auto {
			used_values.margin_right = css_px(0.0)
		}
	} else {
		width = if resolved_intrinsic := intrinsic_width {
			resolved_intrinsic.to_double()
		} else {
			computed.length_percentage_to_px(.width, containing_block_width) or { 0.0 }
		}
		// Intrinsic sizing algorithms return a content-box size already. Only a
		// specified width still needs the border-box adjustment here.
		if intrinsic_width == none && computed.box_sizing() == .border_box {
			width -= edges
			if width < 0 {
				width = 0
			}
		}
	}

	// §10.4: clamp to [min-width, max-width].
	clamped := clamp_box_content_to_min_max(computed, .min_width, .max_width, width, containing_block_width, edges)
	used_values.set_content_width(css_px(clamped))

	// Resolve auto margins against the used (now definite) width — for an explicit width, or an auto width
	// that clamping shrank below the fill.
	if !width_is_auto || clamped != width {
		resolve_auto_margins(computed, mut used_values, containing_block_width, clamped)
	}
}

fn compute_block_used_width_for_node(mut state LayoutState, box &NodeWithStyle, mut used_values UsedValues, available_width AvailableSize) {
	box_node := unsafe { &Node(box) }
	box_as_box := box_node.as_box() or {
		compute_block_used_width(box.computed_values(), mut used_values, available_width.to_px_or_zero().to_double())
		return
	}
	computed_width := box.computed_values().size_value(.width)
	mut intrinsic_width := ?CSSPixels(none)
	// HTML button layout: an auto inline size is fit-content instead of the
	// normal fill-available size of a block-level box.
	if computed_width.is_auto() && box.computed_values().writing_mode() != .horizontal_tb {
		// A vertical flow's automatic block size is content based. The
		// horizontal block width equation would stretch it across the viewport.
		intrinsic_width = calculate_max_content_width(mut state,box_as_box)
	} else if computed_width.is_auto() && node_uses_button_layout(box_node) {
		intrinsic_width = calculate_fit_content_width(mut state, box_as_box, available_width)
	} else if computed_width.is_auto() && box_as_box.has_auto_content_box_size() {
		if auto_width := box_as_box.auto_content_box_size().width {
			intrinsic_width = auto_width
		}
	} else if computed_width.is_min_content() {
		intrinsic_width = calculate_min_content_width(mut state, box_as_box)
	} else if computed_width.is_max_content() {
		intrinsic_width = calculate_max_content_width(mut state, box_as_box)
	} else if computed_width.is_fit_content() {
		intrinsic_width = calculate_fit_content_width(mut state, box_as_box, available_width)
	}
	compute_block_used_width_with_override(box.computed_values(), mut used_values, available_width.to_px_or_zero().to_double(), intrinsic_width)

	// calculate_inner_width() also accepts intrinsic sizing keywords for the
	// min/max constraints. Length-percentage constraints were applied by the
	// CSS 2.1 width equation above; apply keyword constraints in max-then-min
	// order, matching FormattingContext::compute_width().
	mut clamped := used_values.content_width()
	max_size := box.computed_values().size_value(.max_width)
	if max_size.is_intrinsic_sizing_constraint() {
		maximum := intrinsic_width_for_size(mut state, box_as_box, max_size, available_width)
		clamped = css_pixels_min(clamped, maximum)
	}
	min_size := box.computed_values().size_value(.min_width)
	if min_size.is_intrinsic_sizing_constraint() {
		minimum := intrinsic_width_for_size(mut state, box_as_box, min_size, available_width)
		clamped = css_pixels_max(clamped, minimum)
	}
	if clamped.raw_value() != used_values.content_width().raw_value() {
		used_values.set_content_width(clamped)
		resolve_auto_margins(box.computed_values(), mut used_values, available_width.to_px_or_zero().to_double(), clamped.to_double())
	}
}

fn intrinsic_width_for_size(mut state LayoutState, box &Box, size css.Size, available_width AvailableSize) CSSPixels {
	if size.is_min_content() {
		return calculate_min_content_width(mut state, box)
	}
	if size.is_max_content() {
		return calculate_max_content_width(mut state, box)
	}
	if size.is_fit_content() {
		return calculate_fit_content_width(mut state, box, available_width)
	}
	return CSSPixels.new(0)
}

fn clamp_box_content_to_min_max(computed &css.ComputedValues, min_property css.PropertyID, max_property css.PropertyID, value f64, percentage_basis f64, border_padding_edges f64) f64 {
	adjustment := if computed.box_sizing() == .border_box { border_padding_edges } else { 0.0 }
	mut result := value
	if specified_max := computed.length_percentage_to_px(max_property, percentage_basis) {
		max := if specified_max > adjustment { specified_max - adjustment } else { 0.0 }
		if result > max {
			result = max
		}
	}
	specified_min := computed.length_percentage_to_px(min_property, percentage_basis) or { 0.0 }
	min := if specified_min > adjustment { specified_min - adjustment } else { 0.0 }
	if result < min {
		result = min
	}
	return result
}

fn content_height_for_box_sizing(computed &css.ComputedValues, used_values &UsedValues, specified_height f64) f64 {
	if computed.box_sizing() != .border_box {
		return specified_height
	}
	edges := used_values.border_top.to_double() + used_values.padding_top.to_double() + used_values.padding_bottom.to_double() + used_values.border_bottom.to_double()
	return if specified_height > edges { specified_height - edges } else { 0.0 }
}

// Resolve auto left/right margins to absorb the remaining inline space (centering when both are auto),
// given a definite content `width` (CSS 2.1 §10.3.3).
fn resolve_auto_margins(computed &css.ComputedValues, mut used_values UsedValues, containing_block_width f64, width f64) {
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() + used_values.padding_right.to_double() + used_values.border_right.to_double()
	mut margin_left_auto := property_is_auto(computed, .margin_left)
	mut margin_right_auto := property_is_auto(computed, .margin_right)
	fixed_margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
	fixed_margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
	mut remaining := containing_block_width - width - edges - fixed_margin_left - fixed_margin_right

	// CSS 2.1 10.3.3: when a definite width plus the non-auto box edges is
	// already wider than the containing block, auto inline margins are treated
	// as zero before the width equation is solved. They therefore do not split a
	// negative remainder; the over-constrained end margin absorbs it below.
	if width + edges + fixed_margin_left + fixed_margin_right > containing_block_width {
		if margin_left_auto {
			used_values.margin_left = css_px(0)
			margin_left_auto = false
		}
		if margin_right_auto {
			used_values.margin_right = css_px(0)
			margin_right_auto = false
		}
		remaining = containing_block_width - width - edges - fixed_margin_left - fixed_margin_right
	}

	if margin_left_auto && margin_right_auto {
		half := remaining / 2.0
		used_values.margin_left = css_px(half)
		used_values.margin_right = css_px(half)
	} else if margin_left_auto {
		used_values.margin_left = css_px(remaining)
	} else if margin_right_auto {
		used_values.margin_right = css_px(remaining)
	} else {
		// Rust/layout/block_formatting_context.rs: compute_inline_size's
		// equation uses the containing block's direction, including when an
		// oversized definite width has turned auto margins into zero.
		containing_direction := if container := used_values.containing_block_used_values() {
			container.node().computed_values().direction()
		} else { css.Direction.ltr }
		if containing_direction == .rtl {
			used_values.margin_left = css_px(fixed_margin_left + remaining)
		} else {
			used_values.margin_right = css_px(fixed_margin_right + remaining)
		}
	}
}

// Lay out `box` as a block formatting context root (BlockFormattingContext::run for a normal block
// container), writing geometry into `state`: resolve the box's width, lay out its block-level descendants in
// normal flow (its BFC), then compute the box's height. `containing_block_width` is the content width of the
// box's containing block. As a BFC root, the box's own margins do not collapse with its children (CSS 2.1
// §8.3.1); child stacking and margin collapsing happen inside the context (layout_block_level_box). Used as
// a standalone entry point (e.g. by tests); the document path goes through layout_viewport.
//
// The document path enters through layout_viewport; this standalone helper is
// retained for direct algorithm tests.
pub fn layout_block_flow(mut state LayoutState, box &NodeWithStyle, containing_block_width f64, containing_block_height ?f64) {
	// This is a port-only standalone entry point. The document path assigns
	// indices after tree construction, just like DOM::Document::update_layout.
	assign_layout_indexes(unsafe { &Node(box) })
	computed := box.computed_values()
	mut used_values := state.get_mutable(box)
	resolve_box_model_edges(computed, mut used_values, containing_block_width)
	compute_block_used_width_for_node(mut state, box, mut used_values, AvailableSize.make_definite(css_px(containing_block_width)))
	content_width := used_values.content_width().to_double()

	// This box's definite content height, if any (an explicit length, or a percentage resolved against the
	// containing block's definite height). Children resolve their own percentage heights against it.
	definite_content_height := resolve_content_height_for_node(mut state, box, used_values, containing_block_height)
	height_establishes_definite_containing_block := definite_content_height != none
		&& computed_height_establishes_definite_containing_block_height(computed.size_value(.height))
	children_containing_block_height := if height_establishes_definite_containing_block {
		definite_content_height
	} else {
		none
	}

	box_as_node := unsafe { &Node(box) }

	// DOM-built trees already contain the anonymous blocks required to separate
	// mixed block and inline content. Direct synthetic trees use the node's
	// children_are_inline classification.
	mut content_height_from_children := 0.0
	if box_has_inline_content(box_as_node) {
		if block_container := box_as_node.as_block_container() {
		available_height := if resolved_height := children_containing_block_height {
				AvailableSize.make_definite(css_px(resolved_height))
			} else {
				AvailableSize.make_indefinite()
			}
			mut inline_context := BlockFormattingContext.for_root(box_as_node, .normal, has_definite_inline_size(box_as_node,used_values))
			inline_result := inline_context.run_inline_formatting_context_with_floats(mut state, block_container, mut used_values, .normal, AvailableSpace.new(AvailableSize.make_definite(css_px(content_width)), available_height))
			_ = inline_result
			content_height_from_children = if used_values.line_boxes.len > 0 {
				physical_height_of_inline_lines(used_values.line_boxes,box.computed_values().writing_mode()).to_double()
			} else {
				0.0
			}
		} else {
			content_height_from_children = computed_line_height_px(computed)
		}
	} else {
		// Block formatting context: lay out the block children, collapsing adjacent-sibling and parent-child
		// vertical margins (CSS 2.1 §8.3.1). `box` is treated as the BFC root, whose own margins (per §8.3.1)
		// do not collapse with its children — that is handled per-child inside the context.
		mut block_formatting_context := BlockFormattingContext.for_root(box_as_node, .normal, has_definite_inline_size(box_as_node,used_values))
		content_height_from_children = block_formatting_context.layout_block_level_children(mut state,
			box, content_width, children_containing_block_height)
	}

	// Height (CSS 2.1 §10.6): use the definite height if the box has one, else the content height from
	// its children (auto).
	mut height := definite_content_height or { content_height_from_children }
	// §10.7: clamp to [min-height, max-height] (a percentage min/max against the containing block height).
	height = clamp_content_height_for_node(mut state, box, used_values, css_px(height), containing_block_height).to_double()
	used_values.set_content_height(css_px(height))
	// Like BlockFormattingContext::resolve_used_height_if_not_treated_as_auto,
	// definiteness is established by resolving the computed height, not by the
	// generic UsedValues setter. An auto height remains indefinite.
	if height_establishes_definite_containing_block {
		used_values.set_has_definite_height(true)
	}
}

// This box's definite content height, or none if it's auto (or a percentage against an indefinite
// containing-block height). CSS 2.1 §10.5: a percentage height resolves against the containing block's
// height only when that height is itself definite; otherwise the height is treated as auto.
fn resolve_definite_content_height(computed &css.ComputedValues, containing_block_height ?f64) ?f64 {
	if property_is_auto(computed, .height) {
		return none
	}
	if property_is_percentage(computed, .height) {
		basis := containing_block_height or { return none }
		return computed.length_percentage_to_px(.height, basis)
	}
	return computed.length_percentage_to_px(.height, 0.0)
}

// Whether `property_id`'s computed value is a percentage.
fn property_is_percentage(computed &css.ComputedValues, property_id css.PropertyID) bool {
	value := computed.property(property_id, .yes) or { return false }
	return value.css_text.trim_space().ends_with('%')
}

// Whether `box_node` has inline-level (text) content that establishes an inline formatting context.
fn box_has_inline_content(box_node &Node) bool {
	return box_node.children_are_inline()
}

fn computed_line_height_px(computed &css.ComputedValues) f64 {
	return computed.line_height().to_double()
}

// FormattingContext::layout_inside() for boxes which establish an independent
// formatting context. The concrete context is selected from the box's inner
// display type, exactly once, and returns its automatic content dimensions to
// the parent context.
fn layout_inside_independent_formatting_context(mut state LayoutState, box &Node, mut box_state UsedValues, available_space AvailableSpace) FormattingContextResult {
	return layout_inside_independent_formatting_context_with_mode(mut state, box, mut box_state, .normal, available_space)
}

// FormattingContext::layout_inside() carries the parent's layout mode into
// every nested independent context. In intrinsic mode this is observable for
// flex/grid containers: they compute their intrinsic size without performing
// the final normal-layout pass over their items.
fn layout_inside_independent_formatting_context_with_mode(mut state LayoutState, box &Node, mut box_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	mut result := layout_inside_independent_formatting_context_without_containment_override(mut state, box, mut box_state, layout_mode, available_space)
	if box.has_size_containment() {
		// Every formatting context reports the sizes produced by its contents
		// through this result. Replace both physical axes at that shared boundary.
		result = FormattingContextResult{
			automatic_content_width: box.explicit_intrinsic_inner_width() or { CSSPixels.new(0) }
			automatic_content_height: box.explicit_intrinsic_inner_height() or { CSSPixels.new(0) }
		}
	}
	return result
}

// Horizontal line boxes stack in y; vertical lines share the inline y axis.
// Their last line can be shorter than an earlier one.
fn physical_height_of_inline_lines(lines []LineBox, writing_mode css.WritingMode) CSSPixels {
 if lines.len == 0 { return CSSPixels.new(0) }
 if writing_mode == .horizontal_tb { return lines.last().bottom() }
 mut height := CSSPixels.new(0)
 for line in lines { height = css_pixels_max(height,line.height()) }
 return height
}

fn layout_inside_independent_formatting_context_without_containment_override(mut state LayoutState, box &Node, mut box_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	return run_retaining_independent_formatting_context(mut state, box, mut box_state, layout_mode, available_space)
}

fn layout_uncached_independent_formatting_context(mut state LayoutState, box &Node, mut box_state UsedValues, layout_mode LayoutMode, available_space AvailableSpace) FormattingContextResult {
	platform.cooperative_work_checkpoint()
	if box.is_svg_svg_box() {
		return run_root_svg_formatting_context(mut state, box, mut box_state, available_space)
	}
	if box.is_fieldset_box() {
		return run_fieldset_formatting_context(mut state, unsafe { &FieldSetBox(box) }, mut box_state, available_space)
	}
	if box.display().is_flex_inside() {
		return run_flex_formatting_context_with_mode(mut state, box, mut box_state, layout_mode, available_space)
	}
	if box.display().is_grid_inside() {
		return run_grid_formatting_context(mut state, box, mut box_state, layout_mode, available_space)
	}
	if box.display().is_table_inside() {
		return run_table_formatting_context(mut state, box, mut box_state, available_space)
	}
	if box.is_replaced_box_with_children() {
		return run_replaced_with_children_formatting_context(mut state, box, mut box_state, available_space)
	}
	if column_count := determine_used_multicol_column_count(box, box_state.content_width()) {
		// Upstream currently computes these used values before normal block/inline
		// layout; column fragmentation is not performed by that pass yet.
		_ = determine_used_multicol_column_width(box, box_state.content_width(), column_count)
	}
	if box_has_inline_content(box) {
		if block_container := box.as_block_container() {
			mut inline_block_context := BlockFormattingContext.for_root(box, layout_mode, has_definite_inline_size(box,box_state))
			inline_block_context.layout_marker_of_list_item_root(mut state, box, mut box_state)
			// A multi-column container lays its lines out at the column width.
			multicol := multicol_columns_for_content(box, box_state, layout_mode)
			container_width := box_state.content_width()
			mut inline_available_space := available_space
			if columns := multicol {
				box_state.set_content_width(columns.width)
				inline_available_space = AvailableSpace.new(AvailableSize.make_definite(columns.width),
					available_space.height)
			}
			inline_result := inline_block_context.run_inline_formatting_context_with_floats(mut state, block_container, mut box_state, layout_mode, inline_available_space)
			mut column_block_size := ?CSSPixels(none)
			if columns := multicol {
				box_state.set_content_width(container_width)
				if inline_block_context.floating_boxes.len == 0 {
					column_block_size = distribute_lines_into_columns(mut state, box, mut box_state,
						columns, container_width)
				}
			}
			mut automatic_height := if block_size := column_block_size {
				block_size
			} else if box_state.line_boxes.len > 0 {
				physical_height_of_inline_lines(box_state.line_boxes,box.computed_values().writing_mode())
			} else {
				CSSPixels.new(0)
			}
			if box_state.line_boxes.len > 0 {
				last_line := unsafe { &box_state.line_boxes[box_state.line_boxes.len - 1] }
				if last_line.has_block_level_box() {
					automatic_height = automatic_height.plus(last_line.block_level_box_bottom_margin())
				}
			}
			root_origin_y := box_state.cumulative_offset().y()
			for floating in inline_block_context.floating_boxes {
				automatic_height = css_pixels_max(automatic_height, floating.bottom.minus(root_origin_y))
			}
			place_list_item_marker_at_first_baseline(mut state, box)
			return FormattingContextResult{
				automatic_content_width: inline_result.automatic_content_width
				automatic_content_height: floor_list_item_automatic_height_by_marker_line_height(box,
					automatic_height)
			}
		}
	}
	if multicol := layout_multicol_atomic_blocks(mut state, box, mut box_state, layout_mode,
		available_space) {
		return multicol
	}
	styled := box.as_node_with_style() or { return FormattingContextResult{} }
	mut child_context := BlockFormattingContext.for_root(box, layout_mode, has_definite_inline_size(box,box_state))
	child_context.layout_marker_of_list_item_root(mut state, box, mut box_state)
	mut child_containing_block_height := ?f64(none)
	if (box_state.has_definite_height() || box.is_button_content_box_)
		&& available_space.height.is_definite() {
		child_containing_block_height = available_space.height.to_px_or_zero().to_double()
	}
	child_context.layout_block_level_children(mut state, styled, box_state.content_width().to_double(), child_containing_block_height)
	child_context.record_trailing_collapsed_margin(state, box)
	// FormattingContext::compute_auto_height_for_block_formatting_context_root.
	// A run's trailing collapsed margin replaces the last real child's own
	// bottom margin for this calculation without mutating that child.
	mut height := CSSPixels.new(0)
	mut automatic_height_children := box.children()
	if box.is_table_wrapper() {
		mut wrapper_flow_children := []&Node{}
		for table in box.children() {
			if !table.display().is_table_inside() {
				continue
			}
			for caption in table.children() {
				if caption.display().is_table_caption() && !caption.is_absolutely_positioned()
					&& caption.computed_values().caption_side() == .top {
					wrapper_flow_children << caption
				}
			}
			wrapper_flow_children << table
			for caption in table.children() {
				if caption.display().is_table_caption() && !caption.is_absolutely_positioned()
					&& caption.computed_values().caption_side() == .bottom {
					wrapper_flow_children << caption
				}
			}
		}
		automatic_height_children = wrapper_flow_children.clone()
	}
	mut has_collapsing_child := false
	mut has_non_collapsing_child := false
	for child in automatic_height_children {
		if child.is_absolutely_positioned() {
			continue
		}
		if styled.computed_values().overflow_y() == .visible && child.is_floating() {
			continue
		}
		child_styled := child.as_node_with_style() or { continue }
		child_state := state.get(child_styled)
		if child_state.is_invisible_for_line_clamp() {
			continue
		}
		// An empty block's adjoining margins already belong to the run's
		// collapsed aggregate. Its placed offset includes that margin, so
		// adding its bottom margin again would count the same gap twice.
		if !child.is_floating() && margins_collapse_through(child_styled, state) {
			has_collapsing_child = true
			continue
		}
		has_non_collapsing_child = true
		mut margin_bottom := child_state.margin_bottom
		if trailing := child_context.trailing_collapsed_margin {
			if layout_nodes_same(trailing.child, child) {
				margin_bottom = trailing.margin
			}
		}
		child_bottom := child_state.offset.y().plus(child_state.content_height()).plus(child_state.border_box_bottom()).plus(margin_bottom)
		height = css_pixels_max(height, child_bottom)
	}
	if has_collapsing_child && !has_non_collapsing_child {
		// With no real in-flow box, there is no child on which to retain the
		// aggregate. Margins still cannot escape this formatting context.
		height = css_pixels_max(height, css_px(child_context.margin_state.current_collapsed_margin()))
	}
	// Include every floating descendant whose bottom margin edge extends below
	// the in-flow content bottom. Float records are in root coordinates.
	root_origin_y := box_state.cumulative_offset().y()
	for floating in child_context.floating_boxes {
		local_bottom := floating.bottom.minus(root_origin_y)
		height = css_pixels_max(height, local_bottom)
	}
	place_list_item_marker_at_first_baseline(mut state, box)
	return FormattingContextResult{
		automatic_content_width: box_state.content_width()
		automatic_content_height: floor_list_item_automatic_height_by_marker_line_height(box, height)
	}
}

// Lay out the Viewport — the layout tree's root and the initial containing block. Its content box is pinned
// to the viewport rectangle (definite width AND height); then its child (the root element box) is laid out
// within a fresh block formatting context. Faithful to Document::update_layout's root-formatting-context
// setup (Document.cpp) + BlockFormattingContext::layout_viewport: the viewport state's content size is set
// to the viewport rect, so the ICB (document element) fills the viewport width and root-level percentage
// heights resolve against the definite viewport height. Unlike a normal block, the viewport's own dimensions
// are NOT computed from its style — they are the viewport rect.
pub fn layout_viewport(mut state LayoutState, viewport &Viewport, viewport_width f64, viewport_height f64) {
	load_instruction_stage := processmetrics.begin_instruction_stage('flow_layout')
	defer { load_instruction_stage.finish() }
	state.prepare_intrinsic_seed_visits(unsafe { &Node(viewport) })
	viewport_node_with_style := unsafe { &NodeWithStyle(viewport) }
	mut viewport_used_values := state.get_mutable(viewport_node_with_style)
	viewport_used_values.set_content_width(css_px(viewport_width))
	viewport_used_values.set_content_height(css_px(viewport_height))
	viewport_used_values.set_has_definite_height(true)

	// BlockFormattingContext::layout_viewport gives a standalone SVG document
	// special treatment.  The root SVG's missing dimensions are supplied by the
	// viewport and its SVG formatting context is entered directly; it does not
	// participate in the normal block width equation (and therefore does not get
	// a synthetic trailing margin for the unused viewport width).
	if svg_root := unsafe { &Node(viewport) }.first_child() {
		if svg_root.is_svg_svg_box() {
			if svg_styled := svg_root.as_node_with_style() {
				mut svg_state := state.get_mutable(svg_styled)
				natural_size := svg_root.as_box() or { return }.natural_size()
				is_svg_image_document := svg_root.document().is_svg_image_document()
				if is_svg_image_document {
					svg_state.set_content_width(css_px(viewport_width))
				} else if natural_width := natural_size.width {
					svg_state.set_content_width(natural_width)
				} else if !svg_state.has_definite_width()
					|| svg_styled.computed_values().size_value(.width).is_auto() {
					svg_state.set_content_width(css_px(viewport_width))
				}
				if is_svg_image_document {
					svg_state.set_content_height(css_px(viewport_height))
					svg_state.set_has_definite_height(true)
				} else if natural_height := natural_size.height {
					svg_state.set_content_height(natural_height)
					svg_state.set_has_definite_height(true)
				} else if !svg_state.has_definite_height() {
					svg_state.set_content_height(css_px(viewport_height))
					svg_state.set_has_definite_height(true)
				}
				run_root_svg_formatting_context(mut state, svg_root, mut svg_state, AvailableSpace.new(AvailableSize.make_definite(css_px(viewport_width)), AvailableSize.make_definite(css_px(viewport_height))))
				return
			}
		}
	}

	mut block_formatting_context := BlockFormattingContext.for_root(unsafe { &Node(viewport) }, .normal, true)
	block_formatting_context.layout_block_level_children(mut state, viewport_node_with_style, viewport_width, viewport_height)
}
