module css

import dom

fn keyframes_full_element(document &dom.Document, parent &dom.Node, tag string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', tag) or { panic(err) }
	mut node := unsafe { &dom.Node(parent) }
	node.append_child(element.as_node()) or { panic(err) }
	return element
}

fn keyframes_full_opacity(element &dom.Element) string {
	placeholder := dom.AbstractElement.new(element, none).computed_properties() or {
		panic('missing computed properties')
	}
	computed := computed_properties_from_dom(placeholder) or { panic('missing typed properties') }
	return (computed.property(.opacity, .yes) or { panic('missing opacity') }).css_text
}

fn test_pending_full_style_pass_refreshes_added_removed_and_later_selective_keyframes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{})
	root := keyframes_full_element(document, document.as_node(), 'html')
	base_owner := keyframes_full_element(document, root.as_node(), 'style')
	replacement_owner := keyframes_full_element(document, root.as_node(), 'style')
	target := keyframes_full_element(document, root.as_node(), 'div')
	mut scope := css_style_scope_for_document(document)
	mut list := scope.style_sheet_list()
	mut base := parse_css_stylesheet_with_parser(
		'div { animation: fade 1s both; } @keyframes fade { from { opacity: 0.5 } to { opacity: 0.5 } }', none)
	base.set_owner_node(base_owner)
	list.add_sheet(base)
	css_style_computer_for(document)
	document.update_style()
	assert keyframes_full_opacity(target) == '0.5'

	mut replacement := parse_css_stylesheet_with_parser(
		'@keyframes fade { from { opacity: 0.25 } to { opacity: 0.25 } }', none)
	replacement.set_owner_node(replacement_owner)
	document.set_needs_full_style_update(true)
	list.add_sheet(replacement)
	assert document.needs_full_style_update()
	document.update_style()
	assert keyframes_full_opacity(target) == '0.25'
	assert !document.needs_full_style_update()

	document.set_needs_full_style_update(true)
	list.remove_sheet(replacement)
	document.update_style()
	assert keyframes_full_opacity(target) == '0.5'
	assert !document.needs_full_style_update()

	// Once the full pass is drained, ordinary targeted invalidation must resume.
	list.add_sheet(replacement)
	assert target.needs_style_update()
	document.update_style()
	assert keyframes_full_opacity(target) == '0.25'
	list.remove_sheet(replacement)
	assert target.needs_style_update()
	document.update_style()
	assert keyframes_full_opacity(target) == '0.5'
}

fn keyframes_full_set_animation(element &dom.Element) {
	mut computed := computed_properties_with_initial_values()
	value := parse_css_value_logic(.animation_name, 'fade') or { panic('invalid animation name') }
	computed.set_property(.animation_name, dom_style_value_from_value_logic(value), .no, .no)
	mut abstract_element := dom.AbstractElement.new(element, none)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
	mut node := element.as_node()
	node.set_needs_style_update_internal(false)
	node.set_child_needs_style_update(false)
	node.set_entire_subtree_needs_style_update(false)
}

fn test_pending_document_full_pass_keeps_disconnected_shadow_keyframes_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	shadow_node := unsafe { &dom.Node(shadow) }
	target := keyframes_full_element(document, shadow_node, 'span')
	keyframes_full_set_animation(target)
	assert !host.as_node().is_connected()
	assert !target.needs_style_update()
	document.set_needs_full_style_update(true)
	mut list := StyleSheetList.create(shadow_node)
	sheet := parse_css_stylesheet_with_parser('@keyframes fade { from { opacity: 0.25 } }', none)
	list.add_sheet(sheet)
	assert target.needs_style_update()
	assert document.needs_full_style_update()
}

fn test_pending_document_full_pass_keeps_shadow_keyframes_host_fanout() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	root := keyframes_full_element(document, document.as_node(), 'html')
	mut host := keyframes_full_element(document, root.as_node(), 'div')
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	add_shadow_root_author_style_sheet(shadow, ':host { animation-name: fade }')
	keyframes_full_set_animation(host)
	document.set_needs_full_style_update(true)
	mut list := StyleSheetList.create(unsafe { &dom.Node(shadow) })
	sheet := parse_css_stylesheet_with_parser('@keyframes fade { from { opacity: 0.25 } }', none)
	list.add_sheet(sheet)
	assert host.needs_style_update()
	assert document.needs_full_style_update()
}
