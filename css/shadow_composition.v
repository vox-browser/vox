module css

// https://drafts.csswg.org/css-backgrounds/#box-shadow
// Shadow lists add by concatenation. Accumulation pads the shorter list with
// blank shadows like interpolation does, then accumulates each pair's color
// and lengths. A pair whose inset keyword differs cannot accumulate, so the
// caller falls back to replacing the underlying value.
fn composite_shadow_lists(property_id PropertyID, underlying StyleValue, animated StyleValue, operation CompositeOperation) ?StyleValue {
	underlying_list := interpolation_shadow_list(underlying) or { return none }
	animated_list := interpolation_shadow_list(animated) or { return none }
	mut values := []StyleValue{cap: underlying_list.len + animated_list.len}
	if operation == .add {
		for shadow in underlying_list {
			values << StyleValue(shadow)
		}
		for shadow in animated_list {
			values << StyleValue(shadow)
		}
	} else if operation == .accumulate {
		mut a := underlying_list.clone()
		mut b := animated_list.clone()
		interpolation_extend_shadow_list(mut a, b)
		interpolation_extend_shadow_list(mut b, a)
		for index in 0 .. a.len {
			values << StyleValue(accumulate_shadows(property_id, a[index], b[index]) or {
				return none
			})
		}
	} else {
		return none
	}
	if values.len == 0 {
		return StyleValue(KeywordStyleValue.create(.none_))
	}
	return StyleValue(StyleValueList.create(values, .comma, .yes))
}

fn accumulate_shadows(property_id PropertyID, a ShadowStyleValue, b ShadowStyleValue) ?ShadowStyleValue {
	if a.shadow_type() != b.shadow_type() || a.placement() != b.placement() {
		return none
	}
	color := composite_colors(a.color(), b.color(), ColorResolutionContext{}) or { return none }
	offset_x := composite_style_value(property_id, a.offset_x(), b.offset_x(), .accumulate) or {
		return none
	}
	offset_y := composite_style_value(property_id, a.offset_y(), b.offset_y(), .accumulate) or {
		return none
	}
	blur_radius := composite_style_value(property_id, a.blur_radius(), b.blur_radius(), .accumulate) or {
		return none
	}
	spread_distance := if a.shadow_type() == .text {
		?StyleValue(none)
	} else {
		?StyleValue(composite_style_value(property_id, a.spread_distance(), b.spread_distance(),
			.accumulate) or { return none })
	}
	return ShadowStyleValue.create(a.shadow_type(), color, offset_x, offset_y, blur_radius,
		spread_distance, a.placement())
}
