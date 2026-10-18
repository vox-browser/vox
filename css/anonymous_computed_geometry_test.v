module css

import dom

fn anonymous_geometry_set(mut style ComputedProperties, property_id PropertyID, text string) {
	value := parse_css_value(ParsingParams{}, text, property_id) or {
		panic('invalid ${property_id}: ${text}')
	}
	style.set_property(property_id, value, .no, .no)
}

fn anonymous_geometry_assert_same(actual &ComputedValues, expected &ComputedValues) {
	assert actual.computed_layout_cache().computed_values_display_ == expected.computed_layout_cache().computed_values_display_, 'computed_values_display_'
	assert actual.computed_layout_cache().computed_values_display_before_transformation_ == expected.computed_layout_cache().computed_values_display_before_transformation_, 'computed_values_display_before_transformation_'
	assert actual.computed_layout_cache().computed_values_position_ == expected.computed_layout_cache().computed_values_position_, 'computed_values_position_'
	if actual_value := actual.computed_layout_cache().computed_values_position_anchor_ {
		expected_value := expected.computed_layout_cache().computed_values_position_anchor_ or {
			panic('missing computed_values_position_anchor_')
		}

		assert actual_value == expected_value
	} else {
		assert expected.computed_layout_cache().computed_values_position_anchor_ == none
	}
	assert actual.computed_layout_cache().computed_values_float_ == expected.computed_layout_cache().computed_values_float_, 'computed_values_float_'
	assert actual.computed_layout_cache().computed_values_clear_ == expected.computed_layout_cache().computed_values_clear_, 'computed_values_clear_'
	assert actual.computed_layout_cache().computed_values_direction_ == expected.computed_layout_cache().computed_values_direction_, 'computed_values_direction_'
	assert actual.computed_layout_cache().computed_values_writing_mode_ == expected.computed_layout_cache().computed_values_writing_mode_, 'computed_values_writing_mode_'
	assert actual.computed_layout_cache().computed_values_overflow_x_ == expected.computed_layout_cache().computed_values_overflow_x_, 'computed_values_overflow_x_'
	assert actual.computed_layout_cache().computed_values_overflow_y_ == expected.computed_layout_cache().computed_values_overflow_y_, 'computed_values_overflow_y_'
	assert actual.computed_layout_cache().computed_values_font_size_ == expected.computed_layout_cache().computed_values_font_size_, 'computed_values_font_size_'
	assert actual.computed_layout_cache().computed_values_font_weight_ == expected.computed_layout_cache().computed_values_font_weight_, 'computed_values_font_weight_'
	if actual_value := actual.computed_layout_cache().computed_values_font_language_override_ {
		expected_value := expected.computed_layout_cache().computed_values_font_language_override_ or {
			panic('missing computed_values_font_language_override_')
		}

		assert actual_value == expected_value
	} else {
		assert expected.computed_layout_cache().computed_values_font_language_override_ == none
	}
	assert actual.computed_layout_cache().computed_values_caret_color_ == expected.computed_layout_cache().computed_values_caret_color_, 'computed_values_caret_color_'
	assert actual.computed_layout_cache().computed_values_color_ == expected.computed_layout_cache().computed_values_color_, 'computed_values_color_'
	assert actual.computed_layout_cache().computed_values_accent_color_ == expected.computed_layout_cache().computed_values_accent_color_, 'computed_values_accent_color_'
	assert actual.computed_layout_cache().computed_values_color_scheme_ == expected.computed_layout_cache().computed_values_color_scheme_, 'computed_values_color_scheme_'
	assert actual.computed_layout_cache().computed_values_width_ == expected.computed_layout_cache().computed_values_width_, 'computed_values_width_'
	assert actual.computed_layout_cache().computed_values_min_width_ == expected.computed_layout_cache().computed_values_min_width_, 'computed_values_min_width_'
	assert actual.computed_layout_cache().computed_values_max_width_ == expected.computed_layout_cache().computed_values_max_width_, 'computed_values_max_width_'
	assert actual.computed_layout_cache().computed_values_height_ == expected.computed_layout_cache().computed_values_height_, 'computed_values_height_'
	assert actual.computed_layout_cache().computed_values_min_height_ == expected.computed_layout_cache().computed_values_min_height_, 'computed_values_min_height_'
	assert actual.computed_layout_cache().computed_values_max_height_ == expected.computed_layout_cache().computed_values_max_height_, 'computed_values_max_height_'
	assert actual.computed_layout_cache().computed_values_inset_ == expected.computed_layout_cache().computed_values_inset_, 'computed_values_inset_'
	assert actual.computed_layout_cache().computed_values_margin_ == expected.computed_layout_cache().computed_values_margin_, 'computed_values_margin_'
	assert actual.computed_layout_cache().computed_values_padding_ == expected.computed_layout_cache().computed_values_padding_, 'computed_values_padding_'
	assert actual.computed_layout_cache().computed_values_overflow_clip_margin_ == expected.computed_layout_cache().computed_values_overflow_clip_margin_, 'computed_values_overflow_clip_margin_'
	assert actual.computed_layout_cache().computed_values_border_left_ == expected.computed_layout_cache().computed_values_border_left_, 'computed_values_border_left_'
	assert actual.computed_layout_cache().computed_values_border_top_ == expected.computed_layout_cache().computed_values_border_top_, 'computed_values_border_top_'
	assert actual.computed_layout_cache().computed_values_border_right_ == expected.computed_layout_cache().computed_values_border_right_, 'computed_values_border_right_'
	assert actual.computed_layout_cache().computed_values_border_bottom_ == expected.computed_layout_cache().computed_values_border_bottom_, 'computed_values_border_bottom_'
	assert actual.computed_layout_cache().computed_values_has_noninitial_border_radii_ == expected.computed_layout_cache().computed_values_has_noninitial_border_radii_, 'computed_values_has_noninitial_border_radii_'
	assert actual.computed_layout_cache().computed_values_border_bottom_left_radius_ == expected.computed_layout_cache().computed_values_border_bottom_left_radius_, 'computed_values_border_bottom_left_radius_'
	assert actual.computed_layout_cache().computed_values_border_bottom_right_radius_ == expected.computed_layout_cache().computed_values_border_bottom_right_radius_, 'computed_values_border_bottom_right_radius_'
	assert actual.computed_layout_cache().computed_values_border_top_left_radius_ == expected.computed_layout_cache().computed_values_border_top_left_radius_, 'computed_values_border_top_left_radius_'
	assert actual.computed_layout_cache().computed_values_border_top_right_radius_ == expected.computed_layout_cache().computed_values_border_top_right_radius_, 'computed_values_border_top_right_radius_'
	assert actual.computed_layout_cache().computed_values_flex_direction_ == expected.computed_layout_cache().computed_values_flex_direction_, 'computed_values_flex_direction_'
	assert actual.computed_layout_cache().computed_values_flex_wrap_ == expected.computed_layout_cache().computed_values_flex_wrap_, 'computed_values_flex_wrap_'
	assert actual.computed_layout_cache().computed_values_flex_basis_ == expected.computed_layout_cache().computed_values_flex_basis_, 'computed_values_flex_basis_'
	assert actual.computed_layout_cache().computed_values_flex_grow_ == expected.computed_layout_cache().computed_values_flex_grow_, 'computed_values_flex_grow_'
	assert actual.computed_layout_cache().computed_values_flex_shrink_ == expected.computed_layout_cache().computed_values_flex_shrink_, 'computed_values_flex_shrink_'
	assert actual.computed_layout_cache().computed_values_order_ == expected.computed_layout_cache().computed_values_order_, 'computed_values_order_'
	assert actual.computed_layout_cache().computed_values_align_content_ == expected.computed_layout_cache().computed_values_align_content_, 'computed_values_align_content_'
	assert actual.computed_layout_cache().computed_values_align_items_ == expected.computed_layout_cache().computed_values_align_items_, 'computed_values_align_items_'
	assert actual.computed_layout_cache().computed_values_align_self_ == expected.computed_layout_cache().computed_values_align_self_, 'computed_values_align_self_'
	assert actual.computed_layout_cache().computed_values_justify_content_ == expected.computed_layout_cache().computed_values_justify_content_, 'computed_values_justify_content_'
	assert actual.computed_layout_cache().computed_values_justify_items_ == expected.computed_layout_cache().computed_values_justify_items_, 'computed_values_justify_items_'
	assert actual.computed_layout_cache().computed_values_justify_self_ == expected.computed_layout_cache().computed_values_justify_self_, 'computed_values_justify_self_'
	assert actual.computed_layout_cache().computed_values_text_align_ == expected.computed_layout_cache().computed_values_text_align_, 'computed_values_text_align_'
	assert actual.computed_layout_cache().computed_values_text_justify_ == expected.computed_layout_cache().computed_values_text_justify_, 'computed_values_text_justify_'
	assert actual.computed_layout_cache().computed_values_text_transform_ == expected.computed_layout_cache().computed_values_text_transform_, 'computed_values_text_transform_'
	assert actual.computed_layout_cache().computed_values_text_wrap_mode_ == expected.computed_layout_cache().computed_values_text_wrap_mode_, 'computed_values_text_wrap_mode_'
	assert actual.computed_layout_cache().computed_values_white_space_collapse_ == expected.computed_layout_cache().computed_values_white_space_collapse_, 'computed_values_white_space_collapse_'
	assert actual.computed_layout_cache().computed_values_word_break_ == expected.computed_layout_cache().computed_values_word_break_, 'computed_values_word_break_'
	assert actual.computed_layout_cache().computed_values_visibility_ == expected.computed_layout_cache().computed_values_visibility_, 'computed_values_visibility_'
	assert actual.computed_layout_cache().computed_values_box_sizing_ == expected.computed_layout_cache().computed_values_box_sizing_, 'computed_values_box_sizing_'
	assert actual.computed_layout_cache().computed_values_vertical_align_ == expected.computed_layout_cache().computed_values_vertical_align_, 'computed_values_vertical_align_'
	assert actual.computed_layout_cache().computed_values_caption_side_ == expected.computed_layout_cache().computed_values_caption_side_, 'computed_values_caption_side_'
	assert actual.computed_layout_cache().computed_values_content_visibility_ == expected.computed_layout_cache().computed_values_content_visibility_, 'computed_values_content_visibility_'
	assert actual.computed_layout_cache().computed_values_user_select_ == expected.computed_layout_cache().computed_values_user_select_, 'computed_values_user_select_'
	assert actual.computed_layout_cache().computed_values_table_layout_ == expected.computed_layout_cache().computed_values_table_layout_, 'computed_values_table_layout_'
	assert actual.computed_layout_cache().computed_values_border_collapse_ == expected.computed_layout_cache().computed_values_border_collapse_, 'computed_values_border_collapse_'
	assert actual.computed_layout_cache().computed_values_contain_ == expected.computed_layout_cache().computed_values_contain_, 'computed_values_contain_'
	assert actual.computed_layout_cache().computed_values_aspect_ratio_ == expected.computed_layout_cache().computed_values_aspect_ratio_, 'computed_values_aspect_ratio_'
	assert actual.computed_layout_cache().computed_values_column_gap_ == expected.computed_layout_cache().computed_values_column_gap_, 'computed_values_column_gap_'
	assert actual.computed_layout_cache().computed_values_row_gap_ == expected.computed_layout_cache().computed_values_row_gap_, 'computed_values_row_gap_'
	assert actual.computed_layout_cache().computed_values_grid_auto_columns_ == expected.computed_layout_cache().computed_values_grid_auto_columns_, 'computed_values_grid_auto_columns_'
	assert actual.computed_layout_cache().computed_values_grid_auto_rows_ == expected.computed_layout_cache().computed_values_grid_auto_rows_, 'computed_values_grid_auto_rows_'
	assert actual.computed_layout_cache().rare_data().computed_values_grid_template_columns_ == expected.computed_layout_cache().rare_data().computed_values_grid_template_columns_, 'computed_values_grid_template_columns_'
	assert actual.computed_layout_cache().rare_data().computed_values_grid_template_rows_ == expected.computed_layout_cache().rare_data().computed_values_grid_template_rows_, 'computed_values_grid_template_rows_'
	assert actual.computed_layout_cache().rare_data().computed_values_grid_template_areas_ == expected.computed_layout_cache().rare_data().computed_values_grid_template_areas_, 'computed_values_grid_template_areas_'
	assert actual.computed_layout_cache().computed_values_grid_auto_flow_ == expected.computed_layout_cache().computed_values_grid_auto_flow_, 'computed_values_grid_auto_flow_'
	assert actual.computed_layout_cache().computed_values_appearance_ == expected.computed_layout_cache().computed_values_appearance_, 'computed_values_appearance_'
	assert actual.computed_layout_cache().computed_values_opacity_ == expected.computed_layout_cache().computed_values_opacity_, 'computed_values_opacity_'
	assert actual.computed_layout_cache().computed_values_z_index_ == expected.computed_layout_cache().computed_values_z_index_, 'computed_values_z_index_'
	assert actual.computed_layout_cache().computed_values_image_rendering_ == expected.computed_layout_cache().computed_values_image_rendering_, 'computed_values_image_rendering_'
	assert actual.computed_layout_cache().computed_values_pointer_events_ == expected.computed_layout_cache().computed_values_pointer_events_, 'computed_values_pointer_events_'
	assert actual.computed_layout_cache().computed_values_list_style_position_ == expected.computed_layout_cache().computed_values_list_style_position_, 'computed_values_list_style_position_'
	assert actual.computed_layout_cache().computed_values_grid_column_end_ == expected.computed_layout_cache().computed_values_grid_column_end_, 'computed_values_grid_column_end_'
	assert actual.computed_layout_cache().computed_values_grid_column_start_ == expected.computed_layout_cache().computed_values_grid_column_start_, 'computed_values_grid_column_start_'
	assert actual.computed_layout_cache().computed_values_grid_row_end_ == expected.computed_layout_cache().computed_values_grid_row_end_, 'computed_values_grid_row_end_'
	assert actual.computed_layout_cache().computed_values_grid_row_start_ == expected.computed_layout_cache().computed_values_grid_row_start_, 'computed_values_grid_row_start_'
	assert actual.computed_layout_cache().computed_values_column_span_ == expected.computed_layout_cache().computed_values_column_span_, 'computed_values_column_span_'
	assert actual.computed_layout_cache().computed_values_break_after_ == expected.computed_layout_cache().computed_values_break_after_, 'computed_values_break_after_'
	assert actual.computed_layout_cache().computed_values_break_before_ == expected.computed_layout_cache().computed_values_break_before_, 'computed_values_break_before_'
	assert actual.computed_layout_cache().computed_values_break_inside_ == expected.computed_layout_cache().computed_values_break_inside_, 'computed_values_break_inside_'
	assert actual.computed_layout_cache().computed_values_box_decoration_break_ == expected.computed_layout_cache().computed_values_box_decoration_break_, 'computed_values_box_decoration_break_'
	assert actual.computed_layout_cache().computed_values_column_fill_ == expected.computed_layout_cache().computed_values_column_fill_, 'computed_values_column_fill_'
	assert actual.computed_layout_cache().computed_values_block_ellipsis_ == expected.computed_layout_cache().computed_values_block_ellipsis_, 'computed_values_block_ellipsis_'
	assert actual.computed_layout_cache().computed_values_continue_ == expected.computed_layout_cache().computed_values_continue_, 'computed_values_continue_'
	assert actual.computed_layout_cache().computed_values_max_lines_ == expected.computed_layout_cache().computed_values_max_lines_, 'computed_values_max_lines_'
	assert actual.computed_layout_cache().computed_values_webkit_box_orient_ == expected.computed_layout_cache().computed_values_webkit_box_orient_, 'computed_values_webkit_box_orient_'
	assert actual.computed_layout_cache().computed_values_empty_cells_ == expected.computed_layout_cache().computed_values_empty_cells_, 'computed_values_empty_cells_'
	assert actual.computed_layout_cache().computed_values_object_fit_ == expected.computed_layout_cache().computed_values_object_fit_, 'computed_values_object_fit_'
	assert actual.computed_layout_cache().computed_values_object_position_ == expected.computed_layout_cache().computed_values_object_position_, 'computed_values_object_position_'
	assert actual.computed_layout_cache().computed_values_unicode_bidi_ == expected.computed_layout_cache().computed_values_unicode_bidi_, 'computed_values_unicode_bidi_'
	assert actual.computed_layout_cache().computed_values_isolation_ == expected.computed_layout_cache().computed_values_isolation_, 'computed_values_isolation_'
	assert actual.computed_layout_cache().computed_values_mix_blend_mode_ == expected.computed_layout_cache().computed_values_mix_blend_mode_, 'computed_values_mix_blend_mode_'
	assert actual.computed_layout_cache().computed_values_mask_type_ == expected.computed_layout_cache().computed_values_mask_type_, 'computed_values_mask_type_'
	assert actual.computed_layout_cache().computed_values_stop_opacity_ == expected.computed_layout_cache().computed_values_stop_opacity_, 'computed_values_stop_opacity_'
	assert actual.computed_layout_cache().computed_values_fill_opacity_ == expected.computed_layout_cache().computed_values_fill_opacity_, 'computed_values_fill_opacity_'
	assert actual.computed_layout_cache().computed_values_stroke_linecap_ == expected.computed_layout_cache().computed_values_stroke_linecap_, 'computed_values_stroke_linecap_'
	assert actual.computed_layout_cache().computed_values_stroke_linejoin_ == expected.computed_layout_cache().computed_values_stroke_linejoin_, 'computed_values_stroke_linejoin_'
	assert actual.computed_layout_cache().computed_values_stroke_miterlimit_ == expected.computed_layout_cache().computed_values_stroke_miterlimit_, 'computed_values_stroke_miterlimit_'
	assert actual.computed_layout_cache().computed_values_stroke_opacity_ == expected.computed_layout_cache().computed_values_stroke_opacity_, 'computed_values_stroke_opacity_'
	assert actual.computed_layout_cache().computed_values_fill_rule_ == expected.computed_layout_cache().computed_values_fill_rule_, 'computed_values_fill_rule_'
	assert actual.computed_layout_cache().computed_values_clip_rule_ == expected.computed_layout_cache().computed_values_clip_rule_, 'computed_values_clip_rule_'
	assert actual.computed_layout_cache().computed_values_shape_rendering_ == expected.computed_layout_cache().computed_values_shape_rendering_, 'computed_values_shape_rendering_'
	assert actual.computed_layout_cache().computed_values_text_anchor_ == expected.computed_layout_cache().computed_values_text_anchor_, 'computed_values_text_anchor_'
	assert actual.computed_layout_cache().computed_values_outline_offset_ == expected.computed_layout_cache().computed_values_outline_offset_, 'computed_values_outline_offset_'
	assert actual.computed_layout_cache().computed_values_outline_style_ == expected.computed_layout_cache().computed_values_outline_style_, 'computed_values_outline_style_'
	assert actual.computed_layout_cache().computed_values_scrollbar_width_ == expected.computed_layout_cache().computed_values_scrollbar_width_, 'computed_values_scrollbar_width_'
	assert actual.computed_layout_cache().computed_values_resize_ == expected.computed_layout_cache().computed_values_resize_, 'computed_values_resize_'
	assert actual.computed_layout_cache().computed_values_border_spacing_horizontal_ == expected.computed_layout_cache().computed_values_border_spacing_horizontal_, 'computed_values_border_spacing_horizontal_'
	assert actual.computed_layout_cache().computed_values_border_spacing_vertical_ == expected.computed_layout_cache().computed_values_border_spacing_vertical_, 'computed_values_border_spacing_vertical_'
	assert actual.computed_layout_cache().computed_values_color_interpolation_ == expected.computed_layout_cache().computed_values_color_interpolation_, 'computed_values_color_interpolation_'
	assert actual.computed_layout_cache().computed_values_color_interpolation_filters_ == expected.computed_layout_cache().computed_values_color_interpolation_filters_, 'computed_values_color_interpolation_filters_'
	assert actual.computed_layout_cache().computed_values_clip_ == expected.computed_layout_cache().computed_values_clip_, 'computed_values_clip_'
	assert actual.computed_layout_cache().computed_values_cursor_ == expected.computed_layout_cache().computed_values_cursor_, 'computed_values_cursor_'
	assert actual.computed_layout_cache().computed_values_background_color_clip_ == expected.computed_layout_cache().computed_values_background_color_clip_, 'computed_values_background_color_clip_'
	assert actual.computed_layout_cache().computed_values_background_color_ == expected.computed_layout_cache().computed_values_background_color_, 'computed_values_background_color_'
	assert actual.computed_layout_cache().computed_values_background_layers_ == expected.computed_layout_cache().computed_values_background_layers_, 'computed_values_background_layers_'
	assert actual.computed_layout_cache().computed_values_tab_size_ == expected.computed_layout_cache().computed_values_tab_size_, 'computed_values_tab_size_'
	assert actual.computed_layout_cache().computed_values_text_decoration_line_ == expected.computed_layout_cache().computed_values_text_decoration_line_, 'computed_values_text_decoration_line_'
	assert actual.computed_layout_cache().computed_values_text_decoration_skip_ink_ == expected.computed_layout_cache().computed_values_text_decoration_skip_ink_, 'computed_values_text_decoration_skip_ink_'
	assert actual.computed_layout_cache().computed_values_text_decoration_thickness_ == expected.computed_layout_cache().computed_values_text_decoration_thickness_, 'computed_values_text_decoration_thickness_'
	assert actual.computed_layout_cache().computed_values_text_decoration_style_ == expected.computed_layout_cache().computed_values_text_decoration_style_, 'computed_values_text_decoration_style_'
	assert actual.computed_layout_cache().computed_values_text_decoration_color_ == expected.computed_layout_cache().computed_values_text_decoration_color_, 'computed_values_text_decoration_color_'
	assert actual.computed_layout_cache().computed_values_text_indent_ == expected.computed_layout_cache().computed_values_text_indent_, 'computed_values_text_indent_'
	assert actual.computed_layout_cache().computed_values_text_overflow_ == expected.computed_layout_cache().computed_values_text_overflow_, 'computed_values_text_overflow_'
	assert actual.computed_layout_cache().computed_values_text_underline_offset_ == expected.computed_layout_cache().computed_values_text_underline_offset_, 'computed_values_text_underline_offset_'
	assert actual.computed_layout_cache().computed_values_text_underline_position_ == expected.computed_layout_cache().computed_values_text_underline_position_, 'computed_values_text_underline_position_'
	assert actual.computed_layout_cache().computed_values_white_space_trim_ == expected.computed_layout_cache().computed_values_white_space_trim_, 'computed_values_white_space_trim_'
	assert actual.computed_layout_cache().computed_values_word_spacing_ == expected.computed_layout_cache().computed_values_word_spacing_, 'computed_values_word_spacing_'
	assert actual.computed_layout_cache().computed_values_letter_spacing_ == expected.computed_layout_cache().computed_values_letter_spacing_, 'computed_values_letter_spacing_'
	assert actual.computed_layout_cache().rare_data().computed_values_backdrop_filter_ == expected.computed_layout_cache().rare_data().computed_values_backdrop_filter_, 'computed_values_backdrop_filter_'
	assert actual.computed_layout_cache().rare_data().computed_values_filter_ == expected.computed_layout_cache().rare_data().computed_values_filter_, 'computed_values_filter_'
	assert actual.computed_layout_cache().rare_data().computed_values_rotate_ == expected.computed_layout_cache().rare_data().computed_values_rotate_, 'computed_values_rotate_'
	assert actual.computed_layout_cache().rare_data().computed_values_scale_ == expected.computed_layout_cache().rare_data().computed_values_scale_, 'computed_values_scale_'
	assert actual.computed_layout_cache().rare_data().computed_values_perspective_ == expected.computed_layout_cache().rare_data().computed_values_perspective_, 'computed_values_perspective_'
	assert actual.computed_layout_cache().rare_data().computed_values_perspective_origin_ == expected.computed_layout_cache().rare_data().computed_values_perspective_origin_, 'computed_values_perspective_origin_'
	assert actual.computed_layout_cache().rare_data().computed_values_transformations_ == expected.computed_layout_cache().rare_data().computed_values_transformations_, 'computed_values_transformations_'
	assert actual.computed_layout_cache().rare_data().computed_values_transform_box_ == expected.computed_layout_cache().rare_data().computed_values_transform_box_, 'computed_values_transform_box_'
	assert actual.computed_layout_cache().rare_data().computed_values_transform_origin_ == expected.computed_layout_cache().rare_data().computed_values_transform_origin_, 'computed_values_transform_origin_'
	assert actual.computed_layout_cache().rare_data().computed_values_transform_style_ == expected.computed_layout_cache().rare_data().computed_values_transform_style_, 'computed_values_transform_style_'
	assert actual.computed_layout_cache().computed_values_backface_visibility_ == expected.computed_layout_cache().computed_values_backface_visibility_, 'computed_values_backface_visibility_'
	assert actual.computed_layout_cache().rare_data().computed_values_translate_ == expected.computed_layout_cache().rare_data().computed_values_translate_, 'computed_values_translate_'
	assert actual.computed_layout_cache().computed_values_quotes_ == expected.computed_layout_cache().computed_values_quotes_, 'computed_values_quotes_'
	assert actual.computed_layout_cache().computed_values_dominant_baseline_ == expected.computed_layout_cache().computed_values_dominant_baseline_, 'computed_values_dominant_baseline_'
	assert actual.computed_layout_cache().computed_values_container_name_ == expected.computed_layout_cache().computed_values_container_name_, 'computed_values_container_name_'
	assert actual.computed_layout_cache().computed_values_container_type_ == expected.computed_layout_cache().computed_values_container_type_, 'computed_values_container_type_'
	if actual_value := actual.computed_layout_cache().computed_values_view_transition_name_ {
		expected_value := expected.computed_layout_cache().computed_values_view_transition_name_ or {
			panic('missing computed_values_view_transition_name_')
		}

		assert actual_value == expected_value
	} else {
		assert expected.computed_layout_cache().computed_values_view_transition_name_ == none
	}
	assert actual.computed_layout_cache().computed_values_touch_action_ == expected.computed_layout_cache().computed_values_touch_action_, 'computed_values_touch_action_'
	assert actual.computed_layout_cache().computed_values_stroke_dasharray_ == expected.computed_layout_cache().computed_values_stroke_dasharray_, 'computed_values_stroke_dasharray_'
	assert actual.computed_layout_cache().computed_values_flood_opacity_ == expected.computed_layout_cache().computed_values_flood_opacity_, 'computed_values_flood_opacity_'
	assert actual.computed_layout_cache().computed_values_paint_order_ == expected.computed_layout_cache().computed_values_paint_order_, 'computed_values_paint_order_'
	assert actual.computed_layout_cache().computed_values_math_shift_ == expected.computed_layout_cache().computed_values_math_shift_, 'computed_values_math_shift_'
	assert actual.computed_layout_cache().computed_values_math_style_ == expected.computed_layout_cache().computed_values_math_style_, 'computed_values_math_style_'
	assert actual.computed_layout_cache().computed_values_math_depth_ == expected.computed_layout_cache().computed_values_math_depth_, 'computed_values_math_depth_'
	assert actual.computed_layout_cache().computed_values_will_change_ == expected.computed_layout_cache().computed_values_will_change_, 'computed_values_will_change_'
	assert actual.computed_layout_cache().computed_values_stroke_dashoffset_ == expected.computed_layout_cache().computed_values_stroke_dashoffset_, 'computed_values_stroke_dashoffset_'
	assert actual.computed_layout_cache().computed_values_stroke_width_ == expected.computed_layout_cache().computed_values_stroke_width_, 'computed_values_stroke_width_'
	assert actual.computed_layout_cache().rare_data().computed_values_cx_ == expected.computed_layout_cache().rare_data().computed_values_cx_, 'computed_values_cx_'
	assert actual.computed_layout_cache().rare_data().computed_values_cy_ == expected.computed_layout_cache().rare_data().computed_values_cy_, 'computed_values_cy_'
	assert actual.computed_layout_cache().rare_data().computed_values_r_ == expected.computed_layout_cache().rare_data().computed_values_r_, 'computed_values_r_'
	assert actual.computed_layout_cache().computed_values_rx_ == expected.computed_layout_cache().computed_values_rx_, 'computed_values_rx_'
	assert actual.computed_layout_cache().computed_values_ry_ == expected.computed_layout_cache().computed_values_ry_, 'computed_values_ry_'
	assert actual.computed_layout_cache().rare_data().computed_values_x_ == expected.computed_layout_cache().rare_data().computed_values_x_, 'computed_values_x_'
	assert actual.computed_layout_cache().rare_data().computed_values_y_ == expected.computed_layout_cache().rare_data().computed_values_y_, 'computed_values_y_'
	assert actual.computed_layout_cache().computed_values_column_count_ == expected.computed_layout_cache().computed_values_column_count_, 'computed_values_column_count_'
	assert actual.computed_layout_cache().computed_values_column_width_ == expected.computed_layout_cache().computed_values_column_width_, 'computed_values_column_width_'
	assert actual.computed_layout_cache().computed_values_column_height_ == expected.computed_layout_cache().computed_values_column_height_, 'computed_values_column_height_'
	assert actual.computed_layout_cache().computed_values_column_rule_color_ == expected.computed_layout_cache().computed_values_column_rule_color_, 'computed_values_column_rule_color_'
	assert actual.computed_layout_cache().computed_values_column_rule_style_ == expected.computed_layout_cache().computed_values_column_rule_style_, 'computed_values_column_rule_style_'
	assert actual.computed_layout_cache().computed_values_column_rule_width_ == expected.computed_layout_cache().computed_values_column_rule_width_, 'computed_values_column_rule_width_'
	assert actual.computed_layout_cache().computed_values_outline_width_ == expected.computed_layout_cache().computed_values_outline_width_, 'computed_values_outline_width_'
	assert actual.computed_layout_cache().computed_values_transition_delay_ == expected.computed_layout_cache().computed_values_transition_delay_, 'computed_values_transition_delay_'
	assert actual.computed_layout_cache().computed_values_webkit_text_fill_color_ == expected.computed_layout_cache().computed_values_webkit_text_fill_color_, 'computed_values_webkit_text_fill_color_'
	assert actual.computed_layout_cache().computed_values_stop_color_ == expected.computed_layout_cache().computed_values_stop_color_, 'computed_values_stop_color_'
	assert actual.computed_layout_cache().computed_values_flood_color_ == expected.computed_layout_cache().computed_values_flood_color_, 'computed_values_flood_color_'
	assert actual.computed_layout_cache().computed_values_outline_color_ == expected.computed_layout_cache().computed_values_outline_color_, 'computed_values_outline_color_'
	assert actual.computed_layout_cache().computed_values_fill_ == expected.computed_layout_cache().computed_values_fill_, 'computed_values_fill_'
	assert actual.computed_layout_cache().computed_values_stroke_ == expected.computed_layout_cache().computed_values_stroke_, 'computed_values_stroke_'
	assert actual.computed_layout_cache().rare_data().computed_values_mask_ == expected.computed_layout_cache().rare_data().computed_values_mask_, 'computed_values_mask_'
	assert actual.computed_layout_cache().rare_data().computed_values_mask_image_ == expected.computed_layout_cache().rare_data().computed_values_mask_image_, 'computed_values_mask_image_'
	assert actual.computed_layout_cache().rare_data().computed_values_clip_path_ == expected.computed_layout_cache().rare_data().computed_values_clip_path_, 'computed_values_clip_path_'
	assert actual.computed_layout_cache().computed_values_text_shadow_ == expected.computed_layout_cache().computed_values_text_shadow_, 'computed_values_text_shadow_'
	assert actual.computed_layout_cache().computed_values_box_shadow_ == expected.computed_layout_cache().computed_values_box_shadow_, 'computed_values_box_shadow_'
	assert actual.computed_layout_cache().computed_values_scrollbar_color_ == expected.computed_layout_cache().computed_values_scrollbar_color_, 'computed_values_scrollbar_color_'
	assert actual.computed_layout_cache().computed_values_counter_increment_ == expected.computed_layout_cache().computed_values_counter_increment_, 'computed_values_counter_increment_'
	assert actual.computed_layout_cache().computed_values_counter_reset_ == expected.computed_layout_cache().computed_values_counter_reset_, 'computed_values_counter_reset_'
	assert actual.computed_layout_cache().computed_values_counter_set_ == expected.computed_layout_cache().computed_values_counter_set_, 'computed_values_counter_set_'
	assert actual.computed_values_line_height_ == expected.computed_values_line_height_
	assert actual.computed_values_list_style_type_ == expected.computed_values_list_style_type_
	assert actual.computed_values_content_ == expected.computed_values_content_
	assert actual.computed_values_resolved_ == expected.computed_values_resolved_
	assert actual.cached_computed_font_list_owner_ == expected.cached_computed_font_list_owner_
	assert actual.cached_computed_font_list_generation_ == expected.cached_computed_font_list_generation_
	assert actual.cached_first_available_computed_font_ == expected.cached_first_available_computed_font_
	assert voidptr(actual.font_list()) == voidptr(expected.font_list())
	assert actual.viewport_rect_ == expected.viewport_rect_
	assert actual.root_font_size_px_ == expected.root_font_size_px_
	assert actual.root_line_height_px_ == expected.root_line_height_px_
	assert actual.root_font_metrics_depend_on_viewport_metrics_ == expected.root_font_metrics_depend_on_viewport_metrics_
	assert actual.property_inherited_ == expected.property_inherited_
	assert actual.property_important_ == expected.property_important_
	assert actual.display_before_box_type_transformation_ == expected.display_before_box_type_transformation_
	for property_id in computed_interpolation_longhand_property_ids() {
		a := actual.property(property_id, .yes) or { panic('missing actual') }
		b := expected.property(property_id, .yes) or { panic('missing expected') }
		assert a.css_text == b.css_text
	}
	assert actual.computed_layout_cache().writable_owner_identity == 0
}

