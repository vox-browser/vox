// Copyright (c) 2018-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module layout

import css

// CSS 2.2 10.3.2 and 10.6.2 replaced-element tentative sizing. This is shared
// by inline, block, flex/grid item, and absolutely-positioned layout paths.
fn compute_replaced_size(box &Box, available_space AvailableSpace) CSSPixelSize {
	node := unsafe { &Node(box) }
	computed := node.computed_values()
	width_basis := available_space.width.to_px_or_zero()
	height_basis := available_space.height.to_px_or_zero()
	computed_width := computed.size_value(.width)
	computed_height := computed.size_value(.height)
	mut specified_width := resolve_replaced_content_size(node, computed_width, width_basis,
		width_basis, true)
	mut specified_height := resolve_replaced_content_size(node, computed_height, height_basis,
		width_basis, false)
	if computed_width.contains_percentage() && !available_space.width.is_definite() {
		// CSS Sizing's replaced percentage min-contribution resolves a cyclic
		// percentage preferred width against zero. Under max-content or a plain
		// indefinite constraint it behaves as auto instead.
		specified_width = if available_space.width.is_min_content() {
			resolve_replaced_content_size(node, computed_width, CSSPixels.new(0), CSSPixels.new(0), true)
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
			height = CSSPixels.new(150)
		}
	} else if specified_block := specified_height {
		height = specified_block
		if intrinsic_ratio := ratio {
			width = height.times_fraction(intrinsic_ratio)
		} else if intrinsic_width := intrinsic.width {
			width = intrinsic_width
		} else {
			width = CSSPixels.new(300)
		}
	} else if intrinsic_width := intrinsic.width {
		width = intrinsic_width
		if intrinsic_height := intrinsic.height {
			height = intrinsic_height
		} else if intrinsic_ratio := ratio {
			height = width.divided_by_fraction(intrinsic_ratio)
		} else {
			height = CSSPixels.new(150)
		}
	} else if intrinsic_height := intrinsic.height {
		height = intrinsic_height
		if intrinsic_ratio := ratio {
			width = height.times_fraction(intrinsic_ratio)
		} else {
			width = CSSPixels.new(300)
		}
	} else if intrinsic_ratio := ratio {
		width = if available_space.width.is_definite() {
			available_space.width.to_px_or_zero()
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
			width = solve_replaced_size_constraint(box, width, height, intrinsic_ratio,
				available_space).width()
			height = width.divided_by_fraction(intrinsic_ratio)
		}
	} else {
		width = CSSPixels.new(300)
		height = CSSPixels.new(150)
	}
	if intrinsic_ratio := ratio {
		return solve_replaced_size_constraint(box, width, height, intrinsic_ratio, available_space)
	}
	width = clamp_replaced_axis(node, computed.size_value(.min_width),
		computed.size_value(.max_width), width, available_space.width, width_basis, true)
	height = clamp_replaced_axis(node, computed.size_value(.min_height),
		computed.size_value(.max_height), height, available_space.height, width_basis, false)
	return CSSPixelSize.new(width, height)
}

fn replaced_box_sizing_edges(node &Node, percentage_basis CSSPixels, width bool) CSSPixels {
	computed := node.computed_values()
	if computed.box_sizing() != .border_box {
		return CSSPixels.new(0)
	}
	basis := percentage_basis.to_double()
	if width {
		return css_px(
			resolve_used_border_width(computed, .border_left_width, .border_left_style, basis) +
			(computed.length_percentage_to_px(.padding_left, basis) or {
			0.0
		}) +
			(computed.length_percentage_to_px(.padding_right, basis) or { 0.0 }) +
			resolve_used_border_width(computed, .border_right_width, .border_right_style, basis))
	}
	return css_px(
		resolve_used_border_width(computed, .border_top_width, .border_top_style, basis) +
		(computed.length_percentage_to_px(.padding_top, basis) or {
		0.0
	}) +
		(computed.length_percentage_to_px(.padding_bottom, basis) or { 0.0 }) +
		resolve_used_border_width(computed, .border_bottom_width, .border_bottom_style, basis))
}

