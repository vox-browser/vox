module layout

import dom
import html

fn source_language_clear_flags(nodes ...&dom.Node) {
	for node in nodes {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_needs_style_update_internal(false)
		mutable_node.set_child_needs_style_update(false)
		mutable_node.set_entire_subtree_needs_style_update(false)
	}
}

fn test_source_language_publication_updates_warmed_light_and_shadow_descendant_caches() {
	mut document := html.parse_document('<!doctype html><html><head></head><body><div id="host"><span id="light">light</span></div></body></html>')
	defer { document.finalize() }
	document.set_pragma_set_default_language('en')
	mut host := document.get_element_by_id('host')?
	light := document.get_element_by_id('light')?
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_child := document.create_element('span')!
	shadow_node.append_child(shadow_child.as_node())!
	root := document.document_element()?
	assert root.lang()? == 'en'
	assert host.lang()? == 'en'
	assert light.lang()? == 'en'
	assert shadow_child.lang()? == 'en'
	source_language_clear_flags(root.as_node(), host.as_node(), light.as_node(), shadow_child.as_node())
	document.set_pragma_set_default_language('tr')
	mut actual_root := unsafe { &dom.Element(root) }
	actual_root.invalidate_style_after_language_change()
	assert root.lang()? == 'tr' && host.lang()? == 'tr'
	assert light.lang()? == 'tr' && shadow_child.lang()? == 'tr'
	assert light.needs_style_update() && shadow_child.needs_style_update()
}

fn test_source_language_publication_invalidates_actual_retained_casing_text_layout() {
	mut document := html.parse_document('<!doctype html><html><head></head><body><div id="host" style="text-transform: uppercase">istanbul</div></body></html>')
	defer { document.finalize() }
	document.set_pragma_set_default_language('en')
	_ = layout_document_typed_in_viewport(document, 320, 100)
	host := document.get_element_by_id('host')?
	text := host.as_node().first_child()?
	attached := text.layout_node()?
	assert attached.layout_handle != unsafe { nil } && attached.is_text_node()
	assert voidptr(attached.dom_node()?) == voidptr(text)
	assert attached.rendered_text_ == 'ISTANBUL'
	mut retained_text := unsafe { &TextNode(attached.layout_handle) }
	assert retained_text.text_for_rendering() == 'ISTANBUL'
	document.set_pragma_set_default_language('tr')
	mut root := unsafe { &dom.Element(document.document_element()?) }
	root.invalidate_style_after_language_change()
	assert host.lang()? == 'tr'
	assert attached.needs_layout_update()
	assert retained_text.text_for_rendering() == 'İSTANBUL'
	_ = layout_document_typed_in_viewport(document, 320, 100)
	assert text.layout_node()?.rendered_text_ == 'İSTANBUL'
}
