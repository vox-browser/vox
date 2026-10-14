module css

import dom

fn context_copy_fixture() (&StyleComputer, dom.AbstractElement) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 800, 400})
	mut parent := document.create_element('div') or { panic(err) }
	parent.set_attribute_value('style', 'font-size:20px;line-height:30px')
	child := document.create_element('span') or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(parent.as_node()) or { panic(err) }
	mut parent_node := parent.as_node()
	parent_node.append_child(child.as_node()) or { panic(err) }
	computer := StyleComputer.new(document)
	parent_style := computer.compute_style(dom.AbstractElement.new(parent, none))
	parent.set_computed_properties(none, computed_properties_to_dom(parent_style))
	return computer, dom.AbstractElement.new(child, none)
}

fn context_copy_cascade(values map[PropertyID]string) &CascadedProperties {
	mut cascaded := CascadedProperties.new()
	for id, text in values {
		cascaded.set_property(id, parse_css_value(ParsingParams{}, text, id) or { panic(text) },
			.no, .author, none, unsafe { nil }, none)
	}
	return cascaded
}

fn context_copy_cached(font_size f64, dependency bool) ComputationContext {
	return ComputationContext{
		length_resolution_context: LengthResolutionContext{
			viewport_rect: CSSPixelRect.new(0, 0, 800, 400)
			font_metrics: LengthFontMetrics{font_size: CSSPixels.nearest_value_for(font_size)}
		}
		did_resolve_viewport_relative_length: dependency
	}
}

fn test_context_copy_preserves_font_line_height_and_generic_categories() {
	mut computer, subject := context_copy_fixture()
	computed := computed_properties_with_initial_values()
	computer.cached_font_computation_context = context_copy_cached(23, false)
	computer.cached_line_height_computation_context = context_copy_cached(17, false)
	computer.cached_generic_computation_context = context_copy_cached(31, false)
	for id in [PropertyID.color_scheme, .font_family, .font_feature_settings, .font_kerning,
		.font_optical_sizing, .font_size, .font_style, .font_variant_alternates, .font_variant_caps,
		.font_variant_east_asian, .font_variant_emoji, .font_variant_ligatures, .font_variant_numeric,
		.font_variant_position, .font_variation_settings, .font_weight, .font_width, .math_depth,
		.text_rendering] {
		context := computer.get_computation_context_for_property(id, computed, subject)
		assert context.length_resolution_context.font_metrics.font_size.to_double() == 23
	}
	for id in [PropertyID.width, .color, .visibility, .writing_mode] {
		context := computer.get_computation_context_for_property(id, computed, subject)
		assert context.length_resolution_context.font_metrics.font_size.to_double() == 31
	}
	mut line := computer.get_computation_context_for_property(.line_height, computed, subject)
	assert line.length_resolution_context.font_metrics.font_size.to_double() == 17
	line.did_resolve_viewport_relative_length = true
	assert !(computer.cached_line_height_computation_context?).depends_on_viewport_metrics()
	computer.clear_computation_context_caches()
	assert computer.computation_context_cache_is_empty()
}

fn test_context_copy_reuses_seeded_metrics_and_clears_them_after_each_pass() {
	mut computer, subject := context_copy_fixture()
	computer.cached_font_computation_context = context_copy_cached(23, false)
	computer.cached_line_height_computation_context = context_copy_cached(17, false)
	computer.cached_generic_computation_context = context_copy_cached(31, false)
	mut cascaded := context_copy_cascade({PropertyID.font_size: '2em', .line_height: '2em', .width: '2em'})
	first := computer.compute_properties(subject, mut cascaded)
	assert first.font_size().to_double() == 46
	assert first.line_height().to_double() == 34
	assert first.length_percentage_to_px(.width, 0)? == 62
	assert computer.computation_context_cache_is_empty()
	gc_collect()
	second := computer.compute_properties(subject, mut cascaded)
	assert second.font_size().to_double() == 40
	assert second.line_height().to_double() == 80
	assert second.length_percentage_to_px(.width, 0)? == 80
	assert computer.computation_context_cache_is_empty()
}

fn test_context_copy_noncomputed_values_do_not_propagate_stale_dependency_flags() {
	mut computer, subject := context_copy_fixture()
	computer.cached_font_computation_context = context_copy_cached(23, true)
	computer.cached_line_height_computation_context = context_copy_cached(17, true)
	computer.cached_generic_computation_context = context_copy_cached(31, true)
	mut cascaded := context_copy_cascade({PropertyID.font_family: 'serif', .font_kerning: 'normal',
		.text_rendering: 'auto', .visibility: 'hidden', .writing_mode: 'vertical-rl', .direction: 'rtl'})
	computed := computer.compute_properties(subject, mut cascaded)
	assert computed.font_size().to_double() == 20
	assert computed.visibility() == .hidden
	assert computed.writing_mode() == .vertical_rl
	assert !computed.depends_on_viewport_metrics()
	assert !computed.font_metrics_depend_on_viewport_metrics()
	assert computed.is_property_inherited(.font_size)
	assert !computed.is_property_inherited(.visibility)
	assert computer.computation_context_cache_is_empty()
}

fn test_context_copy_keeps_first_generic_observation_before_writing_mode_changes() {
	computer, subject := context_copy_fixture()
	mut cascaded := context_copy_cascade({PropertyID.writing_mode: 'vertical-rl', .width: '10cqi'})
	computed := computer.compute_properties(subject, mut cascaded)
	assert computed.writing_mode() == .vertical_rl
	// The first generic context is primed by an earlier unchanged/inherited
	// property while the working style still has its initial inline axis.
	assert computed.length_percentage_to_px(.width, 0)? == 80
	assert computed.depends_on_viewport_metrics()
	assert computer.computation_context_cache_is_empty()
}

fn test_context_copy_tracks_computed_viewport_dependencies_without_leaking_between_passes() {
	computer, subject := context_copy_fixture()
	for index, values in [{PropertyID.font_size: '20px', .width: '10vw'},
		{PropertyID.font_size: '20px', .width: '10px'},
		{PropertyID.font_size: '10vw', .width: '2em'}] {
		mut cascaded := context_copy_cascade(values)
		gc_collect()
		computed := computer.compute_properties(subject, mut cascaded)
		assert computed.font_size().to_double() == if index == 2 { f64(80) } else { f64(20) }
		assert computed.length_percentage_to_px(.width, 0)? == [f64(80), 10, 160][index]
		assert computed.depends_on_viewport_metrics() == (index != 1)
		assert computed.font_metrics_depend_on_viewport_metrics() == (index == 2)
		assert computer.computation_context_cache_is_empty()
	}
}
