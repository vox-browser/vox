module css

import dom

fn test_adopted_style_sheet_validates_ownership_and_participates_in_document_cascade() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut document_node := unsafe { &dom.Node(document) }
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	element.set_attribute_value('class', 'adopted')
	document_node.append_child(element.as_node())!

	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('.adopted { color: red; }')!
	mut list := create_adopted_style_sheets_list(document_node)
	list.append(sheet)!

	assert list.length() == 1
	assert sheet.owning_documents_or_shadow_roots.len == 1
	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(element, none))
	assert (computed.property(.color, .no) or { panic('adopted color missing') }).css_text == 'rgb(255, 0, 0)'

	mut other_document := dom.Document.create(dom.URL{ value: 'https://other.test/' })
	foreign_sheet := css_style_sheet_construct(none, other_document)!
	if _ := list.append(foreign_sheet) {
		assert false, 'a constructed stylesheet cannot be shared across documents'
	} else {
		assert err.msg().starts_with('NotAllowedError:')
	}

	list.clear()
	assert list.length() == 0
	assert sheet.owning_documents_or_shadow_roots.len == 0
}

fn test_adopted_style_sheet_participates_in_shadow_root_cascade() {
	document := dom.Document.create(dom.url_about_blank())
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node())!
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	})!
	mut child := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	child.set_attribute_value('class', 'inside')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(child.as_node())!

	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('.inside { color: blue; }')!
	mut list := create_adopted_style_sheets_list(shadow_node)
	list.append(sheet)!

	computed := StyleComputer.new(document).compute_style(dom.AbstractElement.new(child, none))
	assert (computed.property(.color, .no) or { panic('shadow adopted color missing') }).css_text == 'rgb(0, 0, 255)'
	assert sheet.owning_documents_or_shadow_roots[0] == shadow_node
}