fn anonymous_geometry_check(source &ComputedProperties, document &dom.Document) {
	ordinary_clone := source.clone_for_anonymous_block()
	expected := resolve_computed_values_for_document(ordinary_clone, document)
	actual := resolve_anonymous_block_values_for_document(source, document)
	anonymous_geometry_assert_same(actual, expected)
}

fn test_anonymous_geometry_matches_full_materialization_for_default_and_rich_inherited_styles() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := ComputedProperties.new()
	_ = resolve_computed_values_for_document(source, document)
	anonymous_geometry_check(source, document)
	anonymous_geometry_set(mut source, .font_family, 'serif')
	anonymous_geometry_set(mut source, .font_size, '19px')
	anonymous_geometry_set(mut source, .font_weight, '700')
	anonymous_geometry_set(mut source, .line_height, '1.6')
	anonymous_geometry_set(mut source, .font_language_override, '"TRK"')
	anonymous_geometry_set(mut source, .font_variation_settings, '"wght" 650')
	anonymous_geometry_set(mut source, .font_feature_settings, '"liga" 0')
	anonymous_geometry_set(mut source, .direction, 'rtl')
	anonymous_geometry_set(mut source, .writing_mode, 'vertical-rl')
	anonymous_geometry_set(mut source, .color, 'rgb(12, 34, 56)')
	anonymous_geometry_set(mut source, .color_scheme, 'dark')
	anonymous_geometry_set(mut source, .accent_color, 'red')
	anonymous_geometry_set(mut source, .caret_color, 'currentcolor')
	anonymous_geometry_set(mut source, .webkit_text_fill_color, 'currentcolor')
	anonymous_geometry_set(mut source, .border_collapse, 'collapse')
	anonymous_geometry_set(mut source, .border_spacing, '7px 11px')
	anonymous_geometry_set(mut source, .caption_side, 'bottom')
	anonymous_geometry_set(mut source, .empty_cells, 'hide')
	anonymous_geometry_set(mut source, .visibility, 'hidden')
	anonymous_geometry_set(mut source, .image_rendering, 'pixelated')
	anonymous_geometry_set(mut source, .pointer_events, 'none')
	anonymous_geometry_set(mut source, .list_style_position, 'inside')
	anonymous_geometry_set(mut source, .list_style_type, 'upper-roman')
	anonymous_geometry_set(mut source, .quotes, '"a" "b"')
	anonymous_geometry_set(mut source, .text_align, 'center')
	anonymous_geometry_set(mut source, .text_justify, 'inter-character')
	anonymous_geometry_set(mut source, .text_transform, 'uppercase')
	anonymous_geometry_set(mut source, .text_wrap_mode, 'nowrap')
	anonymous_geometry_set(mut source, .white_space_collapse, 'preserve')
	anonymous_geometry_set(mut source, .word_break, 'break-all')
	anonymous_geometry_set(mut source, .tab_size, '6')
	anonymous_geometry_set(mut source, .letter_spacing, '3px')
	anonymous_geometry_set(mut source, .word_spacing, '5px')
	anonymous_geometry_set(mut source, .text_indent, '9px')
	anonymous_geometry_set(mut source, .text_shadow, '2px 3px 4px currentcolor')
	anonymous_geometry_set(mut source, .text_decoration_line, 'underline overline')
	anonymous_geometry_set(mut source, .text_decoration_style, 'wavy')
	anonymous_geometry_set(mut source, .text_decoration_thickness, '3px')
	anonymous_geometry_set(mut source, .text_decoration_color, 'rgb(120, 50, 20)')
	anonymous_geometry_set(mut source, .text_decoration_skip_ink, 'none')
	anonymous_geometry_set(mut source, .text_underline_offset, '7px')
	anonymous_geometry_set(mut source, .text_underline_position, 'under')
	anonymous_geometry_set(mut source, .fill, 'currentcolor')
	anonymous_geometry_set(mut source, .stroke, 'blue')
	anonymous_geometry_set(mut source, .fill_opacity, '.4')
	anonymous_geometry_set(mut source, .stroke_opacity, '.6')
	anonymous_geometry_set(mut source, .stroke_linecap, 'round')
	anonymous_geometry_set(mut source, .stroke_linejoin, 'bevel')
	anonymous_geometry_set(mut source, .stroke_miterlimit, '8')
	anonymous_geometry_set(mut source, .fill_rule, 'evenodd')
	anonymous_geometry_set(mut source, .clip_rule, 'evenodd')
	anonymous_geometry_set(mut source, .shape_rendering, 'crispEdges')
	anonymous_geometry_set(mut source, .text_anchor, 'middle')
	anonymous_geometry_set(mut source, .dominant_baseline, 'middle')
	anonymous_geometry_set(mut source, .stroke_dasharray, '3px 7px')
	anonymous_geometry_set(mut source, .stroke_dashoffset, '4px')
	anonymous_geometry_set(mut source, .stroke_width, '5px')
	anonymous_geometry_set(mut source, .paint_order, 'stroke fill')
	anonymous_geometry_set(mut source, .color_interpolation, 'linearRGB')
	anonymous_geometry_set(mut source, .color_interpolation_filters, 'sRGB')
	anonymous_geometry_set(mut source, .math_style, 'compact')
	anonymous_geometry_set(mut source, .math_shift, 'compact')
	anonymous_geometry_set(mut source, .math_depth, '2')
	anonymous_geometry_set(mut source, .block_ellipsis, '"more"')
	anonymous_geometry_set(mut source, .scrollbar_color, 'red blue')
	anonymous_geometry_set(mut source, .width, '123px')
	anonymous_geometry_set(mut source, .height, '91px')
	anonymous_geometry_set(mut source, .margin_left, '23px')
	anonymous_geometry_set(mut source, .padding_left, '17px')
	anonymous_geometry_set(mut source, .background_color, 'red')
	anonymous_geometry_set(mut source, .border_left_width, '9px')
	anonymous_geometry_set(mut source, .border_left_style, 'solid')
	anonymous_geometry_set(mut source, .border_left_color, 'green')
	anonymous_geometry_set(mut source, .outline_color, 'green')
	anonymous_geometry_set(mut source, .column_rule_color, 'blue')
	anonymous_geometry_set(mut source, .opacity, '.2')
	anonymous_geometry_set(mut source, .position, 'relative')
	anonymous_geometry_set(mut source, .content_visibility, 'hidden')
	anonymous_geometry_set(mut source, .display, 'inline-flex')
	anonymous_geometry_set(mut source, .transform, 'translateX(33px)')
	source.viewport_rect_ = CSSPixelRect.new(0, 0, 1100, 720)
	source.root_font_size_px_ = 21
	source.root_line_height_px_ = 29
	source.root_font_metrics_depend_on_viewport_metrics_ = true
	_ = resolve_computed_values_for_document(source, document)
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) != none
	anonymous_geometry_check(source, document)
}

