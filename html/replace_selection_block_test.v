module html

import editing
import dom

fn attach_block_replacement_layout(node &dom.Node, owner u32) {
	if node.is_text() && node.length() > 0 {
		mut mutable_node := unsafe { &dom.Node(node) }
		mutable_node.set_layout_node(&dom.LayoutNode{
			is_text_node_: true
			visual_lines_data_: &dom.LayoutVisualLines{ values: [dom.VisualLine{
				start_offset: 0
				end_offset: node.length()
				end_offset_with_trailing_whitespace: node.length()
				has_fragments: true
				owner_paintable: owner
			}] }
		})
	}
	for child in node.children_as_vector() {
		attach_block_replacement_layout(child, owner)
	}
}

fn prepare_block_replacement(document &dom.Document, text &dom.Node, offset int, value string) (&dom.Range, &editing.ReplacementFragment, &editing.InsertedContent) {
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_browsing_context(&dom.BrowsingContext{
		active_document_: document
	})
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.collapse(text, offset) or { panic(err) }
	range_ := selection.range() or { panic('missing range') }
	fragment := editing.ReplacementFragment.new(range_, value) or { panic(err) }
	for child in fragment.children() {
		attach_block_replacement_layout(child, 20)
	}
	content := editing.InsertedContent.new(fragment.children())
	return range_, fragment, content
}

fn test_block_replacement_integrates_leading_seam_and_preserves_suffix() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><div id="destination"><span>before</span><span>after</span></div></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	attach_block_replacement_layout(destination.as_node(), 10)
	range_, fragment, mut content := prepare_block_replacement(document, destination.as_node(), 1,
		'<p>middle</p>')
	defer {
		content.release()
	}

	caret := editing.replace_selection_with_block_fragment(document, range_, destination.as_node(),
		fragment, mut content) or { panic(err) }

	assert host.as_node().child_count() == 2
	assert host.as_node().text_content()? == 'beforemiddleafter'
	assert caret.node.is_text()
	assert caret.offset == 6
}

fn test_block_replacement_keeps_distinct_inserted_paragraphs() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><div id="destination"><span>before</span><span>after</span></div></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	attach_block_replacement_layout(destination.as_node(), 11)
	range_, fragment, mut content := prepare_block_replacement(document, destination.as_node(), 1,
		'<p>one</p><p>two</p>')
	defer {
		content.release()
	}

	_ := editing.replace_selection_with_block_fragment(document, range_, destination.as_node(),
		fragment, mut content) or { panic(err) }

	assert host.as_node().text_content()? == 'beforeonetwoafter'
	assert host.as_node().child_count() >= 2
}

fn test_block_replacement_reuses_empty_destination_block() {
	document := parse_document('<!doctype html><body><div id="host" contenteditable><div id="destination"><br></div></div></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	range_, fragment, mut content := prepare_block_replacement(document, destination.as_node(), 0,
		'<p>middle</p>')
	defer {
		content.release()
	}

	_ := editing.replace_selection_with_block_fragment(document, range_, destination.as_node(),
		fragment, mut content) or { panic(err) }

	assert host.as_node().text_content()? == 'middle'
	assert host.as_node().child_count() == 1
}

fn test_block_replacement_integrates_matching_list_wrapper() {
	document := parse_document('<!doctype html><body><ul id="host" contenteditable><li id="destination">before</li></ul></body>')
	host := document.get_element_by_id('host') or { panic('missing host') }
	destination := document.get_element_by_id('destination') or { panic('missing destination') }
	attach_block_replacement_layout(destination.as_node(), 12)
	range_, fragment, mut content := prepare_block_replacement(document, destination.as_node(),
		destination.as_node().child_count(), '<ul><li>one</li><li>two</li></ul>')
	defer {
		content.release()
	}

	_ := editing.replace_selection_with_block_fragment(document, range_, destination.as_node(),
		fragment, mut content) or { panic(err) }

	assert host.as_node().text_content()? == 'beforeonetwo'
	assert host.as_node().child_count() == 3
}
