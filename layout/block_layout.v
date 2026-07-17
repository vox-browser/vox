module layout

import css

// First slices of the block layout algorithm (Layout/BlockFormattingContext.cpp + FormattingContext.cpp):
// resolve a box's used box-model edges from its computed style, and compute the used width of a
// normal-flow block-level box per CSS 2.1 §10.3.3 (including auto width / auto margins).
//
// DEFERRED: min/max-width clamping, replaced/inline/float/abspos width, over-constrained resolution
// direction (assumes LTR, drops margin-right), border-width vs border-style interaction, and vertical
// layout (heights + child stacking) — later slices.

fn css_px(value f64) CSSPixels {
	return CSSPixels.nearest_value_for(value)
}

// Whether `property_id`'s computed value is the `auto` keyword.
fn property_is_auto(computed &css.ComputedProperties, property_id css.PropertyID) bool {
	value := computed.property(property_id, .yes) or { return false }
	return value.css_text.trim_space().to_lower() == 'auto'
}

// The used border width for one side: 0 if that side's border-style is none/hidden (CSS 2.1 §8.5.3),
// otherwise the resolved border-width.
fn resolve_used_border_width(computed &css.ComputedProperties, width_property css.PropertyID, style_property css.PropertyID, containing_block_width f64) f64 {
	style_value := computed.property(style_property, .yes) or { return 0.0 }
	style_keyword := style_value.css_text.trim_space().to_lower()
	if style_keyword == 'none' || style_keyword == 'hidden' {
		return 0.0
	}
	return computed.length_percentage_to_px(width_property, containing_block_width) or { 0.0 }
}

// Resolve the used margin/border/padding edges from `computed` into `used_values`. `containing_block_width`
// is the percentage basis. `auto` margins resolve to 0 here (compute_block_used_width may reassign them).
fn resolve_box_model_edges(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64) {
	used_values.padding_left = css_px(computed.length_percentage_to_px(.padding_left, containing_block_width) or {
		0.0
	})
	used_values.padding_right = css_px(computed.length_percentage_to_px(.padding_right, containing_block_width) or {
		0.0
	})
	used_values.padding_top = css_px(computed.length_percentage_to_px(.padding_top, containing_block_width) or {
		0.0
	})
	used_values.padding_bottom = css_px(computed.length_percentage_to_px(.padding_bottom, containing_block_width) or {
		0.0
	})

	// CSS 2.1 §8.5.3: the used border width is 0 when the border style is none or hidden.
	used_values.border_left = css_px(resolve_used_border_width(computed, .border_left_width,
		.border_left_style, containing_block_width))
	used_values.border_right = css_px(resolve_used_border_width(computed, .border_right_width,
		.border_right_style, containing_block_width))
	used_values.border_top = css_px(resolve_used_border_width(computed, .border_top_width, .border_top_style,
		containing_block_width))
	used_values.border_bottom = css_px(resolve_used_border_width(computed, .border_bottom_width,
		.border_bottom_style, containing_block_width))

	// auto margins resolve to 0 for now (width computation reassigns them for centering).
	used_values.margin_left = css_px(computed.length_percentage_to_px(.margin_left, containing_block_width) or {
		0.0
	})
	used_values.margin_right = css_px(computed.length_percentage_to_px(.margin_right, containing_block_width) or {
		0.0
	})
	used_values.margin_top = css_px(computed.length_percentage_to_px(.margin_top, containing_block_width) or {
		0.0
	})
	used_values.margin_bottom = css_px(computed.length_percentage_to_px(.margin_bottom, containing_block_width) or {
		0.0
	})
}

// CSS 2.1 §10.3.3: compute the used content width (and resolve auto margins) of a normal-flow block-level
// box, given its containing block's width. Assumes resolve_box_model_edges already ran.
fn compute_block_used_width(computed &css.ComputedProperties, mut used_values UsedValues, containing_block_width f64) {
	// Non-content horizontal edges (border + padding).
	edges := used_values.border_left.to_double() + used_values.padding_left.to_double() +
		used_values.padding_right.to_double() + used_values.border_right.to_double()

	width_is_auto := property_is_auto(computed, .width)
	margin_left_auto := property_is_auto(computed, .margin_left)
	margin_right_auto := property_is_auto(computed, .margin_right)

	if width_is_auto {
		// auto width fills the containing block; auto margins become 0.
		margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
		margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
		mut width := containing_block_width - margin_left - margin_right - edges
		if width < 0.0 {
			width = 0.0
		}
		used_values.margin_left = css_px(margin_left)
		used_values.margin_right = css_px(margin_right)
		used_values.set_content_width(css_px(width))
		return
	}

	// Definite width.
	width := computed.length_percentage_to_px(.width, containing_block_width) or { 0.0 }
	used_values.set_content_width(css_px(width))

	// Resolve auto margins: they absorb the remaining space (centering when both are auto).
	fixed_margin_left := if margin_left_auto { 0.0 } else { used_values.margin_left.to_double() }
	fixed_margin_right := if margin_right_auto { 0.0 } else { used_values.margin_right.to_double() }
	remaining := containing_block_width - width - edges - fixed_margin_left - fixed_margin_right

	if margin_left_auto && margin_right_auto {
		half := remaining / 2.0
		used_values.margin_left = css_px(half)
		used_values.margin_right = css_px(half)
	} else if margin_left_auto {
		used_values.margin_left = css_px(remaining)
	} else if margin_right_auto {
		used_values.margin_right = css_px(remaining)
	}
	// FIXME: over-constrained (no auto) — CSS 2.1 ignores margin-right in LTR; not adjusted here.
}