fn test_anonymous_geometry_preserves_full_resolver_for_unresolved_and_animated_sources() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := ComputedProperties.new()
	anonymous_geometry_set(mut source, .font_size, '23px')
	anonymous_geometry_set(mut source, .color, 'purple')
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.set_animated_property(.font_size, &dom.StyleValue{
		css_text: '40px'
	}, .no, .no)
	source.set_animated_property(.color, &dom.StyleValue{
		css_text: 'red'
	}, .no, .no)
	_ = resolve_computed_values_for_document(source, document)
	anonymous_geometry_check(source, document)
}

fn test_anonymous_geometry_preserves_relative_units_normal_metrics_and_cache_lifetimes() {
	document := dom.Document.create(dom.url_about_blank())
	for size in ['13px', '27px'] {
		mut source := ComputedProperties.new()
		anonymous_geometry_set(mut source, .font_size, size)
		anonymous_geometry_set(mut source, .line_height, 'normal')
		anonymous_geometry_set(mut source, .letter_spacing, '0.2em')
		anonymous_geometry_set(mut source, .word_spacing, '1rem')
		anonymous_geometry_set(mut source, .text_underline_offset, '1ex')
		anonymous_geometry_set(mut source, .text_shadow, '1em 2px 0 currentcolor')
		source.viewport_rect_ = CSSPixelRect.new(0, 0, 900, 700)
		source.root_font_size_px_ = 21
		source.root_line_height_px_ = 29
		_ = resolve_computed_values_for_document(source, document)
		anonymous_geometry_check(source, document)
		retained := resolve_anonymous_block_values_for_document(source, document)
		original_color := retained.color()
		original_size := retained.font_size()
		retained.share_computed_layout_cache()
		mut copied := *retained
		mut mutable_original := unsafe { &MutableComputedValues(retained) }
		mutable_original.set_color(Color{5, 6, 7, 255})
		assert copied.color() == original_color
		mut mutable_copy := unsafe { &MutableComputedValues(&copied) }
		mutable_copy.set_font_size(CSSPixels.new(72))
		assert retained.font_size() == original_size
		anonymous_geometry_set(mut source, .color, 'yellow')
		_ = resolve_computed_values_for_document(source, document)
		gc_collect()
		assert copied.color() == original_color
		assert retained.font_size() == original_size
		anonymous_geometry_check(source, document)
	}
}

