module css

fn test_generated_property_bounds_reject_unaccepted_dimension_types() {
	assert !property_accepts_angle(.color, Angle.make_degrees(1))
	assert !property_accepts_flex(.width, Flex.make_fr(1))
	assert !property_accepts_frequency(.font_size, Frequency.make_hertz(440))
	assert !property_accepts_resolution(.background_image, Resolution.make_dots_per_pixel(2))
	assert !property_accepts_length(.color, Length.make_px(1))
	assert !property_accepts_number(.width, 1)
	assert !property_accepts_percentage(.color, Percentage.new(50))
	assert !property_accepts_integer(.color, 1)
	assert !property_accepts_time(.color, Time.make_seconds(1))
}

fn test_generated_property_bounds_match_upstream_ranges() {
	assert property_accepts_length(.margin_left, Length.make_px(-1))
	assert !property_accepts_length(.width, Length.make_px(-1))
	assert property_accepts_length(.width, Length.make_px(0))

	assert property_accepts_percentage(.margin_left, Percentage.new(-1))
	assert !property_accepts_percentage(.width, Percentage.new(-1))
	assert property_accepts_percentage(.width, Percentage.new(0))

	assert property_accepts_integer(.z_index, -1)
	assert !property_accepts_integer(.column_count, 0)
	assert property_accepts_integer(.column_count, 1)

	assert property_accepts_time(.animation_delay, Time.make_seconds(-1))
	assert !property_accepts_time(.animation_duration, Time.make_seconds(-1))
	assert property_accepts_time(.animation_duration, Time.make_seconds(0))
}

fn test_generated_property_type_sets_match_properties_json() {
	assert property_accepts_type(.opacity, .opacity)
	assert !property_accepts_type(.opacity, .number)
	assert property_accepts_type(.clip, .rect)
	assert property_accepts_type(.background_position, .background_position)
	assert property_accepts_type(.translate, .length)
	assert property_accepts_type(.translate, .percentage)
	assert !property_accepts_type(.translate, .transform_function)
	assert !property_accepts_type(.rotate, .transform_function)
	assert property_accepts_type(.font_feature_settings, .integer)
	assert property_accepts_type(.font_feature_settings, .opentype_tag)
	// Logical aliases inherit their physical property's grammar in the C++
	// PropertyID generator before these tables are emitted.
	assert property_accepts_type(.block_size, .length)
	assert property_accepts_type(.block_size, .percentage)
}

fn test_generated_property_keyword_sets_match_properties_and_enums_json() {
	assert property_accepts_keyword(.width, .auto)
	assert property_accepts_keyword(.display, .block)
	assert property_accepts_keyword(.overflow_x, .overlay)
	assert !property_accepts_keyword(.width, .block)
	// CSS-wide keywords are handled before the property-specific generated
	// check, just as they are by StyleValue::is_css_wide_keyword upstream.
	assert !property_accepts_keyword(.width, .inherit)
}

fn test_generated_property_quirks_match_properties_json() {
	assert property_has_quirk(.width, .unitless_length)
	assert property_has_quirk(.clip, .unitless_length)
	assert !property_has_quirk(.opacity, .unitless_length)

	assert property_has_quirk(.color, .hashless_hex_color)
	assert property_has_quirk(.border_top_color, .hashless_hex_color)
	assert !property_has_quirk(.background_image, .hashless_hex_color)

	// PropertyID.cpp removes quirks while replacing a logical alias with the
	// physical property's value grammar.
	assert !property_has_quirk(.inline_size, .unitless_length)
}

fn test_custom_ident_acceptance_uses_generated_type_and_blacklist_metadata() {
	assert property_accepts_custom_ident(.animation_name, 'fade')
	assert !property_accepts_custom_ident(.animation_name, 'none')
	assert !property_accepts_custom_ident(.animation_name, 'default')
	assert property_accepts_custom_ident(.transition_property, 'opacity')
	assert !property_accepts_custom_ident(.transition_property, 'none')
	assert !property_accepts_custom_ident(.color, 'brand')

	// Dashed identifiers temporarily share CustomIdentStyleValue in this port;
	// their legality still comes from the generated ValueType table.
	assert property_accepts_custom_ident(.anchor_name, '--card')
	assert !property_accepts_custom_ident(.anchor_name, 'card')
}

