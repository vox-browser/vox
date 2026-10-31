module css

import dom
import platform

fn page_reuse_fixture(declaration string) (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	$if prealloc { document.enable_native_storage() }
	mut allocations := document.enter_native_storage()
	defer { allocations.finish() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', declaration)
	document.as_node().append_child(root.as_node()) or { panic(err) }
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn page_reuse_source(source &ComputedProperties) &ComputedProperties {
	return &ComputedProperties{
		...*source
		property_store_: source.clone_raw_property_store()
		computed_property_graph_token_: &ComputedPropertyGraphMutationToken{}
		device_layout_projection_: unsafe { nil }
	}
}

fn page_reuse_index(property PropertyID) int {
	return (int(property) - int(first_longhand_property_id())) / computed_property_page_size
}

fn page_reuse_value(text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, .width) or { panic('invalid width: ${text}') }
}

fn assert_page_reuse_values_equal(first &ComputedProperties, second &ComputedProperties) {
	for property in computed_interpolation_longhand_property_ids() {
		a := first.property(property, .no) or { continue }
		b := second.property(property, .no) or { panic('missing ${property}') }
		assert a.css_text == b.css_text, property.str()
		assert first.is_property_important(property) == second.is_property_important(property)
		assert first.is_property_inherited(property) == second.is_property_inherited(property)
	}
	assert first.resolved_font_size_px() == second.resolved_font_size_px()
}

fn test_device_layout_pages_share_scaled_pixels_and_preserve_flags_at_fractional_scales() {
	mut document, mut original := page_reuse_fixture('font:13.25px Arial;width:6.4px!important;height:37%;margin-left:3.25px;padding-left:4px;border:medium solid')
	defer { document.finalize(); document.release_native_storage() }
	for scale in [0.5, 1.25, 2.0, 2.75] {
		document.set_layout_coordinate_scale(scale)
		first := computed_style_in_layout_coordinates(page_reuse_source(original), document)
		second := computed_style_in_layout_coordinates(page_reuse_source(original), document)
		index := page_reuse_index(.width)
		assert voidptr(first.property_store_.pages[index]) == voidptr(second.property_store_.pages[index])
		assert voidptr(first.property_store_.pages[index]) != voidptr(original.property_store_.pages[index])
		mut computer := css_style_computer_for(document)
		cache := computer.device_layout_property_pages_
		computer.device_layout_property_pages_ = unsafe { nil }
		reference := computed_style_in_layout_coordinates(page_reuse_source(original), document)
		computer.device_layout_property_pages_ = cache
		assert_page_reuse_values_equal(second, reference)
		assert original.property(.width, .no)?.css_text == '6.4px'
		assert second.is_property_important(.width)
	}
}

fn test_device_layout_page_reuse_keeps_source_and_projected_copy_on_write_independent() {
	mut document, mut source := page_reuse_fixture('font:16px Arial;width:7px')
	defer { document.finalize(); document.release_native_storage() }
	document.set_layout_coordinate_scale(2)
	mut first := unsafe { &ComputedProperties(computed_style_in_layout_coordinates(page_reuse_source(source), document)) }
	mut alias := *first
	alias.set_property_without_modifying_flags(.width, page_reuse_value('99px'))
	assert first.property(.width, .no)?.css_text == '99px'
	second := computed_style_in_layout_coordinates(page_reuse_source(source), document)
	assert second.property(.width, .no)?.css_text == '14px'
	assert source.property(.width, .no)?.css_text == '7px'
	source.set_property_without_modifying_flags(.width, page_reuse_value('11px'))
	third := computed_style_in_layout_coordinates(page_reuse_source(source), document)
	assert third.property(.width, .no)?.css_text == '22px'
	assert second.property(.width, .no)?.css_text == '14px'
}

fn test_device_layout_page_reuse_rejects_contextual_untyped_and_animated_pages() {
	mut document, mut source := page_reuse_fixture('font:16px Arial;width:7px')
	defer { document.finalize(); document.release_native_storage() }
	document.set_layout_coordinate_scale(2)
	for value in [page_reuse_value('calc(50% - 3px)'),
		page_reuse_value('2em'), &dom.StyleValue{css_text: '9px'}] {
		source.set_property_without_modifying_flags(.width, value)
		_ = computed_style_in_layout_coordinates(page_reuse_source(source), document)
		page := source.property_store_.pages[page_reuse_index(.width)]
		assert css_style_computer_for(document).device_layout_page(page, page_reuse_index(.width), 2) == none
	}
	source.set_property_without_modifying_flags(.width, page_reuse_value('0px'))
	source.set_animated_property(.width, page_reuse_value('13px'), .no, .no)
	projected := computed_style_in_layout_coordinates(page_reuse_source(source), document)
	assert projected.property(.width, .no)?.css_text == '26px'
	assert source.property(.width, .no)?.css_text == '0px'
}

fn test_device_layout_page_reuse_checks_property_position_scale_and_recycled_generation() {
	mut document, source := page_reuse_fixture('font:16px Arial;width:7px')
	defer { document.finalize(); document.release_native_storage() }
	document.set_layout_coordinate_scale(2)
	_ = computed_style_in_layout_coordinates(page_reuse_source(source), document)
	index := page_reuse_index(.width)
	mut page := source.property_store_.pages[index]
	computer := css_style_computer_for(document)
	assert computer.device_layout_page(page, index, 2) != none
	assert computer.device_layout_page(page, index + 1, 2) == none
	assert computer.device_layout_page(page, index, 3) == none
	page.invalidate_device_layout_candidates()
	assert computer.device_layout_page(page, index, 2) == none
	page.device_layout_generation_ = ~u64(0)
	page.invalidate_device_layout_candidates()
	assert page.device_layout_generation_ == 0
	page.invalidate_device_layout_candidates()
	assert page.device_layout_generation_ == 0
}

fn test_device_layout_page_reuse_survives_projection_scratch_retirement() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	document.set_layout_coordinate_scale(2)
	mut source := computed_properties_with_initial_values()
	source.set_property_without_modifying_flags(.width, page_reuse_value('7px'))
	mut scratch := platform.begin_thread_scratch('device page projection test')
	first := computed_style_in_layout_coordinates(page_reuse_source(source), document)
	scratch.finish()
	second := computed_style_in_layout_coordinates(page_reuse_source(source), document)
	index := page_reuse_index(.width)
	assert voidptr(first.property_store_.pages[index]) == voidptr(second.property_store_.pages[index])
	assert second.property(.width, .no)?.css_text == '14px'
	$if prealloc {
		owner := document.native_storage()
		assert owner.arena.contains(voidptr(second.property_store_.pages[index]))
		assert owner.arena.contains(voidptr(css_style_computer_for(document).device_layout_property_pages_))
	}
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_device_layout_page_reuse_does_not_retain_scratch_source_pages() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_layout_coordinate_scale(2)
	mut scratch := platform.begin_thread_scratch('borrowed source property pages')
	mut source := computed_properties_with_initial_values()
	source.set_property_without_modifying_flags(.width, page_reuse_value('7px'))
	index := page_reuse_index(.width)
	page := source.property_store_.pages[index]
	projected := computed_style_in_layout_coordinates(source, document)
	assert projected.property(.width, .no)?.css_text == '14px'
	assert css_style_computer_for(document).device_layout_page(page, index, 2) == none
	scratch.finish()
	document.finalize()
	document.release_native_storage()
}

fn test_device_layout_page_reuse_does_not_publish_host_owned_pages_on_a_child_computer() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_layout_coordinate_scale(2)
	mut child_scope := document.enter_native_storage()
	mut source := computed_properties_with_initial_values()
	source.set_property_without_modifying_flags(.width, page_reuse_value('7px'))
	computer := css_style_computer_for(document)
	child_scope.finish()
	mut host := platform.new_retained_arena('host of projected child document')
	mut host_scope := host.enter()
	defer {
		host_scope.finish()
		host.release()
		document.finalize()
		document.release_native_storage()
	}
	projected := computed_style_in_layout_coordinates(page_reuse_source(source), document)
	assert projected.property(.width, .no)?.css_text == '14px'
	index := page_reuse_index(.width)
	retained := computer.device_layout_page(source.property_store_.pages[index], index, 2) != none
	assert !retained
}
