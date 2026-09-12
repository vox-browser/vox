module css

import dom

fn shadow_animation_test_element(document &dom.Document, name string) &dom.Element {
	return document.create_element_ns('http://www.w3.org/1999/xhtml', name) or {
		panic('${err}')
	}
}

fn shadow_animation_test_tree() (&dom.Document, &dom.Element, &dom.ShadowRoot) {
	mut document := dom.Document.create(dom.url_about_blank())
	mut host := shadow_animation_test_element(document, 'div')
	mut slotted := shadow_animation_test_element(document, 'span')
	slotted.set_attribute_value('id', 'slotted')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic('${err}') }
	mut host_node := host.as_node()
	host_node.append_child(slotted.as_node()) or { panic('${err}') }
	shadow_root := host.attach_shadow(dom.ShadowRootInit{
		mode: .open
	}) or { panic('${err}') }
	mut slot_element := shadow_animation_test_element(document, 'slot')
	mut shadow_node := unsafe { &dom.Node(shadow_root) }
	shadow_node.append_child(slot_element.as_node()) or { panic('${err}') }
	assert slotted.as_node().assigned_slot_internal() != none
	return document, slotted, shadow_root
}

fn test_slotted_animation_name_uses_keyframes_from_its_declaration_scope() {
	document, slotted, shadow_root := shadow_animation_test_tree()
	add_document_author_style_sheet(document, '@keyframes fade {
		from { opacity: 0.5; } to { opacity: 0.5; }
	}')
	add_shadow_root_author_style_sheet(shadow_root, '::slotted(#slotted) {
		animation-name: fade;
		animation-duration: 1s;
		animation-fill-mode: both;
	}
	@keyframes fade {
		from { opacity: 0.25; } to { opacity: 0.25; }
	}')

	computed := css_style_computer_for(document).compute_style(dom.AbstractElement.new(slotted, none))
	assert (computed.property(.opacity, .yes) or { panic('animated opacity missing') }).css_text == '0.25'
}

fn test_document_animation_name_prefers_document_keyframes_for_slotted_element() {
	document, slotted, shadow_root := shadow_animation_test_tree()
	add_document_author_style_sheet(document, '#slotted {
		animation-name: fade;
		animation-duration: 1s;
		animation-fill-mode: both;
	}
	@keyframes fade {
		from { opacity: 0.5; } to { opacity: 0.5; }
	}')
	add_shadow_root_author_style_sheet(shadow_root, '@keyframes fade {
		from { opacity: 0.25; } to { opacity: 0.25; }
	}')

	computed := css_style_computer_for(document).compute_style(dom.AbstractElement.new(slotted, none))
	assert (computed.property(.opacity, .yes) or { panic('animated opacity missing') }).css_text == '0.5'
}

fn test_existing_css_animation_refreshes_inserted_keyframes() {
	document := dom.Document.create(dom.url_about_blank())
	mut target := shadow_animation_test_element(document, 'div')
	target.set_attribute_value('class', 'target')
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(target.as_node()) or { panic('${err}') }
	mut sheet := parse_css_stylesheet_with_parser('.target {
		animation-name: fade;
		animation-duration: 1s;
		animation-fill-mode: both;
	}', none)
	sheet.add_owning_document_or_shadow_root(document_node)
	holder := css_author_style_sheets_for(document)
	unsafe {
		holder.sheets << sheet
	}
	mut scope := css_style_scope_for_document(document)
	scope.invalidate_rule_cache()

	computer := css_style_computer_for(document)
	abstract_target := dom.AbstractElement.new(target, none)
	_ = computer.compute_style(abstract_target)
	animation := computer.css_animation_for(abstract_target, 'fade') or {
		panic('missing CSS animation')
	}
	assert animation.effect_.key_frame_set == none

	sheet.insert_rule('@keyframes fade { from { opacity: 0.25; } to { opacity: 0.25; } }', u32(sheet.css_rules().length()))!
	computed := computer.compute_style(abstract_target)
	assert animation.effect_.key_frame_set != none
	assert (computed.property(.opacity, .yes) or { panic('animated opacity missing') }).css_text == '0.25'
}
