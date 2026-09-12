module dom

fn shadow_parts_element(document &Document, tag string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or {
		panic(err)
	}
}

fn append_shadow_parts_child(mut parent Node, child &Element) {
	parent.append_child(child.as_node()) or { panic(err) }
}

fn test_exportparts_forwards_and_renames_nested_part_elements() {
	document := Document.create(url_about_blank())
	mut outer_host := shadow_parts_element(document, 'outer-host')
	outer_root := outer_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_host := shadow_parts_element(document, 'inner-host')
	inner_host.set_attribute_value('exportparts', 'label: outer-label, icon')
	mut outer_root_node := shadow_root_as_node(outer_root)
	append_shadow_parts_child(mut outer_root_node, inner_host)

	inner_root := inner_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut label := shadow_parts_element(document, 'span')
	label.set_attribute_value('part', 'label icon')
	mut inner_root_node := shadow_root_as_node(inner_root)
	append_shadow_parts_child(mut inner_root_node, label)

	parts := outer_root.part_element_map()
	outer_labels := parts['outer-label'] or { panic('renamed part was not forwarded') }
	icons := parts['icon'] or { panic('shorthand part was not forwarded') }
	assert outer_labels.len == 1
	assert voidptr(outer_labels[0].element()) == voidptr(label)
	assert icons.len == 1
	assert voidptr(icons[0].element()) == voidptr(label)
	assert 'label' !in parts
}

fn test_exportparts_forwarding_is_transitive_and_deduplicated() {
	document := Document.create(url_about_blank())
	mut outer_host := shadow_parts_element(document, 'outer-host')
	outer_root := outer_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut middle_host := shadow_parts_element(document, 'middle-host')
	middle_host.set_attribute_value('exportparts', 'middle: public, middle: public')
	mut outer_root_node := shadow_root_as_node(outer_root)
	append_shadow_parts_child(mut outer_root_node, middle_host)

	middle_root := middle_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_host := shadow_parts_element(document, 'inner-host')
	inner_host.set_attribute_value('exportparts', 'private: middle')
	mut middle_root_node := shadow_root_as_node(middle_root)
	append_shadow_parts_child(mut middle_root_node, inner_host)

	inner_root := inner_host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut part := shadow_parts_element(document, 'span')
	part.set_attribute_value('part', 'private')
	mut inner_root_node := shadow_root_as_node(inner_root)
	append_shadow_parts_child(mut inner_root_node, part)

	parts := outer_root.part_element_map()
	public_parts := parts['public'] or { panic('transitive part was not forwarded') }
	assert public_parts.len == 1
	assert voidptr(public_parts[0].element()) == voidptr(part)
}
