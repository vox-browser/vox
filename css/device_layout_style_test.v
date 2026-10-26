module css

import dom

fn test_chromium_fixed_line_height_rounds_only_after_device_projection() {
	for value in ['17.6px', '1.6em', '160%'] {
		mut document, source := device_layout_test_style('font:11px Verdana;line-height:${value}')
		defer { document.finalize() }
		assert source.line_height() == CSSPixels.nearest_value_for(17.6)
		document.set_layout_coordinate_scale(2)
		projected := computed_style_in_layout_coordinates(source, document)
		assert projected.line_height() == CSSPixels.nearest_value_for(35.2)
	}
	mut document, source := device_layout_test_style('font:11px/1.6 Verdana')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	// Unitless line heights use Blink's percentage calculation and truncate.
	assert computed_style_in_layout_coordinates(source, document).line_height() == CSSPixels.truncated_value_for(35.2)
}

fn test_device_layout_ex_width_uses_the_selected_unrounded_x_height() {
	mut document, source := device_layout_test_style('font:bold 13px Verdana;width:4.1ex')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	mut mutable_projected := unsafe { &ComputedProperties(projected) }
	font := mutable_projected.first_available_computed_font(FontComputer.create_for_document(document))
	x_height := f64(font.font_for_metrics().pixel_metrics().x_height)
	metrics_source := computed_interpolation_font_metrics_for_style(source, FontComputer.create_for_document(document))
	raw_source := metrics_source.x_height_unrounded or { panic('missing source x-height') }
	assert projected.length_percentage_to_px(.width, 1600)? == CSSPixels.truncated_value_for(raw_source * 4.1 * 2).to_double()
	metrics := computed_interpolation_font_metrics_for_style(projected, FontComputer.create_for_document(document))
	assert (metrics.x_height_unrounded or { panic('missing Chromium x-height') }) == x_height
}

fn device_layout_test_style(declaration string) (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', declaration)
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn device_layout_transform_values(style &ComputedProperties) []StyleValue {
	value := style.property(.transform, .yes) or { panic('missing transform') }
	typed := style_value_logic_from_dom(.transform, value) or { panic('missing typed transform') }
	first := if typed is StyleValueList { typed.values()[0] } else { typed }
	if first is TransformationStyleValue { return first.values_ }
	panic('missing transform function')
}

fn test_device_layout_style_scales_lengths_without_mutating_cssom_or_colors() {
	mut document, source := device_layout_test_style('font:17px/1.3 Arial;width:6.4px;height:50%;margin-left:.4em;padding-left:40px;border:medium solid;transform:matrix(1,0,0,1,3,4);background:hsl(20.5 31.2% 82.4%)')
	defer { document.finalize() }
	assert voidptr(computed_style_in_layout_coordinates(source, document)) == voidptr(source)
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	assert projected.layout_coordinate_scale() == 2
	assert projected.resolved_font_size_px() == 34
	assert source.resolved_font_size_px() == 17
	assert source.length_percentage_to_px(.width, 800)? == 6.390625
	assert projected.length_percentage_to_px(.width, 1600)? == 12.796875
	assert projected.length_percentage_to_px(.height, 1200)? == 600
	assert projected.length_percentage_to_px(.margin_left, 1600)? == 13.59375
	assert projected.length_percentage_to_px(.padding_left, 1600)? == 80
	assert projected.length_percentage_to_px(.border_top_width, 1600)? == 6
	assert voidptr(projected.property(.background_color, .yes)?) == voidptr(source.property(.background_color, .yes)?)
	transform := device_layout_transform_values(projected)
	assert transform[4].as_number().number() == 6
	assert transform[5].as_number().number() == 8
	assert device_layout_transform_values(source)[4].as_number().number() == 3
}

fn test_device_layout_calculations_scale_dimensions_and_keep_percentage_bases() {
	mut document, source := device_layout_test_style('font:17px Arial;width:calc(50% - 1.2px);padding-left:calc(1em + 1px);transform:matrix3d(1,0,0,.02,0,1,0,.04,0,0,1,.01,3,4,5,1)')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	assert projected.length_percentage_to_px(.width, 1000)? == 497.59375
	assert projected.length_percentage_to_px(.padding_left, 1000)? == 36
	assert source.length_percentage_to_px(.width, 500)? == 248.796875
	values := device_layout_transform_values(projected)
	assert values[3].as_number().number() == 0.01
	assert values[7].as_number().number() == 0.02
	assert values[11].as_number().number() == 0.005
	assert values[12].as_number().number() == 6
	assert values[13].as_number().number() == 8
	assert values[14].as_number().number() == 10
	assert values[15].as_number().number() == 1
}

fn test_device_layout_projection_reuses_only_matching_source_revisions_and_scales() {
	mut document, source := device_layout_test_style('font:17px Arial;width:6.4px')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	first := computed_style_in_layout_coordinates(source, document)
	assert voidptr(computed_style_in_layout_coordinates(source, document)) == voidptr(first)
	mut mutable_source := unsafe { &ComputedProperties(source) }
	mutable_source.set_property_without_modifying_flags(.width,
		dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(7.1)))))
	second := computed_style_in_layout_coordinates(source, document)
	assert voidptr(first) != voidptr(second)
	assert first.length_percentage_to_px(.width, 1600)? == 12.796875
	assert second.length_percentage_to_px(.width, 1600)? == 14.1875
	document.set_layout_coordinate_scale(3)
	third := computed_style_in_layout_coordinates(source, document)
	assert third.resolved_font_size_px() == 51
	assert third.length_percentage_to_px(.width, 2400)? == 21.296875
	rescaled := computed_style_in_layout_coordinates(second, document)
	assert rescaled.layout_coordinate_scale() == 3
	assert rescaled.resolved_font_size_px() == 51
	assert rescaled.length_percentage_to_px(.width, 2400)? == 21.296875
}

