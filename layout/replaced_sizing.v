// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// The percentage basis and used padding that `box-sizing: border-box` is
// resolved against. FormattingContext::calculate_inner_width() reads the *used*
// inline padding out of LayoutState rather than recomputing it, so a caller that
// has not assigned that padding yet (see
// BlockFormattingContext::compute_width_for_block_level_replaced_element_in_normal_flow())
// resolves the inline axis against zero padding.
struct ReplacedBoxModel {
	percentage_basis    CSSPixels
	used_inline_padding ?CSSPixels
}

// CSS 2.2 10.3.2 and 10.6.2 replaced-element tentative sizing. This is shared
// by inline, block, flex/grid item, and absolutely-positioned layout paths.
fn compute_replaced_size(box &Box, available_space AvailableSpace) CSSPixelSize {
	return compute_replaced_size_with_box_model(box, available_space, ReplacedBoxModel{
		percentage_basis: available_space.width.to_px_or_zero()
	})
}

fn chromium_auto_svg_transfers_block_size(node &Node) bool {
	if (!node.is_svg_svg_box() && !node.is_image_box())
		|| node.document().font_rendering_policy() != .chromium
		|| node.document().is_svg_image_document() { return false }
	computed := node.computed_values()
	// A ratio-only SVG image also transfers its quantized used height. An
	// unresolved percentage height takes the automatic-height branch below,
	// but remains the input to Blink's subsequent automatic-width calculation.
	height := computed.size_value(.height)
	if !computed.size_value(.width).is_auto()
		|| (!height.is_auto() && !(node.is_image_box() && height.contains_percentage())) {
		return false
	}
	box := node.as_box() or { return false }
	intrinsic := box.auto_content_box_size()
	return intrinsic.width == none && intrinsic.height == none
		&& box.preferred_aspect_ratio() != none
}