fn test_anonymous_geometry_keeps_font_environment_refresh_and_explicit_metrics_fallback() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := ComputedProperties.new()
	anonymous_geometry_set(mut source, .font_size, '21px')
	_ = resolve_computed_values_for_document(source, document)
	source.line_height_ = CSSPixels.new(47)
	_ = resolve_computed_values_for_document(source, document)
	anonymous_geometry_check(source, document)
	source.line_height_ = none
	_ = resolve_computed_values_for_document(source, document)
	mut computer := css_style_computer_for(document).font_computer()
	computer.clear_computed_font_cache('serif')
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	anonymous_geometry_check(source, document)
}

fn anonymous_geometry_resolved_source(document &dom.Document) &ComputedProperties {
	mut source := computed_properties_with_initial_values()
	anonymous_geometry_set(mut source, .font_family, 'serif')
	anonymous_geometry_set(mut source, .font_size, '19px')
	_ = resolve_computed_values_for_document(source, document)
	assert source.computed_layout_cache().resolution_provenance != unsafe { nil }
	return source
}

fn test_anonymous_geometry_provenance_tracks_raw_aliases_created_before_and_after_resolution() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := computed_properties_with_initial_values()
	mut earlier_copy := *source
	_ = resolve_computed_values_for_document(source, document)
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) != none
	anonymous_geometry_set(mut earlier_copy, .text_align, 'right')
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	mut later_copy := *source
	anonymous_geometry_set(mut later_copy, .text_transform, 'uppercase')
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	mut revert_style := computed_properties_with_initial_values()
	anonymous_geometry_set(mut revert_style, .direction, 'rtl')
	source.revert_property(.direction, revert_style)
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
}

