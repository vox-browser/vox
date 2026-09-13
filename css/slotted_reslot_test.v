module css

import dom

fn test_slotted_rules_skip_intermediate_reslotted_slot_elements() {
	document := dom.Document.create(dom.url_about_blank())
	mut outer_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'outer-host') or {
		panic(err)
	}
	mut leaf := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or {
		panic(err)
	}
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(outer_host.as_node()) or { panic(err) }
	mut outer_host_node := outer_host.as_node()
	outer_host_node.append_child(leaf.as_node()) or { panic(err) }

	outer_shadow := outer_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'inner-host') or {
		panic(err)
	}
	mut outer_slot := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		panic(err)
	}
	mut outer_shadow_node := unsafe { &dom.Node(outer_shadow) }
	outer_shadow_node.append_child(inner_host.as_node()) or { panic(err) }
	mut inner_host_node := inner_host.as_node()
	inner_host_node.append_child(outer_slot.as_node()) or { panic(err) }

	inner_shadow := inner_host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut inner_slot := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot') or {
		panic(err)
	}
	mut inner_shadow_node := unsafe { &dom.Node(inner_shadow) }
	inner_shadow_node.append_child(inner_slot.as_node()) or { panic(err) }
	add_shadow_root_author_style_sheet(inner_shadow, '::slotted(*) { color: red }')

	assert leaf.as_node().assigned_slot_internal() != none
	assert outer_slot.as_node().assigned_slot_internal() != none
	assert outer_slot.as_node().root().is_shadow_root()
	computer := StyleComputer.new(document)
	slot_style := computer.compute_style(dom.AbstractElement.new(outer_slot, none))
	leaf_style := computer.compute_style(dom.AbstractElement.new(leaf, none))
	assert (slot_style.property(.color, .no) or { panic('slot color missing') }).css_text != 'rgb(255, 0, 0)'
	assert (leaf_style.property(.color, .no) or { panic('leaf color missing') }).css_text == 'rgb(255, 0, 0)'
}
