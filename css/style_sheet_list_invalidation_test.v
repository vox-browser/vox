module css

import dom

const style_sheet_list_invalidation_html_namespace = 'http://www.w3.org/1999/xhtml'

fn style_sheet_list_invalidation_element(document &dom.Document, local_name string) &dom.Element {
	return document.create_element_ns(style_sheet_list_invalidation_html_namespace, local_name) or {
		panic(err)
	}
}

fn clear_style_sheet_list_invalidation_flags(nodes ...&dom.Node) {
	for node in nodes {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_child_needs_style_update(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
	}
}

fn set_style_sheet_list_invalidation_animation_name(mut element dom.Element, name string) {
	mut computed := computed_properties_with_initial_values()
	value := parse_css_value_logic(.animation_name, name) or {
		panic('could not parse animation-name ${name}')
	}
	computed.set_property(.animation_name, dom_style_value_from_value_logic(value), .no, .no)
	mut abstract_element := dom.AbstractElement.new(element, none)
	abstract_element.set_computed_properties(computed_properties_to_dom(computed))
}

fn test_style_sheet_list_add_and_remove_target_document_elements() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	mut target := style_sheet_list_invalidation_element(document, 'div')
	target.set_attribute_value('class', 'target')
	mut bystander := style_sheet_list_invalidation_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }

	mut list := StyleSheetList.create(document_node)
	sheet := parse_css_stylesheet_with_parser('.target { color: red }', none)
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()

	list.add_sheet(sheet)
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().full_style_invalidations == 0

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), target.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()
	list.remove_sheet(sheet)
	assert target.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().full_style_invalidations == 0
}

fn test_style_sheet_list_keeps_untitled_alternate_sheet_disabled() {
	document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut list := StyleSheetList.create(document_node)

	untitled_alternate := list.create_a_css_style_sheet('.target { color: red }', 'text/css',
		none, '', '', .yes, .yes, none, none, none)
	assert untitled_alternate.base.disabled

	persistent := list.create_a_css_style_sheet('.target { color: blue }', 'text/css', none,
		'', '', .no, .yes, none, none, none)
	assert !persistent.base.disabled

	preferred := list.create_a_css_style_sheet('.target { color: green }', 'text/css', none,
		'', 'dark', .no, .yes, none, none, none)
	assert !preferred.base.disabled
	matching_alternate := list.create_a_css_style_sheet('.target { color: black }', 'text/css',
		none, '', 'DARK', .yes, .yes, none, none, none)
	assert !matching_alternate.base.disabled
}

fn test_shadow_sheet_add_targets_local_elements_and_slot_inheritors() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut host := style_sheet_list_invalidation_element(document, 'div')
	mut slotted := style_sheet_list_invalidation_element(document, 'span')
	slotted.set_attribute_value('slot', 'target')
	mut light_bystander := style_sheet_list_invalidation_element(document, 'span')
	light_bystander.set_attribute_value('slot', 'other')
	document_node.append_child(host.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(slotted.as_node()) or { panic(err) }
	host_node.append_child(light_bystander.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut wrapper := style_sheet_list_invalidation_element(document, 'div')
	wrapper.set_attribute_value('class', 'slot-wrapper')
	mut shadow_bystander := style_sheet_list_invalidation_element(document, 'div')
	mut slot_element := style_sheet_list_invalidation_element(document, 'slot')
	slot_element.set_attribute_value('name', 'target')
	shadow_node.append_child(wrapper.as_node()) or { panic(err) }
	shadow_node.append_child(shadow_bystander.as_node()) or { panic(err) }
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(slot_element.as_node()) or { panic(err) }
	mut slot := unsafe { &dom.HTMLSlotElement(slot_element) }
	slot.set_assigned_nodes([slotted.as_node()])

	mut list := StyleSheetList.create(shadow_node)
	sheet := parse_css_stylesheet_with_parser('.slot-wrapper { color: green }', none)
	clear_style_sheet_list_invalidation_flags(document_node, host.as_node(), slotted.as_node(), light_bystander.as_node(), shadow_node, wrapper.as_node(), shadow_bystander.as_node(), slot_element.as_node())
	document.set_needs_full_style_update(false)

	list.add_sheet(sheet)
	assert wrapper.needs_style_update()
	assert slotted.needs_style_update()
	assert !shadow_bystander.needs_style_update()
	assert !light_bystander.needs_style_update()
	assert !host.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_non_style_rules_force_broad_add_remove_but_inactive_sheets_do_not() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut list := StyleSheetList.create(document_node)
	broad_sheet := parse_css_stylesheet_with_parser('@layer B, A;', none)
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node())
	document.set_needs_full_style_update(false)

	list.add_sheet(broad_sheet)
	assert document.needs_full_style_update()

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node())
	document.set_needs_full_style_update(false)
	list.remove_sheet(broad_sheet)
	assert document.needs_full_style_update()

	mut inactive_sheet := parse_css_stylesheet_with_parser('@layer D, C;', none)
	inactive_sheet.set_media('print')
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node())
	document.set_needs_full_style_update(false)
	list.add_sheet(inactive_sheet)
	assert !document.needs_full_style_update()
	assert !root.needs_style_update()
}