fn test_device_layout_fonts_preserve_optical_axes_and_physical_cache_precision() {
	typeface := &PlatformTypeface{ family_name: 'Fixture' }
	font := PlatformFont{
		typeface:              typeface
		point_size:            f32(10.129 * 0.75)
		pixel_size_override_:  browser_font_size_for_rendering(10.129)
		font_rendering_policy: .chromium
		variations:            FontVariationSettings{ opsz: 10.129 }
	}
	mut source := FontCascadeList.create()
	source.add(font, [])
	source.last_resort_font = &PlatformFont{ ...font }
	scaled := device_layout_fonts(source, 2, 20.258)
	assert scaled.fonts[0].font.pixel_size_override_? == f32(20.25)
	rescaled := device_layout_fonts(scaled, 1.5, 30.387)
	assert rescaled.fonts[0].font.pixel_size_override_? == f32(30.38)
	assert source.fonts[0].font.pixel_size_override_? == f32(10.12)
	assert scaled.fonts[0].font.variations.opsz? == 10.129
	assert scaled.last_resort_font.variations.opsz? == 10.129
	assert voidptr(scaled.fonts[0].font.typeface) == voidptr(source.fonts[0].font.typeface)
}

fn test_device_layout_fractional_comment_header_uses_physical_font_precision() {
	mut document, source := device_layout_test_style('font:8pt Verdana')
	defer { document.finalize() }
	for index, scale in [2.0, 3.0] {
		document.set_layout_coordinate_scale(scale)
		projected := computed_style_in_layout_coordinates(source, document)
		assert projected.cached_computed_font_list_?.fonts[0].font.pixel_size_override_? == [
			f32(21.33),
			f32(32),
		][index]
	}
}

fn test_anonymous_layout_wrappers_keep_their_projected_font_and_scale() {
	mut document, source := device_layout_test_style('font:17px/1.3 Arial;padding:10px')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	values := resolve_computed_values_for_document(projected, document)
	anonymous := resolve_anonymous_block_values_for_document(values, document)
	assert anonymous.layout_coordinate_scale() == 2
	assert anonymous.resolved_font_size_px() == 34
	assert voidptr(computed_style_in_layout_coordinates(anonymous, document)) == voidptr(anonymous)
	assert anonymous.length_percentage_to_px(.padding_left, 1600)? == 0
	assert voidptr(anonymous.cached_computed_font_list_?) == voidptr(values.cached_computed_font_list_?)
}

fn test_direct_anonymous_clones_preserve_layout_coordinates_before_resolution() {
	mut document, source := device_layout_test_style('font:17px Arial;padding:10px')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	assert projected.cached_computed_font_list_ != none
	assert projected.cached_computed_font_list_?.fonts[0].font.pixel_size_override_? == 34

	for clone in [projected.clone_for_anonymous_block(), projected.clone_for_button_flex_wrapper(),
		projected.clone_for_anonymous_with_display(Display.from_short(.flow_root))] {
		assert clone.layout_coordinate_scale() == 2
		assert clone.resolved_font_size_px() == 34
		assert voidptr(computed_style_in_layout_coordinates(clone, document)) == voidptr(clone)
		assert clone.cached_computed_font_list_ != none
		assert voidptr(clone.cached_computed_font_list_?) == voidptr(projected.cached_computed_font_list_?)
	}
	mut inherited := source.clone_for_anonymous_block()
	inherited.inherit_from_for_layout(projected)
	assert inherited.layout_coordinate_scale() == 2
	assert inherited.resolved_font_size_px() == 34
	assert voidptr(computed_style_in_layout_coordinates(inherited, document)) == voidptr(inherited)
}

