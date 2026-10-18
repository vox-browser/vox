module layout

import css
import dom
import html

fn media_controls_namespace_document(markup string) !&dom.Document {
	address := dom.URL{ value: 'https://media-controls-layout.example.test/' }
	return html.parse_navigation_document(markup, address, address.origin(), none)!
}

fn media_controls_namespace_build(document &dom.Document) &Node {
	root := build_layout_tree(document) or { panic('Missing media controls layout tree') }
	attach_layout_nodes(root)
	return root
}

fn media_controls_namespace_layout_node(root &Node, target &dom.Node) ?&Node {
	if owner := root.dom_node() {
		if voidptr(owner) == voidptr(target) { return root }
	}
	for child in root.children() {
		if found := media_controls_namespace_layout_node(child, target) { return found }
	}
	return none
}

fn media_controls_namespace_append(document &dom.Document, parent &dom.Element, namespace string, tag string, id string) !&dom.Element {
	mut element := document.create_element_ns(namespace, tag)!
	element.set_attribute_value('id', id)
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	return element
}

fn test_media_controls_initial_widgets_require_null_namespace_attributes_and_retain_the_same_subtrees() {
	mut document := media_controls_namespace_document('<!doctype html><body><video id="mcns-video"></video><audio id="mcns-audio"></audio>')!
	defer { document.finalize() }
	video := document.get_element_by_id('mcns-video') or { panic('Missing namespace video') }
	audio := document.get_element_by_id('mcns-audio') or { panic('Missing namespace audio') }
	for item in [video, audio] {
		mut element := unsafe { &dom.Element(item) }
		element.set_attribute_ns_for_bindings('urn:media-controls-test', 'controls', 'foreign value')!
		assert element.has_attribute('controls') && !element.has_attribute_ns(none, 'controls')
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing HTML media model') }
		media.set_current_playback_position(4)
		media.set_official_playback_position(4)
		media.set_paused(false)
	}
	initial := media_controls_namespace_build(document)
	assert initial.child_count() > 0
	assert video.shadow_root() == none && audio.shadow_root() == none
	assert audio.as_node().unsafe_layout_node() == none
	for item in [video, audio] {
		mut element := unsafe { &dom.Element(item) }
		media := html.html_media_element_for_dom_element(element) or { panic('Missing retained media model') }
		element.set_attribute_value('controls', 'ordinary raw value')
		root := media_controls_namespace_build(document)
		shadow := element.shadow_root() or { panic('Missing actual controls shadow') }
		assert shadow.is_user_agent_internal() && shadow.mode() == .closed
		assert voidptr(shadow.host()?) == voidptr(element)
		selector := if element.local_name() == 'video' { '.container.video' } else { '.container.audio' }
		mut container := css.query_selector(shadow.as_node(), selector) or { panic('Missing actual controls container') }
		assert media_controls_namespace_layout_node(root, container.as_node()) != none
		assert element.as_node().unsafe_layout_node() != none
		assert css.query_selector(shadow.as_node(), '.timeline-track') != none
		assert css.query_selector(shadow.as_node(), '.play-pause-button') != none
		assert css.query_selector_all(shadow.as_node(), '.container').len == 1
		container.set_attribute_value('data-retained-widget', 'unchanged')
		children := shadow.as_node().children_as_vector().map(it.unique_id())
		assert children.len > 0
		rebuilt := media_controls_namespace_build(document)
		retained_shadow := element.shadow_root() or { panic('Missing retained controls shadow') }
		retained_container := css.query_selector(retained_shadow.as_node(), selector) or { panic('Missing retained controls container') }
		assert voidptr(retained_shadow) == voidptr(shadow) && voidptr(retained_container) == voidptr(container)
		assert retained_shadow.as_node().children_as_vector().map(it.unique_id()) == children
		assert retained_container.get_attribute('data-retained-widget')? == 'unchanged'
		assert media_controls_namespace_layout_node(rebuilt, retained_container.as_node()) != none
		assert css.query_selector_all(retained_shadow.as_node(), '.container').len == 1
		assert element.get_attribute_ns(none, 'controls')? == 'ordinary raw value'
		assert element.get_attribute_ns('urn:media-controls-test', 'controls')? == 'foreign value'
		retained_media := html.html_media_element_for_dom_element(element) or { panic('Missing same media model') }
		assert voidptr(retained_media) == voidptr(media)
		assert retained_media.current_time() == 4 && !retained_media.paused() && retained_media.has_controls()
		assert retained_media.current_src() == '' && retained_media.network_state() == .empty
		for name in ['loadstart', 'play', 'pause', 'volumechange'] { assert retained_media.event_count(name) == 0 }
	}
}

