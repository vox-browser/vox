module css

import dom

#include "computed_property_store_test.h"

fn C.vox_property_store_bytes() u32
fn C.vox_property_page_bytes() u32

$if gcboehm ? {
	fn C.vox_property_store_watch(index u32, owner voidptr)
	fn C.vox_property_store_collect(depth u32)
	fn C.vox_property_store_worker(work fn ())
	fn C.vox_property_store_alive() u32
}

__global property_store_iteration_ids []PropertyID

fn property_store_value(text string) &dom.StyleValue {
	return parse_css_value(ParsingParams{}, text, .width) or { panic(text) }
}

fn property_store_iterate(property PropertyID, _ &dom.StyleValue) {
	property_store_iteration_ids << property
}

fn test_paged_property_new_initial_nil_equality_and_ordered_iteration() {
	mut empty := ComputedProperties.new()
	assert empty.raw_property_count() == number_of_longhand_properties
	assert empty.property(.width, .no) == none
	assert empty.equals(ComputedProperties.new())
	assert (ComputedProperties{}).raw_property_count() == 0
	assert empty.raw_property_at_index(-1) == unsafe { nil }
	assert empty.raw_property_at_index(number_of_longhand_properties) == unsafe { nil }
	initial := computed_properties_with_initial_values()
	assert !initial.equals(empty)
	assert initial.property(.width, .no) != none
	value := property_store_value('41px')
	empty.set_property(.width, value, .no, .no)
	empty.set_property(.height, value, .no, .no)
	property_store_iteration_ids = []PropertyID{}
	empty.for_each_property(property_store_iterate)
	assert property_store_iteration_ids == [PropertyID.height, .width]
	assert empty.equals(&ComputedProperties{ ...empty })
}

fn test_paged_property_alias_writes_in_both_orders_keep_value_flags_behavior() {
	mut style := computed_properties_with_initial_values()
	mut alias := *style
	first := property_store_value('41px')
	second := property_store_value('93px')
	style.set_property(.width, first, .no, .no)
	assert (alias.property(.width, .no) or { panic('lost alias') }) == first
	alias.set_property(.width, second, .yes, .yes)
	assert (style.property(.width, .no) or { panic('lost original') }) == second
	assert !style.is_property_important(.width)
	assert alias.is_property_important(.width)
	assert !style.is_property_inherited(.width)
	assert alias.is_property_inherited(.width)
	assert voidptr(style.property_store_) == voidptr(alias.property_store_)
	assert voidptr(style.computed_property_graph_token_) == voidptr(alias.computed_property_graph_token_)
	mut computer := StyleComputer.new(dom.Document.create(dom.url_about_blank()))
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	computer.publish_computed_property_pages(style)
	assert style.property_store_.writable == 0
	alias.set_property(.height, first, .no, .no)
	assert (style.property(.height, .no) or { panic('lost published alias') }) == first
	style.set_property(.height, second, .no, .no)
	assert (alias.property(.height, .no) or { panic('lost reverse alias') }) == second
}

fn test_paged_property_explicit_clone_freezes_source_aliases_and_isolates_both_writers() {
	mut style := computed_properties_with_initial_values()
	first := property_store_value('41px')
	second := property_store_value('93px')
	style.set_property(.width, first, .no, .no)
	mut alias := *style
	mut clone := &ComputedProperties{ ...style, property_store_: style.clone_raw_property_store(), computed_property_graph_token_: unsafe { nil } }
	assert voidptr(clone.property_store_) != voidptr(style.property_store_)
	assert clone.property_store_.writable == 0 && style.property_store_.writable == 0
	alias.set_property(.width, second, .no, .no)
	assert (clone.property(.width, .no) or { panic('lost clone') }) == first
	clone.set_property(.height, second, .no, .no)
	assert (style.property(.height, .no) or { panic('lost original') }) != second
	assert !clone.equals(style)
	mut table_source := computed_properties_with_initial_values()
	table_source.set_property(.margin_left, first, .no, .no)
	table, wrapper := table_source.table_box_and_wrapper_properties()
	assert (table_source.property(.margin_left, .no) or { panic('source margin') }) == first
	assert (table.property(.margin_left, .no) or { panic('table margin') }) != first
	assert (wrapper.property(.margin_left, .no) or { panic('wrapper margin') }) == first
}

