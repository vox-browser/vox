module html

import dom

fn test_document_exec_command_mutates_the_live_contenteditable_host() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_editable(true)
	document.set_browsing_context(&dom.BrowsingContext{})
	install_document_fragment_parsing_hook(document)

	mut host := document.create_element('div') or { panic(err) }
	host.set_attribute_for_bindings('contenteditable', 'true') or { panic(err) }
	text := document.create_text_node('hello')
	mut host_node := host.as_node()
	host_node.append_child(text.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(host.as_node()) or { panic(err) }

	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.set_base_and_extent(text.as_node(), 0, text.as_node(), 5) or { panic(err) }

	assert document.exec_command('bold', false, '')!
	assert host.as_node().text_content()? == 'hello'
	assert host.inner_html()!.contains('<b>')

	// The adapter restores the live DOM selection after replacing the host's
	// markup, so a subsequent editing command operates on the same range.
	assert document.exec_command('insertText', false, 'V')!
	assert host.as_node().text_content()? == 'V'
	assert host.inner_html()!.contains('V')
	assert !document.exec_command('notACommand', false, '')!
}
