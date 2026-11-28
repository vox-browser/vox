module css

import dom

fn device_retained_fixture() (&dom.Document, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	root := document.create_element_ns(dom.namespace_html_uri, 'html') or { panic(err) }
	mut branch := document.create_element_ns(dom.namespace_html_uri, 'div') or { panic(err) }
	mut target := document.create_element_ns(dom.namespace_html_uri, 'span') or { panic(err) }
	branch.set_attribute_value('style', 'color:red;font-size:17px')
	target.set_attribute_value('style', 'display:block;width:31.5px;margin-left:3px;border:medium solid;padding:0.3em')
	mut document_node := document.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(branch.as_node()) or { panic(err) }
	mut branch_node := branch.as_node()
	branch_node.append_child(target.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	return document, target
}

// A no-op restyle: a new style object with the same raw inputs and no
// projection of its own yet.
fn device_retained_copy(source &ComputedProperties) &ComputedProperties {
	return &ComputedProperties{
		...source
		property_store_:                source.clone_raw_property_store()
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
		device_layout_projection_:      unsafe { nil }
	}
}

fn device_retained_length(px f64) &dom.StyleValue {
	return dom_style_value_from_value_logic(StyleValue(LengthStyleValue.create(Length.make_px(px))))
}

// What a box holds under device layout: the resolved projection of its
// element's style into physical coordinates.
fn device_retained_box_style(source &ComputedProperties, document &dom.Document) &ComputedProperties {
	return resolve_computed_values_for_document(computed_style_in_layout_coordinates(source, document), document)
}

fn test_device_layout_keeps_values_across_noop_restyles() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	source := up_to_date_computed_properties_for_element(target)
	assert source.layout_coordinate_scale() == 1
	previous := device_retained_box_style(source, document)
	assert previous.layout_coordinate_scale() == 2
	assert voidptr(previous) != voidptr(source)
	// The unchanged style still projects to the box's own values.
	assert previous.has_identical_retained_layout_inputs(source, document)
	// A fresh style with the same inputs gets a projection of its own, which
	// matches in physical coordinates.
	replacement := device_retained_copy(source)
	assert previous.has_identical_retained_layout_inputs(replacement, document)
	assert voidptr(computed_style_in_layout_coordinates(replacement, document)) != voidptr(previous)
	// A font list that cannot keep its projection is projected again for each
	// style; the box's list is still the one these fonts project to.
	fonts := source.cached_computed_font_list_ or { panic('fonts') }
	mut uncached := unsafe { &FontCascadeList(fonts) }
	uncached.device_layout_font_projection_ = unsafe { nil }
	reprojected := device_retained_copy(source)
	assert previous.has_identical_retained_layout_inputs(reprojected, document)
	box_fonts := previous.cached_computed_font_list_ or { panic('box fonts') }
	again := computed_style_in_layout_coordinates(reprojected, document).cached_computed_font_list_ or {
		panic('projected fonts')
	}
	assert voidptr(again) != voidptr(box_fonts)
	// Fresh scalar values equal to the old ones project to equal lengths.
	device_retained_scalar_copies_match(source, previous, document)
}

// An author face that has not loaded keeps its list from being shared, so
// every style projects the list for itself.
fn test_device_layout_compares_font_lists_with_pending_faces() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	source := up_to_date_computed_properties_for_element(target)
	computer := css_style_computer_for(document).font_computer()
	fonts := source.computed_font_list(computer)
	mut pending := unsafe { &FontCascadeList(fonts) }
	pending.pending_faces << PendingFontFace{
		font_index:     0
		unicode_ranges: [UnicodeRange{0x400, 0x4ff}]
	}
	previous := device_retained_box_style(source, document)
	box_fonts := previous.cached_computed_font_list_ or { panic('box fonts') }
	assert box_fonts.pending_faces.len == 1
	replacement := device_retained_copy(source)
	assert previous.has_identical_retained_layout_inputs(replacement, document)
	again := computed_style_in_layout_coordinates(replacement, document).cached_computed_font_list_ or {
		panic('projected fonts')
	}
	assert voidptr(again) != voidptr(box_fonts)
	// A face that loaded or joined since is another cascade.
	pending.pending_faces << PendingFontFace{
		font_index:     0
		unicode_ranges: [UnicodeRange{0x370, 0x3ff}]
	}
	assert previous.retained_layout_input_difference(device_retained_copy(source), document) == 'fonts'
	pending.pending_faces.clear()
	assert previous.retained_layout_input_difference(device_retained_copy(source), document) == 'fonts'
}

fn device_retained_scalar_copies_match(source &ComputedProperties, previous &ComputedProperties, document &dom.Document) {
	for id in [PropertyID.display, .color, .width, .margin_left, .padding_top] {
		mut scalar_copy := device_retained_copy(source)
		value := source.property(id, .no) or { panic('${id}') }
		typed := typed_style_value_logic_from_dom(value) or { panic('${id}') }
		scalar_copy.set_property_without_modifying_flags(id, dom_style_value_from_value_logic(typed))
		assert scalar_copy.reuse_unchanged_font_cache(source, css_style_computer_for(document).font_computer())
		assert previous.has_identical_retained_layout_inputs(scalar_copy, document), '${id}'
	}
}