fn compute_replaced_size_with_box_model(box &Box, available_space AvailableSpace, box_model ReplacedBoxModel) CSSPixelSize {
	node := unsafe { &Node(box) }
	computed := node.computed_values()
	width_basis := available_space.width.to_px_or_zero()
	height_basis := available_space.height.to_px_or_zero()
	computed_width := computed.size_value(.width)
	computed_height := computed.size_value(.height)
	mut specified_width := resolve_replaced_content_size(node, computed_width, width_basis, box_model, true)
	mut specified_height := resolve_replaced_content_size(node, computed_height, height_basis, box_model, false)
	if computed_width.contains_percentage() && !available_space.width.is_definite() {
		// CSS Sizing's replaced percentage min-contribution resolves a cyclic
		// percentage preferred width against zero. Under max-content or a plain
		// indefinite constraint it behaves as auto instead.
		specified_width = if available_space.width.is_min_content() {
			resolve_replaced_content_size(node, computed_width, CSSPixels.new(0), ReplacedBoxModel{
				percentage_basis: CSSPixels.new(0)
				used_inline_padding: box_model.used_inline_padding
			}, true)
		} else {
			none
		}
	}
	if computed_height.contains_percentage() && !available_space.height.is_definite() {
		specified_height = none
	}
	intrinsic := box.auto_content_box_size()
	ratio := box.preferred_aspect_ratio()

	mut width := CSSPixels.new(0)
	mut height := CSSPixels.new(0)
	if specified := specified_width {
		width = specified
		if specified_block := specified_height {
			height = specified_block
		} else if intrinsic_ratio := ratio {
			height = width.divided_by_fraction(intrinsic_ratio)
		} else if intrinsic_height := intrinsic.height {
			height = intrinsic_height
		} else {
			height = CSSPixels.nearest_value_for(150 * node.document().layout_coordinate_scale())
		}
	} else if specified_block := specified_height {
		// tentative_width_for_replaced_element() transfers the *used* height,
		// and compute_height_for_replaced_element() has already applied its
		// max-height and min-height steps by then.
		height = apply_replaced_axis_constraints(node, computed.size_value(.min_height),
			computed.size_value(.max_height), specified_block, available_space.height,
			box_model, false)
		if intrinsic_ratio := ratio {
			width = height.times_fraction(intrinsic_ratio)
		} else if intrinsic_width := intrinsic.width {
			width = intrinsic_width
		} else {
			width = CSSPixels.nearest_value_for(300 * node.document().layout_coordinate_scale())
		}
	} else if intrinsic_width := intrinsic.width {
		width = intrinsic_width
		if intrinsic_height := intrinsic.height {
			height = intrinsic_height
		} else if intrinsic_ratio := ratio {
			height = width.divided_by_fraction(intrinsic_ratio)
		} else {
			height = CSSPixels.nearest_value_for(150 * node.document().layout_coordinate_scale())
		}
	} else if intrinsic_height := intrinsic.height {
		height = intrinsic_height
		if intrinsic_ratio := ratio {
			width = height.times_fraction(intrinsic_ratio)
		} else {
			width = CSSPixels.nearest_value_for(300 * node.document().layout_coordinate_scale())
		}
	} else if intrinsic_ratio := ratio {
		width = if available_space.width.is_definite() {
			available_space.width.to_px_or_zero()
		} else if computed_width.contains_percentage()
			&& available_space.width.is_max_content() {
			// A cyclic percentage preferred size is treated as its initial
			// value during max-content measurement. For a replaced element
			// with only a natural ratio, that falls through to the 300px
			// default instead of stretch-fitting against a zero constraint.
			CSSPixels.nearest_value_for(300 * node.document().layout_coordinate_scale())
		} else {
			// CSS 2.2 leaves this width undefined and suggests the normal-flow
			// constraint equation when the containing block does not depend on
			// the replaced element. An intrinsic sizing constraint therefore has
			// a zero stretch-fit width; min-width may subsequently enlarge it.
			CSSPixels.new(0)
		}
		height = width.divided_by_fraction(intrinsic_ratio)
		// Upstream computes used width before used height. Preserve that order:
		// a width constraint applied to a ratio-only replaced element becomes
		// the basis for its tentative auto height.
		if !available_space.width.is_definite() {
			width = solve_replaced_size_constraint(box, width, height, intrinsic_ratio, available_space, box_model).width()
			height = width.divided_by_fraction(intrinsic_ratio)
		}
	} else {
		width = CSSPixels.nearest_value_for(300 * node.document().layout_coordinate_scale())
		height = CSSPixels.nearest_value_for(150 * node.document().layout_coordinate_scale())
	}
	// FormattingContext::compute_width_for_replaced_element() and
	// compute_height_for_replaced_element() run the constraint-violation table
	// only when both axes are automatic. With one axis specified each axis is
	// clamped on its own through tentative_width_for_replaced_element() /
	// tentative_height_for_replaced_element(), which is what clamp_replaced_axis()
	// reproduces: the constraint passes through the same box-sizing conversion as
	// the preferred size.
	if intrinsic_ratio := ratio {
		if specified_width == none && specified_height == none {
			solved := solve_replaced_size_constraint(box, width, height, intrinsic_ratio, available_space, box_model)
			width = solved.width()
			height = solved.height()
		}
	}
	width = apply_replaced_axis_constraints(node, computed.size_value(.min_width), computed.size_value(.max_width),
		width, available_space.width, box_model, true)
	// CSS 2.2 10.6.2 transfers the used width into an automatic height.
	// A specified width can still be changed by min/max-width; deriving the
	// height before that clamp leaves responsive images at their old height.
	// Definite heights and the both-auto constraint table retain their own
	// independent block-axis constraints.
	if specified_width != none && specified_height == none {
		if intrinsic_ratio := ratio {
			height = width.divided_by_fraction(intrinsic_ratio)
		}
	}
	constraint_rerun_uses_intrinsic_height := specified_width == none
		&& specified_height == none && ratio == none && intrinsic.height != none
	constraint_rerun_intrinsic_height := intrinsic.height or { CSSPixels.new(0) }
	height = apply_replaced_block_axis_constraints(node, computed.size_value(.min_height),
		computed.size_value(.max_height), height, available_space.height, box_model,
		constraint_rerun_uses_intrinsic_height, constraint_rerun_intrinsic_height)
	// Blink transfers an automatically sized ratio-only SVG's used block size back
	// through its natural ratio. The block size has already been quantized to
	// LayoutUnit: a 20px-wide 448:512 icon becomes 22.84375px high and then
	// 19.984375px wide. Keep authored widths and SVG-image viewports independent.
	if chromium_auto_svg_transfers_block_size(node) {
		if natural_ratio := ratio {
			width = apply_replaced_axis_constraints(node, computed.size_value(.min_width),
				computed.size_value(.max_width), height.times_fraction(natural_ratio),
				available_space.width, box_model, true)
		}
	}
	return CSSPixelSize.new(width, height)
}

