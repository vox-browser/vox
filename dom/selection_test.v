module dom

fn selection_test_document_with_text(value string) (&Document, &Text) {
	document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	root := document.create_element('html') or { panic(err) }
	document_node.append_child(root.as_node()) or { panic(err) }
	text := document.create_text_node(value)
	mut root_node := root.as_node()
	root_node.append_child(text.as_node()) or { panic(err) }
	return document, text
}

fn test_selection_is_range_backed_and_tracks_direction() {
	document, text := selection_test_document_with_text('hello')
	mut selection := Selection.create(document)
	assert selection.is_empty()
	assert selection.is_collapsed()
	assert selection.type_() == 'None'

	selection.set_base_and_extent(text.as_node(), 4, text.as_node(), 1) or { panic(err) }
	assert selection.range_count() == 1
	assert selection.direction() == 'backward'
	assert selection.anchor_offset() == 4
	assert selection.focus_offset() == 1
	assert selection.to_string() == 'ell'
	assert selection.get_range_at(0) or { panic(err) } == selection.range() or {
		panic('missing range')
	}
}

fn test_selection_collapse_extend_and_remove_range() {
	document, text := selection_test_document_with_text('hello')
	mut selection := Selection.create(document)
	selection.collapse(text.as_node(), 2) or { panic(err) }
	assert selection.type_() == 'Caret'
	selection.extend(text.as_node(), 5) or { panic(err) }
	assert selection.to_string() == 'llo'
	assert selection.direction() == 'forward'
	range := selection.range() or { panic('missing range') }
	selection.remove_range(range) or { panic(err) }
	assert selection.is_empty()
	assert range.associated_selection_ == unsafe { nil }
}

fn test_selection_moves_by_grapheme_not_code_unit() {
	document, text := selection_test_document_with_text('a👩🏼‍❤️‍👨🏻b')
	mut selection := Selection.create(document)
	selection.collapse(text.as_node(), 1) or { panic(err) }
	selection.move_offset_to_next_character(true)
	assert selection.focus_offset() > 2
	selection.move_offset_to_previous_character(true)
	assert selection.focus_offset() == 1
}

fn test_selection_selects_and_deletes_contents() {
	document, text := selection_test_document_with_text('hello')
	mut selection := Selection.create(document)
	selection.set_base_and_extent(text.as_node(), 1, text.as_node(), 4) or { panic(err) }
	assert selection.contains_node(text.as_node(), true)
	selection.delete_from_document() or { panic(err) }
	assert text.data() == 'ho'
}
