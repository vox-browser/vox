module dom

fn test_part_attribute_change_marks_element_for_style_update() {
	document := Document.create(url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut node := element.as_node()
	node.set_needs_style_update_internal(false)

	element.attribute_changed('part', none, 'label icon', none)
	assert element.part_names() == ['label', 'icon']
	assert element.needs_style_update()
}

fn test_exportparts_change_invalidates_part_elements_in_shadow_tree() {
	document := Document.create(url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'x-host') or {
		panic(err)
	}
	shadow_root := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &Node(shadow_root) }
	mut part := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	part.set_attribute_value('part', 'label')
	mut bystander := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	shadow_node.append_child(part.as_node()) or { panic(err) }
	shadow_node.append_child(bystander.as_node()) or { panic(err) }
	mut part_node := part.as_node()
	part_node.set_needs_style_update_internal(false)
	mut bystander_node := bystander.as_node()
	bystander_node.set_needs_style_update_internal(false)

	host.attribute_changed('exportparts', none, 'label: public-label', none)
	assert part.needs_style_update()
	assert !bystander.needs_style_update()
}
