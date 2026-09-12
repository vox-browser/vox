module css

import dom

const style_sheet_invalidation_html_namespace = 'http://www.w3.org/1999/xhtml'

fn style_sheet_invalidation_test_element(document &dom.Document, local_name string) &dom.Element {
	return document.create_element_ns(style_sheet_invalidation_html_namespace, local_name) or {
		panic(err)
	}
}

fn clear_style_sheet_invalidation_test_flags(nodes ...&dom.Node) {
	for node in nodes {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_child_needs_style_update(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
	}
}

fn install_inline_style_sheet_for_invalidation_test(mut sheet CSSStyleSheet, owner &dom.Element, root &dom.Node) {
	sheet.set_owner_node(owner)
	sheet.add_owning_document_or_shadow_root(root)
	if shadow_root := root.as_shadow_root() {
		mut scope := css_style_scope_for_shadow_root(shadow_root)
		scope.author_style_sheets << sheet
	} else {
		holder := css_author_style_sheets_for(root.document())
		unsafe {
			holder.sheets << sheet
		}
	}
}

fn set_style_sheet_invalidation_test_animation_name(mut element dom.Element, pseudo_element ?dom.PseudoElement, name string) {
	mut computed := computed_properties_with_initial_values()
	value := parse_css_value_logic(.animation_name, name) or {
		panic('could not parse animation-name ${name}')
	}
	computed.set_property(.animation_name, dom_style_value_from_value_logic(value), .no, .no)
	mut abstract_element := dom.AbstractElement.new(element, pseudo_element)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
}

fn test_insert_rule_targets_matching_elements_in_inline_style_sheet() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('.target { color: red }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_insert_rule_uses_leading_anchor_for_trailing_universal_and_pseudo_element() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut anchor := style_sheet_invalidation_test_element(document, 'section')
	anchor.set_attribute_value('id', 'scope')
	anchor.set_attribute_value('class', 'anchor')
	mut child := style_sheet_invalidation_test_element(document, 'span')
	mut outside := style_sheet_invalidation_test_element(document, 'span')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(anchor.as_node()) or { panic(err) }
	root_node.append_child(outside.as_node()) or { panic(err) }
	mut anchor_node := anchor.as_node()
	anchor_node.append_child(child.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), anchor.as_node(), child.as_node(), outside.as_node())
	document.set_needs_full_style_update(false)

	assert sheet.insert_rule('#scope > * { color: red }', 0)! == 0
	assert child.needs_style_update()
	assert !outside.needs_style_update()
	assert !document.needs_full_style_update()

	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), anchor.as_node(), child.as_node(), outside.as_node())
	assert sheet.insert_rule('.anchor::before { content: "x" }', 1)! == 1
	assert anchor.needs_style_update()
	assert !child.needs_style_update()
	assert !outside.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_insert_rule_targets_matching_elements_inside_shadow_root() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'span')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_invalidation_test_element(document, 'span')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(target.as_node()) or { panic(err) }
	shadow_node.append_child(bystander.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), shadow_node, style.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('.target { color: green }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_shadow_host_escape_selector_classification() {
	assert selector_text_may_match_light_dom_under_shadow_host('::slotted(.item)')
	assert selector_text_may_match_light_dom_under_shadow_host(':host > .item')
	assert selector_text_may_match_light_dom_under_shadow_host(':host + .item')
	assert selector_text_may_match_light_dom_under_shadow_host(':host ~ .item')
	assert !selector_text_may_match_light_dom_under_shadow_host(':host')
	assert !selector_text_may_match_light_dom_under_shadow_host(':host(.active)')
	assert !selector_text_may_match_light_dom_under_shadow_host('.item')
	assert !selector_text_may_match_light_dom_under_shadow_host('not[')
}

fn test_insert_keyframes_rule_targets_only_animation_name_users() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut target := style_sheet_invalidation_test_element(document, 'div')
	mut pseudo_target := style_sheet_invalidation_test_element(document, 'div')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(pseudo_target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	set_style_sheet_invalidation_test_animation_name(mut target, none, 'other, fade')
	set_style_sheet_invalidation_test_animation_name(mut pseudo_target, dom.PseudoElement.before, 'fade')
	set_style_sheet_invalidation_test_animation_name(mut bystander, none, 'other')

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), target.as_node(), pseudo_target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('@keyframes fade { from { opacity: 0 } to { opacity: 1 } }', 0)! == 0
	assert target.needs_style_update()
	assert pseudo_target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 2
}