fn test_transferred_wrapper_properties_keep_the_scaled_font_after_mutations() {
	mut document, source := device_layout_test_style('font:17px Arial;display:table;margin:10px;overflow:scroll')
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	projected := computed_style_in_layout_coordinates(source, document)
	table, wrapper := projected.table_box_and_wrapper_properties()
	mut fieldset := projected.clone_for_anonymous_block()
	content := fieldset.take_properties_for_fieldset_content_box()
	for style in [table, wrapper, fieldset, content] {
		assert style.layout_coordinate_scale() == 2
		assert style.resolved_font_size_px() == 34
		assert style.cached_computed_font_list_ != none
		assert voidptr(style.cached_computed_font_list_?) == voidptr(projected.cached_computed_font_list_?)
	}
}

fn test_device_layout_verdana_normal_strut_rounds_the_physical_font() {
	$if macos {
		mut document, source := device_layout_test_style('font:12px Verdana')
		defer { document.finalize() }
		document.set_layout_coordinate_scale(2)
		projected := computed_style_in_layout_coordinates(source, document)
		metrics := projected.cached_computed_font_list_?.fonts[0].font.font_for_rendering().inline_metrics()
		// Native Brave at 2x lays out its 12px Verdana navigation at 14.5 CSS px.
		assert metrics.ascent + metrics.descent + metrics.line_gap == 29
	}
}

fn test_device_layout_projection_preserves_unscaled_values_and_keyword_widths() {
	mut document, source := device_layout_test_style('font:17px Arial;width:0px;height:40%;margin:0px;padding:0px;border-style:solid;border-top-width:thin;border-right-width:medium;border-bottom-width:thick;border-left-width:0px;opacity:.5;color:rgb(20,40,60);position:relative;transform:matrix(1,0,0,1,0,3)')
	defer { document.finalize() }
	for scale in [0.5, 1.25, 2.0, 3.0] {
		document.set_layout_coordinate_scale(scale)
		projected := computed_style_in_layout_coordinates(source, document)
		for property in [PropertyID.width, .margin_top, .margin_right, .margin_bottom,
			.margin_left, .padding_top, .padding_right, .padding_bottom, .padding_left,
			.border_left_width, .height, .opacity, .color, .position] {
			assert voidptr(projected.property(property, .yes)?) == voidptr(source.property(property, .yes)?)
		}
		for index, property in [PropertyID.border_top_width, .border_right_width, .border_bottom_width] {
			property_value := projected.property(property, .yes) or { panic('missing projected width') }
			value := style_value_logic_from_dom(property, property_value) or { panic('missing typed width') }
			assert value is LengthStyleValue
			assert (value as LengthStyleValue).raw_value() == [1.0, 3.0, 5.0][index] * scale
		}
		assert projected.length_percentage_to_px(.height, 1000)? == 400
		transform := device_layout_transform_values(projected)
		assert transform[4].as_number().number() == 0
		assert transform[5].as_number().number() == 3 * scale
		assert source.resolved_font_size_px() == 17
		assert voidptr(computed_style_in_layout_coordinates(source, document)) == voidptr(projected)
	}
}

fn device_projection_page_preference(target voidptr) string {
	return unsafe { *(&string(target)) }
}