fn replaced_box_sizing_edges(node &Node, box_model ReplacedBoxModel, width bool) CSSPixels {
	computed := node.computed_values()
	if computed.box_sizing() != .border_box {
		return CSSPixels.new(0)
	}
	basis := box_model.percentage_basis.to_double()
	if width {
		borders := resolve_used_border_width(computed, .border_left_width) +
			resolve_used_border_width(computed, .border_right_width)
		if used_padding := box_model.used_inline_padding {
			return css_px(borders).plus(used_padding)
		}
		return css_px(borders + (computed.length_percentage_to_px(.padding_left, basis) or {
			0.0
		}) + (computed.length_percentage_to_px(.padding_right, basis) or { 0.0 }))
	}
	return css_px(resolve_used_border_width(computed, .border_top_width) + (computed.length_percentage_to_px(.padding_top, basis) or {
		0.0
	}) + (computed.length_percentage_to_px(.padding_bottom, basis) or { 0.0 }) + resolve_used_border_width(computed, .border_bottom_width))
}

fn resolve_replaced_content_size(node &Node, size css.Size, size_basis CSSPixels, box_model ReplacedBoxModel, width bool) ?CSSPixels {
	resolved := resolve_layout_size(node, size, size_basis) or { return none }
	return css_pixels_max(CSSPixels.new(0), resolved.minus(replaced_box_sizing_edges(node, box_model, width)))
}

fn should_treat_replaced_max_as_none(maximum css.Size, available_size AvailableSize) bool {
	if maximum.is_none() {
		return true
	}
	// CSS Sizing's cyclic-percentage rule keeps a replaced percentage maximum
	// for min-content measurement (where it resolves against zero), but ignores
	// it for max-content or otherwise indefinite available space.
	if maximum.contains_percentage() && !available_size.is_definite()
		&& !available_size.is_min_content() {
		return true
	}
	if maximum.is_fit_content() && available_size.is_intrinsic_sizing_constraint() {
		return true
	}
	if maximum.is_max_content() && available_size.is_max_content() {
		return true
	}
	if maximum.is_min_content() && available_size.is_min_content() {
		return true
	}
	return false
}

fn replaced_axis_constraints(node &Node, minimum css.Size, maximum css.Size, input CSSPixels, available_size AvailableSize, box_model ReplacedBoxModel, width bool) (CSSPixels, CSSPixels) {
	basis := available_size.to_px_or_zero()
	min_value := resolve_replaced_content_size(node, minimum, basis, box_model, width) or {
		CSSPixels.new(0)
	}
	specified_max := if should_treat_replaced_max_as_none(maximum, available_size) {
		input
	} else {
		resolve_replaced_content_size(node, maximum, basis, box_model, width) or { input }
	}
	return min_value, css_pixels_max(min_value, specified_max)
}

fn clamp_replaced_axis(node &Node, minimum css.Size, maximum css.Size, input CSSPixels, available_size AvailableSize, box_model ReplacedBoxModel, width bool) CSSPixels {
	min_value, max_value := replaced_axis_constraints(node, minimum, maximum, input, available_size, box_model, width)
	return css_pixels_max(min_value, css_pixels_min(input, max_value))
}

