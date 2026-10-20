module css

import dom

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