fn test_device_layout_projection_preserves_used_color_scheme_in_nested_values() {
	for preference in ['light', 'dark'] {
		for schemes in ['normal', 'light', 'light dark'] {
			for document_dark in [false, true] {
				mut document, mut source := device_layout_test_style('font:16px Arial;color-scheme:${schemes};color:light-dark(red,blue);accent-color:CanvasText')
				defer { document.finalize() }
				document.set_page(&dom.Page{
					target: unsafe { voidptr(&preference) }
					preferred_color_scheme_callback: device_projection_page_preference
				})
				if document_dark {
					document.set_supported_color_schemes(['dark'], false)
				}
				legacy := ColorResolutionContext.for_computed_properties(source, document)
				expected := if schemes == 'light' { PreferredColorScheme.light }
					else if schemes == 'light dark' { preferred_color_scheme_from_string(preference) }
					else if document_dark { PreferredColorScheme.dark }
					else { PreferredColorScheme.light }
				assert legacy.color_scheme? == expected

				// Install unresolved nested colors after style computation so the
				// projection itself must select the scheme and scale the stop.
				gradient := parse_css_value_logic(.background_image,
					'linear-gradient(Canvas 1px, light-dark(red, blue) 50%)')?
				source.set_property_without_modifying_flags(.background_image,
					dom_style_value_from_value_logic(gradient))
				for scale in [0.5, 2.0, 3.0] {
					document.set_layout_coordinate_scale(scale)
					projected := computed_style_in_layout_coordinates(source, document)
					mut reference_context := ComputationContext{
						length_resolution_context: projected.length_resolution_context()
						color_scheme: legacy.color_scheme
					}
					reference_context.length_resolution_context.absolute_length_scale = scale
					if element := source.subject_element_ {
						reference_context.abstract_element = dom.AbstractElement.new(element, none)
					}
					property := projected.property(.background_image, .yes)?
					actual := style_value_logic_from_dom(.background_image, property)?
					reference := gradient.absolutized(reference_context)
					assert actual.equals(reference)
					assert !actual.serialize(.normal).contains('light-dark')
					assert source.property(.background_image, .yes)?.css_text.contains('1px')
				}
			}
		}
	}
}

fn test_device_projection_absolute_units_match_complete_length_context() {
	mut document, mut source := device_layout_test_style('font:17px/1.3 Arial')
	defer { document.finalize() }
	for token in ['.75px', '-1.25px', '0cm', '.33in', '-2.1cm', '3.7mm', '-1.5q', '2.3pt', '-.7pc'] {
		original := parse_css_value_logic(.margin_left, token)?
		retained := dom_style_value_from_value_logic(original)
		source.set_property_without_modifying_flags(.margin_left, retained)
		for scale in [0.5, 1.25, 2.0, 3.0] {
			document.set_layout_coordinate_scale(scale)
			projected := computed_style_in_layout_coordinates(source, document)
			mut context := ComputationContext{
				length_resolution_context: projected.length_resolution_context()
			}
			context.length_resolution_context.absolute_length_scale = scale
			property := projected.property(.margin_left, .yes)?
			actual := style_value_logic_from_dom(.margin_left, property)?
			reference := original.absolutized(context)
			assert actual.equals(reference)
			assert actual is LengthStyleValue
			assert (actual as LengthStyleValue).length_.is_px()
			source_property := source.property(.margin_left, .yes)?
			assert voidptr(source_property) == voidptr(retained)
			assert source_property.css_text == retained.css_text
		}
	}
}

fn test_device_projection_relative_and_nested_values_keep_complete_length_context() {
	properties := [PropertyID.margin_left, .margin_right, .margin_top, .margin_bottom,
		.width, .height, .padding_top, .padding_left, .border_top_left_radius,
		.background_image, .transform]
	tokens := ['1.3em', '2.1ex', '1.1rem', '2lh', '3rlh', '7vh', '4cqw',
		'calc(1em + 1.25px)', '1em 2px',
		'linear-gradient(Canvas 1em, light-dark(red,blue) 2px)', 'translate(1em, 2px)']
	for index, id in properties {
		mut document, mut source := device_layout_test_style('font:17px/1.3 Arial;color-scheme:light dark')
		defer { document.finalize() }
		original := parse_css_value_logic(id, tokens[index])?
		retained := dom_style_value_from_value_logic(original)
		source.set_property_without_modifying_flags(id, retained)
		for scale in [0.5, 1.25, 2.0, 3.0] {
			document.set_layout_coordinate_scale(scale)
			projected := computed_style_in_layout_coordinates(source, document)
			mut context := ComputationContext{
				length_resolution_context: projected.length_resolution_context()
				color_scheme: source.color_scheme(
					preferred_color_scheme_from_string(document.preferred_color_scheme()),
					document.supported_color_schemes())
			}
			context.length_resolution_context.absolute_length_scale = scale
			if element := source.subject_element_ {
				context.abstract_element = dom.AbstractElement.new(element, none)
			}
			property := projected.property(id, .yes)?
			actual := style_value_logic_from_dom(id, property)?
			reference := original.absolutized(context)
			assert actual.equals(reference)
			source_property := source.property(id, .yes)?
			assert voidptr(source_property) == voidptr(retained)
			assert source_property.css_text == retained.css_text
		}
	}
}