fn test_paged_property_revert_restores_raw_value_and_independent_flags() {
	mut previous := computed_properties_with_initial_values()
	first := property_store_value('41px')
	previous.set_property(.width, first, .yes, .yes)
	mut current := computed_properties_with_initial_values()
	current.set_property(.width, property_store_value('93px'), .no, .no)
	current.revert_property(.width, previous)
	assert (current.property(.width, .no) or { panic('missing reverted width') }) == first
	assert current.is_property_important(.width) && current.is_property_inherited(.width)
	current.set_property(.height, first, .no, .no)
	assert (previous.property(.height, .no) or { panic('missing old height') }) != first
}

fn test_paged_property_publication_keeps_tokens_and_preserves_shared_page_cow() {
	mut computer := StyleComputer.new(dom.Document.create(dom.url_about_blank()))
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut first := computed_properties_with_initial_values()
	mut second := computed_properties_with_initial_values()
	value := property_store_value('41px')
	first.set_property(.width, value, .no, .no)
	second.set_property(.width, value, .no, .no)
	token := first.computed_property_graph_token_
	generation := token.generation
	computer.publish_computed_property_pages(first)
	computer.publish_computed_property_pages(second)
	assert voidptr(first.computed_property_graph_token_) == voidptr(token) && token.generation == generation
	index := int(PropertyID.width) - int(first_longhand_property_id())
	assert voidptr(first.property_store_.pages[index >> 4]) == voidptr(second.property_store_.pages[index >> 4])
	assert voidptr(first.property_store_) != voidptr(second.property_store_)
	first.set_property(.width, property_store_value('93px'), .no, .no)
	assert (second.property(.width, .no) or { panic('mutated second page') }) == value
}

fn test_paged_property_interner_rejects_hash_collisions_and_caps_entries() {
	mut pool := ComputedPropertyPageInterner{}
	mut first := &ComputedPropertyPage{}
	mut second := &ComputedPropertyPage{}
	first.values[0] = property_store_value('41px')
	second.values[0] = property_store_value('93px')
	assert pool.intern(first, 7) == first
	assert pool.intern(second, 7) == second
	assert pool.pages.len == 1 && pool.pages[7] == first
	identical := copy_computed_property_page(first)
	assert pool.intern(identical, 7) == first
	for index in 0 .. computed_property_page_pool_limit + 10 {
		_ = pool.intern(first, u64(index + 100))
	}
	assert pool.pages.len == computed_property_page_pool_limit
	assert pool.intern(second, ~u64(0)) == second
	assert pool.pages.len == computed_property_page_pool_limit
}

fn test_paged_property_controlled_shared_styles_have_bounded_logical_payload() {
	assert computed_property_page_count <= 32
	assert C.vox_property_store_bytes() == 208
	assert C.vox_property_page_bytes() == 128
	mut computer := StyleComputer.new(dom.Document.create(dom.url_about_blank()))
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut styles := []&ComputedProperties{}
	value := property_store_value('41px')
	mut pages := map[u64]bool{}
	mut stores := map[u64]bool{}
	for _ in 0 .. 256 {
		mut style := computed_properties_with_initial_values()
		style.set_property(.width, value, .no, .no)
		computer.publish_computed_property_pages(style)
		styles << style
		stores[u64(voidptr(style.property_store_))] = true
		for page in style.property_store_.pages { pages[u64(voidptr(page))] = true }
	}
	assert styles.len == 256 && stores.len == 256
	assert pages.len == computed_property_page_count
	payload := stores.len * int(C.vox_property_store_bytes()) + pages.len * int(C.vox_property_page_bytes())
	dense_payload := styles.len * number_of_longhand_properties * int(sizeof(voidptr))
	println('controlled_property_payload=${payload} dense_pointer_payload=${dense_payload}')
	assert payload < dense_payload / 4
}