fn resolve_replaced_content_size(node &Node, size css.Size, size_basis CSSPixels, box_model_basis CSSPixels, width bool) ?CSSPixels {
	resolved := resolve_layout_size(node, size, size_basis) or { return none }
	return css_pixels_max(CSSPixels.new(0), resolved.minus(replaced_box_sizing_edges(node,
		box_model_basis, width)))
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

fn replaced_axis_constraints(node &Node, minimum css.Size, maximum css.Size, input CSSPixels, available_size AvailableSize, box_model_basis CSSPixels, width bool) (CSSPixels, CSSPixels) {
	basis := available_size.to_px_or_zero()
	min_value := resolve_replaced_content_size(node, minimum, basis, box_model_basis, width) or {
		CSSPixels.new(0)
	}
	specified_max := if should_treat_replaced_max_as_none(maximum, available_size) {
		input
	} else {
		resolve_replaced_content_size(node, maximum, basis, box_model_basis, width) or { input }
	}
	return min_value, css_pixels_max(min_value, specified_max)
}

fn clamp_replaced_axis(node &Node, minimum css.Size, maximum css.Size, input CSSPixels, available_size AvailableSize, box_model_basis CSSPixels, width bool) CSSPixels {
	min_value, max_value := replaced_axis_constraints(node, minimum, maximum, input,
		available_size, box_model_basis, width)
	return css_pixels_max(min_value, css_pixels_min(input, max_value))
}

// CSS 2.2 10.4 constraint-violation table. Replaced boxes with a preferred
// aspect ratio adjust the opposite axis when a min/max constraint applies.
fn solve_replaced_size_constraint(box &Box, input_width CSSPixels, input_height CSSPixels, aspect_ratio css.CSSPixelFraction, available_space AvailableSpace) CSSPixelSize {
	node := unsafe { &Node(box) }
	computed := node.computed_values()
	width_basis := available_space.width.to_px_or_zero()
	min_width, max_width := replaced_axis_constraints(node, computed.size_value(.min_width),
		computed.size_value(.max_width), input_width, available_space.width, width_basis, true)
	min_height, max_height := replaced_axis_constraints(node, computed.size_value(.min_height),
		computed.size_value(.max_height), input_height, available_space.height, width_basis, false)

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
			return CSSPixelSize.new(max_width, css_pixels_max(min_height,
				max_width.divided_by_fraction(aspect_ratio)))
		}
		if input_width.raw_value() > max_width.raw_value()
			&& input_height.raw_value() > max_height.raw_value() && width_scale > height_scale {
			return CSSPixelSize.new(css_pixels_max(min_width,
				max_height.times_fraction(aspect_ratio)), max_height)
		}
		min_width_scale := min_width.to_double() / input_width.to_double()
		min_height_scale := min_height.to_double() / input_height.to_double()
		if input_width.raw_value() < min_width.raw_value()
			&& input_height.raw_value() < min_height.raw_value()
			&& min_width_scale <= min_height_scale {
			return CSSPixelSize.new(css_pixels_min(max_width,
				min_height.times_fraction(aspect_ratio)), min_height)
		}
		if input_width.raw_value() < min_width.raw_value()
			&& input_height.raw_value() < min_height.raw_value()
			&& min_width_scale > min_height_scale {
			return CSSPixelSize.new(min_width, css_pixels_min(max_height,
				min_width.divided_by_fraction(aspect_ratio)))
		}
	}
	if input_width.raw_value() > max_width.raw_value() {
		return CSSPixelSize.new(max_width, css_pixels_max(max_width.divided_by_fraction(aspect_ratio),
			min_height))
	}
	if input_width.raw_value() < min_width.raw_value() {
		return CSSPixelSize.new(min_width, css_pixels_min(min_width.divided_by_fraction(aspect_ratio),
			max_height))
	}
	if input_height.raw_value() > max_height.raw_value() {
		return CSSPixelSize.new(css_pixels_max(max_height.times_fraction(aspect_ratio), min_width),
			max_height)
	}
	if input_height.raw_value() < min_height.raw_value() {
		return CSSPixelSize.new(css_pixels_min(min_height.times_fraction(aspect_ratio), max_width),
			min_height)
	}
	return CSSPixelSize.new(input_width, input_height)
}
