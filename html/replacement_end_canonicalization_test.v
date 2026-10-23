module html

import editing
import dom

fn replacement_fragment_with_terminal_newline(document &dom.Document, context &dom.Node) &editing.ReplacementFragment {
	range_ := dom.Range.create_from_boundary_points(context, 0, context, 0)
	return editing.ReplacementFragment.new(range_, '<span>inserted</span><br class="Apple-interchange-newline">') or {
		panic(err)
	}
}

fn attach_replacement_end_layout(node &dom.Node, owner u32) {
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
		attach_replacement_end_layout(child, owner)
	}
}

fn test_replacement_end_newline_advances_into_destination_suffix() {
	document := parse_document('<!doctype html><body><div contenteditable><p id="inserted">middle</p><p id="suffix">after</p></div></body>')
	inserted := document.get_element_by_id('inserted') or { panic('missing inserted paragraph') }
	suffix := document.get_element_by_id('suffix') or { panic('missing suffix') }
	attach_replacement_end_layout(inserted.as_node(), 1)
	attach_replacement_end_layout(suffix.as_node(), 2)
	inserted_text := inserted.as_node().first_child() or { panic('missing inserted text') }
	suffix_text := suffix.as_node().first_child() or { panic('missing suffix text') }
	fragment := replacement_fragment_with_terminal_newline(document, inserted.as_node())

	result := editing.canonicalize_inserted_content_end(dom.BoundaryPoint{
		node: inserted_text
		offset: inserted_text.length()
	}, fragment, editing.BlockReplacementPlan{})

	assert voidptr(result.node) == voidptr(suffix_text)
	assert result.offset == 0
}

fn test_replacement_end_newline_preserves_genuine_empty_terminal_paragraph() {
	document := parse_document('<!doctype html><body><div contenteditable><p id="empty"><br></p><p>after</p></div></body>')
	empty := document.get_element_by_id('empty') or { panic('missing empty paragraph') }
	fragment := replacement_fragment_with_terminal_newline(document, empty.as_node())
	boundary := dom.BoundaryPoint{
		node: empty.as_node()
		offset: 0
	}

	result := editing.canonicalize_inserted_content_end(boundary, fragment,
		editing.BlockReplacementPlan{
			selection_end_was_end_of_paragraph: true
		})

	assert voidptr(result.node) == voidptr(boundary.node)
	assert result.offset == boundary.offset
}

fn test_replacement_end_newline_materializes_terminal_list_item() {
	document := parse_document('<!doctype html><body><ul contenteditable><li id="item">last</li></ul></body>')
	item := document.get_element_by_id('item') or { panic('missing item') }
	attach_replacement_end_layout(item.as_node(), 3)
	text := item.as_node().first_child() or { panic('missing item text') }
	list := item.as_node().parent() or { panic('missing list') }
	fragment := replacement_fragment_with_terminal_newline(document, item.as_node())

	result := editing.canonicalize_inserted_content_end(dom.BoundaryPoint{
		node: text
		offset: text.length()
	}, fragment, editing.BlockReplacementPlan{})

	assert list.child_count() == 2
	assert voidptr(result.node) == voidptr(list.last_child()?)
	assert result.offset == 0
	assert result.node.as_element()?.local_name() == 'li'
}

fn test_replacement_end_newline_advances_to_following_list_item() {
	document := parse_document('<!doctype html><body><ul contenteditable><li id="first">one</li><li id="second">two</li></ul></body>')
	first := document.get_element_by_id('first') or { panic('missing first item') }
	second := document.get_element_by_id('second') or { panic('missing second item') }
	attach_replacement_end_layout(first.as_node(), 4)
	attach_replacement_end_layout(second.as_node(), 5)
	first_text := first.as_node().first_child() or { panic('missing first text') }
	second_text := second.as_node().first_child() or { panic('missing second text') }
	fragment := replacement_fragment_with_terminal_newline(document, first.as_node())

	result := editing.canonicalize_inserted_content_end(dom.BoundaryPoint{
		node: first_text
		offset: first_text.length()
	}, fragment, editing.BlockReplacementPlan{})

	assert voidptr(result.node) == voidptr(second_text)
	assert result.offset == 0
}