// Steps 2 and 3 of FormattingContext::compute_width_for_replaced_element() and
// compute_height_for_replaced_element(). Both the comparison and the replacement
// size use calculate_inner_width()/calculate_inner_height(), represented by the
// shared content-box constraint resolver here.
fn apply_replaced_axis_constraints(node &Node, minimum css.Size, maximum css.Size, input CSSPixels, available_size AvailableSize, box_model ReplacedBoxModel, width bool) CSSPixels {
	return clamp_replaced_axis(node, minimum, maximum, input, available_size, box_model, width)
}

// tentative_block_size_for_replaced_element() checks whether both original
// axes are automatic before it examines the block-size argument supplied by a
// min/max constraint rerun. Consequently, an intrinsic block size wins again
// when either constraint is violated. This asymmetry does not apply to the
// inline-axis tentative-size algorithm.
fn apply_replaced_block_axis_constraints(node &Node, minimum css.Size, maximum css.Size, input CSSPixels, available_size AvailableSize, box_model ReplacedBoxModel, constraint_rerun_uses_intrinsic_height bool, constraint_rerun_intrinsic_height CSSPixels) CSSPixels {
	min_value, max_value := replaced_axis_constraints(node, minimum, maximum, input,
		available_size, box_model, false)
	mut used := input
	if used.raw_value() > max_value.raw_value() {
		used = if constraint_rerun_uses_intrinsic_height {
			constraint_rerun_intrinsic_height
		} else {
			max_value
		}
	}
	if used.raw_value() < min_value.raw_value() {
		used = if constraint_rerun_uses_intrinsic_height {
			constraint_rerun_intrinsic_height
		} else {
			min_value
		}
	}
	return used
}

// CSS 2.2 10.4 constraint-violation table. Replaced boxes with a preferred
// aspect ratio adjust the opposite axis when a min/max constraint applies. The
// min/max sizes are converted from the specified box to content-box space before
// the table compares them with the tentative content size.
fn solve_replaced_size_constraint(box &Box, input_width CSSPixels, input_height CSSPixels, aspect_ratio css.CSSPixelFraction, available_space AvailableSpace, box_model ReplacedBoxModel) CSSPixelSize {
	node := unsafe { &Node(box) }
	computed := node.computed_values()
	min_width, max_width := replaced_axis_constraints(node, computed.size_value(.min_width), computed.size_value(.max_width), input_width, available_space.width, box_model, true)
	min_height, max_height := replaced_axis_constraints(node, computed.size_value(.min_height), computed.size_value(.max_height), input_height, available_space.height, box_model, false)

	if input_width.raw_value() < min_width.raw_value()
		&& input_height.raw_value() > max_height.raw_value() {
		return CSSPixelSize.new(min_width, max_height)
	}
	if input_width.raw_value() > max_width.raw_value()
		&& input_height.raw_value() < min_height.raw_value() {
		return CSSPixelSize.new(max_width, min_height)
	}
	if input_width.raw_value() > 0 && input_height.raw_value() > 0 {
		width_scale := max_width.to_double() / input_width.to_double()
		height_scale := max_height.to_double() / input_height.to_double()
		if input_width.raw_value() > max_width.raw_value()
			&& input_height.raw_value() > max_height.raw_value() && width_scale <= height_scale {
			return CSSPixelSize.new(max_width, css_pixels_max(min_height, max_width.divided_by_fraction(aspect_ratio)))
		}
		if input_width.raw_value() > max_width.raw_value()
			&& input_height.raw_value() > max_height.raw_value() && width_scale > height_scale {
			return CSSPixelSize.new(css_pixels_max(min_width, max_height.times_fraction(aspect_ratio)), max_height)
		}
		min_width_scale := min_width.to_double() / input_width.to_double()
		min_height_scale := min_height.to_double() / input_height.to_double()
		if input_width.raw_value() < min_width.raw_value()
			&& input_height.raw_value() < min_height.raw_value()
			&& min_width_scale <= min_height_scale {
			return CSSPixelSize.new(css_pixels_min(max_width, min_height.times_fraction(aspect_ratio)), min_height)
		}
		if input_width.raw_value() < min_width.raw_value()
			&& input_height.raw_value() < min_height.raw_value()
			&& min_width_scale > min_height_scale {
			return CSSPixelSize.new(min_width, css_pixels_min(max_height, min_width.divided_by_fraction(aspect_ratio)))
		}
	}
	if input_width.raw_value() > max_width.raw_value() {
		return CSSPixelSize.new(max_width, css_pixels_max(max_width.divided_by_fraction(aspect_ratio), min_height))
	}
	if input_width.raw_value() < min_width.raw_value() {
		return CSSPixelSize.new(min_width, css_pixels_min(min_width.divided_by_fraction(aspect_ratio), max_height))
	}
	if input_height.raw_value() > max_height.raw_value() {
		return CSSPixelSize.new(css_pixels_max(max_height.times_fraction(aspect_ratio), min_width), max_height)
	}
	if input_height.raw_value() < min_height.raw_value() {
		return CSSPixelSize.new(css_pixels_min(min_height.times_fraction(aspect_ratio), max_width), min_height)
	}
	return CSSPixelSize.new(input_width, input_height)
}

