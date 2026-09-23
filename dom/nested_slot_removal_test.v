module dom

struct NestedSlotFixture {
	host      &Element
	wrapper   &Element
	slot      &HTMLSlotElement
	slottable &Element
}

fn nested_slot_fixture(mut document Document, name string) NestedSlotFixture {
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(ShadowRootInit{ mode: .open }) or { panic(err) }
	mut wrapper := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut slot_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		panic(err)
	}
	if name != '' {
		slot_element.set_attribute_value('name', name)
	}
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(slot_element.as_node()) or { panic(err) }
	mut shadow_node := unsafe { &Node(shadow_root) }
	shadow_node.append_child(wrapper.as_node()) or { panic(err) }
	mut slottable := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span') or {
		panic(err)
	}
	if name != '' {
		slottable.set_attribute_value('slot', name)
	}
	mut host_node := host.as_node()
	host_node.append_child(slottable.as_node()) or { panic(err) }
	return NestedSlotFixture{
		host: host
		wrapper: wrapper
		slot: unsafe { &HTMLSlotElement(slot_element) }
		slottable: slottable
	}
}

fn assert_nested_slot_is_assigned(fixture NestedSlotFixture) {
	assert fixture.slot.assigned_nodes_internal().len == 1
	assert voidptr(fixture.slot.assigned_nodes_internal()[0]) == voidptr(fixture.slottable.as_node())
	assigned_slot := fixture.slottable.as_node().assigned_slot_internal() or {
		panic('slottable was not assigned')
	}
	assert voidptr(assigned_slot) == voidptr(fixture.slot)
}

fn assert_nested_slot_is_unassigned(fixture NestedSlotFixture) {
	assert fixture.slot.assigned_nodes_internal().len == 0
	assert fixture.slottable.as_node().assigned_slot_internal() == none
}

fn test_removing_a_wrapper_unassigns_its_descendant_slots() {
	mut document := Document.create(url_about_blank())
	fixture := nested_slot_fixture(mut document, 'named')
	assert_nested_slot_is_assigned(fixture)

	mut wrapper_node := fixture.wrapper.as_node()
	wrapper_node.remove(false)
	assert_nested_slot_is_unassigned(fixture)
}

fn test_moving_a_wrapper_out_of_a_shadow_tree_unassigns_its_descendant_slots() {
	mut document := Document.create(url_about_blank())
	fixture := nested_slot_fixture(mut document, '')
	assert_nested_slot_is_assigned(fixture)
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	mut host_node := fixture.host.as_node()
	host_node.append_child(target.as_node()) or { panic(err) }

	mut wrapper_node := fixture.wrapper.as_node()
	mut target_node := target.as_node()
	wrapper_node.move_node(mut target_node, none)!
	assert_nested_slot_is_unassigned(fixture)
}
