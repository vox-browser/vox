module dom

fn test_slot_assignment_changes_invalidate_slottable_element_style() {
	mut document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &Node(shadow_root) }
	mut slot := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		panic(err)
	}
	shadow_node.append_child(slot.as_node()) or { panic(err) }
	mut slottable := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	mut host_node := host.as_node()
	host_node.append_child(slottable.as_node()) or { panic(err) }
	assert slottable.as_node().assigned_slot_internal() != none

	mut slottable_node := slottable.as_node()
	slottable_node.set_needs_style_update_internal(false)
	slot.set_attribute_value('name', 'other')
	assert slottable.as_node().assigned_slot_internal() == none
	assert slottable.needs_style_update()

	slottable_node.set_needs_style_update_internal(false)
	slot.set_attribute_value('name', '')
	assert slottable.as_node().assigned_slot_internal() != none
	assert slottable.needs_style_update()
}