// FormattingContext::should_treat_width_as_auto()
fn should_treat_width_as_auto(state &LayoutState, box &Box, available_space AvailableSpace) bool {
	node := unsafe { &Node(box) }
	computed_width := node.computed_values().size_value(.width)
	if computed_width.is_auto() {
		return true
	}

	// https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution
	if computed_width.contains_percentage() {
		if !node.is_replaced_box() && available_space.width.is_min_content() {
			return true
		}
		if available_space.width.is_max_content() {
			return true
		}
		if available_space.width.is_indefinite() {
			return true
		}
	}
	// AD-HOC: If the box has a preferred aspect ratio and an intrinsic keyword for width...
	if box.has_preferred_aspect_ratio() && computed_width.is_intrinsic_sizing_constraint() {
		// If the box has no natural height to resolve the aspect ratio, we treat the width as auto.
		if box.auto_content_box_size().height == none {
			return true
		}
		// If the box has definite height, we can resolve the width through the aspect ratio.
		if used_values := state.try_get(node.as_node_with_style() or { return false }) {
			if used_values.has_definite_height() {
				return true
			}
		}
	}
	return false
}

// FormattingContext::should_treat_height_as_auto()
fn should_treat_height_as_auto(state &LayoutState, box &Box, available_space AvailableSpace) bool {
	node := unsafe { &Node(box) }
	styled := node.as_node_with_style() or { return true }
	computed_height := node.computed_values().size_value(.height)
	if computed_height.is_auto() {
		if used_values := state.try_get(styled) {
			if used_values.has_definite_width() && box.has_preferred_aspect_ratio() {
				return false
			}
		}
		return true
	}

	// https://drafts.csswg.org/css-sizing-3/#cyclic-percentage-contribution
	if computed_height.contains_percentage() {
		if !node.is_replaced_box() && available_space.height.is_min_content() {
			return true
		}
		if available_space.height.is_max_content() {
			return true
		}
		// https://www.w3.org/TR/CSS22/visudet.html#the-height-property
		// If the height of the containing block is not specified explicitly (i.e., it depends on
		// content height), and this element is not absolutely positioned, the percentage value
		// is treated as 'auto'.
		if !node.is_absolutely_positioned()
			&& !percentage_height_quirk_applies(node, node.computed_values()) {
			// NOTE: Anonymous blocks inherit height definiteness from their containing block.
			//       However, anonymous table cells are proper containing blocks with their own
			//       height semantics, so we must not walk past them.
			mut containing_block := node.containing_block()
			for {
				current := containing_block or { return true }
				if !current.is_anonymous() || current.display().is_table_cell() {
					break
				}
				containing_block = current.containing_block()
			}
			current := containing_block or { return true }
			containing_styled := unsafe { &Node(current) }.as_node_with_style() or { return true }
			containing_used_values := state.try_get(containing_styled) or { return true }
			if !containing_used_values.has_definite_height() {
				return true
			}
		}
	}

	// AD-HOC: If the box has a preferred aspect ratio and an intrinsic keyword for height...
	if box.has_preferred_aspect_ratio() && computed_height.is_intrinsic_sizing_constraint() {
		// If the box has no natural width to resolve the aspect ratio, we treat the height as auto.
		if box.auto_content_box_size().width == none {
			return true
		}
		// If the box has definite width, we can resolve the height through the aspect ratio.
		if used_values := state.try_get(styled) {
			if used_values.has_definite_width() {
				return true
			}
		}
	}
	return false
}

