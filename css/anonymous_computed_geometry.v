module css

import platform

// Resolving initial geometry once keeps anonymous boxes independent of the
// parent's non-inherited values without decoding those same defaults per box.
__global (
	anonymous_initial_geometry_cache &ComputedLayoutCache
)

fn initial_anonymous_geometry_cache() &ComputedLayoutCache {
	if anonymous_initial_geometry_cache == unsafe { nil } {
		persistent := platform.enter_persistent()
		defer { platform.leave_persistent(persistent) }
		initial := computed_properties_with_initial_values()
		_ = resolve_computed_values(initial)
		anonymous_initial_geometry_cache = initial.computed_layout_cache()
	}
	return anonymous_initial_geometry_cache
}

fn resolve_anonymous_computed_geometry(style &ComputedProperties, inherited &ComputedLayoutCache) &ComputedValues {
	mut values := unsafe { &MutableComputedValues(style) }
	values.ensure_computed_layout_cache().computed_values_direction_ = inherited.computed_values_direction_
	values.ensure_computed_layout_cache().computed_values_writing_mode_ = inherited.computed_values_writing_mode_
	values.ensure_computed_layout_cache().computed_values_font_size_ = inherited.computed_values_font_size_
	values.ensure_computed_layout_cache().computed_values_font_weight_ = inherited.computed_values_font_weight_
	values.ensure_computed_layout_cache().computed_values_font_language_override_ = inherited.computed_values_font_language_override_
	values.ensure_computed_layout_cache().computed_values_caret_color_ = inherited.computed_values_caret_color_
	values.ensure_computed_layout_cache().computed_values_color_ = inherited.computed_values_color_
	values.ensure_computed_layout_cache().computed_values_accent_color_ = inherited.computed_values_accent_color_
	values.ensure_computed_layout_cache().computed_values_color_scheme_ = inherited.computed_values_color_scheme_
	values.ensure_computed_layout_cache().computed_values_text_align_ = inherited.computed_values_text_align_
	values.ensure_computed_layout_cache().computed_values_text_justify_ = inherited.computed_values_text_justify_
	values.ensure_computed_layout_cache().computed_values_text_transform_ = inherited.computed_values_text_transform_
	values.ensure_computed_layout_cache().computed_values_text_wrap_mode_ = inherited.computed_values_text_wrap_mode_
	values.ensure_computed_layout_cache().computed_values_white_space_collapse_ = inherited.computed_values_white_space_collapse_
	values.ensure_computed_layout_cache().computed_values_word_break_ = inherited.computed_values_word_break_
	values.ensure_computed_layout_cache().computed_values_visibility_ = inherited.computed_values_visibility_
	values.ensure_computed_layout_cache().computed_values_caption_side_ = inherited.computed_values_caption_side_
	values.ensure_computed_layout_cache().computed_values_border_collapse_ = inherited.computed_values_border_collapse_
	values.ensure_computed_layout_cache().computed_values_image_rendering_ = inherited.computed_values_image_rendering_
	values.ensure_computed_layout_cache().computed_values_pointer_events_ = inherited.computed_values_pointer_events_
	values.ensure_computed_layout_cache().computed_values_list_style_position_ = inherited.computed_values_list_style_position_
	values.ensure_computed_layout_cache().computed_values_block_ellipsis_ = inherited.computed_values_block_ellipsis_
	values.ensure_computed_layout_cache().computed_values_empty_cells_ = inherited.computed_values_empty_cells_
	values.ensure_computed_layout_cache().computed_values_fill_opacity_ = inherited.computed_values_fill_opacity_
	values.ensure_computed_layout_cache().computed_values_stroke_linecap_ = inherited.computed_values_stroke_linecap_
	values.ensure_computed_layout_cache().computed_values_stroke_linejoin_ = inherited.computed_values_stroke_linejoin_
	values.ensure_computed_layout_cache().computed_values_stroke_miterlimit_ = inherited.computed_values_stroke_miterlimit_
	values.ensure_computed_layout_cache().computed_values_stroke_opacity_ = inherited.computed_values_stroke_opacity_
	values.ensure_computed_layout_cache().computed_values_fill_rule_ = inherited.computed_values_fill_rule_
	values.ensure_computed_layout_cache().computed_values_clip_rule_ = inherited.computed_values_clip_rule_
	values.ensure_computed_layout_cache().computed_values_shape_rendering_ = inherited.computed_values_shape_rendering_
	values.ensure_computed_layout_cache().computed_values_text_anchor_ = inherited.computed_values_text_anchor_
	values.ensure_computed_layout_cache().computed_values_border_spacing_horizontal_ = inherited.computed_values_border_spacing_horizontal_
	values.ensure_computed_layout_cache().computed_values_border_spacing_vertical_ = inherited.computed_values_border_spacing_vertical_
	values.ensure_computed_layout_cache().computed_values_color_interpolation_ = inherited.computed_values_color_interpolation_
	values.ensure_computed_layout_cache().computed_values_color_interpolation_filters_ = inherited.computed_values_color_interpolation_filters_
	values.ensure_computed_layout_cache().computed_values_cursor_ = inherited.computed_values_cursor_
	values.ensure_computed_layout_cache().computed_values_tab_size_ = inherited.computed_values_tab_size_
	values.ensure_computed_layout_cache().computed_values_text_decoration_line_ = inherited.computed_values_text_decoration_line_
	values.ensure_computed_layout_cache().computed_values_text_decoration_skip_ink_ = inherited.computed_values_text_decoration_skip_ink_
	values.ensure_computed_layout_cache().computed_values_text_decoration_thickness_ = inherited.computed_values_text_decoration_thickness_
	values.ensure_computed_layout_cache().computed_values_text_decoration_style_ = inherited.computed_values_text_decoration_style_
	values.ensure_computed_layout_cache().computed_values_text_decoration_color_ = inherited.computed_values_text_decoration_color_
	values.ensure_computed_layout_cache().computed_values_text_indent_ = inherited.computed_values_text_indent_
	values.ensure_computed_layout_cache().computed_values_text_underline_offset_ = inherited.computed_values_text_underline_offset_
	values.ensure_computed_layout_cache().computed_values_text_underline_position_ = inherited.computed_values_text_underline_position_
	values.ensure_computed_layout_cache().computed_values_word_spacing_ = inherited.computed_values_word_spacing_
	values.ensure_computed_layout_cache().computed_values_letter_spacing_ = inherited.computed_values_letter_spacing_
	values.ensure_computed_layout_cache().computed_values_quotes_ = inherited.computed_values_quotes_
	values.ensure_computed_layout_cache().computed_values_dominant_baseline_ = inherited.computed_values_dominant_baseline_
	values.ensure_computed_layout_cache().computed_values_stroke_dasharray_ = inherited.computed_values_stroke_dasharray_
	values.ensure_computed_layout_cache().computed_values_paint_order_ = inherited.computed_values_paint_order_
	values.ensure_computed_layout_cache().computed_values_math_shift_ = inherited.computed_values_math_shift_
	values.ensure_computed_layout_cache().computed_values_math_style_ = inherited.computed_values_math_style_
	values.ensure_computed_layout_cache().computed_values_math_depth_ = inherited.computed_values_math_depth_
	values.ensure_computed_layout_cache().computed_values_stroke_dashoffset_ = inherited.computed_values_stroke_dashoffset_
	values.ensure_computed_layout_cache().computed_values_stroke_width_ = inherited.computed_values_stroke_width_
	values.ensure_computed_layout_cache().computed_values_webkit_text_fill_color_ = inherited.computed_values_webkit_text_fill_color_
	values.ensure_computed_layout_cache().computed_values_fill_ = inherited.computed_values_fill_
	values.ensure_computed_layout_cache().computed_values_stroke_ = inherited.computed_values_stroke_
	values.ensure_computed_layout_cache().computed_values_text_shadow_ = inherited.computed_values_text_shadow_
	values.ensure_computed_layout_cache().computed_values_scrollbar_color_ = inherited.computed_values_scrollbar_color_
	// Font discovery above belongs to the clone. Preserve its normal-line-height
	// metrics and font variation ownership exactly as the ordinary resolver.
	values.set_font_size(style.font_size())
	values.set_line_height(style.line_height())
	values.set_font_weight(style.font_weight())
	values.set_font_language_override(style.font_language_override())
	apply_resolved_font_variation_settings(style, mut values)
	values.set_display(style.display())
	values.set_display_before_box_type_transformation(style.display_before_box_type_transformation())
	values.computed_values_resolved_ = true
	return unsafe { &ComputedValues(style) }
}