fn test_font_face_sheet_add_and_remove_do_not_force_broad_invalidation() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut list := StyleSheetList.create(document_node)
	font_face_sheet := parse_css_stylesheet_with_parser('@font-face { font-family: Test; src: local(Test); }', none)
	assert font_face_sheet.css_rules().length() == 1
	assert !stylesheet_requires_broad_add_or_remove_invalidation(font_face_sheet)

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node())
	document.set_needs_full_style_update(false)
	list.add_sheet(font_face_sheet)
	assert !document.needs_full_style_update()
	assert !root.needs_style_update()

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node())
	document.set_needs_full_style_update(false)
	list.remove_sheet(font_face_sheet)
	assert !document.needs_full_style_update()
	assert !root.needs_style_update()
}

fn test_keyframes_sheet_add_and_remove_target_animation_name_users() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	mut target := style_sheet_list_invalidation_element(document, 'div')
	mut bystander := style_sheet_list_invalidation_element(document, 'div')
 mut second := style_sheet_list_invalidation_element(document,'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(target.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
 root_node.append_child(second.as_node()) or { panic(err) }
	set_style_sheet_list_invalidation_animation_name(mut target, 'fade')
	set_style_sheet_list_invalidation_animation_name(mut bystander, 'other')
 set_style_sheet_list_invalidation_animation_name(mut second,'spin')

	mut list := StyleSheetList.create(document_node)
	keyframes_sheet := parse_css_stylesheet_with_parser('@keyframes fade { from { opacity: 0 } } @keyframes spin { to { opacity: 1 } } @keyframes unused { to { opacity: 0.5 } }', none)
	assert !stylesheet_requires_broad_add_or_remove_invalidation(keyframes_sheet)

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), target.as_node(), bystander.as_node(),second.as_node())
	document.set_needs_full_style_update(false)
	list.add_sheet(keyframes_sheet)
	assert target.needs_style_update()
 assert second.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), target.as_node(), bystander.as_node(),second.as_node())
	document.set_needs_full_style_update(false)
	list.remove_sheet(keyframes_sheet)
	assert target.needs_style_update()
 assert second.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_root_and_hover_sheet_add_target_current_pseudo_matches() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	mut hovered := style_sheet_list_invalidation_element(document, 'div')
	mut hover_child := style_sheet_list_invalidation_element(document, 'span')
	mut bystander := style_sheet_list_invalidation_element(document, 'aside')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(hovered.as_node()) or { panic(err) }
	mut hovered_node := hovered.as_node()
	hovered_node.append_child(hover_child.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	mut list := StyleSheetList.create(document_node)

	root_sheet := parse_css_stylesheet_with_parser(':root { color: red }', none)
	assert !build_invalidation_set_for_stylesheet(root_sheet).invalidation_set.needs_invalidate_whole_subtree()
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), hovered.as_node(), hover_child.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	list.add_sheet(root_sheet)
	assert root.needs_style_update()
	assert !hovered.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()

	document.set_hovered_node(hover_child.as_node())
	hover_sheet := parse_css_stylesheet_with_parser(':hover { color: blue }', none)
	assert !build_invalidation_set_for_stylesheet(hover_sheet).invalidation_set.needs_invalidate_whole_subtree()
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), hovered.as_node(), hover_child.as_node(), bystander.as_node())
	document.set_needs_full_style_update(false)
	list.add_sheet(hover_sheet)
	assert root.needs_style_update()
	assert hovered.needs_style_update()
	assert hover_child.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_first_child_only_sheet_add_targets_boundary_elements() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	mut first := style_sheet_list_invalidation_element(document, 'div')
	mut middle := style_sheet_list_invalidation_element(document, 'div')
	mut last := style_sheet_list_invalidation_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(first.as_node()) or { panic(err) }
	root_node.append_child(middle.as_node()) or { panic(err) }
	root_node.append_child(last.as_node()) or { panic(err) }
	mut list := StyleSheetList.create(document_node)
	first_child_sheet := parse_css_stylesheet_with_parser(':first-child { color: red }', none)
	result := build_invalidation_set_for_stylesheet(first_child_sheet)
	assert !result.invalidation_set.needs_invalidate_whole_subtree()
	assert result.invalidation_set.properties().any(it.pseudo_class == .first_child)

	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), first.as_node(), middle.as_node(), last.as_node())
	document.set_needs_full_style_update(false)
	list.add_sheet(first_child_sheet)
	assert root.needs_style_update()
	assert first.needs_style_update()
	assert !middle.needs_style_update()
	assert !last.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_keyframes_sheet_add_reaches_animation_name_on_host() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	mut host := style_sheet_list_invalidation_element(document, 'x-host')
	mut bystander := style_sheet_list_invalidation_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	root_node.append_child(bystander.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut style := style_sheet_list_invalidation_element(document, 'style')
	shadow_node.append_child(style.as_node()) or { panic(err) }
	set_style_sheet_list_invalidation_animation_name(mut host, 'fade')

	mut name_sheet := parse_css_stylesheet_with_parser(':host { animation-name: fade }', none)
	name_sheet.set_owner_node(style)
	name_sheet.add_owning_document_or_shadow_root(shadow_node)
	mut scope := css_style_scope_for_shadow_root(shadow_root)
	scope.author_style_sheets << name_sheet
	mut list := StyleSheetList.create(shadow_node)
	keyframes_sheet := parse_css_stylesheet_with_parser('@keyframes fade { from { opacity: 0 } }', none)
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), host.as_node(), bystander.as_node(), shadow_node, style.as_node())
	document.set_needs_full_style_update(false)

	list.add_sheet(keyframes_sheet)
	assert host.needs_style_update()
	assert !bystander.needs_style_update()
	assert !document.needs_full_style_update()
}

