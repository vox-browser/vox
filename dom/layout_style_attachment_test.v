module dom

fn test_repeated_layout_attachment_reuses_the_live_style_wrapper_and_refreshes_properties() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	first_properties := &CSSComputedProperties_{font_weight_: 400}
	element.computed_properties_ = first_properties
	mut node := element.as_node()
	layout_node := &LayoutNode{}
	node.set_layout_node(layout_node)
	mut wrapper := element.layout_node_with_style_?
	assert voidptr(wrapper.applied_properties_?) == voidptr(first_properties)
	wrapper.kind_ = .block_container
	next_properties := &CSSComputedProperties_{font_weight_: 700}
	element.computed_properties_ = next_properties
	for _ in 0 .. 8 {
		node.set_layout_node(layout_node)
		current := element.layout_node_with_style_?
		assert voidptr(current) == voidptr(wrapper)
		assert voidptr(current.applied_properties_?) == voidptr(next_properties)
		assert current.kind_ == .inline_node
	}
}

fn test_replacing_a_layout_boundary_preserves_the_previous_wrapper_association() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	mut node := element.as_node()
	first := &LayoutNode{}
	node.set_layout_node(first)
	previous := element.layout_node_with_style_?
	next := &LayoutNode{}
	node.set_layout_node(next)
	current := element.layout_node_with_style_?
	assert voidptr(current) != voidptr(previous)
	assert voidptr(previous.layout_node_?) == voidptr(first)
	assert voidptr(current.layout_node_?) == voidptr(next)
}

fn test_detaching_a_layout_boundary_does_not_revive_its_retired_style_wrapper() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut element := document.create_element('div')!
	mut node := element.as_node()
	layout_node := &LayoutNode{}
	node.set_layout_node(layout_node)
	previous := element.layout_node_with_style_?
	node.clear_layout_node_and_paintable()
	assert element.layout_node_with_style_ == none
	node.set_layout_node(layout_node)
	assert voidptr(element.layout_node_with_style_?) != voidptr(previous)
}
