module css

import dom

fn deleted_rule_element(document &dom.Document, parent &dom.Node, name string) &dom.Element {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', name) or { panic(err) }
	mut mutable_parent := unsafe { &dom.Node(parent) }
	mutable_parent.append_child(element.as_node()) or { panic(err) }
	return element
}

fn deleted_rule_fixture(source string) (&dom.Document, &CSSStyleSheet, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document})
	document.set_viewport_rect(dom.Rect{width:800, height:600})
	root := deleted_rule_element(document, document.as_node(), 'html')
	style := deleted_rule_element(document, root.as_node(), 'style')
	mut target := deleted_rule_element(document, root.as_node(), 'div')
	target.set_attribute_value('class', 'target')
	bystander := deleted_rule_element(document, root.as_node(), 'div')
	mut sheet := parse_css_stylesheet_with_parser(source, none)
	sheet.set_owner_node(style)
	sheet.add_owning_document_or_shadow_root(document.as_node())
	holder := css_author_style_sheets_for(document)
	unsafe { holder.sheets << sheet }
	css_style_computer_for(document)
	document.update_style()
	return document, sheet, target, bystander
}

fn deleted_rule_color(element &dom.Element) string {
	return computed_value_for(element, .color) or { panic('missing color') }
}

fn test_deleted_style_rule_updates_inheritance_and_preserves_unrelated_styles() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('div {color:blue} .target {color:red}')
	defer { document.finalize() }
	child := deleted_rule_element(document, target.as_node(), 'span')
	document.update_style()
	assert deleted_rule_color(child) == 'rgb(255, 0, 0)'
	previous := bystander.el_computed_properties() or { panic('missing bystander style') }
	removed := sheet.css_rules().item(1) or { panic('missing removed rule') }
	sheet.delete_rule(1)!
	assert document.needs_full_style_update() == disable_deleted_style_rule_invalidation
	assert removed.parent_style_sheet == none
	assert !css_style_scope_for_document(document).has_valid_rule_cache()
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
	assert deleted_rule_color(child) == 'rgb(0, 0, 255)'
	assert (voidptr(bystander.el_computed_properties() or { panic('missing style') }) == voidptr(previous)) == !disable_deleted_style_rule_invalidation
	// Subsequent attribute invalidation must use the rebuilt remaining rules.
	mut mutable_target := unsafe { &dom.Element(target) }
	mutable_target.set_attribute_value('class', '')
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
}

fn test_deleted_pseudo_element_rule_removes_the_computed_pseudo() {
	mut document, mut sheet, target, bystander := deleted_rule_fixture('.target::before {content:"before";color:red}')
	defer { document.finalize() }
	assert computed_properties_for_pseudo_element(target, .before) != none
	previous := bystander.el_computed_properties() or { panic('missing style') }
	sheet.delete_rule(0)!
	document.update_style()
	assert computed_properties_for_pseudo_element(target, .before) == none
	assert (voidptr(bystander.el_computed_properties() or { panic('missing style') }) == voidptr(previous)) == !disable_deleted_style_rule_invalidation
}

fn test_deleted_rule_keeps_namespace_context_and_cssom_errors() {
	mut document, mut sheet, target, _ := deleted_rule_fixture('@namespace h "http://www.w3.org/1999/xhtml"; h|div {color:blue} h|*.target {color:red}')
	defer { document.finalize() }
	assert deleted_rule_color(target) == 'rgb(255, 0, 0)'
	sheet.delete_rule(99) or { assert err.msg().starts_with('IndexSizeError:') }
	assert sheet.css_rules().rules.len == 3
	assert !document.needs_full_style_update()
	sheet.delete_rule(0) or { assert err.msg().starts_with('InvalidStateError:') }
	assert sheet.css_rules().rules.len == 3
	assert !document.needs_full_style_update()
	sheet.disallow_modification = true
	sheet.delete_rule(2) or { assert err.msg().starts_with('NotAllowedError:') }
	assert sheet.css_rules().rules.len == 3
	sheet.disallow_modification = false
	sheet.delete_rule(2)!
	document.update_style()
	assert deleted_rule_color(target) == 'rgb(0, 0, 255)'
}

fn test_deleted_rule_retains_broad_fallbacks_for_global_nested_and_universal_rules() {
	for source in ['@media all {.target {color:red}}', '@layer base {.target {color:red}}', '.target {color:red; & span {color:lime}}', '* {color:red}', ':has(.target) {color:red}'] {
		mut document, mut sheet, _, _ := deleted_rule_fixture(source)
		sheet.delete_rule(0)!
		assert document.needs_full_style_update(), source
		document.update_style()
		document.finalize()
	}
	mut document, mut sheet, _, _ := deleted_rule_fixture('.target {color:red}')
	defer { document.finalize() }
	sheet.constructed = true
	sheet.delete_rule(0)!
	assert document.needs_full_style_update()
}

fn test_deleted_shadow_rule_invalidates_host_and_slot_inheritance() {
	mut document, _, host, _ := deleted_rule_fixture('div {color:blue}')
	defer { document.finalize() }
	mut mutable_host := unsafe { &dom.Element(host) }
	shadow := mutable_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	shadow_node := unsafe { &dom.Node(shadow) }
	style := deleted_rule_element(document, shadow_node, 'style')
	slot := deleted_rule_element(document, shadow_node, 'slot')
	child := deleted_rule_element(document, host.as_node(), 'span')
	mut sheet := parse_css_stylesheet_with_parser(':host {color:red} slot {color:lime}', none)
	sheet.set_owner_node(style)
	sheet.add_owning_document_or_shadow_root(shadow_node)
	mut scope := css_style_scope_for_shadow_root(shadow)
	scope.author_style_sheets << sheet
	document.set_needs_full_style_update(true)
	document.update_style()
	assert deleted_rule_color(host) == 'rgb(255, 0, 0)'
	assert deleted_rule_color(slot) == 'rgb(0, 255, 0)'
	assert deleted_rule_color(child) == 'rgb(0, 255, 0)'
	sheet.delete_rule(1)!
	document.update_style()
	assert deleted_rule_color(slot) == 'rgb(255, 0, 0)'
	assert deleted_rule_color(child) == 'rgb(255, 0, 0)'
	sheet.delete_rule(0)!
	document.update_style()
	assert deleted_rule_color(host) == 'rgb(0, 0, 255)'
	assert deleted_rule_color(child) == 'rgb(0, 0, 255)'
}

fn test_deleted_rule_preserves_preexisting_media_changes_and_old_shadow_host_effects() {
	mut document, _, host, _ := deleted_rule_fixture('div {color:blue}')
	defer { document.finalize() }
	mut mutable_host := unsafe { &dom.Element(host) }
	shadow := mutable_host.attach_shadow(dom.ShadowRootInit{mode: .open})!
	shadow_node := unsafe { &dom.Node(shadow) }
	style := deleted_rule_element(document, shadow_node, 'style')
	mut sheet := parse_css_stylesheet_with_parser('@media (max-width:900px) {:host {color:red}} .absent {color:lime}', none)
	sheet.set_owner_node(style)
	sheet.add_owning_document_or_shadow_root(shadow_node)
	mut scope := css_style_scope_for_shadow_root(shadow)
	scope.author_style_sheets << sheet
	document.set_needs_full_style_update(true)
	document.update_style()
	assert deleted_rule_color(host) == 'rgb(255, 0, 0)'
	document.set_viewport_rect(dom.Rect{width:1000,height:600})
	sheet.delete_rule(1)!
	document.update_style()
	assert deleted_rule_color(host) == 'rgb(0, 0, 255)'
}
