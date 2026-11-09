module css

import dom

fn test_cascade_scratch_overrides_keep_importance_layer_source_and_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	defer { document.release_native_storage() }
	mut storage := document.enter_native_storage()
	defer { storage.finish() }
	computer := StyleComputer.new(document)
	mut lease := computer.acquire_cascade_scratch()
	defer { lease.finish() }
	mut cascade := lease.properties
	first := &dom.StyleValue{css_text:'first'}
	second := &dom.StyleValue{css_text:'second'}
	cascade.set_property(.color,first,.no,.author,'theme',voidptr(first),none)
	used := computer.cascade_scratch_.slots[0].arena.usage().used
	for _ in 0 .. 64 {
		cascade.set_property(.color,second,.yes,.author,'theme',voidptr(second),none)
		cascade.set_property(.color,first,.no,.author,'theme',voidptr(first),none)
	}
	assert cascade.style_property(.color)?.important == .yes
	assert voidptr(cascade.property(.color)?) == voidptr(second)
	assert cascade.property_source(.color) == voidptr(second)
	assert computer.cascade_scratch_.slots[0].arena.usage().used == used
	cascade.set_property(.color,first,.yes,.author,'override',voidptr(first),none)
	assert voidptr(cascade.property(.color)?) == voidptr(first)
	cascade.revert_layer_property(.color,.yes,'override')
	assert voidptr(cascade.property(.color)?) == voidptr(second)
}

fn test_cascade_scratch_reuses_capacity_and_preserves_nested_callers() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	mut computer := StyleComputer.new(document)
	value := &dom.StyleValue{css_text: 'retained value'}
	mut outer := computer.acquire_cascade_scratch()
	mut properties := outer.properties
	properties.set_property(.color, value, .no, .author, none, unsafe { nil }, none)
	mut nested := computer.acquire_cascade_scratch()
	mut inner := nested.properties
	inner.set_property(.width, value, .no, .author, none, unsafe { nil }, none)
	nested.finish()
	assert properties.property(.color)?.css_text == 'retained value'
	outer.finish()
	mut before := i64(0)
	for round in 0 .. 100 {
		mut lease := computer.acquire_cascade_scratch()
		mut cascade := lease.properties
		assert cascade.property(.color) == none
		for index in 1 .. 129 {
			property := unsafe { PropertyID(index) }
			cascade.set_property(property, value, .no, .author, none, unsafe { nil }, none)
			if index % 3 == 0 {
				cascade.revert_property(property, .no, .author)
				assert cascade.property(property) == none
				cascade.set_property(property, value, .no, .author, none, unsafe { nil }, none)
			}
		}
		lease.finish()
		if round == 0 { before = computer.cascade_scratch_.slots[0].arena.usage().used }
	}
	assert computer.cascade_scratch_.slots.len == 2
	assert computer.cascade_scratch_.slots[0].arena.usage().used <= before + 64
	assert value.css_text == 'retained value'
	document.release_native_storage()
	$if prealloc {
		assert computer.cascade_scratch_.slots[0].arena.usage().used == 0
		assert computer.cascade_scratch_.slots[0].properties == unsafe { nil }
	}
}

fn test_computed_styles_keep_their_values_after_cascade_scratch_is_reused() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element_ns(dom.namespace_html_uri, 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut first := document.create_element_ns(dom.namespace_html_uri, 'p')!
	mut second := document.create_element_ns(dom.namespace_html_uri, 'p')!
	first.set_attribute_value('style', 'color:red;direction:rtl;margin-inline-start:12px')
	second.set_attribute_value('style', 'color:blue;direction:ltr;margin-inline-start:4px')
	mut root_node := root.as_node()
	root_node.append_child(first.as_node())!
	root_node.append_child(second.as_node())!
	computer := StyleComputer.new(document)
	left := computer.compute_style(dom.AbstractElement.new(first, none))
	retained_color := left.property(.color, .no)?.css_text
	right := computer.compute_style(dom.AbstractElement.new(second, none))
	assert left.property(.color, .no)?.css_text == retained_color
	assert right.property(.color, .no)?.css_text != retained_color
	assert left.property(.direction, .no)?.css_text == 'rtl'
	assert right.property(.direction, .no)?.css_text == 'ltr'
	assert left.property(.margin_right, .no)?.css_text == '12px'
	assert right.property(.margin_left, .no)?.css_text == '4px'
}

