module css

import dom

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

fn test_device_layout_fonts_preserve_optical_axes_and_recompute_cache_precision() {
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
	assert source.fonts[0].font.pixel_size_override_? == f32(10.12)
	assert scaled.fonts[0].font.variations.opsz? == 10.129
	assert scaled.last_resort_font.variations.opsz? == 10.129
	assert voidptr(scaled.fonts[0].font.typeface) == voidptr(source.fonts[0].font.typeface)
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
