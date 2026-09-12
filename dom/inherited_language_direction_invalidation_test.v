module dom

fn inherited_invalidation_test_element(document &Document, name string) &Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
}

fn clear_inherited_invalidation_test_flags(nodes ...&Node) {
	for node in nodes {
		mut mutable_node := unsafe { &Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_child_needs_style_update(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
	}
}

fn test_dir_and_lang_changes_invalidate_shadow_including_descendants() {
	mut document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	mut host := inherited_invalidation_test_element(document, 'div')
	host.set_attribute_value('lang', 'en')
	document_node.append_child(host.as_node()) or { panic(err) }
	mut light_child := inherited_invalidation_test_element(document, 'span')
	mut host_node := host.as_node()
	host_node.append_child(light_child.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &Node(shadow_root) }
	mut shadow_child := inherited_invalidation_test_element(document, 'span')
	shadow_node.append_child(shadow_child.as_node()) or { panic(err) }
	assert light_child.lang() or { '' } == 'en'
	assert shadow_child.lang() or { '' } == 'en'

	clear_inherited_invalidation_test_flags(document_node, host.as_node(), light_child.as_node(),
		shadow_node, shadow_child.as_node())
	host.set_attribute_value('dir', 'rtl')
	assert light_child.needs_style_update()
	assert shadow_child.needs_style_update()

	clear_inherited_invalidation_test_flags(document_node, host.as_node(), light_child.as_node(),
		shadow_node, shadow_child.as_node())
	host.set_attribute_value('lang', 'fr')
	assert light_child.needs_style_update()
	assert shadow_child.needs_style_update()
	assert light_child.lang() or { '' } == 'fr'
	assert shadow_child.lang() or { '' } == 'fr'
}
