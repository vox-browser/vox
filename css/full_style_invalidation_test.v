module css

import dom

fn full_invalidation_element(document &dom.Document, parent &dom.Node, tag string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or { panic(err) }
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn test_full_style_update_drains_removed_attribute_plans_before_later_selective_updates() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := full_invalidation_element(document, unsafe { &dom.Node(document) }, 'html')
	mut parent := full_invalidation_element(document, root.as_node(), 'div')
	mut target := full_invalidation_element(document, parent.as_node(), 'span')
	target.set_attribute_value('class', 'target')
	parent.set_attribute_value('data-theme', '')
	add_document_author_style_sheet(document, '.target {color:blue} [data-theme] .target {color:red} .later .target {color:lime}')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	parent.remove_attribute('data-theme')
	document.set_needs_full_style_update(true)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	assert parent.removed_attributes_for_style_invalidation.len == 0
	assert !document.needs_full_style_update
	parent.set_attribute_value('class', 'later')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 255, 0)'
	parent.remove_attribute('class')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
}

fn test_full_style_update_preserves_shadow_scope_and_following_sibling_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := full_invalidation_element(document, unsafe { &dom.Node(document) }, 'html')
	mut host := full_invalidation_element(document, root.as_node(), 'div')
	shadow := host.attach_shadow(dom.ShadowRootInit{mode: .open}) or { panic(err) }
	mut first := full_invalidation_element(document, unsafe { &dom.Node(shadow) }, 'span')
	second := full_invalidation_element(document, unsafe { &dom.Node(shadow) }, 'span')
	outside := full_invalidation_element(document, root.as_node(), 'span')
	add_document_author_style_sheet(document, 'span {color:blue}')
	add_shadow_root_author_style_sheet(shadow, 'span {color:red} .on + span {color:lime}')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(second, .color) or { '' } == 'rgb(255, 0, 0)'
	assert computed_value_for(outside, .color) or { '' } == 'rgb(0, 0, 255)'
	first.set_attribute_value('class', 'on')
	document.set_needs_full_style_update(true)
	document.update_style()
	assert computed_value_for(second, .color) or { '' } == 'rgb(0, 255, 0)'
	assert computed_value_for(outside, .color) or { '' } == 'rgb(0, 0, 255)'
	first.remove_attribute('class')
	document.update_style()
	assert computed_value_for(second, .color) or { '' } == 'rgb(255, 0, 0)'
	assert first.removed_attributes_for_style_invalidation.len == 0
	assert computed_value_for(outside, .color) or { '' } == 'rgb(0, 0, 255)'
}

fn test_full_style_update_covers_has_fanout_and_later_partial_mutations() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := full_invalidation_element(document, unsafe { &dom.Node(document) }, 'html')
	section := full_invalidation_element(document, root.as_node(), 'section')
	mut trigger := full_invalidation_element(document, section.as_node(), 'i')
	target := full_invalidation_element(document, section.as_node(), 'span')
	add_document_author_style_sheet(document, 'span {color:blue} section:has(.on) span {color:red}')
	css_style_computer_for(document)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	trigger.set_attribute_value('class', 'on')
	assert document.needs_invalidation_of_elements_affected_by_has
	document.set_needs_full_style_update(true)
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
	assert !document.needs_invalidation_of_elements_affected_by_has
	trigger.remove_attribute('class')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(0, 0, 255)'
	assert trigger.removed_attributes_for_style_invalidation.len == 0
	trigger.set_attribute_value('class', 'on')
	document.update_style()
	assert computed_value_for(target, .color) or { '' } == 'rgb(255, 0, 0)'
}
