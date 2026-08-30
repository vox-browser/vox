module editing

fn test_document_plain_text_and_html_serialization() {
	document := new_document('hello\nworld')
	assert document.blocks.len == 2
	assert document.plain_text() == 'hello\nworld'
	assert document.serialize_html() == '<div>hello</div><div>world</div>'
}

fn test_selection_is_normalized_and_validated() {
	mut document := new_document('abc\ndef')
	document.set_selection(Boundary{1, 2}, Boundary{0, 1})!
	assert document.selection.start == Boundary{0, 1}
	assert document.selection.end == Boundary{1, 2}
	if _ := document.checked_boundary(Boundary{3, 0}) {
		assert false
	} else {
		assert err.msg().contains('block index')
	}
}

fn test_insert_text_replaces_selection_and_handles_paragraphs() {
	mut document := new_document('hello world')
	document.set_selection(Boundary{0, 6}, Boundary{0, 11})!
	assert document.exec_command('insertText', false, 'V\neditor')!
	assert document.plain_text() == 'hello V\neditor'
	assert document.blocks.len == 2
	assert document.selection == EditingRange{
		start: Boundary{1, 6}
		end:   Boundary{1, 6}
	}
	assert document.input_events.last().input_type == 'insertText'
	assert document.input_events.last().data? == 'V\neditor'
}

fn test_backward_and_forward_delete_work_across_blocks() {
	mut backward := new_document('ab\ncd')
	backward.collapse(Boundary{1, 0})!
	assert backward.exec_command('delete', false, '')!
	assert backward.plain_text() == 'abcd'
	assert backward.selection.start == Boundary{0, 2}
	backward.exec_command('delete', false, '')!
	assert backward.plain_text() == 'acd'

	mut forward := new_document('ab\ncd')
	forward.collapse(Boundary{0, 2})!
	assert forward.exec_command('forwardDelete', false, '')!
	assert forward.plain_text() == 'abcd'
	forward.exec_command('forwardDelete', false, '')!
	assert forward.plain_text() == 'abd'
}

fn test_inline_formatting_applies_to_selection() {
	mut document := new_document('Ladybird')
	document.set_selection(Boundary{0, 0}, Boundary{0, 4})!
	assert document.exec_command('bold', false, '')!
	assert document.exec_command('italic', false, '')!
	assert document.query_command_state('bold')!
	assert document.query_command_state('italic')!
	assert document.blocks[0].items[0].style.bold
	assert document.blocks[0].items[3].style.italic
	assert !document.blocks[0].items[4].style.bold
	assert document.serialize_html().starts_with('<div><b><i>L</i></b>')
}

fn test_collapsed_formatting_is_preserved_for_inserted_text() {
	mut document := new_document('ab')
	document.collapse(Boundary{0, 1})!
	document.exec_command('bold', false, '')!
	assert document.query_command_state('bold')!
	document.exec_command('insertText', false, 'X')!
	assert document.plain_text() == 'aXb'
	assert document.blocks[0].items[1].style.bold
}

fn test_script_commands_are_mutually_exclusive() {
	mut document := new_document('abc')
	document.select_all()
	document.exec_command('subscript', false, '')!
	assert document.query_command_state('subscript')!
	assert !document.query_command_state('superscript')!
	document.exec_command('superscript', false, '')!
	assert !document.query_command_state('subscript')!
	assert document.query_command_state('superscript')!
}

fn test_colors_fonts_links_and_unlink() {
	mut document := new_document('link')
	document.select_all()
	assert document.exec_command('foreColor', false, 'f00')!
	assert document.exec_command('backColor', false, 'navy')!
	assert document.exec_command('fontName', false, 'serif')!
	assert document.exec_command('fontSize', false, '+2')!
	assert document.exec_command('createLink', false, 'https://example.test/')!
	style := document.blocks[0].items[0].style
	assert style.color == '#f00'
	assert style.background == 'navy'
	assert style.font_name == 'serif'
	assert style.font_size == 'x-large'
	assert style.link == 'https://example.test/'
	assert document.query_command_value('fontSize')! == '5'
	assert document.exec_command('unlink', false, '')!
	assert document.blocks[0].items.all(it.style.link == '')
}

fn test_collapsed_link_override_applies_to_inserted_text() {
	mut document := new_document('ab')
	document.collapse(Boundary{0, 1})!
	assert document.exec_command('createLink', false, 'https://example.test/')!
	assert document.query_command_value('createLink')! == 'https://example.test/'
	assert document.exec_command('insertText', false, 'X')!
	assert document.blocks[0].items[1].style.link == 'https://example.test/'
}

fn test_remove_format_preserves_links_and_collapsed_link_override() {
	mut selected := new_document('link')
	selected.select_all()
	selected.exec_command('createLink', false, 'https://example.test/')!
	selected.exec_command('bold', false, '')!
	selected.exec_command('removeFormat', false, '')!
	assert selected.blocks[0].items.all(it.style.link == 'https://example.test/')
	assert selected.blocks[0].items.all(!it.style.bold)

	mut collapsed := new_document('ab')
	collapsed.collapse(Boundary{0, 1})!
	collapsed.exec_command('createLink', false, 'https://example.test/')!
	collapsed.exec_command('bold', false, '')!
	collapsed.exec_command('removeFormat', false, '')!
	assert !collapsed.command_state_overrides[command_bold]
	assert collapsed.command_value_overrides[command_create_link] == 'https://example.test/'
}