fn test_anonymous_geometry_provenance_is_cleared_by_typed_overrides_and_animation_removal() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := anonymous_geometry_resolved_source(document)
	provenance := source.computed_layout_cache().resolution_provenance
	_ = resolve_computed_values_for_document(source, document)
	assert voidptr(provenance) == voidptr(source.computed_layout_cache().resolution_provenance)
	mut typed := unsafe { &MutableComputedValues(source) }
	typed.set_direction(.rtl)
	assert source.computed_layout_cache().resolution_provenance == unsafe { nil }
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.set_animated_property(.text_align, &dom.StyleValue{
		css_text: 'center'
	}, .no, .no)
	_ = resolve_computed_values_for_document(source, document)
	source.remove_animated_property(.text_align)
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.set_animated_property(.direction, &dom.StyleValue{
		css_text: 'rtl'
	}, .no, .no)
	_ = resolve_computed_values_for_document(source, document)
	source.reset_non_inherited_animated_properties()
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
}

fn test_anonymous_geometry_provenance_checks_root_viewport_and_subject_context() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := anonymous_geometry_resolved_source(document)
	source.viewport_rect_ = CSSPixelRect.new(0, 0, 1200, 800)
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.root_font_size_px_ = 27
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.root_line_height_px_ = 39
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.root_font_metrics_depend_on_viewport_metrics_ = true
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	source.subject_element_ = document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) == none
	anonymous_geometry_check(source, document)
}

