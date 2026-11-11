module css

// Recursive children used to be one-element arrays, whose equality compares
// values. Pointer storage must preserve that contract for both concrete
// records and the generated StyleValue sum-type equality.
fn style_value_slots_equal(a &StyleValueSlot, b &StyleValueSlot) bool {
	if a == unsafe { nil } { return b == unsafe { nil } }
	if b == unsafe { nil } { return false }
	return a.len == b.len && a.value == b.value
}

pub fn (a RGBColorStyleValue) == (b RGBColorStyleValue) bool {
	return style_value_slots_equal(a.r_, b.r_)
		&& style_value_slots_equal(a.g_, b.g_)
		&& style_value_slots_equal(a.b_, b.b_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.color_syntax_ == b.color_syntax_
		&& a.name_ == b.name_
		&& a.preserve_float_alpha_ == b.preserve_float_alpha_
		&& a.unclamped_animation_channels_ == b.unclamped_animation_channels_
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
}

pub fn (a HSLColorStyleValue) == (b HSLColorStyleValue) bool {
	return style_value_slots_equal(a.h_, b.h_)
		&& style_value_slots_equal(a.s_, b.s_)
		&& style_value_slots_equal(a.l_, b.l_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.color_syntax_ == b.color_syntax_
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
		&& a.missing_component_form_ == b.missing_component_form_
}

pub fn (a HWBColorStyleValue) == (b HWBColorStyleValue) bool {
	return style_value_slots_equal(a.h_, b.h_)
		&& style_value_slots_equal(a.w_, b.w_)
		&& style_value_slots_equal(a.b_, b.b_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.color_syntax_ == b.color_syntax_
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
		&& a.missing_component_form_ == b.missing_component_form_
}

pub fn (a LabColorStyleValue) == (b LabColorStyleValue) bool {
	return style_value_slots_equal(a.l_, b.l_)
		&& style_value_slots_equal(a.a_, b.a_)
		&& style_value_slots_equal(a.b_, b.b_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
}

pub fn (a OKLabColorStyleValue) == (b OKLabColorStyleValue) bool {
	return style_value_slots_equal(a.l_, b.l_)
		&& style_value_slots_equal(a.a_, b.a_)
		&& style_value_slots_equal(a.b_, b.b_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
}

pub fn (a LCHColorStyleValue) == (b LCHColorStyleValue) bool {
	return style_value_slots_equal(a.l_, b.l_)
		&& style_value_slots_equal(a.c_, b.c_)
		&& style_value_slots_equal(a.h_, b.h_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
		&& a.computed_coordinates_ == b.computed_coordinates_
}

pub fn (a OKLCHColorStyleValue) == (b OKLCHColorStyleValue) bool {
	return style_value_slots_equal(a.l_, b.l_)
		&& style_value_slots_equal(a.c_, b.c_)
		&& style_value_slots_equal(a.h_, b.h_)
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
		&& a.computed_coordinates_ == b.computed_coordinates_
}

pub fn (a ColorFunctionStyleValue) == (b ColorFunctionStyleValue) bool {
	return a.color_type_ == b.color_type_
		&& a.channels_ == b.channels_
		&& style_value_slots_equal(a.alpha_, b.alpha_)
		&& a.relative_origin_ == b.relative_origin_
		&& a.relative_alpha_ == b.relative_alpha_
		&& a.alpha_function_ == b.alpha_function_
}

pub fn (a RadialGradientStyleValue) == (b RadialGradientStyleValue) bool {
	return a.ending_shape_ == b.ending_shape_
		&& style_value_slots_equal(a.size_, b.size_)
		&& a.position_ == b.position_
		&& a.color_stop_list_ == b.color_stop_list_
		&& a.repeating_ == b.repeating_
		&& a.color_interpolation_method_ == b.color_interpolation_method_
		&& a.color_syntax_ == b.color_syntax_
		&& a.webkit_ == b.webkit_
		&& a.webkit_shape_specified_ == b.webkit_shape_specified_
		&& a.webkit_extent_keyword_ == b.webkit_extent_keyword_
}

pub fn (a ConicGradientStyleValue) == (b ConicGradientStyleValue) bool {
	return style_value_slots_equal(a.from_angle_, b.from_angle_)
		&& a.position_ == b.position_
		&& a.color_stop_list_ == b.color_stop_list_
		&& a.repeating_ == b.repeating_
		&& a.color_interpolation_method_ == b.color_interpolation_method_
		&& a.color_syntax_ == b.color_syntax_
}

pub fn (a AnchorStyleValue) == (b AnchorStyleValue) bool {
	return a.anchor_name_ == b.anchor_name_
		&& a.anchor_side_ == b.anchor_side_
		&& style_value_slots_equal(a.fallback_value_, b.fallback_value_)
}

pub fn (a AnchorSizeStyleValue) == (b AnchorSizeStyleValue) bool {
	return a.anchor_name_ == b.anchor_name_
		&& a.anchor_size_ == b.anchor_size_
		&& style_value_slots_equal(a.fallback_value_, b.fallback_value_)
}

pub fn (a CursorStyleValue) == (b CursorStyleValue) bool {
	return a.image_ == b.image_
		&& style_value_slots_equal(a.x_, b.x_)
		&& style_value_slots_equal(a.y_, b.y_)
}

pub fn (a EdgeStyleValue) == (b EdgeStyleValue) bool {
	return a.edge_ == b.edge_
		&& style_value_slots_equal(a.offset_, b.offset_)
}

pub fn (a FontStyleStyleValue) == (b FontStyleStyleValue) bool {
	return a.font_style_ == b.font_style_
		&& style_value_slots_equal(a.angle_value_, b.angle_value_)
}

pub fn (a RandomValueSharingStyleValue) == (b RandomValueSharingStyleValue) bool {
	return style_value_slots_equal(a.fixed_value_, b.fixed_value_)
		&& a.is_auto_ == b.is_auto_
		&& a.name_ == b.name_
		&& a.element_shared_ == b.element_shared_
}

pub fn (a ShadowStyleValue) == (b ShadowStyleValue) bool {
	return a.shadow_type_ == b.shadow_type_
		&& style_value_slots_equal(a.color_, b.color_)
		&& a.offset_x_ == b.offset_x_
		&& a.offset_y_ == b.offset_y_
		&& style_value_slots_equal(a.blur_radius_, b.blur_radius_)
		&& style_value_slots_equal(a.spread_distance_, b.spread_distance_)
		&& a.placement_ == b.placement_
}
