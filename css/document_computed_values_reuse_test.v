module css

import dom

fn document_reuse_set(mut style ComputedProperties, property PropertyID, text string) {
	style.set_property(property, parse_css_value(ParsingParams{}, text, property) or { panic(err) }, .no, .no)
}

fn test_unchanged_document_materialization_keeps_the_published_cache() {
	document := dom.Document.create(dom.url_about_blank())
	mut style := computed_properties_with_initial_values()
	document_reuse_set(mut style, .width, '41px')
	document_reuse_set(mut style, .color, 'red')
	_ = resolve_computed_values_for_document(style, document)
	cache := style.computed_layout_cache()
	copy := &ComputedProperties{ ...style }
	for _ in 0 .. 64 {
		values := resolve_computed_values_for_document(style, document)
		assert voidptr(style.computed_layout_cache()) == voidptr(cache)
		assert values.width() == cache.computed_values_width_
		assert values.color() == Color{255, 0, 0, 255}
	}
	assert voidptr(copy.computed_layout_cache()) == voidptr(cache)
	assert cache.writable_owner_identity == 0
}

fn test_document_materialization_rechecks_alias_mutations_and_geometry_context() {
	document := dom.Document.create(dom.url_about_blank())
	mut style := computed_properties_with_initial_values()
	document_reuse_set(mut style, .width, '10px')
	_ = resolve_computed_values_for_document(style, document)
	cache := style.computed_layout_cache()
	mut alias := *style
	document_reuse_set(mut alias, .width, '90px')
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) != voidptr(cache)
	assert style.computed_layout_cache().computed_values_width_ != cache.computed_values_width_
	for context in [0, 1] {
		before := style.computed_layout_cache()
		if context == 0 { style.viewport_rect_.width = CSSPixels.nearest_value_for(900) }
		else { style.root_font_size_px_ += 1 }
		_ = resolve_computed_values_for_document(style, document)
		assert voidptr(style.computed_layout_cache()) != voidptr(before)
	}
}

fn test_document_materialization_rechecks_theme_and_document_identity() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_svg_image_color_scheme('light')
	mut style := computed_properties_with_initial_values()
	document_reuse_set(mut style, .color_scheme, 'light dark')
	document_reuse_set(mut style, .color, 'CanvasText')
	document_reuse_set(mut style, .background_color, 'Canvas')
	_ = resolve_computed_values_for_document(style, document)
	light := style.computed_layout_cache()
	document.set_svg_image_color_scheme('dark')
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) != voidptr(light)
	assert style.computed_layout_cache().computed_values_color_ != light.computed_values_color_
	assert style.computed_layout_cache().computed_values_background_color_ != light.computed_values_background_color_
	dark := style.computed_layout_cache()
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) == voidptr(dark)
	mut other := dom.Document.create(dom.url_about_blank())
	other.set_svg_image_color_scheme('dark')
	_ = resolve_computed_values_for_document(style, other)
	assert voidptr(style.computed_layout_cache()) != voidptr(dark)
	assert style.computed_layout_cache().document_resolution_owner == other
}

fn test_document_materialization_keeps_animated_and_manual_cache_writes_conservative() {
	document := dom.Document.create(dom.url_about_blank())
	mut style := computed_properties_with_initial_values()
	_ = resolve_computed_values_for_document(style, document)
	mut values := unsafe { &MutableComputedValues(style) }
	values.set_color(Color{123, 45, 67, 255})
	manual := style.computed_layout_cache()
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) != voidptr(manual)
	width := parse_css_value(ParsingParams{}, '70px', .width) or { panic(err) }
	style.set_animated_property(.width, width, .no, .no)
	_ = resolve_computed_values_for_document(style, document)
	animated := style.computed_layout_cache()
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) != voidptr(animated)
}
