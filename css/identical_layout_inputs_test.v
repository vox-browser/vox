module css

import dom

fn identical_inputs_fixture() (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	defer { scope.finish() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{0,0,800,600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic('Expected typed computed style value') }
	root.set_attribute_value('style', 'font:13.25px Arial;line-height:normal;width:7px;color:rgb(17 34 51)')
	document.as_node().append_child(root.as_node()) or { panic('Expected typed computed style value') }
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn identical_inputs_clone(source &ComputedProperties) &ComputedProperties {
	return &ComputedProperties{...*source, property_store_:source.clone_raw_property_store(),
		computed_property_graph_token_:&ComputedPropertyGraphMutationToken{},
		computed_layout_cache_:unsafe { nil }, device_layout_projection_:unsafe { nil },
		computed_values_resolved_:false}
}

fn test_identical_geometry_inputs_match_ordinary_resolution_and_keep_mutation_independent() {
	$if !prealloc { return }
	mut document, source := identical_inputs_fixture()
	mut scope := document.enter_native_storage()
	defer { scope.finish(); document.finalize(); document.release_native_storage() }
	document.set_layout_coordinate_scale(2)
	first := computed_style_in_layout_coordinates(identical_inputs_clone(source), document)
	_ = resolve_computed_values_for_document(first, document)
	second := computed_style_in_layout_coordinates(identical_inputs_clone(source), document)
	_ = resolve_computed_values_for_document(second, document)
	assert voidptr(first.computed_layout_cache()) == voidptr(second.computed_layout_cache())
	assert second.computed_values_resolved_
	assert second.size_value(.width) == first.size_value(.width)
	mut pool := css_style_computer_for(document).initial_layout_snapshots_
	saved := pool.identical_inputs
	pool.identical_inputs = map[u64][]IdenticalLayoutInputs{}
	ordinary := computed_style_in_layout_coordinates(identical_inputs_clone(source), document)
	_ = resolve_computed_values_for_document(ordinary, document)
	pool.identical_inputs = saved
	assert idle_layout_snapshots_equal(second.computed_layout_cache(), ordinary.computed_layout_cache())
	mut changed := unsafe { &ComputedProperties(second) }
	changed.set_property_without_modifying_flags(.width,
		parse_css_value(ParsingParams{}, '26px', .width) or { panic('Expected typed computed style value') })
	_ = resolve_computed_values_for_document(changed, document)
	assert changed.size_value(.width) != first.size_value(.width)
	assert first.property(.width, .no)?.css_text == '14px'
}

fn test_identical_geometry_inputs_reject_untyped_animated_and_contextual_values() {
	$if !prealloc { return }
	mut document, source := identical_inputs_fixture()
	mut scope := document.enter_native_storage()
	defer { scope.finish(); document.finalize(); document.release_native_storage() }
	for text in ['2em', 'calc(50% - 1px)'] {
		mut candidate := identical_inputs_clone(source)
		candidate.set_property_without_modifying_flags(.width,
			parse_css_value(ParsingParams{}, text, .width) or { panic('Expected typed computed style value') })
		assert identical_layout_inputs(candidate, document) == none
	}
	mut untyped := identical_inputs_clone(source)
	untyped.set_property_without_modifying_flags(.width, &dom.StyleValue{css_text:'7px'})
	assert identical_layout_inputs(untyped, document) == none
	mut animated := identical_inputs_clone(source)
	animated.set_animated_property(.width,
		parse_css_value(ParsingParams{}, '9px', .width) or { panic('Expected typed computed style value') }, .no, .no)
	assert identical_layout_inputs(animated, document) == none
}
