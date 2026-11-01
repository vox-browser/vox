module css

import dom

fn document_reuse_set(mut style ComputedProperties, property PropertyID, text string) {
	style.set_property(property, parse_css_value(ParsingParams{}, text, property) or { panic('missing CSS value') }, .no, .no)
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
	assert voidptr(style.computed_layout_cache().document_resolution_owner) == voidptr(other)
}

fn test_document_materialization_requires_property_graph_identity_not_equal_token_fields() {
	document := dom.Document.create(dom.url_about_blank())
	mut first := computed_properties_with_initial_values()
	mut second := computed_properties_with_initial_values()
	document_reuse_set(mut first, .width, '10px')
	document_reuse_set(mut second, .width, '90px')
	_ = resolve_computed_values_for_document(first, document)
	_ = resolve_computed_values_for_document(second, document)
	mut copied := &ComputedProperties{
		...first
		property_store_: second.property_store_
		computed_property_graph_token_: second.computed_property_graph_token_
	}
	assert voidptr(copied.computed_property_graph_token_) != voidptr(first.computed_property_graph_token_)
	assert copied.computed_property_graph_token_.generation == first.computed_property_graph_token_.generation
	previous := copied.computed_layout_cache()
	_ = resolve_computed_values_for_document(copied, document)
	assert voidptr(copied.computed_layout_cache()) != voidptr(previous)
	assert copied.computed_layout_cache().computed_values_width_ == second.computed_layout_cache().computed_values_width_
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
	width := parse_css_value(ParsingParams{}, '70px', .width) or { panic('missing CSS value') }
	style.set_animated_property(.width, width, .no, .no)
	_ = resolve_computed_values_for_document(style, document)
	animated := style.computed_layout_cache()
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.computed_layout_cache()) != voidptr(animated)
}

fn test_document_geometry_survives_an_unrelated_font_generation_with_its_original_cascade() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut style := computed_properties_with_initial_values()
	document_reuse_set(mut style, .font_family, 'serif')
	document_reuse_set(mut style, .width, '3ch')
	_ = resolve_computed_values_for_document(style, document)
	before := style.computed_layout_cache()
	proof := style.geometry_provenance()
	fonts := style.cached_computed_font_list()?
	mut computer := css_style_computer_for(document).font_computer()
	computer.did_load_font('GeometryUnusedFamily')
	_ = resolve_computed_values_for_document(style, document)
	assert style.cached_computed_font_list_generation_ > proof.font_generation
	assert voidptr(style.cached_computed_font_list()?) == voidptr(fonts)
	assert voidptr(style.geometry_provenance()) == voidptr(proof)
	assert voidptr(style.computed_layout_cache()) == voidptr(before)
	assert proof.matches(style)
	// An affected family and a changed root context keep their full fallback.
	computer.did_load_font('serif')
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.cached_computed_font_list()?) != voidptr(fonts)
	assert voidptr(style.geometry_provenance()) != voidptr(proof)
	current := style.geometry_provenance()
	style.root_line_height_px_ += 1
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.geometry_provenance()) != voidptr(current)
}

fn test_font_geometry_does_not_reuse_a_new_cascade_as_proof_of_older_geometry() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut style := computed_properties_with_initial_values()
	document_reuse_set(mut style, .font_family, 'serif')
	_ = resolve_computed_values_for_document(style, document)
	proof := style.geometry_provenance()
	mut computer := css_style_computer_for(document).font_computer()
	computer.did_load_font('serif')
	// Discovery may happen before the geometry resolver. Keep this new list
	// separate from the original list captured by the old provenance.
	_ = style.computed_font_list(computer)
	assert !proof.matches(style)
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.geometry_provenance()) != voidptr(proof)
}

fn test_font_geometry_keeps_pending_cascades_conservative_across_generations() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut computer := css_style_computer_for(document).font_computer()
	face := FontFaceObject.construct_impl('GeometryPending', FontFaceSource.from_string('url("pending.ttf")'), FontFaceDescriptors{})
	computer.register_font_face(face)
	mut style := computed_properties_with_initial_values()
	document_reuse_set(mut style, .font_family, 'GeometryPending')
	_ = resolve_computed_values_for_document(style, document)
	proof := style.geometry_provenance()
	assert !proof.font_cascade_was_settled
	assert (style.cached_computed_font_list()?).pending_faces.len == 1
	computer.did_load_font('GeometryUnusedFamily')
	_ = resolve_computed_values_for_document(style, document)
	assert voidptr(style.geometry_provenance()) != voidptr(proof)
}