fn test_document_keyframes_insertion_walks_existing_shadow_trees() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(style.as_node()) or { panic(err) }
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut target := style_sheet_invalidation_test_element(document, 'span')
	mut bystander := style_sheet_invalidation_test_element(document, 'span')
	shadow_node.append_child(target.as_node()) or { panic(err) }
	shadow_node.append_child(bystander.as_node()) or { panic(err) }
	set_style_sheet_invalidation_test_animation_name(mut target, none, 'fade')
	set_style_sheet_invalidation_test_animation_name(mut bystander, none, 'other')

	mut sheet := parse_css_stylesheet_with_parser('', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, document_node)
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), style.as_node(), host.as_node(), shadow_node, target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)

	assert sheet.insert_rule('@keyframes fade { from { opacity: 0 } }', 0)! == 0
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_keyframes_insertion_reaches_host_without_document_bystanders() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut bystander := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	set_style_sheet_invalidation_test_animation_name(mut host, none, 'fade')

	mut sheet := parse_css_stylesheet_with_parser(':host { animation-name: fade }', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	effects := determine_shadow_root_style_sheet_effects(shadow_root)
	assert effects.may_match_shadow_host
	assert !effects.may_match_light_dom_under_shadow_host
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), bystander.as_node(), shadow_node, style.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	assert sheet.insert_rule('@keyframes fade { from { opacity: 0.25 } }', 1)! == 1
	assert host.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	counters := document.style_invalidation_counters()
	assert counters.full_style_invalidations == 0
	assert counters.style_invalidations == 1
}

fn test_shadow_root_style_sheet_effects_include_hosts_light_dom_and_slots() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := style_sheet_invalidation_test_element(document, 'div')
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_invalidation_test_element(document, 'style')
	mut slot_wrapper := style_sheet_invalidation_test_element(document, 'div')
	slot_wrapper.set_attribute_value('class', 'slot-wrapper')
	mut slot := style_sheet_invalidation_test_element(document, 'slot')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	shadow_node.append_child(slot_wrapper.as_node()) or { panic(err) }
	mut wrapper_node := slot_wrapper.as_node()
	wrapper_node.append_child(slot.as_node()) or { panic(err) }

	mut sheet := parse_css_stylesheet_with_parser(':host > .item {} .slot-wrapper {}', none)
	install_inline_style_sheet_for_invalidation_test(mut sheet, style, shadow_node)
	effects := determine_shadow_root_style_sheet_effects(shadow_root)
	assert effects.may_match_shadow_host
	assert effects.may_match_light_dom_under_shadow_host
	assert effects.may_affect_assigned_nodes_via_slots
}

fn test_shadow_local_replace_sync_does_not_invalidate_light_dom() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut light_bystander := style_sheet_invalidation_test_element(document, 'span')
	light_bystander.set_attribute_value('class', 'foo')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(light_bystander.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut shadow_target := style_sheet_invalidation_test_element(document, 'div')
	shadow_target.set_attribute_value('class', 'foo')
	shadow_node.append_child(shadow_target.as_node()) or { panic(err) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), light_bystander.as_node(), shadow_node, shadow_target.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	sheet.replace_sync('.foo { color: green }') or { panic(err) }
	assert shadow_node.entire_subtree_needs_style_update()
	assert !host.as_node().entire_subtree_needs_style_update()
	assert !light_bystander.needs_style_update()
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().style_invalidations == 0
}

fn test_shadow_style_replacement_uses_pre_mutation_host_reach() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut slotted := style_sheet_invalidation_test_element(document, 'span')
	slotted.set_attribute_value('class', 'item')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(slotted.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut slot := style_sheet_invalidation_test_element(document, 'slot')
	shadow_node.append_child(slot.as_node()) or { panic(err) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync('::slotted(.item) { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), slotted.as_node(), shadow_node, slot.as_node())
	document.set_needs_full_style_update(false)

	sheet.replace_sync('') or { panic(err) }
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_rule_deletion_uses_pre_mutation_host_reach() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync(':host { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), shadow_node)
	document.set_needs_full_style_update(false)

	sheet.delete_rule(0) or { panic(err) }
	assert host.as_node().entire_subtree_needs_style_update()
	assert shadow_node.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_sheet_disabled_toggle_preserves_host_reach_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_invalidation_test_element(document, 'html')
	mut host := style_sheet_invalidation_test_element(document, 'div')
	mut slotted := style_sheet_invalidation_test_element(document, 'span')
	slotted.set_attribute_value('class', 'item')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(slotted.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut slot := style_sheet_invalidation_test_element(document, 'slot')
	shadow_node.append_child(slot.as_node()) or { panic(err) }

	mut sheet := css_style_sheet_construct(none, document) or { panic(err) }
	sheet.replace_sync('::slotted(.item) { color: blue }') or { panic(err) }
	mut adopted := create_adopted_style_sheets_list(shadow_node)
	adopted.append(sheet) or { panic(err) }
	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), slotted.as_node(), shadow_node, slot.as_node())
	document.set_needs_full_style_update(false)

	sheet.set_disabled(true)
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()

	clear_style_sheet_invalidation_test_flags(document_node, root.as_node(), host.as_node(), slotted.as_node(), shadow_node, slot.as_node())
	document.set_needs_full_style_update(false)
	sheet.set_disabled(false)
	assert host.as_node().entire_subtree_needs_style_update()
	assert !document.needs_full_style_update()
}
