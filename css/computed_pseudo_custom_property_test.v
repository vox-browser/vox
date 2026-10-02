module css

import dom

fn test_computed_pseudo_custom_properties_inherit_slotted_origin_before_initial() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div')!
	mut target := document.create_element_ns('http://www.w3.org/1999/xhtml', 'span')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	root_node.append_child(host.as_node())!
	mut host_node := host.as_node()
	host_node.append_child(target.as_node())!
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	slot := document.create_element_ns('http://www.w3.org/1999/xhtml', 'slot')!
	shadow_node.append_child(slot.as_node())!
	mut sheet := css_style_sheet_construct(none, document)!
	sheet.replace_sync('::slotted(span) { --accent: red; --plain: blue; }')!
	mut sheets := create_adopted_style_sheets_list(shadow_node)
	sheets.append(sheet)!
	add_document_author_style_sheet(document, 'span::before { content: "x"; }')
	register_property_for_document(mut document, PropertyDefinition{
		name:          '--accent'
		syntax:        '<color>'
		inherits:      true
		initial_value: 'green'
	})!
	css_style_computer_for(document)
	document.needs_full_style_update = true
	document.update_style()
	assert target.as_node().assigned_slot_internal() != none
	assert target.custom_property_data(none)?.get('--plain')?.css_text == 'blue'
	// This is the no-own-data state handled by CSSStyleProperties.cpp. The
	// originating element's data came through the live slotted cascade above.
	target.set_custom_property_data(int(dom.PseudoElement.before), none)
	mut pseudo := dom.AbstractElement.new(target, dom.PseudoElement.before)
	resolved := CSSStyleProperties.create_resolved_style(pseudo)
	assert resolved.get_property_value('--plain') == 'blue'
	assert resolved.get_property_value('--accent') == 'red'
	pseudo.set_custom_property_data(dom.CSSCustomPropertyData_.create({
		'--plain': dom.CSSCustomProperty_{
			value: &dom.CSSStyleValue_{ css_text: 'yellow' }
		}
	}, none))
	assert resolved.get_property_value('--plain') == 'yellow'
}
