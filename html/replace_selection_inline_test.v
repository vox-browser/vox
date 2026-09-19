module html

import editing
import dom

fn collapse_replace_selection(document &dom.Document, node &dom.Node, offset int) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(node, offset) or { panic(err) }
}

fn test_inline_replacement_coalesces_plain_text_and_places_caret() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable>beforeafter</div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	text := host.as_node().first_child() or { panic('missing text') }
	collapse_replace_selection(document, text, 6)

	caret := editing.replace_collapsed_selection_with_inline_html(document, 'middle') or {
		panic(err)
	}

	assert host.inner_html()! == 'beforemiddleafter'
	assert host.as_node().child_count() == 1
	merged_text := host.as_node().first_child() or { panic('missing merged text') }
	assert caret == dom.BoundaryPoint{ node: merged_text, offset: 12 }
	selection := document.get_selection() or { panic('missing selection') }
	assert selection.is_collapsed()
	assert selection.focus_node()? == merged_text
	assert selection.focus_offset() == 12
}

fn test_inline_replacement_splits_destination_formatting_chain() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><b id="bold">beforeafter</b></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	bold := document.get_element_by_id('bold') or { panic('missing bold') }
	mut mutable_bold := unsafe { &dom.Element(bold) }
	mutable_bold.remove_attribute('id')
	text := bold.as_node().first_child() or { panic('missing text') }
	collapse_replace_selection(document, text, 6)

	caret := editing.replace_collapsed_selection_with_inline_html(document, '<i>middle</i>') or {
		panic(err)
	}

	assert host.inner_html()! == '<b>before</b><i>middle</i><b>after</b>'
	assert caret.node.is_text()
	assert caret.node.text_content()? == 'middle'
	assert caret.offset == 6
}

fn test_inline_replacement_removes_empty_block_placeholder() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><br></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	collapse_replace_selection(document, host.as_node(), 0)

	_ := editing.replace_collapsed_selection_with_inline_html(document, 'text') or { panic(err) }

	assert host.inner_html()! == 'text'
}
