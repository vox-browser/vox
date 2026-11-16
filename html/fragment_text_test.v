module html

import dom
import platform

fn fragment_text_tree(context &dom.Element, text string, enabled bool) !string {
	set_fragment_text_for_testing(enabled)
	nodes := parse_html_fragment(context, text)
	mut fragment := dom.new_document_fragment(context.document()).as_node()
	for node in nodes {
		assert voidptr(node.document()) == voidptr(context.document())
		has_parent := node.parent() != none
		assert !has_parent
		fragment.append_child(node)!
	}
	return fragment.serialize_fragment(.yes, .inner)
}

fn test_plain_html_fragments_match_full_tree_builder_for_text_unicode_and_fallbacks() {
	mut document := parse_document('<!doctype html><body></body>')
	defer { document.finalize() }
	for tag in ['a', 'div', 'span', 'p', 'body', 'pre', 'textarea', 'script', 'style',
		'table', 'tbody', 'tr', 'td', 'select', 'option', 'template', 'noscript'] {
		context := dom.create_element(document, tag, ns_html, none, none, false)!
		for text in ['', 'plain text', '[–]', '[100 more]', '日本語😀', '\ufefftext', ' \t\n\f ',
			'A\r\nB\rC', 'before\u0000after', '&amp;&#x1f600;', '<b>bold</b>',
			[ u8(0xff), 0xc0, 0xaf ].bytestr()] {
			expected := fragment_text_tree(context, text, false)!
			actual := fragment_text_tree(context, text, true)!
			assert actual == expected, '${tag}: ${text}'
		}
	}
	for namespace in ['http://www.w3.org/2000/svg', 'http://www.w3.org/1998/Math/MathML'] {
		context := document.create_element_ns(namespace, 'span')!
		assert fragment_text_tree(context, 'foreign &amp; text', true)! == fragment_text_tree(context, 'foreign &amp; text', false)!
	}
	set_fragment_text_for_testing(true)
}

fn test_plain_fragment_setter_keeps_replacement_identity_live_ranges_and_content() {
	mut document := parse_document('<!doctype html><body><a id="target"><b>old</b></a></body>')
	defer { document.finalize() }
	mut target := document.get_element_by_id('target')?
	mut range := document.create_range()
	range.select_node_contents(target.as_node())!
	old := target.as_node().first_child()?
	for enabled in [false, true] {
		set_fragment_text_for_testing(enabled)
		target.set_inner_html('[–]')!
		assert target.inner_html()! == '[–]'
		assert target.as_node().children.len == 1
		assert target.as_node().first_child()?.is_text()
		assert voidptr(range.start_container()) == voidptr(target.as_node())
		assert range.start_offset() == 0 && range.end_offset() == 0
	}
	old_has_parent := old.parent() != none
	assert !old_has_parent
	set_fragment_text_for_testing(true)
}

fn test_plain_fragment_nodes_own_text_after_temporary_storage_is_reused() {
	mut document := parse_document('<!doctype html><body><div id="target"></div></body>')
	document.enable_native_storage()
	defer { document.finalize(); document.release_native_storage() }
	context := document.get_element_by_id('target')?
	mut nodes := []&dom.Node{}
	scratch := platform.begin_thread_scratch('plain fragment input')
	input := 'owned 日本語 😀'.clone()
	nodes = parse_html_fragment(context, input)
	scratch.finish()
	reuse := platform.begin_thread_scratch('reuse plain fragment input')
	_ := []u8{len: 1024 * 1024, init: 0xa5}
	reuse.finish()
	assert nodes.len == 1 && nodes[0].text_content()? == 'owned 日本語 😀'
	has_parent := nodes[0].parent() != none
	assert !has_parent
}

fn test_plain_fragment_setters_preserve_observed_child_replacement_records() {
	for enabled in [false, true] {
		set_fragment_text_for_testing(enabled)
		mut document := parse_document('<!doctype html><body><a id="target"><b>old</b></a></body>')
		mut target := document.get_element_by_id('target')?
		old := target.as_node().first_child()?
		mut queue := dom.MutationObserverDeliveryQueue.create(fn () {})
		mut observer := dom.MutationObserver.construct_impl(none)!
		observer.delivery_queue_ = queue
		mut options := dom.MutationObserverOptions{child_list: true, subtree: true, character_data: true}
		observer.observe(target.as_node(), mut options)!
		target.set_inner_html('[100 more]')!
		records := observer.take_records()
		assert records.len == 1
		assert records[0].added_nodes_().len == 1 && records[0].removed_nodes_().len == 1
		assert voidptr(records[0].removed_nodes_()[0]) == voidptr(old)
		assert records[0].added_nodes_()[0].text_content()? == '[100 more]'
		observer.disconnect()
		queue.retire()
		document.finalize()
	}
	set_fragment_text_for_testing(true)
}