fn test_property_name_lookup_and_aliases_are_generated_from_properties_json() {
	assert (property_id_from_string('WIDTH') or { panic('missing width') }) == .width
	assert (property_id_from_string('-webkit-transform') or { panic('missing alias') }) == .transform
	assert (property_id_from_string('font-stretch') or { panic('missing alias') }) == .font_width
	assert (property_id_from_string('-webkit-text-fill-color') or {
		panic('missing property')
	}) == .webkit_text_fill_color
	assert (property_id_from_string('corner-inline-end-shape') or {
		panic('missing property')
	}) == .corner_inline_end_shape
	assert property_id_from_string('definitely-not-a-property') == none

	alias := PropertyNameAndID.from_name('-WEBKIT-TRANSFORM') or { panic('missing alias') }
	assert alias.name() == 'transform'
	assert (alias.id() or { panic('missing alias id') }) == .transform
	custom := PropertyNameAndID.from_name('--Brand') or { panic('missing custom property') }
	assert custom.name() == '--Brand'
	assert custom.is_custom_property()
}

fn test_generated_property_behavior_metadata_matches_property_id_generator() {
	assert is_inherited_property(.color)
	assert is_inherited_property(.font_family)
	assert !is_inherited_property(.width)
	assert property_initial_value_string(.border_block_end_color) == 'currentcolor'
	assert property_initial_value_string(.overflow_block) == 'visible'
	assert property_initial_value_string(.background) == 'transparent'

	assert property_multiplicity(.animation_duration) == .coordinating_list
	assert property_multiplicity(.filter) == .list
	assert property_multiplicity(.width) == .single
	assert property_is_list_valued(.backdrop_filter)
	assert property_is_list_valued(.filter)
	assert property_is_single_valued(.width)

	assert property_maximum_value_count(.border_image_width) == 4
	assert property_maximum_value_count(.transform_origin) == 3
	assert property_maximum_value_count(.touch_action) == 2
	assert property_maximum_value_count(.width) == 1

	assert property_affects_layout(.width)
	assert !property_affects_layout(.background_color)
	assert !property_affects_layout(.border_block_end_color)
	assert property_affects_stacking_context(.filter)
	assert property_affects_stacking_context(.backdrop_filter)
	assert property_affects_stacking_context(.clip_path)
	assert !property_affects_stacking_context(.background_color)

	assert animation_type_from_longhand_property(.border_block_end_color) == .by_computed_value
	assert animation_type_from_longhand_property(.overflow_block) == .discrete
	assert animation_type_from_longhand_property(.object_position) == .repeatable_list
	assert is_animatable_property(.margin)
	assert is_animatable_property(.all)
	assert !is_animatable_property(.animation)
	assert !is_animatable_property(.direction)

	assert property_requires_computation_with_inherited_value(.background_attachment)
	assert !property_requires_computation_with_inherited_value(.background_color)
	assert property_requires_computation_with_initial_value(.background_color)
	assert !property_requires_computation_with_initial_value(.font_style)
	assert !property_requires_computation_with_initial_value(.math_depth)
	assert !property_requires_computation_with_initial_value(.text_decoration_color)
	assert property_requires_computation_with_cascaded_value(.font_style)
	assert property_requires_computation_with_cascaded_value(.block_size)

	assert property_is_positional_value_list_shorthand(.margin)
	assert property_is_positional_value_list_shorthand(.border_block_color)
	assert !property_is_positional_value_list_shorthand(.background)
}

fn test_legacy_value_aliases_use_generated_property_specific_metadata() {
	assert (resolve_legacy_value_alias(.overflow_x, .overlay) or {
		panic('missing overflow alias')
	}) == .auto
	assert (resolve_legacy_value_alias(.text_justify, .distribute) or {
		panic('missing text-justify alias')
	}) == .inter_character
	assert (resolve_legacy_value_alias(.overflow_block, .overlay) or {
		panic('missing logical overflow alias')
	}) == .auto

	overflow := parse_css_value_logic(.overflow_x, 'overlay') or {
		panic('legacy overflow alias did not parse')
	}
	assert overflow.to_string() == 'auto'
	overflow_block := parse_css_value_logic(.overflow_block, 'overlay') or {
		panic('legacy logical overflow alias did not parse')
	}
	assert overflow_block.to_string() == 'auto'
	text_justify := parse_css_value_logic(.text_justify, 'distribute') or {
		panic('legacy text-justify alias did not parse')
	}
	assert text_justify.to_string() == 'inter-character'
}
