module css

import dom

fn projection_page_value(text string, property PropertyID) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, property) or { panic(text) }
}

fn projection_page_test_style() (&dom.Document, &ComputedProperties) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	document.set_font_rendering_policy(.chromium)
	mut root := document.create_element('html') or { panic(err) }
	root.set_attribute_value('style', 'font:16px Arial;width:0px')
	mut node := document.as_node()
	node.append_child(root.as_node()) or { panic(err) }
	_ = css_style_computer_for(document)
	document.update_style()
	return document, up_to_date_computed_properties_for_element(root)
}

fn test_projection_page_candidates_keep_untyped_keywords_and_nested_lengths() {
	mut page := &ComputedPropertyPage{}
	page.values[0] = projection_page_value('0px', .width)
	page.values[1] = projection_page_value('4px', .width)
	page.values[2] = projection_page_value('50%', .width)
	page.values[3] = dom_style_value_from_value_logic(StyleValue(KeywordStyleValue.create(.thin)))
	page.values[4] = &dom.StyleValue{ css_text: 'calc(50% - 3px)' }
	page.values[5] = projection_page_value('translate(3px, 4px)', .transform)
	page.values[6] = projection_page_value('red', .color)
	page.values[7] = projection_page_value('0px 25%', .background_size)
	page.values[8] = projection_page_value('1em', .width)
	expected := u16((1 << 1) | (1 << 3) | (1 << 4) | (1 << 5) | (1 << 8))
	assert page.device_layout_candidates() == expected
	assert page.device_layout_candidates() == expected
	// The same interned page may occupy different property positions. A border
	// keyword remains a candidate independently of its slot's property ID.
	assert page.device_layout_candidates_ == u64(expected) | 0x10000
}

fn test_projection_page_masks_preserve_all_initial_property_candidates() {
	initial := computed_properties_with_initial_values()
	for index, property in computed_interpolation_longhand_property_ids() {
		value := initial.raw_property_at_index(index)
		if value == unsafe { nil } { continue }
		mask := initial.property_store_.pages[index >> 4].device_layout_candidates()
		if value.css_value_handle == unsafe { nil } {
			assert mask & (u16(1) << (index & 15)) != 0
		} else {
			box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
			if device_layout_value_needs_projection(property, &box.value) {
				assert mask & (u16(1) << (index & 15)) != 0
			}
		}
	}
}

fn test_projection_page_cache_invalidates_writes_and_preserves_cow_snapshots() {
	mut source := ComputedProperties.new()
	index := int(PropertyID.width) - int(first_longhand_property_id())
	bit := u16(1) << (index & 15)
	source.set_property(.width, projection_page_value('0px', .width), .no, .no)
	old := source.property_store_.pages[index >> 4]
	assert old.device_layout_candidates() & bit == 0
	mut snapshot := &ComputedProperties{ ...source, property_store_: source.clone_raw_property_store() }
	source.set_property(.width, projection_page_value('9px', .width), .no, .no)
	assert source.property_store_.pages[index >> 4].device_layout_candidates() & bit != 0
	assert old.device_layout_candidates() & bit == 0
	assert snapshot.property(.width, .no)?.css_text == '0px'
	// An exclusive page is also writable after its first cached scan.
	source.set_property(.width, projection_page_value('0px', .width), .no, .no)
	assert source.property_store_.pages[index >> 4].device_layout_candidates() & bit == 0
	snapshot.set_property(.width, projection_page_value('3px', .width), .no, .no)
	assert snapshot.property_store_.pages[index >> 4].device_layout_candidates() & bit != 0
	assert old.device_layout_candidates() & bit == 0
}

fn test_projection_page_masks_do_not_hide_animations_or_transition_precedence() {
	mut document, mut source := projection_page_test_style()
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	assert computed_style_in_layout_coordinates(source, document).length_percentage_to_px(.width, 1600)? == 0
	animated := projection_page_value('7px', .width)
	source.set_animated_property(.width, animated, .no, .no)
	projected := computed_style_in_layout_coordinates(source, document)
	// Projection writes the selected value to the raw store and preserves the
	// source animation overlay. Inspect the raw result to exercise the fallback
	// scan even though the source page's zero width has no candidate bit.
	assert projected.property(.width, .no)?.css_text == '14px'
	assert voidptr(projected.property(.width, .yes)?) == voidptr(animated)
	assert source.property(.width, .no)?.css_text == '0px'
	source.set_property(.width, projection_page_value('0px', .width), .no, .yes)
	assert computed_style_in_layout_coordinates(source, document).length_percentage_to_px(.width, 1600)? == 0
	source.set_animated_property(.width, animated, .yes, .no)
	transitioned := computed_style_in_layout_coordinates(source, document)
	assert transitioned.property(.width, .no)?.css_text == '14px'
	assert voidptr(transitioned.property(.width, .yes)?) == voidptr(animated)
	source.remove_animated_property(.width)
	assert computed_style_in_layout_coordinates(source, document).length_percentage_to_px(.width, 1600)? == 0
}

fn test_projection_page_late_initial_fill_has_a_fresh_mask() {
	_ = computed_properties_with_initial_values()
	index := int(PropertyID.width) - int(first_longhand_property_id())
	previous := computed_interpolation_initial_value_cache[index]
	defer { update_initial_computed_property_page(index, previous) }
	zero := projection_page_value('0px', .width)
	update_initial_computed_property_page(index, zero)
	before := new_initial_computed_property_store()
	bit := u16(1) << (index & 15)
	assert before.pages[index >> 4].device_layout_candidates() & bit == 0
	update_initial_computed_property_page(index, projection_page_value('8px', .width))
	after := new_initial_computed_property_store()
	assert after.pages[index >> 4].device_layout_candidates() & bit != 0
	assert before.pages[index >> 4].device_layout_candidates() & bit == 0
}

fn test_projection_page_recycling_clears_and_recomputes_cached_masks() {
	$if !prealloc {
		return
	}
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	computer := StyleComputer.new(document)
	computer.begin_computed_property_page_batch()
	value := projection_page_value('4px', .width)
	index := int(PropertyID.width) - int(first_longhand_property_id())
	bit := u16(1) << (index & 15)
	mut first := computed_properties_with_initial_values()
	computer.prepare_computed_property_page_recycling(first)
	first.set_property(.width, value, .no, .no)
	computer.publish_computed_property_pages(first)
	mut duplicate := computed_properties_with_initial_values()
	computer.prepare_computed_property_page_recycling(duplicate)
	duplicate.set_property(.width, value, .no, .no)
	recycled := duplicate.property_store_.pages[index >> 4]
	assert recycled.device_layout_candidates() & bit != 0
	computer.publish_computed_property_pages(duplicate)
	assert computer.computed_property_page_recycling_.pages.len == 1
	assert recycled.device_layout_candidates() == 0
	mut next := computed_properties_with_initial_values()
	computer.prepare_computed_property_page_recycling(next)
	next.set_property(.width, projection_page_value('0px', .width), .no, .no)
	assert voidptr(next.property_store_.pages[index >> 4]) == voidptr(recycled)
	assert recycled.device_layout_candidates() & bit == 0
	assert first.property_store_.pages[index >> 4].device_layout_candidates() & bit != 0
	computer.end_computed_property_page_batch()
	allocations.finish()
	document.finalize()
	document.release_native_storage()
}