// FormattingContext::box_is_sized_as_replaced_element()
//
// When a box has a preferred aspect ratio, its automatic sizes are calculated the same as for a
// replaced element with a natural aspect ratio and no natural size in that axis, see e.g. CSS2 §10
// and CSS Flexible Box Model Level 1 §9.2.
// https://www.w3.org/TR/css-sizing-4/#aspect-ratio-automatic
fn box_is_sized_as_replaced_element(state &LayoutState, node &Node, available_space AvailableSpace) bool {
	box := node.as_box() or { return false }
	if node.is_replaced_box() && box.has_auto_content_box_size() {
		return true
	}

	if box.has_preferred_aspect_ratio() || box.has_auto_content_box_size() {
		// AD-HOC: If box has preferred aspect ratio but width and height are not specified, then we
		//         should size it as a normal box to match other browsers.
		auto_size := box.auto_content_box_size()
		if should_treat_width_as_auto(state, box, available_space)
			&& should_treat_height_as_auto(state, box, available_space) && auto_size.width == none
			&& auto_size.height == none {
			return false
		}
		return true
	}

	return false
}

// The border-box branch of FormattingContext::calculate_inner_width() for an
// already-resolved pixel length. The used inline padding is read from
// `box_state`; the border widths come from the computed values.
fn calculate_inner_width_for_used_px(node &Node, box_state &UsedValues, width CSSPixels) CSSPixels {
	computed := node.computed_values()
	if computed.box_sizing() != .border_box {
		return width
	}
	inner_width := width.minus(css_px(resolve_used_border_width(computed, .border_left_width)))
		.minus(box_state.padding_left)
		.minus(css_px(resolve_used_border_width(computed, .border_right_width)))
		.minus(box_state.padding_right)
	return css_pixels_max(CSSPixels.new(0), inner_width)
}