@[noinline]
fn property_store_create_document_graph() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'section') or { panic(err) }
	mut computer := StyleComputer.new(document)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut style := computer.compute_style(dom.AbstractElement.new(element, none))
	style.set_property(.width, property_store_value('314159px'), .no, .no)
	computer.publish_computed_property_pages(style)
	index := int(PropertyID.width) - int(first_longhand_property_id())
	$if gcboehm ? {
		C.vox_property_store_watch(0, voidptr(document))
		C.vox_property_store_watch(1, voidptr(computer))
		C.vox_property_store_watch(2, voidptr(style.property_store_.pages[index >> 4]))
	}
	document.finalize()
}

fn test_paged_property_document_owned_interner_and_values_are_collectible() {
	$if gcboehm ? {
		C.vox_property_store_worker(property_store_create_document_graph)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		mask := C.vox_property_store_alive()
		println('property_store_owner_mask=${mask}')
		assert mask == 0
	} $else {
		property_store_create_document_graph()
	}
}

fn test_paged_property_identity_rejects_equal_content_distinct_mutable_wrappers() {
	first_value := &dom.StyleValue{ css_text: '41px' }
	mut second_value := &dom.StyleValue{ css_text: '41px' }
	assert voidptr(first_value) != voidptr(second_value)
	mut first := &ComputedPropertyPage{}
	mut second := &ComputedPropertyPage{}
	first.values[0] = first_value
	second.values[0] = second_value
	mut pool := ComputedPropertyPageInterner{}
	assert voidptr(pool.intern(first, 71)) == voidptr(first)
	assert voidptr(pool.intern(second, 71)) == voidptr(second)
	mut style := ComputedProperties.new()
	style.set_property(.width, first_value, .no, .no)
	style.set_property(.width, second_value, .no, .no)
	assert voidptr(style.property(.width, .no) or { panic('missing replacement') }) == voidptr(second_value)
	second_value.css_text = '93px'
	assert (style.property(.width, .no) or { panic('missing mutable replacement') }).css_text == '93px'
	assert first_value.css_text == '41px'
	mut equal_style := ComputedProperties.new()
	equal_style.set_property(.width, &dom.StyleValue{ css_text: '93px' }, .no, .no)
	assert style.equals(equal_style)
}

fn test_paged_property_initial_template_and_cloned_pages_are_independent() {
	mut first := computed_properties_with_initial_values()
	assert computed_interpolation_initial_values_complete
	assert computed_interpolation_initial_value_cache.len == number_of_longhand_properties
	for index in 0 .. number_of_longhand_properties {
		assert voidptr(first.raw_property_at_index(index)) == voidptr(computed_interpolation_initial_value_cache[index])
	}
	index := int(PropertyID.width) - int(first_longhand_property_id())
	initial := first.raw_property_at_index(index)
	initial_page := computed_initial_property_store.pages[index >> 4]
	first.set_property(.width, property_store_value('41px'), .no, .no)
	assert voidptr(initial_page.values[index & 15]) == voidptr(initial)
	second := computed_properties_with_initial_values()
	assert voidptr(second.raw_property_at_index(index)) == voidptr(initial)
	mut clone := &ComputedProperties{ ...first, property_store_: first.clone_raw_property_store() }
	frozen_page := first.property_store_.pages[index >> 4]
	clone.set_property(.width, property_store_value('93px'), .no, .no)
	assert frozen_page.values[index & 15].css_text == '41px'
	assert first.raw_property_at_index(index).css_text == '41px'
	first.set_property(.width, property_store_value('17px'), .no, .no)
	assert clone.raw_property_at_index(index).css_text == '93px'
	assert frozen_page.values[index & 15].css_text == '41px'
}

