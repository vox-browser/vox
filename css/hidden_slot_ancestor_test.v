module css

import dom

fn test_hidden_ancestor_check_follows_assigned_slot_style_inheritance() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut slot := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot')!
	mut document_node := document.as_node()
	document_node.append_child(host.as_node())!
	mut host_node := host.as_node()
	host_node.append_child(target.as_node())!
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	mut shadow_node := shadow.as_node()
	shadow_node.append_child(slot.as_node())!
	assert target.as_node().assigned_slot() != none
	computer := css_style_computer_for(document)
	slot.set_attribute_value('style', 'display:none')
	slot.set_computed_properties(none, computed_properties_to_dom(computer.compute_style(dom.AbstractElement.new(slot, none))))
	assert target.as_node().has_inclusive_ancestor_with_display_none_ignoring_animations()
	slot.set_attribute_value('style', 'display:contents')
	slot.set_computed_properties(none, computed_properties_to_dom(computer.compute_style(dom.AbstractElement.new(slot, none))))
	assert !target.as_node().has_inclusive_ancestor_with_display_none_ignoring_animations()
}