// BlockFormattingContext::compute_width_for_block_level_replaced_element_in_normal_flow()
//
// The source assigns the used padding *after* calling
// compute_width_for_replaced_element(), so the replaced algorithm resolves
// `box-sizing: border-box` against a still-zero inline padding, and the returned
// content width is then converted a second time by calculate_inner_width() —
// this time with the real padding in place. Both conversions are reproduced
// here, because a block-level replaced (or aspect-ratio-sized) box with
// `box-sizing: border-box` really does lose its inline border and padding twice.
fn compute_size_for_block_level_replaced_element_in_normal_flow(box &Box, box_state &UsedValues, available_space AvailableSpace) CSSPixelSize {
	node := unsafe { &Node(box) }
	// Chromium text controls convert the author border-box width once, with
	// the final padding already available. The translated LibWeb path below
	// intentionally retains its second conversion and ratio transfer.
	if node.document().font_rendering_policy() == .chromium
		&& node.computed_values().box_sizing() == .border_box
		&& (node.is_text_input_box() || node.is_textarea_box())
		&& !box.has_preferred_aspect_ratio() {
		return compute_replaced_size_with_box_model(box, available_space, ReplacedBoxModel{
			percentage_basis:    available_space.width.to_px_or_zero()
			used_inline_padding: box_state.padding_left.plus(box_state.padding_right)
		})
	}
	tentative := compute_replaced_size_with_box_model(box, available_space, ReplacedBoxModel{
		percentage_basis: available_space.width.to_px_or_zero()
		used_inline_padding: CSSPixels.new(0)
	})
	width := calculate_inner_width_for_used_px(node, box_state, tentative.width())
	if width.raw_value() == tentative.width().raw_value() {
		return tentative
	}
	// FormattingContext::tentative_height_for_replaced_element() transfers the
	// *used* content width through the aspect ratio, so a height that came from
	// the ratio follows the converted width.
	ratio := box.preferred_aspect_ratio() or { return CSSPixelSize.new(width, tentative.height()) }
	computed := node.computed_values()
	computed_width := computed.size_value(.width)
	computed_height := computed.size_value(.height)
	width_treated_as_auto := computed_width.is_auto()
		|| (computed_width.contains_percentage() && !available_space.width.is_definite())
	// should_treat_height_as_auto() answers `false` for a computed `auto` height
	// once the box has a definite inline size and a preferred aspect ratio, which
	// is exactly the state the caller is about to assign.
	height_treated_as_auto := computed_height.contains_percentage()
		&& !available_space.height.is_definite()
	// tentative_height_for_replaced_element() takes the natural height when both
	// axes are treated as automatic; only its next branch reads the used content
	// width, so only that one has to follow the converted inline size.
	intrinsic := box.auto_content_box_size()
	takes_the_natural_height := width_treated_as_auto && height_treated_as_auto
		&& intrinsic.height != none
	height_came_from_the_ratio := (computed_height.is_auto() || height_treated_as_auto)
		&& !takes_the_natural_height
	if !height_came_from_the_ratio {
		return CSSPixelSize.new(width, tentative.height())
	}
	box_model := ReplacedBoxModel{
		percentage_basis: available_space.width.to_px_or_zero()
	}
	height := clamp_replaced_axis(node, node.computed_values().size_value(.min_height),
		node.computed_values().size_value(.max_height), width.divided_by_fraction(ratio),
		available_space.height, box_model, false)
	return CSSPixelSize.new(width, height)
}

// FormattingContext::calculate_inner_width(). Intrinsic keywords resolve to the
// matching intrinsic width; a length or percentage passes through the
// `box-sizing: border-box` conversion against the *used* inline padding.
fn calculate_inner_width(mut state LayoutState, box &Box, box_state &UsedValues, available_width AvailableSize, size css.Size) CSSPixels {
	if size.is_fit_content() {
		return calculate_fit_content_width(mut state, box, available_width)
	}
	if size.is_max_content() {
		return calculate_max_content_width(mut state, box)
	}
	if size.is_min_content() {
		return calculate_min_content_width(mut state, box)
	}
	node := unsafe { &Node(box) }
	resolved := resolve_layout_size(node, size, available_width.to_px_or_zero()) or {
		CSSPixels.new(0)
	}
	return calculate_inner_width_for_used_px(node, box_state, resolved)
}

// BlockFormattingContext::compute_width() feeds the already-computed replaced
// width back into the CSS 2.1 width equation, including its max-width and
// min-width re-runs, purely so the used margins are resolved from the clamped
// value. The clamped width itself is discarded: step 4 only assigns it when the
// box is *not* sized as a replaced element.
fn replaced_width_for_margin_resolution(mut state LayoutState, box &Box, box_state &UsedValues, available_width AvailableSize, content_width CSSPixels) CSSPixels {
	node := unsafe { &Node(box) }
	computed := node.computed_values()
	mut used_width := content_width
	max_width := computed.size_value(.max_width)
	if !should_treat_max_width_as_none(state, node, available_width) && !max_width.is_none() {
		maximum := calculate_inner_width(mut state, box, box_state, available_width, max_width)
		if used_width.raw_value() > maximum.raw_value() {
			used_width = maximum
		}
	}
	min_width := computed.size_value(.min_width)
	if !min_width.is_auto() {
		minimum := calculate_inner_width(mut state, box, box_state, available_width, min_width)
		if used_width.raw_value() < minimum.raw_value() {
			used_width = minimum
		}
	}
	return used_width
}
