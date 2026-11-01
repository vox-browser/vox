module css

import dom

fn user_change_element(document &dom.Document, parent &dom.Node, name string, class_name string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
	element.set_attribute_value('class', class_name)
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node()) or { panic(err) }
	return element
}

fn user_change_fixture() (&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{width:800,height:600})
	root := user_change_element(document, document.as_node(), 'html', '')
	first := user_change_element(document, root.as_node(), 'div', 'first')
	second := user_change_element(document, root.as_node(), 'div', 'second')
	bystander := user_change_element(document, root.as_node(), 'aside', '')
	add_document_author_style_sheet(document, 'div {color:blue!important}')
	css_style_computer_for(document)
	document.update_style()
	return document, first, second, bystander
}

fn user_change_color(element &dom.Element) string {
	return computed_value_for(element, .color) or { panic('missing color') }
}

fn test_user_style_replacement_invalidates_old_and_new_subjects_and_inheritance() {
	mut document, first, second, bystander := user_change_fixture()
	defer { document.finalize() }
	child := user_change_element(document, first.as_node(), 'span', '')
	set_document_user_style_sheet(document, '.first {color:red!important}')
	document.update_style()
	assert user_change_color(first) == 'rgb(255, 0, 0)'
	assert user_change_color(child) == 'rgb(255, 0, 0)'
	previous := bystander.el_computed_properties() or { panic('missing style') }
	set_document_user_style_sheet(document, '.second {color:lime!important}')
	assert document.needs_full_style_update() == disable_targeted_user_style_changes
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
	assert user_change_color(child) == 'rgb(0, 0, 255)'
	assert user_change_color(second) == 'rgb(0, 255, 0)'
	assert (voidptr(bystander.el_computed_properties() or { panic('missing style') }) == voidptr(previous)) == !disable_targeted_user_style_changes
}

fn test_removing_user_styles_restores_author_rules_and_identical_source_is_a_noop() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	source := '.first {color:red!important}'
	set_document_user_style_sheet(document, source)
	document.update_style()
	version := document.style_environment_version()
	set_document_user_style_sheet(document, source)
	assert document.style_environment_version() == version
	assert !document.needs_full_style_update()
	set_document_user_style_sheet(document, '')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
	assert document.style_environment_version() == version + 1
}

fn test_user_style_replacement_updates_generated_pseudo_elements() {
	mut document, first, _, bystander := user_change_fixture()
	defer { document.finalize() }
	set_document_user_style_sheet(document, '.first::before {content:"old"}')
	document.update_style()
	assert computed_properties_for_pseudo_element(first, .before) != none
	previous := bystander.el_computed_properties() or { panic('missing style') }
	set_document_user_style_sheet(document, '.first::after {content:"new"}')
	document.update_style()
	assert computed_properties_for_pseudo_element(first, .before) == none
	assert computed_properties_for_pseudo_element(first, .after) != none
	assert (voidptr(bystander.el_computed_properties() or { panic('missing style') }) == voidptr(previous)) == !disable_targeted_user_style_changes
}

fn test_user_style_global_nested_and_unbounded_rules_keep_full_invalidation_in_both_directions() {
	for source in ['* {color:red}', '@media all {.first {color:red}}', '@layer colors {.first {color:red}}', '@font-face {font-family:user-test;src:local("Arial")}', '.first {& span {color:red}}'] {
		mut document, _, _, _ := user_change_fixture()
		set_document_user_style_sheet(document, source)
		assert document.needs_full_style_update(), source
		document.update_style()
		set_document_user_style_sheet(document, '.second {color:lime!important}')
		assert document.needs_full_style_update(), source
		document.update_style()
		document.finalize()
	}
}

fn test_user_style_replacement_propagates_inherited_changes_through_shadow_slots() {
	mut document, host, _, _ := user_change_fixture()
	defer { document.finalize() }
	mut mutable_host := unsafe { &dom.Element(host) }
	shadow := mutable_host.attach_shadow(dom.ShadowRootInit{mode:.open})!
	slot := user_change_element(document, unsafe { &dom.Node(shadow) }, 'slot', '')
	child := user_change_element(document, host.as_node(), 'span', '')
	set_document_user_style_sheet(document, '.first {color:red!important}')
	document.update_style()
	assert user_change_color(slot) == 'rgb(255, 0, 0)'
	assert user_change_color(child) == 'rgb(255, 0, 0)'
	set_document_user_style_sheet(document, '.first {color:lime!important}')
	document.update_style()
	assert user_change_color(slot) == 'rgb(0, 255, 0)'
	assert user_change_color(child) == 'rgb(0, 255, 0)'
}

fn user_change_page_source(_ voidptr) ?string { return '.first {color:red!important}' }

fn test_user_style_replacement_projects_the_implicit_page_user_sheet() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	document.set_page(&dom.Page{target:voidptr(document),user_style_callback:user_change_page_source})
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_user_style_sheet()
	document.set_needs_full_style_update(true)
	document.update_style()
	assert user_change_color(first) == 'rgb(255, 0, 0)'
	set_document_user_style_sheet(document, '')
	document.update_style()
	assert user_change_color(first) == 'rgb(0, 0, 255)'
}

fn test_user_style_replacement_preserves_a_pending_full_update() {
	mut document, first, _, _ := user_change_fixture()
	defer { document.finalize() }
	document.set_needs_full_style_update(true)
	set_document_user_style_sheet(document, '.first {color:red!important}')
	assert document.needs_full_style_update()
	document.update_style()
	assert user_change_color(first) == 'rgb(255, 0, 0)'
}