fn test_cascade_scratch_reset_clears_payloads_and_visits_only_current_heads() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	defer { document.release_native_storage() }
	mut host := document.create_element_ns(dom.namespace_html_uri, 'div')!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	computer := StyleComputer.new(document)
	value := &dom.StyleValue{css_text: 'retained value'}
	mut lease := computer.acquire_cascade_scratch()
	mut properties := lease.properties
	for index in 0 .. int(PropertyID.container) + 1 {
		id := unsafe { PropertyID(index) }
		properties.set_property(id, value, .no, .author, 'retained-layer', voidptr(value), shadow)
	}
	snapshot := properties.entry_node(properties.winning_entry_index(.width)).entry
	allocated := properties.allocated_entry_count_
	chunks := properties.entry_chunks_.len
	capacity := properties.entry_heads_.active.cap
	buffer := properties.entry_heads_.active.data
	// Public stale presence must also clear, including a now-empty head.
	properties.revert_property(.height, .no, .author)
	properties.contained_properties_cache_[int(PropertyID.height)] = 1
	lease.finish()
	assert properties.entry_heads_.active.len == 0
	assert properties.entry_heads_.active.cap == capacity
	assert properties.entry_heads_.active.data == buffer
	assert properties.allocated_entry_count_ == 0
	assert properties.free_entry_index_ == -1
	for index in 0 .. allocated {
		node := properties.entry_node(index)
		assert node.entry.property.value == unsafe { nil }
		assert node.entry.source == unsafe { nil }
		assert node.entry.source_shadow_root == none
		assert node.entry.layer_name == none
		assert node.previous == -1
	}
	for bit in properties.contained_properties_cache_ { assert bit == 0 }
	assert voidptr(snapshot.property.value) == voidptr(value)
	assert snapshot.source == voidptr(value)
	assert snapshot.layer_name? == 'retained-layer'
	assert voidptr(snapshot.source_shadow_root?) == voidptr(shadow)

	mut next := computer.acquire_cascade_scratch()
	mut current := next.properties
	assert voidptr(current) == voidptr(properties)
	current.set_property(.color, value, .yes, .user, none, unsafe { nil }, none)
	current.set_property(.container, value, .no, .author, none, unsafe { nil }, none)
	assert current.entry_heads_.active.len == 2
	assert PropertyID.color in current.entry_heads_.active
	assert PropertyID.container in current.entry_heads_.active
	assert current.entry_chunks_.len == chunks
	assert current.entry_heads_.active.cap == capacity
	assert current.entry_heads_.active.data == buffer
	assert current.property(.width) == none
	next.finish()
}

fn test_cascade_scratch_growing_known_empty_active_ids_stays_in_bookkeeping_owner() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	defer { document.release_native_storage() }
	computer := StyleComputer.new(document)
	value := &dom.StyleValue{css_text: 'value'}
	mut first := computer.acquire_cascade_scratch()
	mut properties := first.properties
	mut arena := computer.cascade_scratch_.slots[0].arena
	entry := arena.enter()
	properties.entry_heads_.active = []PropertyID{cap: 1}
	arena.leave(entry)
	properties.set_property(.width, value, .no, .author, none, unsafe { nil }, none)
	first.finish()
	mut second := computer.acquire_cascade_scratch()
	mut second_properties := second.properties
	second_properties.set_property(.height, value, .no, .author, none, unsafe { nil }, none)
	second.finish()
	assert properties.entry_heads_.contains(.width)
	assert properties.entry_heads_.contains(.height)
	assert properties.entry_heads_.active.cap == 1

	mut third := computer.acquire_cascade_scratch()
	mut current := third.properties
	current.set_property(.width, value, .no, .author, none, unsafe { nil }, none)
	assert !current.entry_heads_.can_set_without_allocation(.height)
	current.set_property(.height, value, .no, .author, none, unsafe { nil }, none)
	assert current.entry_heads_.active.len == 2
	assert current.entry_heads_.active.cap >= 2
	$if prealloc { assert arena.contains(current.entry_heads_.active.data) }
	third.finish()
}
