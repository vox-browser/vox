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

fn test_selection_nullable_collapse_and_foreign_extend_ordering() {
	document, text := selection_test_document_with_text('hello')
	mut selection := Selection.create(document)
	selection.collapse(text.as_node(), 2) or { panic(err) }
	selection.collapse(none, 999) or { panic(err) }
	assert selection.is_empty()

	foreign_document, foreign_text := selection_test_document_with_text('x')
	_ = foreign_document
	// Upstream checks document membership before the empty-selection and offset
	// errors, so a foreign node is an observable no-op.
	selection.extend(foreign_text.as_node(), 99) or { panic(err) }
	assert selection.is_empty()
}

fn test_selection_modify_moves_by_line() {
	document, text := selection_test_document_with_text('one\ntwo')
	mut text_node := text.as_node()
	text_node.set_layout_node(&LayoutNode{
		is_text_node_:      true
		visual_lines_data_: &LayoutVisualLines{
			values: [
				VisualLine{
					start_offset:                        0
					end_offset:                          3
					end_offset_with_trailing_whitespace: 3
					has_fragments:                       true
					caret_stops:                         [
						VisualCaretStop{ offset: 0, inline_coordinate: 0 },
						VisualCaretStop{ offset: 1, inline_coordinate: 10 },
						VisualCaretStop{ offset: 3, inline_coordinate: 30 },
					]
				},
				VisualLine{
					start_offset:                        4
					end_offset:                          7
					end_offset_with_trailing_whitespace: 7
					has_fragments:                       true
					line_index:                          1
					caret_stops:                         [
						VisualCaretStop{ offset: 4, inline_coordinate: 0 },
						VisualCaretStop{ offset: 5, inline_coordinate: 10 },
						VisualCaretStop{ offset: 7, inline_coordinate: 30 },
					]
				},
			]
		}
	})
	mut selection := Selection.create(document)
	selection.collapse(text.as_node(), 1) or { panic(err) }
	selection.modify('move', 'forward', 'line') or { panic(err) }
	assert selection.focus_offset() == 5
}

fn selection_test_editing_host() (&Document, &Element) {
	mut document := Document.create(url_about_blank())
	mut document_node := unsafe { &Node(document) }
	host := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut mutable_host := unsafe { &Element(host) }
	mutable_host.set_attribute_value('contenteditable', 'true')
	document_node.append_child(host.as_node()) or { panic(err) }
	return document, host
}

fn attach_selection_test_line(node &Node, owner u32) {
	mut mutable_node := unsafe { &Node(node) }
	mutable_node.set_layout_node(&LayoutNode{
		is_text_node_:      node.is_text()
		is_atomic_inline_:  !node.is_text()
		visual_lines_data_: &LayoutVisualLines{
			values: if node.is_text() {
				[VisualLine{
					start_offset:                        0
					end_offset:                          node.length()
					end_offset_with_trailing_whitespace: node.length()
					has_fragments:                       true
					owner_paintable:                     owner
				}]
			} else {
				[]VisualLine{}
			}
		}
	})
}

fn test_caret_navigator_crosses_split_text_and_atomic_inline_content() {
	document, host := selection_test_editing_host()
	first := document.create_text_node('one')
	image := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img') or { panic(err) }
	second := document.create_text_node('two')
	mut host_node := host.as_node()
	host_node.append_child(first.as_node()) or { panic(err) }
	host_node.append_child(image.as_node()) or { panic(err) }
	host_node.append_child(second.as_node()) or { panic(err) }
	attach_selection_test_line(first.as_node(), 1)
	attach_selection_test_line(image.as_node(), 1)
	attach_selection_test_line(second.as_node(), 1)
	assert first.as_node().is_editable()
	navigator := CaretNavigator.new(document)
	after_image := navigator.move(CaretLocation{ node: first.as_node(), offset: 3 }, .move,
		.forward, .character, none) or { panic('missing atomic-inline destination') }
	assert after_image.node == host.as_node()
	assert after_image.offset == 2
	// A backward step across an atomic inline beside text in the same parent lands on the preceding text end, the
	// visually identical position before the image.
	before_image := navigator.move(after_image, .extend, .backward, .character, none) or {
		panic('missing reverse atomic-inline destination')
	}
	assert before_image.node == first.as_node()
	assert before_image.offset == 3

	end := navigator.move(CaretLocation{ node: first.as_node(), offset: 1 }, .move, .forward,
		.document_boundary, none) or { panic('missing editing-host end') }
	assert end.node == second.as_node()
	assert end.offset == 3
	start := navigator.move(end, .move, .backward, .document_boundary, none) or {
		panic('missing editing-host start')
	}
	assert start.node == first.as_node()
	assert start.offset == 0
}

fn test_selection_modifier_applies_one_cross_node_mutation_and_select_all() {
	document, host := selection_test_editing_host()
	first := document.create_text_node('one ')
	second := document.create_text_node('two')
	mut host_node := host.as_node()
	host_node.append_child(first.as_node()) or { panic(err) }
	host_node.append_child(second.as_node()) or { panic(err) }
	attach_selection_test_line(first.as_node(), 1)
	attach_selection_test_line(second.as_node(), 1)
	mut selection := Selection.create(document)
	selection.collapse(first.as_node(), first.length()) or { panic(err) }
	modifier := SelectionModifier.new(selection)
	modifier.modify(.move, .forward, .character)
	assert selection.focus_node()? == second.as_node()
	assert selection.focus_offset() == 1
	selection.set_focus_affinity(.upstream)
	assert selection.focus_affinity() == .upstream
	selection.collapse(second.as_node(), 1) or { panic(err) }
	assert selection.focus_affinity() == .downstream

	modifier.select_all()
	assert selection.anchor_node()? == first.as_node()
	assert selection.anchor_offset() == 0
	assert selection.focus_node()? == second.as_node()
	assert selection.focus_offset() == second.length()
}