fn test_single_constructed_sheet_cache_is_shared_across_shadow_scopes() {
	mut document := dom.Document.create(dom.url_about_blank())
	mut document_node := unsafe { &dom.Node(document) }
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut host_a := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut host_b := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	host_a.set_attribute_value('class', 'primary')
	host_b.set_attribute_value('class', 'secondary')
	mut slotted_a := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut slotted_b := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	slotted_a.set_attribute_value('class', 'slot-target')
	slotted_b.set_attribute_value('class', 'slot-target')
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(host_a.as_node())!
	root_node.append_child(host_b.as_node())!
	mut host_a_node := host_a.as_node()
	mut host_b_node := host_b.as_node()
	host_a_node.append_child(slotted_a.as_node())!
	host_b_node.append_child(slotted_b.as_node())!

	shadow_a := host_a.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	shadow_b := host_b.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut shadow_a_node := unsafe { &dom.Node(shadow_a) }
	mut shadow_b_node := unsafe { &dom.Node(shadow_b) }
	mut target_a := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut target_b := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	target_a.set_attribute_value('class', 'target')
	target_b.set_attribute_value('class', 'target')
	mut slot_a := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot')!
	mut slot_b := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot')!
	shadow_a_node.append_child(target_a.as_node())!
	shadow_a_node.append_child(slot_a.as_node())!
	shadow_b_node.append_child(target_b.as_node())!
	shadow_b_node.append_child(slot_b.as_node())!
	assert slotted_a.as_node().assigned_slot_internal() != none
	assert slotted_b.as_node().assigned_slot_internal() != none

	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync(':host(.primary) .target { color: green }
		:host(.secondary) .target { color: blue }
		::slotted(.slot-target) { background-color: yellow }')!
	mut adopted_a := create_adopted_style_sheets_list(shadow_a_node)
	mut adopted_b := create_adopted_style_sheets_list(shadow_b_node)
	adopted_a.append(sheet)!
	adopted_b.append(sheet)!

	computer := StyleComputer.new(document)
	initial_a := computer.compute_style(dom.AbstractElement.new(target_a, none))
	initial_b := computer.compute_style(dom.AbstractElement.new(target_b, none))
	initial_slotted_a := computer.compute_style(dom.AbstractElement.new(slotted_a, none))
	initial_slotted_b := computer.compute_style(dom.AbstractElement.new(slotted_b, none))
	assert (initial_a.property(.color, .no) or { panic('A target color missing') }).css_text == 'rgb(0, 128, 0)'
	assert (initial_b.property(.color, .no) or { panic('B target color missing') }).css_text == 'rgb(0, 0, 255)'
	assert (initial_slotted_a.property(.background_color, .no) or { panic('A slot color missing') }).css_text == 'rgb(255, 255, 0)'
	assert (initial_slotted_b.property(.background_color, .no) or { panic('B slot color missing') }).css_text == 'rgb(255, 255, 0)'

	first_scope := css_style_scope_for_shadow_root(shadow_a)
	second_scope := css_style_scope_for_shadow_root(shadow_b)
	first_cache := first_scope.rule_cache or { panic('first cache missing') }
	second_cache := second_scope.rule_cache or { panic('second cache missing') }
	assert voidptr(first_cache) == voidptr(second_cache)

	sheet.replace_sync(':host(.primary) .target { color: purple }
		:host(.secondary) .target { color: orange }
		::slotted(.slot-target) { background-color: cyan }')!
	assert first_scope.rule_cache == none
	assert second_scope.rule_cache == none
	assert sheet.shared_single_constructed_sheet_style_cache == none

	replaced_a := computer.compute_style(dom.AbstractElement.new(target_a, none))
	replaced_b := computer.compute_style(dom.AbstractElement.new(target_b, none))
	replaced_slotted_a := computer.compute_style(dom.AbstractElement.new(slotted_a, none))
	replaced_slotted_b := computer.compute_style(dom.AbstractElement.new(slotted_b, none))
	assert (replaced_a.property(.color, .no) or { panic('replaced A target color missing') }).css_text == 'rgb(128, 0, 128)'
	assert (replaced_b.property(.color, .no) or { panic('replaced B target color missing') }).css_text == 'rgb(255, 165, 0)'
	assert (replaced_slotted_a.property(.background_color, .no) or { panic('replaced A slot color missing') }).css_text == 'rgb(0, 255, 255)'
	assert (replaced_slotted_b.property(.background_color, .no) or { panic('replaced B slot color missing') }).css_text == 'rgb(0, 255, 255)'
	assert voidptr(first_scope.rule_cache or { panic('rebuilt first cache missing') }) == voidptr(second_scope.rule_cache or { panic('rebuilt second cache missing') })
	assert voidptr(first_scope.rule_cache or { panic('rebuilt cache missing') }) != voidptr(first_cache)
}

fn test_constructed_style_sheet_replacement_and_disabled_state_invalidate_owners() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(none, document)!
	mut list := create_adopted_style_sheets_list(document_node)
	list.append(sheet)!

	document.set_needs_full_style_update(false)
	sheet.replace_sync('.first { color: red; }')!
	assert document.needs_full_style_update()
	first_rule := sheet.css_rules().item(0) or { panic('missing replacement rule') }
	assert first_rule.parent_style_sheet? == sheet

	document.set_needs_full_style_update(false)
	sheet.replace('.second { color: blue; }')!
	assert document.needs_full_style_update()
	second_rule := sheet.css_rules().item(0) or { panic('missing async replacement rule') }
	assert second_rule.parent_style_sheet? == sheet

	document.set_needs_full_style_update(false)
	sheet.set_disabled(true)
	assert document.needs_full_style_update()
	document.set_needs_full_style_update(false)
	sheet.set_disabled(true)
	assert !document.needs_full_style_update()
}

fn test_disabled_adopted_style_sheet_delays_font_and_image_activation() {
	mut document := dom.Document.create(dom.url_about_blank())
	document_node := unsafe { &dom.Node(document) }
	mut sheet := css_style_sheet_construct(CSSStyleSheetInit{
		disabled: true
	}, document)!
	sheet.replace_sync('@font-face { font-family: Delayed; src: url(delayed.ttf); }')!
	mut pending_image := &dom.StyleValue{
		css_text: 'url(delayed.png)'
	}
	sheet.register_pending_image_value(pending_image)
	mut list := create_adopted_style_sheets_list(document_node)
	list.append(sheet)!

	font_rule := sheet.css_rules().item(0) or { panic('missing font-face rule') }
	font_face_rule := font_rule.font_face_rule_ref() or { panic('not a font-face rule') }
	assert font_face_rule.css_connected_font_face_ref() == none
	assert sheet.pending_image_values.len == 1

	sheet.set_disabled(false)
	assert font_face_rule.css_connected_font_face_ref() != none
	assert sheet.pending_image_values.len == 0

	sheet.set_disabled(true)
	assert font_face_rule.css_connected_font_face_ref() == none
}
