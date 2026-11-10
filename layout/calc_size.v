module layout

import css

// SizingContext::resolve_calc_size() from Ladybird's Rust layout: the used
// content size of a box whose size property is `size`, given the content size
// its basis resolved to. A calc-size() resolves its calculation against that
// size; any other size keeps it.
// https://drafts.csswg.org/css-values-5/#resolving-calc-size
fn resolve_calc_size_for_box(computed &css.ComputedValues, used &UsedValues, size css.Size, inline_axis bool, content_size CSSPixels, percentage_basis ?CSSPixels) CSSPixels {
	calc_size := size.calc_size() or { return content_size }
	// For all purposes other than resolving the size, a calc-size() with a
	// <calc-sum> basis acts as that calculation, so it reaches here only when
	// the calculation behaves as auto; the calc-size() does too.
	if !size.has_resolvable_calc_size() {
		return content_size
	}
	// The size is that of the box the box-sizing property names.
	edges := if computed.box_sizing() == .border_box {
		if inline_axis {
			used.border_left.plus(used.padding_left).plus(used.padding_right).plus(used.border_right)
		} else {
			used.border_top.plus(used.padding_top).plus(used.padding_bottom).plus(used.border_bottom)
		}
	} else {
		CSSPixels.new(0)
	}
	basis_size := content_size.plus(edges).to_double()
	basis := if value := percentage_basis { ?f64(value.to_double()) } else { ?f64(none) }
	resolved := css.resolve_calc_size(calc_size, basis, basis_size, computed.length_resolution_context()) or {
		return content_size
	}
	return css_pixels_max(CSSPixels.nearest_value_for(resolved).minus(edges), CSSPixels.new(0))
}

// Whether `size` is a calc-size() whose calculation layout applies to the size
// its keyword basis resolves to.
fn size_has_keyword_calc_size(size css.Size) bool {
	return size.calc_size() != none && !size.is_length_percentage()
}

// Whether a size that behaved as auto still resolves a calc-size() calculation:
// a keyword basis, or an any basis whose calculation was indefinite.
fn size_resolves_calc_size_when_auto(size css.Size) bool {
	return size.has_resolvable_calc_size()
}

// FormattingContext::calculate_inner_width() for min-width and max-width given
// as an intrinsic sizing keyword, or as a calc-size() with such a basis (or an
// auto basis for the minimum), on a box sized outside normal block flow.
// clamp_layout_content_size() applies the length and stretch limits.
fn apply_intrinsic_width_limits(mut state LayoutState, node &Node, used &UsedValues, value CSSPixels, available_width AvailableSize) CSSPixels {
	if used.width_constraint != .none {
		return value
	}
	box := node.as_box() or { return value }
	computed := node.computed_values()
	percentage_basis := if available_width.is_definite() { ?CSSPixels(available_width.to_px_or_zero()) } else { ?CSSPixels(none) }
	mut result := value
	maximum_size := computed.size_value(.max_width)
	if maximum_size.is_intrinsic_sizing_constraint() && !should_treat_max_width_as_none(state, node, available_width) {
		maximum := intrinsic_width_for_size(mut state, box, maximum_size, available_width)
		result = css_pixels_min(result, resolve_calc_size_for_box(computed, used, maximum_size, true, maximum, percentage_basis))
	}
	minimum_size := computed.size_value(.min_width)
	if minimum_size.is_intrinsic_sizing_constraint() {
		minimum := intrinsic_width_for_size(mut state, box, minimum_size, available_width)
		result = css_pixels_max(result, resolve_calc_size_for_box(computed, used, minimum_size, true, minimum, percentage_basis))
	} else if minimum_size.is_auto() && minimum_size.calc_size() != none {
		// Outside flex and grid layout, the automatic minimum size is zero,
		// which a minimum given as a calc-size() with an auto basis resolves against.
		result = css_pixels_max(result, resolve_calc_size_for_box(computed, used, minimum_size, true, CSSPixels.new(0), percentage_basis))
	}
	return result
}
