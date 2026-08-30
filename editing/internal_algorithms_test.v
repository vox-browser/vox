module editing

fn test_canonical_space_sequence_matches_editing_algorithm() {
	assert canonical_space_sequence(0, false, false) == ''
	assert canonical_space_sequence(1, false, false) == ' '
	assert canonical_space_sequence(1, true, false) == '\u00a0'
	assert canonical_space_sequence(2, false, false) == '  '
	assert canonical_space_sequence(2, false, true) == ' \u00a0'
	assert canonical_space_sequence(4, true, true) == '\u00a0 \u00a0\u00a0'
}

fn test_canonicalize_whitespace_preserves_run_length_and_content() {
	result := canonicalize_whitespace_text('  hello\t\nworld ', true, true)
	assert result.runes().len == 15
	assert result.starts_with('\u00a0 ')
	assert result.contains('hello')
	assert result.contains('world')
	assert result.ends_with('\u00a0')
}

fn test_element_name_classification() {
	assert is_formattable_block_name('H3')
	assert is_formattable_block_name('address')
	assert !is_formattable_block_name('section')
	assert is_heading('h6')
	assert !is_heading('header')
	assert is_name_of_an_element_with_inline_contents('ruby')
	assert !is_name_of_an_element_with_inline_contents('table')
	assert is_prohibited_paragraph_child_name('table')
	assert is_prohibited_paragraph_child_name('ARTICLE')
	assert !is_prohibited_paragraph_child_name('span')
	assert is_remove_format_candidate('strong')
	assert !is_remove_format_candidate('img')
	assert is_non_list_single_line_container('pre')
	assert is_single_line_container('li')
}

fn test_font_size_conversion_and_legacy_thresholds() {
	assert named_font_sizes().len == 7
	assert font_size_to_pixel_size('18px') == 18.0
	assert font_size_to_pixel_size('x-large') == 24.0
	assert font_size_to_pixel_size('unexpected') == 16.0
	assert font_size_to_pixel_size('not-a-numberpx') == 16.0
	assert legacy_font_size(9) == '1'
	assert legacy_font_size(16) == '3'
	assert legacy_font_size(100) == '7'
}

fn test_equivalent_and_loosely_equivalent_values() {
	assert values_are_equivalent(command_bold, 'bold', '700')
	assert values_are_equivalent(command_bold, 'normal', '400')
	assert !values_are_equivalent(command_bold, 'normal', '700')
	assert values_are_equivalent(command_fore_color, '#F00', '#f00')
	assert values_are_equivalent(command_fore_color, 'red', '#ff0000')
	assert values_are_equivalent(command_fore_color, 'rgb(255, 0, 0)', '#ff0000')
	assert !values_are_equivalent(command_fore_color, 'rgb(1, 2, 3)', 'rgb(4, 5, 6)')
	assert values_are_equivalent(command_fore_color, 'invalid', 'also-invalid')
	assert values_are_equivalent(command_italic, none, none)
	assert !values_are_equivalent(command_italic, none, 'italic')
	assert values_are_loosely_equivalent(command_font_size, 'x-small', '1')
	assert values_are_loosely_equivalent(command_font_size, '7', 'xxx-large')
	assert !values_are_loosely_equivalent(command_font_size, 'small', '6')
}

fn test_list_state_reports_uniform_and_mixed_selections() {
	mut document := new_document('one\ntwo')
	document.set_selection(Boundary{0, 0}, Boundary{1, 3})!
	assert selections_list_state(document) == .none
	document.blocks[0].list_kind = .ordered
	document.blocks[1].list_kind = .ordered
	assert selections_list_state(document) == .ol
	document.blocks[1].list_kind = .unordered
	assert selections_list_state(document) == .mixed
	document.blocks[1].list_kind = .none
	assert selections_list_state(document) == .mixed_ol
}

fn test_record_and_restore_overrides() {
	mut document := new_document('x')
	document.command_state_overrides[command_bold] = true
	document.set_value_override(command_back_color, '#fff')
	recorded := record_current_overrides(document)
	assert recorded.len == 2
	assert recorded[0].command == command_bold
	assert recorded[0].is_bool
	assert recorded[1].command == command_hilite_color
	document.command_state_overrides.clear()
	document.command_value_overrides.clear()
	restore_states_and_values(mut document, recorded)
	assert document.command_state_overrides[command_bold]
	assert document.command_value_overrides[command_back_color] == '#fff'
	assert document.command_value_overrides[command_hilite_color] == '#fff'
}

