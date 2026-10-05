module layout

import dom
import html
import page

fn source_meta_language_document() !&dom.Document {
	owner := page.Page.create(1)!
	url := dom.URL{value: 'https://meta-language.test/page'}
	mut document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	document.set_document_type(.html)
	html.parse_html_from_a_string(document, '<!doctype html><html><head><meta http-equiv="content-language" content="en"></head><body><div id="host" style="text-transform: uppercase">istanbul<span id="light">light</span></div></body></html>')
	initial_language := document.pragma_set_default_language_value() or {
		return error('missing actual initial pragma language')
	}
	assert initial_language == 'en'
	assert document.get_window() != none
	assert voidptr(document.page()) == voidptr(owner)
	return document
}

fn source_meta_language_insert(document &dom.Document, language string) ! {
	mut meta := document.create_element('meta')!
	meta.set_attribute_value('http-equiv', 'content-language')
	meta.set_attribute_value('content', language)
	head := document.head() or { return error('missing actual head') }
	mut head_node := head.as_node()
	head_node.append_child(meta.as_node())!
}

fn test_source_meta_language_insertion_publishes_actual_warmed_light_and_shadow_caches() {
	mut document := source_meta_language_document()!
	defer { document.finalize() }
	mut host := document.get_element_by_id('host')?
	light := document.get_element_by_id('light')?
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .open })!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_child := document.create_element('span')!
	shadow_node.append_child(shadow_child.as_node())!
	assert host.lang()? == 'en' && light.lang()? == 'en'
	assert shadow_child.lang()? == 'en'
	for element in [host, light, shadow_child] {
		mut node := element.as_node()
		node.set_needs_style_update_internal(false)
		node.set_child_needs_style_update(false)
		node.set_entire_subtree_needs_style_update(false)
	}
	source_meta_language_insert(document, 'tr')!
	assert document.pragma_set_default_language_value()? == 'tr'
	assert host.lang()? == 'tr' && light.lang()? == 'tr'
	assert shadow_child.lang()? == 'tr'
	assert light.needs_style_update() && shadow_child.needs_style_update()
}

fn test_source_meta_language_insertion_invalidates_same_genuine_retained_casing_text() {
	mut document := source_meta_language_document()!
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 100)
	host := document.get_element_by_id('host')?
	text := host.as_node().first_child()?
	attached := text.layout_node()?
	assert attached.is_text_node() && attached.layout_handle != unsafe { nil }
	assert voidptr(attached.dom_node()?) == voidptr(text)
	assert attached.rendered_text_ == 'ISTANBUL'
	mut retained := unsafe { &TextNode(attached.layout_handle) }
	assert retained.text_for_rendering() == 'ISTANBUL'
	source_meta_language_insert(document, 'tr')!
	assert attached.needs_layout_update()
	assert retained.text_for_rendering() == 'İSTANBUL'
	_ = layout_document_typed_in_viewport(document, 320, 100)
	assert text.layout_node()?.rendered_text_ == 'İSTANBUL'
}