fn test_paged_property_late_initial_fill_preserves_constructor_snapshots() {
	_ = computed_properties_with_initial_values()
	index := int(PropertyID.width) - int(first_longhand_property_id())
	previous := computed_interpolation_initial_value_cache[index]
	defer {
		computed_interpolation_initial_value_cache[index] = previous
		update_initial_computed_property_page(index, previous)
	}
	computed_interpolation_initial_value_cache[index] = unsafe { nil }
	update_initial_computed_property_page(index, unsafe { nil })
	before := computed_properties_with_initial_values()
	assert before.property(.width, .no) == none
	late := computed_interpolation_property_initial_value(.width)
	after := computed_properties_with_initial_values()
	assert voidptr(after.raw_property_at_index(index)) == voidptr(late)
	assert before.property(.width, .no) == none
}

__global property_store_live_computer &StyleComputer
__global property_store_live_current &ComputedProperties
__global property_store_live_old_snapshot &ComputedProperties

fn test_paged_property_nested_batches_drop_only_pool_and_preserve_published_pages() {
	computer := StyleComputer.new(dom.Document.create(dom.url_about_blank()))
	mut style := computed_properties_with_initial_values()
	style.set_property(.width, property_store_value('41px'), .no, .no)
	computer.begin_computed_property_page_batch()
	computer.begin_computed_property_page_batch()
	computer.publish_computed_property_pages(style)
	pool := computer.computed_property_page_interner_
	assert pool != unsafe { nil }
	computer.end_computed_property_page_batch()
	assert voidptr(computer.computed_property_page_interner_) == voidptr(pool)
	computer.end_computed_property_page_batch()
	assert computer.computed_property_page_batch_depth_ == 0
	assert computer.computed_property_page_interner_ == unsafe { nil }
	assert (style.property(.width, .no) or { panic('lost published page') }).css_text == '41px'
	style.set_property(.width, property_store_value('93px'), .no, .no)
	assert (style.property(.width, .no) or { panic('lost COW after batch') }).css_text == '93px'
}

@[noinline]
fn property_store_setup_live_image_graph() {
	mut document := dom.Document.create(dom.URL{ value: 'https://property.test/' })
	document.set_scripting_enabled_by_embedder(false)
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	computer := StyleComputer.new(document)
	computer.begin_computed_property_page_batch()
	defer { computer.end_computed_property_page_batch() }
	mut current := computer.compute_style(dom.AbstractElement.new(element, none))
	// Use the actual image/request records without registering a separate cache
	// owner on Document. This isolates the page-pool edge being tested.
	request := &dom.SharedResourceRequest{ url: dom.URL{ value: 'https://property.test/old-property.svg' }, document: document }
	mut image := ImageStyleValue.create_from_url_string(request.url.value)
	image.document_ = document
	image.resource_request_ = request
	value := dom_style_value_from_value_logic(StyleValue(image))
	current.set_property(.background_image, value, .no, .no)
	computer.publish_computed_property_pages(current)
	property_store_live_old_snapshot = &ComputedProperties{ ...current, property_store_: current.clone_raw_property_store() }
	current.set_property(.background_image, computed_interpolation_property_initial_value(.background_image), .no, .no)
	computer.publish_computed_property_pages(current)
	property_store_live_current = current
	property_store_live_computer = computer
	$if gcboehm ? {
		C.vox_property_store_watch(0, voidptr(value))
		C.vox_property_store_watch(1, voidptr(request))
		C.vox_property_store_watch(2, value.css_value_handle)
	}
}