fn test_media_controls_layout_excludes_svg_mathml_media_names_and_ordinary_html_elements() {
	mut document := media_controls_namespace_document('<!doctype html><body><div id="mcns-parent"></div>')!
	defer { document.finalize() }
	parent := document.get_element_by_id('mcns-parent') or { panic('Missing foreign parent') }
	mut elements := []&dom.Element{}
	mut markers := []&dom.Node{}
	for index, namespace in ['http://www.w3.org/2000/svg', 'http://www.w3.org/1998/Math/MathML'] {
		for tag in ['audio', 'video'] {
			mut element := media_controls_namespace_append(document, parent, namespace, tag, 'mcns-foreign-${index}-${tag}')!
			element.set_attribute_value('controls', 'ordinary controls')
			assert !element.is_html_element() && element.has_attribute_ns(none, 'controls')
			marker := document.create_text_node('retained foreign fallback').as_node()
			mut node := element.as_node()
			node.append_child(marker)!
			elements << element
			markers << marker
		}
	}
	mut ordinary := media_controls_namespace_append(document, parent, 'http://www.w3.org/1999/xhtml', 'div', 'mcns-ordinary')!
	ordinary.set_attribute_value('controls', '')
	ordinary_marker := document.create_text_node('retained ordinary fallback').as_node()
	mut ordinary_node := ordinary.as_node()
	ordinary_node.append_child(ordinary_marker)!
	elements << ordinary
	markers << ordinary_marker
	assert css.query_selector_all(document.as_node(), 'audio, video').len == 4
	for _ in 0 .. 2 {
		root := media_controls_namespace_build(document)
		assert root.child_count() > 0
		for index, element in elements {
			assert element.shadow_root() == none
			assert element.as_node().child_count() == 1
			assert voidptr(element.as_node().first_child()?) == voidptr(markers[index])
			assert element.has_attribute_ns(none, 'controls')
			assert html.html_media_element_for_dom_element(element) == none
		}
	}
}

fn test_media_controls_layout_preserves_preexisting_html_and_foreign_shadow_roots_without_altering_children() {
	mut document := media_controls_namespace_document('<!doctype html><body><div id="mcns-existing-parent"></div>')!
	defer { document.finalize() }
	parent := document.get_element_by_id('mcns-existing-parent') or { panic('Missing existing-shadow parent') }
	mut elements := []&dom.Element{}
	mut shadows := []&dom.ShadowRoot{}
	mut sentinels := []&dom.Element{}
	for index, namespace in ['http://www.w3.org/1999/xhtml', 'http://www.w3.org/2000/svg'] {
		for tag in ['audio', 'video'] {
			mut element := media_controls_namespace_append(document, parent, namespace, tag, 'mcns-existing-${index}-${tag}')!
			element.set_attribute_value('controls', 'keep existing root')
			shadow := element.attach_a_user_agent_shadow_root(.named)
			mut sentinel := document.create_element('span')!
			sentinel.set_attribute_value('data-existing-shadow', '${index}-${tag}')
			mut sentinel_node := sentinel.as_node()
			sentinel_node.append_child(document.create_text_node('original widget contents').as_node())!
			mut shadow_node := shadow.as_node()
			shadow_node.append_child(sentinel.as_node())!
			elements << element
			shadows << shadow
			sentinels << sentinel
		}
	}
	for _ in 0 .. 2 {
		root := media_controls_namespace_build(document)
		assert root.child_count() > 0
		for index, element in elements {
			shadow := element.shadow_root() or { panic('Existing shadow was discarded') }
			assert voidptr(shadow) == voidptr(shadows[index])
			assert shadow.mode() == .closed && shadow.is_user_agent_internal()
			assert voidptr(shadow.host()?) == voidptr(element)
			assert shadow.as_node().child_count() == 1
			assert voidptr(shadow.as_node().first_child()?) == voidptr(sentinels[index].as_node())
			assert sentinels[index].as_node().text_content()? == 'original widget contents'
			expected := '${index / 2}-${element.local_name()}'
			assert sentinels[index].get_attribute('data-existing-shadow')? == expected
			assert css.query_selector(shadow.as_node(), '.container') == none
			assert element.get_attribute_ns(none, 'controls')? == 'keep existing root'
		}
	}
}
