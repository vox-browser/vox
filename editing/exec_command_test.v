module editing

fn test_supported_command_queries_are_case_insensitive() {
	document := new_document('x')
	assert document.query_command_supported('BoLd')!
	assert document.query_command_supported('insertHTML')!
	assert !document.query_command_supported('preserveWhitespace')!
	assert !document.query_command_supported('copy')!
	assert !document.query_command_supported('unknown')!
}

fn test_non_html_documents_reject_all_document_editing_methods() {
	mut document := new_document('x')
	document.is_html_document = false
	if _ := document.exec_command('bold', false, '') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError')
	}
	if _ := document.query_command_supported('bold') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError')
	}
	if _ := document.query_command_enabled('bold') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError')
	}
	if _ := document.query_command_state('bold') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError')
	}
	if _ := document.query_command_indeterm('bold') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError')
	}
	if _ := document.query_command_value('bold') {
		assert false
	} else {
		assert err.msg().starts_with('InvalidStateError')
	}
}

fn test_exec_command_recursion_guard_returns_false() {
	mut document := new_document('x')
	document.inside_exec_command = true
	assert !document.exec_command('bold', false, '')!
	assert document.inside_exec_command
}

fn test_plaintext_only_host_disables_rich_commands() {
	mut document := new_document('x')
	document.plaintext_only = true
	assert !document.query_command_enabled('bold')!
	assert !document.query_command_enabled('insertHTML')!
	assert document.query_command_enabled('insertText')!
	assert document.query_command_enabled('delete')!
	assert document.query_command_enabled('defaultParagraphSeparator')!
}

fn test_default_paragraph_separator_and_css_flags() {
	mut document := new_document('x')
	assert document.query_command_value('defaultParagraphSeparator')! == 'div'
	assert document.exec_command('defaultParagraphSeparator', false, 'P')!
	assert document.query_command_value('defaultParagraphSeparator')! == 'p'
	assert !document.exec_command('defaultParagraphSeparator', false, 'section')!
	assert document.exec_command('styleWithCSS', false, 'true')!
	assert document.query_command_state('styleWithCSS')!
	assert document.exec_command('styleWithCSS', false, 'false')!
	assert !document.query_command_state('styleWithCSS')!
	assert document.exec_command('useCSS', false, 'false')!
	assert document.css_styling_flag
}

fn test_query_indeterminate_for_mixed_inline_values() {
	mut document := new_document('ab')
	document.set_selection(Boundary{0, 0}, Boundary{0, 1})!
	document.exec_command('bold', false, '')!
	document.select_all()
	assert document.query_command_indeterm('bold')!
	assert !document.query_command_state('bold')!
}

fn test_query_indeterminate_uses_raw_color_values() {
	mut document := new_document('ab')
	document.blocks[0].items[0].style.color = 'red'
	document.blocks[0].items[1].style.color = '#ff0000'
	document.select_all()

	// The colors have equivalent RGBA components, but upstream's
	// queryCommandIndeterm algorithm compares their effective strings.
	assert document.query_command_indeterm('foreColor')!
}

fn test_query_indeterminate_for_blocks_and_lists() {
	mut document := new_document('a\nb')
	document.blocks[0].tag = 'p'
	document.blocks[1].tag = 'h1'
	document.blocks[0].list_kind = .ordered
	document.blocks[1].list_kind = .unordered
	document.select_all()
	assert document.query_command_indeterm('formatBlock')!
	assert document.query_command_indeterm('insertOrderedList')!
	assert document.query_command_indeterm('insertUnorderedList')!
	document.blocks[1].alignment = .right
	assert document.query_command_indeterm('justifyLeft')!
}

fn test_select_all_and_input_event_mapping() {
	mut document := new_document('abc')
	document.collapse(Boundary{0, 2})!
	assert document.exec_command('selectAll', false, '')!
	assert document.selection == EditingRange{
		start: Boundary{0, 0}
		end:   Boundary{0, 3}
	}
	document.exec_command('bold', false, '')!
	assert document.input_events.last().input_type == 'formatBold'
}

fn test_command_value_overrides_link_background_commands() {
	mut document := new_document('x')
	document.set_value_override(command_hilite_color, '#123')
	assert document.query_command_value(command_back_color)! == '#123'
	assert document.query_command_value(command_hilite_color)! == '#123'
}

fn test_query_value_is_empty_without_a_registered_value_callback() {
	mut document := new_document('x')
	document.select_all()
	document.exec_command('bold', false, '')!
	document.blocks[0].items[0].style.font_name = 'serif'
	document.blocks[0].items[0].style.color = 'red'

	assert document.query_command_value('bold')! == ''
	assert document.query_command_value('fontName')! == ''
	assert document.query_command_value('foreColor')! == ''
}

fn test_select_all_is_enabled_when_the_typed_document_has_no_blocks() {
	mut document := new_document('')
	document.blocks.clear()
	assert document.query_command_enabled('selectAll')!
}