fn test_device_layout_observes_changed_lengths_flags_and_context() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	source := up_to_date_computed_properties_for_element(target)
	previous := device_retained_box_style(source, document)
	// 31.5px projects to 63 physical pixels; other lengths project elsewhere.
	for id in [PropertyID.width, .margin_left, .padding_top, .border_top_width] {
		mut changed := device_retained_copy(source)
		changed.set_property_without_modifying_flags(id, device_retained_length(63))
		assert !previous.has_identical_retained_layout_inputs(changed, document), '${id}'
	}
	// The projection parses an untyped length, so equal text is the same
	// physical input; text it cannot project stays unvalidated, as in CSS pixels.
	mut untyped := device_retained_copy(source)
	untyped.set_property_without_modifying_flags(.width, &dom.StyleValue{ css_text: '31.5px' })
	assert previous.has_identical_retained_layout_inputs(untyped, document)
	untyped = device_retained_copy(source)
	untyped.set_property_without_modifying_flags(.width, &dom.StyleValue{ css_text: '40px' })
	assert !previous.has_identical_retained_layout_inputs(untyped, document)
	for id in [PropertyID.display, .color, .content] {
		mut unparsed := device_retained_copy(source)
		unparsed.set_property_without_modifying_flags(id, &dom.StyleValue{ css_text: 'different' })
		assert !previous.has_identical_retained_layout_inputs(unparsed, document), '${id}'
	}
	mut flags := device_retained_copy(source)
	flags.property_important_[0] ^= 1
	assert !previous.has_identical_retained_layout_inputs(flags, document)
	for kind in 0 .. 6 {
		mut changed := device_retained_copy(source)
		match kind {
			0 { changed.viewport_rect_.width = CSSPixels.new(123) }
			1 { changed.root_font_size_px_ += 1 }
			2 { changed.subject_element_ = none }
			3 { changed.line_height_ = CSSPixels.new(20) }
			4 { changed.set_animated_property(.opacity, &dom.StyleValue{ css_text: '0.5' }, .no, .no) }
			else { changed.property_store_ = unsafe { nil } }
		}
		assert !previous.has_identical_retained_layout_inputs(changed, document), '${kind}'
	}
	// A larger font size projects to other faces, even from the same list.
	mut larger := device_retained_copy(source)
	larger.set_property_without_modifying_flags(.font_size, device_retained_length(23))
	assert previous.retained_layout_input_difference(larger, document) != ''
	assert previous.retained_layout_input_difference(device_retained_copy(source), document) == ''
	// An unresolved projection has no values a box could keep.
	unresolved := computed_style_in_layout_coordinates(device_retained_copy(source), document)
	assert !unresolved.computed_values_resolved_
	assert !unresolved.has_identical_retained_layout_inputs(source, document)
}

fn test_device_layout_projection_for_another_scale_never_matches() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	source := up_to_date_computed_properties_for_element(target)
	previous := device_retained_box_style(source, document)
	assert previous.has_identical_retained_layout_inputs(device_retained_copy(source), document)
	document.set_layout_coordinate_scale(3)
	assert !previous.has_identical_retained_layout_inputs(device_retained_copy(source), document)
	assert !previous.has_identical_retained_layout_inputs(source, document)
	// Back in CSS pixels the physical values no longer describe the style.
	document.set_layout_coordinate_scale(1)
	assert !previous.has_identical_retained_layout_inputs(device_retained_copy(source), document)
	assert !previous.has_identical_retained_layout_inputs(source, document)
}

fn test_css_pixel_layout_still_compares_styles_directly() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	source := up_to_date_computed_properties_for_element(target)
	previous := resolve_computed_values_for_document(source, document)
	assert voidptr(previous) == voidptr(source)
	assert previous.has_identical_retained_layout_inputs(device_retained_copy(source), document)
	mut changed := device_retained_copy(source)
	changed.set_property_without_modifying_flags(.width, device_retained_length(63))
	assert !previous.has_identical_retained_layout_inputs(changed, document)
}

// Retained text asks whether the fonts that shaped it are still current. A
// projection carries no stamps of its own; its source cascade does.
fn test_device_layout_font_projection_is_current_while_its_cascade_is() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	source := up_to_date_computed_properties_for_element(target)
	computer := css_style_computer_for(document).font_computer()
	fonts := source.computed_font_list(computer)
	generation := computer.environment_generation()
	assert source.cached_font_inputs_are_unchanged_since(computer, generation)
	previous := device_retained_box_style(source, document)
	projected := previous.cached_computed_font_list_ or { panic('projected fonts') }
	assert voidptr(projected) != voidptr(fonts)
	assert voidptr(projected.cache_stamp_owner()) == voidptr(fonts)
	assert !projected.computed_cache_current_
	assert previous.cached_font_inputs_are_unchanged_since(computer, generation)
	// A loaded or failed face expires the cascade, and its projection with it.
	mut expired := unsafe { &FontCascadeList(fonts) }
	expired.computed_cache_current_ = false
	assert !source.cached_font_inputs_are_unchanged_since(computer, generation)
	assert !previous.cached_font_inputs_are_unchanged_since(computer, generation)
}

fn test_device_layout_box_keeps_its_scaled_faces_after_an_unrelated_font_change() {
	mut document, target := device_retained_fixture()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	source := up_to_date_computed_properties_for_element(target)
	mut computer := unsafe { &FontComputer(css_style_computer_for(document).font_computer()) }
	fonts := source.computed_font_list(computer)
	mut box := unsafe { &ComputedProperties(device_retained_box_style(source, document)) }
	projected := box.cached_computed_font_list_ or { panic('projected fonts') }
	selected := box.first_available_computed_font(computer)
	// Another family finishing its load starts a new font environment
	// generation without expiring this cascade.
	generation := computer.environment_generation()
	computer.clear_computed_font_cache('A family this style does not name')
	assert computer.environment_generation() != generation
	assert computer.cached_cascade_is_current(fonts)
	// The box keeps the faces scaled from its CSS-pixel cascade. Computing a
	// cascade for its physical font size would select other optical sizes.
	assert voidptr(box.computed_font_list(computer)) == voidptr(projected)
	assert voidptr(box.first_available_computed_font(computer)) == voidptr(selected)
	assert box.cached_computed_font_list_generation_ == computer.environment_generation()
}
