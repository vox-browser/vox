module dom

fn test_part_attribute_change_marks_element_for_style_update() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut node := element.as_node()
	node.set_needs_style_update_internal(false)

	element.attribute_changed('part', none, 'label icon', none)
	assert element.parts == ['label', 'icon']
	assert element.needs_style_update()
}