fn test_record_current_overrides_uses_the_upstream_subset_and_order() {
	mut document := new_document('x')
	document.command_value_overrides[command_create_link] = 'https://example.test/'
	document.command_state_overrides[command_underline] = false
	document.command_state_overrides[command_bold] = true
	document.command_value_overrides[command_fore_color] = 'red'
	document.command_value_overrides[command_back_color] = 'blue'
	document.command_value_overrides[command_hilite_color] = 'blue'
	document.command_value_overrides[command_default_paragraph_separator] = 'p'

	recorded := record_current_overrides(document)
	assert recorded.map(it.command) == [command_create_link, command_bold, command_underline,
		command_fore_color, command_hilite_color]
}

fn test_recorded_selection_values_can_be_restored() {
	mut document := new_document('ab')
	document.blocks[0].items[0].style.bold = true
	document.blocks[0].items[0].style.color = 'red'
	document.blocks[0].items[1].style.bold = false
	document.blocks[0].items[1].style.color = 'blue'
	document.select_all()
	bold_values := record_the_values_of_selection(document, command_bold)
	color_values := record_the_values_of_selection(document, command_fore_color)

	document.blocks[0].items[0].style = InlineStyle{}
	document.blocks[0].items[1].style = InlineStyle{}
	restore_the_values_of_selection(mut document, bold_values)
	restore_the_values_of_selection(mut document, color_values)
	assert document.blocks[0].items[0].style.bold
	assert document.blocks[0].items[0].style.color == 'red'
	assert !document.blocks[0].items[1].style.bold
	assert document.blocks[0].items[1].style.color == 'blue'
}

fn test_effective_values_ignore_non_formattable_replaced_items() {
	mut document := new_document('x')
	document.blocks[0].items[0].style.bold = true
	document.blocks[0].items << InlineItem{
		kind: .horizontal_rule
	}
	document.select_all()
	assert effective_command_values(document, command_bold) == ['bold']
	assert record_the_values_of_selection(document, command_bold).len == 1
}

fn test_upstream_range_and_node_entry_points() {
	mut document := new_document('abc\ndef')
	document.set_selection(Boundary{0, 1}, Boundary{1, 2})!
	range := active_range(document) or { panic('expected active range') }
	extended := block_extend_a_range(document, range)
	assert extended == EditingRange{
		start: Boundary{0, 0}
		end:   Boundary{1, 3}
	}
	item := EditingNode{0, 1}
	assert (block_node_of_node(document, item) or { EditingNode{-1, none} }) == EditingNode{0, none}
	assert is_effectively_contained_in_range(document, item, range)
	assert is_formattable_node(document, item)
	assert is_visible_node(document, item)
	assert follows_a_line_break(document, EditingNode{1, 0})
	assert precedes_a_line_break(document, EditingNode{0, 2})
}

fn test_upstream_whitespace_autolink_and_value_algorithms() {
	mut whitespace := new_document('  x  ')
	canonicalize_whitespace(mut whitespace, Boundary{0, 1}, true)
	assert whitespace.plain_text().runes().len == 5
	assert whitespace.plain_text().starts_with('\u00a0 ')

	mut link := new_document('https://example.test')
	autolink(mut link, Boundary{0, link.blocks[0].items.len})
	assert link.blocks[0].items.all(it.style.link == 'https://example.test')

	node := EditingNode{0, 0}
	force_the_value(mut link, node, command_bold, 'bold')
	assert effective_command_value(link, node, command_bold)? == 'bold'
	recorded := record_the_values_of_nodes(link, [node], command_bold)
	clear_the_value(mut link, command_bold, [node])
	assert effective_command_value(link, node, command_bold)? == 'normal'
	restore_the_values_of_nodes(mut link, recorded)
	assert effective_command_value(link, node, command_bold)? == 'bold'
}

fn test_move_node_preserves_logical_range_boundaries() {
	mut document := new_document('abc')
	document.set_selection(Boundary{0, 1}, Boundary{0, 3})!
	move_node_preserving_ranges(mut document, EditingNode{0, 0}, EditingNode{0, none}, 3)
	assert document.plain_text() == 'bca'
	assert document.selection == EditingRange{
		start: Boundary{0, 0}
		end:   Boundary{0, 2}
	}
}

fn is_blockquote_block(block Block) bool {
	return block.tag == 'blockquote'
}

fn test_wrap_moves_items_into_requested_parent() {
	mut document := new_document('ab')
	parent := wrap(mut document, [EditingNode{0, 0}, EditingNode{0, 1}],
		is_blockquote_block, Block{tag: 'blockquote'}) or { panic('expected wrapper') }
	assert parent == EditingNode{0, none}
	assert document.blocks.len == 1
	assert document.blocks[0].tag == 'blockquote'
	assert document.plain_text() == 'ab'
}