fn test_anonymous_geometry_callback_mutations_preserve_the_original_clone_boundary() {
	document := dom.Document.create(dom.url_about_blank())
	mut source := anonymous_geometry_resolved_source(document)
	// A font-discovery callback during a preceding child can change a parent's
	// nonfont property without changing its selected font list or generation.
	before_clone := fn [source] () {
		mut parent := unsafe { &ComputedProperties(source) }
		anonymous_geometry_set(mut parent, .text_transform, 'uppercase')
	}
	before_clone()
	anonymous_geometry_check(source, document)
	_ = resolve_computed_values_for_document(source, document)
	clone := source.clone_for_anonymous_block()
	snapshot := source.anonymous_computed_geometry_source(clone)
	assert snapshot != none
	old_geometry := source.computed_layout_cache()
	// A callback after the raw clone can also rematerialize the parent. The
	// clone must keep the old, immutable geometry captured with its old graph.
	after_clone := fn [source, document] () {
		mut parent := unsafe { &ComputedProperties(source) }
		anonymous_geometry_set(mut parent, .text_transform, 'lowercase')
		anonymous_geometry_set(mut parent, .text_align, 'right')
		_ = resolve_computed_values_for_document(parent, document)
	}
	after_clone()
	gc_collect()
	actual := resolve_computed_values_for_document_impl(clone, document, snapshot)
	ordinary := clone.clone_for_anonymous_block()
	expected := resolve_computed_values_for_document(ordinary, document)
	anonymous_geometry_assert_same(actual, expected)
	assert old_geometry.computed_values_text_transform_ == .uppercase
	assert source.computed_layout_cache().computed_values_text_transform_ == .lowercase
	assert actual.computed_layout_cache().computed_values_text_transform_ == .uppercase
}

