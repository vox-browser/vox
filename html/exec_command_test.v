module html

import dom
import editing

fn exec_command_document(markup string) (&dom.Document, &dom.Element) {
	mut document := parse_document('<!doctype html><body><div id="host" contenteditable>${markup}</div></body>')
	// NB: Resolved style, which the command states and values read, is only computed with a browsing context.
	document.set_browsing_context(&dom.BrowsingContext{})
	install_document_fragment_parsing_hook(document)
	host := document.get_element_by_id('host') or { panic('missing host') }
	return document, host
}

fn exec_command_select(document &dom.Document, start_node &dom.Node, start_offset int, end_node &dom.Node, end_offset int) {
	selection_pointer := document.get_selection() or { panic('missing selection') }
	mut selection := unsafe { &dom.Selection(selection_pointer) }
	selection.set_base_and_extent(start_node, start_offset, end_node, end_offset) or { panic(err) }
}

fn exec_command_first_text(element &dom.Element) &dom.Node {
	mut node := element.as_node().first_child() or { panic('missing child') }
	for !node.is_text() {
		node = node.first_child() or { panic('missing text descendant') }
	}
	return node
}

fn test_bold_wraps_the_selected_run_and_is_undoable() {
	mut document, host := exec_command_document('abc')
	text := exec_command_first_text(host)
	exec_command_select(document, text, 1, text, 2)
	assert !document.query_command_state('bold')!

	assert document.exec_command('bold', false, '')!
	assert host.inner_html()! == 'a<b>b</b>c'
	assert document.query_command_state('bold')!

	assert document.exec_command('undo', false, '')!
	assert host.inner_html()! == 'abc'
	history := editing.editing_history_if_exists(document) or { panic('missing editing history') }
	assert history.unproxied_mutation_count() == 0
}

fn test_bold_state_reflects_existing_markup_and_toggling_removes_it() {
	mut document, host := exec_command_document('<b>bold</b>')
	text := exec_command_first_text(host)
	exec_command_select(document, text, 0, text, 4)
	assert document.query_command_state('bold')!
	assert !document.query_command_indeterm('bold')!

	assert document.exec_command('bold', false, '')!
	assert host.inner_html()! == 'bold'
	assert !document.query_command_state('bold')!
}

fn test_command_values_are_read_from_resolved_style() {
	mut document, host := exec_command_document('<font color="red" size="5" face="serif">x</font>')
	text := exec_command_first_text(host)
	exec_command_select(document, text, 0, text, 1)
	assert document.query_command_value('foreColor')! == 'rgb(255, 0, 0)'
	assert document.query_command_value('fontSize')! == '5'
	assert document.query_command_value('fontName')! == 'serif'
	assert !document.query_command_indeterm('foreColor')!
}

fn test_fore_color_on_a_mixed_selection_is_indeterminate() {
	mut document, host := exec_command_document('<font color="red">a</font>b')
	first := exec_command_first_text(host)
	last := host.as_node().last_child() or { panic('missing trailing text') }
	exec_command_select(document, first, 0, last, 1)
	assert document.query_command_indeterm('foreColor')!
}

fn test_fore_color_applies_a_font_element_when_css_styling_is_off() {
	mut document, host := exec_command_document('abc')
	text := exec_command_first_text(host)
	exec_command_select(document, text, 0, text, 3)
	assert document.exec_command('foreColor', false, '#00ff00')!
	assert host.inner_html()! == '<font color="#00ff00">abc</font>'
	assert document.query_command_value('foreColor')! == 'rgb(0, 255, 0)'
}

fn test_back_color_and_hilite_color_share_a_value_override() {
	mut document, host := exec_command_document('abc')
	text := exec_command_first_text(host)
	exec_command_select(document, text, 1, text, 1)
	assert document.exec_command('backColor', false, 'red')!
	assert document.command_value_override('backColor')? == 'red'
	assert document.command_value_override('hiliteColor')? == 'red'
	assert host.inner_html()! == 'abc'
}

fn test_insert_ordered_list_wraps_the_current_paragraph() {
	mut document, host := exec_command_document('item')
	text := exec_command_first_text(host)
	exec_command_select(document, text, 2, text, 2)
	assert !document.query_command_state('insertOrderedList')!
	assert document.exec_command('insertOrderedList', false, '')!
	assert host.inner_html()! == '<ol><li>item</li></ol>'
	assert document.query_command_state('insertOrderedList')!
}

fn test_font_size_to_pixel_size_scales_the_default_font_size_by_the_absolute_size_factor() {
	assert editing.font_size_to_pixel_size('x-small').to_int() == 12
	assert editing.font_size_to_pixel_size('medium').to_int() == 16
	assert editing.font_size_to_pixel_size('XX-LARGE').to_int() == 32
	assert editing.font_size_to_pixel_size('7').to_int() == 48
	assert editing.font_size_to_pixel_size('20px').to_int() == 20
}