fn test_font_size_accepts_upstream_floating_number_forms() {
	mut document := new_document('x')
	document.select_all()
	assert document.exec_command('fontSize', false, '3.5')!
	assert document.blocks[0].items[0].style.font_size == 'medium'
	assert document.exec_command('fontSize', false, '+2.9')!
	assert document.blocks[0].items[0].style.font_size == 'x-large'
	assert document.exec_command('fontSize', false, '-1.5')!
	assert document.blocks[0].items[0].style.font_size == 'small'
	assert !document.exec_command('fontSize', false, '1.')!
	assert !document.exec_command('fontSize', false, '\u00a03\u00a0')!
}

fn test_invalid_color_is_successful_noop_and_empty_link_fails() {
	mut document := new_document('x')
	document.select_all()
	assert document.exec_command('foreColor', false, 'not a color')!
	assert document.blocks[0].items[0].style.color == ''
	assert !document.exec_command('createLink', false, '')!
}

fn test_color_commands_use_full_libgfx_parser_without_trimming() {
	mut document := new_document('abc')
	document.select_all()
	assert document.exec_command('foreColor', false, 'rebeccapurple')!
	assert document.blocks[0].items.all(it.style.color == '#663399')
	assert document.exec_command('foreColor', false, 'RGB(1, 2, 3)')!
	assert document.blocks[0].items.all(it.style.color == '#010203')
	assert document.exec_command('hiliteColor', false, 'aliceblue')!
	assert document.blocks[0].items.all(it.style.background == '#f0f8ff')
	assert values_are_equivalent(command_fore_color, 'rebeccapurple', '#663399')
	assert !values_are_equivalent(command_fore_color, 'rebeccapurple', 'aliceblue')

	// Commands.cpp passes the string to Color verbatim; surrounding whitespace
	// is invalid and the browser-compatible action is a successful no-op.
	assert document.exec_command('foreColor', false, ' red ')!
	assert document.blocks[0].items.all(it.style.color == '#010203')
}

fn test_format_block_lists_indentation_and_justification() {
	mut document := new_document('one\ntwo')
	document.select_all()
	assert document.exec_command('formatBlock', false, '<H2>')!
	assert document.blocks.all(it.tag == 'h2')
	assert document.query_command_value('formatBlock')! == 'h2'
	assert document.exec_command('insertOrderedList', false, '')!
	assert document.query_command_state('insertOrderedList')!
	assert document.exec_command('indent', false, '')!
	assert document.blocks.all(it.indent == 1)
	assert document.exec_command('justifyCenter', false, '')!
	assert document.query_command_state('justifyCenter')!
	assert document.query_command_value('justifyCenter')! == 'center'
	assert document.exec_command('outdent', false, '')!
	assert document.blocks.all(it.indent == 0)
	assert document.exec_command('insertOrderedList', false, '')!
	assert document.blocks.all(it.list_kind == .none)
}

fn test_format_block_does_not_trim_input() {
	mut document := new_document('text')
	document.select_all()
	assert !document.exec_command('formatBlock', false, ' <H2> ')!
	assert document.blocks[0].tag == 'div'
	assert document.exec_command('formatBlock', false, '<H2>')!
	assert document.blocks[0].tag == 'h2'
}

fn test_remaining_command_action_groups_are_observable() {
	mut document := new_document('one\ntwo')
	assert document.exec_command('defaultParagraphSeparator', false, 'P')!
	assert document.default_paragraph_separator == 'p'
	assert document.exec_command('styleWithCSS', false, 'false')!
	assert !document.css_styling_flag
	assert document.exec_command('useCSS', false, 'false')!
	assert document.css_styling_flag

	document.select_all()
	assert document.exec_command('insertUnorderedList', false, '')!
	assert document.blocks.all(it.list_kind == .unordered)
	assert document.exec_command('justifyRight', false, '')!
	assert document.blocks.all(it.alignment == .right)
	assert document.exec_command('justifyFull', false, '')!
	assert document.blocks.all(it.alignment == .justify)
	assert document.exec_command('justifyLeft', false, '')!
	assert document.blocks.all(it.alignment == .left)
}

fn test_insert_replaced_content_and_remove_format() {
	mut document := new_document('ab')
	document.collapse(Boundary{0, 1})!
	assert document.exec_command('insertLineBreak', false, '')!
	assert document.exec_command('insertImage', false, 'bird.png')!
	assert document.exec_command('insertHorizontalRule', false, '')!
	assert document.exec_command('insertHTML', false, '<em>raw</em>')!
	assert document.serialize_html().contains('<br><img src="bird.png"><hr><em>raw</em>')
	document.select_all()
	document.exec_command('underline', false, '')!
	document.exec_command('removeFormat', false, '')!
	assert document.blocks[0].items.all(!it.style.underline)
}

fn test_upstream_named_command_entry_points_share_dispatch_logic() {
	mut document := new_document('one\ntwo')
	document.select_all()
	assert command_bold_action(mut document, '')
	assert document.blocks[0].items.all(it.style.bold)
	assert command_format_block_action(mut document, '<H2>')
	assert command_format_block_value(document) == 'h2'
	assert command_insert_ordered_list_action(mut document, '')
	assert command_insert_ordered_list_state(document)
	assert command_justify_center_action(mut document, '')
	assert command_justify_center_state(document)
	assert command_justify_center_value(document) == 'center'
	assert command_style_with_css_action(mut document, 'false')
	assert !command_style_with_css_state(document)
	assert command_use_css_action(mut document, 'false')
	assert command_style_with_css_state(document)
}