fn property_store_drop_old_snapshot() {
	assert property_store_live_computer.computed_property_page_batch_depth_ == 0
	assert property_store_live_computer.computed_property_page_interner_ == unsafe { nil }
	assert (property_store_live_current.property(.background_image, .no) or { panic('lost current style') }).css_text == 'none'
	assert (property_store_live_old_snapshot.property(.background_image, .no) or { panic('lost old snapshot') }).css_text.contains('old-property.svg')
	property_store_live_old_snapshot = unsafe { nil }
}

fn property_store_release_live_graph() {
	mut document := unsafe { &dom.Document(property_store_live_computer.document_) }
	document.finalize()
	property_store_live_current = unsafe { nil }
	property_store_live_computer = unsafe { nil }
}

fn test_paged_property_finished_batch_releases_old_image_graph_with_document_alive() {
	$if gcboehm ? {
		C.vox_property_store_worker(property_store_setup_live_image_graph)
		C.vox_property_store_collect(8)
		assert C.vox_property_store_alive() == 7
		C.vox_property_store_worker(property_store_drop_old_snapshot)
		C.vox_property_store_collect(8)
		C.vox_property_store_collect(8)
		mask := C.vox_property_store_alive()
		println('live_document_discarded_image_mask=${mask}')
		assert mask == 0
		C.vox_property_store_worker(property_store_release_live_graph)
	} $else {
		property_store_setup_live_image_graph()
		property_store_drop_old_snapshot()
		property_store_release_live_graph()
	}
}

fn test_paged_property_document_batches_follow_class_inline_and_background_mutations() {
	mut document := dom.Document.create(dom.URL{ value: 'https://property.test/' })
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic(err) }
	body := document.create_element_ns('http://www.w3.org/1999/xhtml', 'body') or { panic(err) }
	style_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'style') or { panic(err) }
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut document_node := document.as_node()
	mut root_node := root.as_node()
	mut body_node := body.as_node()
	mut style_node := style_element.as_node()
	document_node.append_child(root.as_node()) or { panic(err) }
	root_node.append_child(body.as_node()) or { panic(err) }
	body_node.append_child(style_element.as_node()) or { panic(err) }
	body_node.append_child(target.as_node()) or { panic(err) }
	style_node.append_child(dom.Text.new(document, '.first { color: red } .second { color: blue }').as_node()) or { panic(err) }
	target.set_attribute_value('class', 'first')
	target.set_attribute_value('style', 'width:41px;background-image:url(https://property.test/first.svg)')
	sync_document_style_elements(document)
	computer := css_style_computer_for(document)
	document.set_needs_full_style_update(true)
	document.update_style()
	before := up_to_date_computed_properties_for_element(target)
	assert property_store_raw_color(before) == Color{255, 0, 0, 255}
	assert (before.property(.background_image, .no) or { panic('missing old background') }).css_text.contains('first.svg')
	assert computer.computed_property_page_batch_depth_ == 0
	assert computer.computed_property_page_interner_ == unsafe { nil }
	target.set_attribute_value('class', 'second')
	document.update_style()
	after_class := up_to_date_computed_properties_for_element(target)
	assert property_store_raw_color(after_class) == Color{0, 0, 255, 255}
	target.set_attribute_value('style', 'width:93px;background-image:url(https://property.test/second.svg)')
	document.update_style()
	after_inline := up_to_date_computed_properties_for_element(target)
	assert (after_inline.property(.width, .no) or { panic('missing new width') }).css_text == '93px'
	assert (after_inline.property(.background_image, .no) or { panic('missing new background') }).css_text.contains('second.svg')
	assert computer.computed_property_page_batch_depth_ == 0
	assert computer.computed_property_page_interner_ == unsafe { nil }
	assert (before.property(.background_image, .no) or { panic('mutated old background') }).css_text.contains('first.svg')
}

fn property_store_raw_color(style &ComputedProperties) Color {
	value := style.property(.color, .no) or { panic('missing color') }
	typed := style_value_logic_from_dom(.color, value) or { panic('missing typed color') }
	return typed.to_color(ColorResolutionContext{}) or { panic('unresolved color') }
}