fn test_shadow_sheet_invalidation_distinguishes_host_subtree_and_sibling_reach() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := style_sheet_list_invalidation_element(document, 'html')
	mut host := style_sheet_list_invalidation_element(document, 'div')
	mut child := style_sheet_list_invalidation_element(document, 'span')
	mut sibling := style_sheet_list_invalidation_element(document, 'div')
	document_node.append_child(root.as_node()) or { panic(err) }
	mut root_node := root.as_node()
	root_node.append_child(host.as_node()) or { panic(err) }
	root_node.append_child(sibling.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(child.as_node()) or { panic(err) }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{ mode: .open }) or { panic(err) }
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	mut list := StyleSheetList.create(shadow_node)

	contained_sheet := parse_css_stylesheet_with_parser('@keyframes contained { from { opacity: 1 } } :host * { color: blue }', none)
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), host.as_node(), child.as_node(), sibling.as_node(), shadow_node)
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()
	list.add_sheet(contained_sheet)
	assert !host.as_node().entire_subtree_needs_style_update()
	assert child.needs_style_update()
	assert !sibling.needs_style_update()
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().full_style_invalidations == 0

	list.remove_sheet(contained_sheet)
	clear_style_sheet_list_invalidation_flags(document_node, root.as_node(), host.as_node(), child.as_node(), sibling.as_node(), shadow_node)
	document.set_needs_full_style_update(false)
	document.reset_style_invalidation_counters()
	sibling_sheet := parse_css_stylesheet_with_parser('@keyframes sibling { from { opacity: 1 } } :host + * { color: red }', none)
	list.add_sheet(sibling_sheet)
	assert sibling.needs_style_update()
	assert !host.needs_style_update()
	assert !child.needs_style_update()
	assert !document.needs_full_style_update()
	assert document.style_invalidation_counters().full_style_invalidations == 0
}