fn anonymous_geometry_container_fixture() (&dom.Document, &dom.Element, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 900, 700})
	mut container := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic('${err}')
	}
	container.set_attribute_value('style', 'container-type: size')
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic('${err}')
	}
	subject.set_attribute_value('style',
		'font-family: serif; text-indent: 10cqw; letter-spacing: 1cqh; stroke-width: 5cqh; stroke-dashoffset: 3cqi; text-decoration-thickness: 2cqmax')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(container.as_node()) or { panic('${err}') }
	mut container_node := container.as_node()
	container_node.append_child(subject.as_node()) or { panic('${err}') }
	computer := StyleComputer.new(document)
	container_computed := computer.compute_style(dom.AbstractElement.new(container, none))
	container.set_computed_properties(none, computed_properties_to_dom(container_computed))
	container_node.set_layout_node(&dom.LayoutNode{
		dom_node_:       container.as_node()
		has_geometry_:   true
		content_width_:  400
		content_height_: 250
	})
	computed := computer.compute_style(dom.AbstractElement.new(subject, none))
	subject.set_computed_properties(none, computed_properties_to_dom(computed))
	return document, container, computed
}

fn test_anonymous_geometry_preserves_container_lengths_when_the_container_resizes() {
	document, container, initial_source := anonymous_geometry_container_fixture()
	mut source := unsafe { &ComputedProperties(initial_source) }
	// The normal cascade already freezes container units into computed pixels.
	assert !(source.property(.text_indent, .no) or { panic('missing indent') }).css_text.contains('cq')
	_ = resolve_computed_values_for_document(source, document)
	geometry := container.as_node().layout_node() or { panic('missing container geometry') }
	mut mutable_geometry := unsafe { &dom.LayoutNode(geometry) }
	mutable_geometry.content_width_ = 800
	mutable_geometry.content_height_ = 500
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) != none
	anonymous_geometry_check(source, document)

	// Lower-level callers can retain unresolved container lengths. These fields
	// keep their Length/LengthPercentage payload until each used-value query.
	anonymous_geometry_set(mut source, .text_indent, '10cqw')
	anonymous_geometry_set(mut source, .stroke_width, '5cqh')
	anonymous_geometry_set(mut source, .stroke_dashoffset, '3cqi')
	anonymous_geometry_set(mut source, .text_decoration_thickness, '2cqmax')
	anonymous_geometry_set(mut source, .border_spacing, '1cqw 2cqh')
	anonymous_geometry_set(mut source, .tab_size, '3cqi')
	anonymous_geometry_set(mut source, .letter_spacing, '1cqw')
	anonymous_geometry_set(mut source, .text_underline_offset, '2cqh')
	_ = resolve_computed_values_for_document(source, document)
	zero := CSSPixels.new(0)
	assert source.computed_layout_cache().computed_values_text_indent_.length_percentage.to_px(source.length_resolution_context(),
		zero).to_double() == 80
	mutable_geometry.content_width_ = 1200
	mutable_geometry.content_height_ = 700
	assert source.anonymous_computed_geometry_source(source.clone_for_anonymous_block()) != none
	anonymous_geometry_check(source, document)
	actual := resolve_anonymous_block_values_for_document(source, document)
	context := actual.length_resolution_context()
	assert actual.computed_layout_cache().computed_values_text_indent_.length_percentage.to_px(context,
		zero).to_double() == 120
	assert actual.computed_layout_cache().computed_values_stroke_width_.to_px(context, zero).to_double() == 35
	assert actual.computed_layout_cache().computed_values_stroke_dashoffset_.to_px(context, zero).to_double() == 36
	assert actual.computed_layout_cache().computed_values_border_spacing_horizontal_.to_px(context).to_double() == 12
	assert actual.computed_layout_cache().computed_values_border_spacing_vertical_.to_px(context).to_double() == 14
}