fn test_editing_host_input_target_selects_to_document_boundaries() {
	document, host := selection_test_editing_host()
	mut mutable_document := unsafe { &Document(document) }
	mutable_document.set_browsing_context(&BrowsingContext{
		active_document_: document
	})
	first := document.create_text_node('one ')
	second := document.create_text_node('two')
	mut host_node := host.as_node()
	host_node.append_child(first.as_node()) or { panic(err) }
	host_node.append_child(second.as_node()) or { panic(err) }
	attach_selection_test_line(first.as_node(), 1)
	attach_selection_test_line(second.as_node(), 1)
	selection_pointer := document.get_selection() or { panic('missing document selection') }
	mut selection := unsafe { &Selection(selection_pointer) }
	selection.collapse(second.as_node(), 1) or { panic(err) }
	mut manager := document.editing_host_manager()
	manager.set_active_contenteditable_element(host.as_node())
	input_target := unsafe { &InputEventsTarget(manager) }
	assert input_target.mouse_selection_scope()? == host.as_node()
	input_target.set_selection_anchor(second.as_node(), 1, .upstream)
	assert selection.is_collapsed()
	assert selection.focus_affinity() == .upstream
	input_target.set_selection_focus(second.as_node(), 2, .downstream)
	assert selection.anchor_offset() == 1
	assert selection.focus_offset() == 2
	assert selection.focus_affinity() == .downstream
	input_target.select_all()
	assert selection.anchor_node()? == first.as_node()
	assert selection.anchor_offset() == 0
	assert selection.focus_node()? == second.as_node()
	assert selection.focus_offset() == second.length()
	input_target.move_cursor_to_start(.yes)
	assert selection.focus_node()? == second.as_node()
	assert selection.focus_offset() == 0
	input_target.move_cursor_to_start_of_document(.yes)
	assert selection.focus_node()? == first.as_node()
	assert selection.focus_offset() == 0
	input_target.move_cursor_to_end_of_document(.yes)
	assert selection.focus_node()? == second.as_node()
	assert selection.focus_offset() == second.length()
}

fn test_word_segment_kinds_and_line_boundaries() {
	assert word_segment_kind(' ') == .separator
	assert word_segment_kind('!') == .punctuation
	assert word_segment_kind('word') == .word
	document, text := selection_test_document_with_text('abc\ndef')
	navigator := CaretNavigator.new(document)
	line_end := navigator.move(CaretLocation{ node: text.as_node(), offset: 1 }, .move, .forward,
		.line_boundary, none) or { panic('line end') }
	assert line_end.offset == 3
	line_start := navigator.move(CaretLocation{ node: text.as_node(), offset: 6 }, .move,
		.backward, .line_boundary, none) or { panic('line start') }
	assert line_start.offset == 4
}

fn selection_test_paragraph(document &Document, text string) &Element {
	paragraph := document.create_element_ns('http://www.w3.org/1999/xhtml', 'p') or { panic(err) }
	mut paragraph_node := paragraph.as_node()
	paragraph_node.append_child(document.create_text_node(text).as_node()) or { panic(err) }
	return paragraph
}

fn test_canonical_editing_location_skips_formatting_whitespace_into_the_following_block() {
	document, host := selection_test_editing_host()
	mut host_node := host.as_node()
	first := selection_test_paragraph(document, 'a')
	whitespace := document.create_text_node('\n  ')
	second := selection_test_paragraph(document, 'b')
	host_node.append_child(first.as_node()) or { panic(err) }
	host_node.append_child(whitespace.as_node()) or { panic(err) }
	host_node.append_child(second.as_node()) or { panic(err) }
	second_text := second.as_node().first_child() or { panic('missing second text') }
	navigator := CaretNavigator.new(document)

	between := navigator.canonical_location_for_editing(CaretLocation{ node: host_node, offset: 1 })
	assert between.node == second_text
	assert between.offset == 0

	inside_whitespace := navigator.canonical_location_for_editing(CaretLocation{
		node:   whitespace.as_node()
		offset: 1
	})
	assert inside_whitespace.node == second_text
	assert inside_whitespace.offset == 0
}

fn test_canonical_editing_location_moves_before_a_trailing_placeholder_break() {
	document, host := selection_test_editing_host()
	paragraph := selection_test_paragraph(document, 'text')
	line_break := document.create_element_ns('http://www.w3.org/1999/xhtml', 'br') or { panic(err) }
	mut paragraph_node := paragraph.as_node()
	paragraph_node.append_child(line_break.as_node()) or { panic(err) }
	mut host_node := host.as_node()
	host_node.append_child(paragraph_node) or { panic(err) }
	text := paragraph_node.first_child() or { panic('missing text') }

	location := CaretNavigator.new(document).canonical_location_for_editing(CaretLocation{
		node:   paragraph_node
		offset: 2
	})
	assert location.node == text
	assert location.offset == 4
}

fn test_word_segment_kind_uses_unicode_general_categories() {
	assert word_segment_kind('word') == .word
	assert word_segment_kind('　') == .separator
	assert word_segment_kind(' ') == .separator
	assert word_segment_kind('、') == .punctuation
	assert word_segment_kind('«—') == .punctuation
}
