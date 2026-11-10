module layout

import editing
import html

fn test_styled_clipboard_accumulator_preserves_boxless_whitespace_in_visible_structure() {
	document := html.parse_document('<!doctype html><div id="selection"><p>first</p> \n <p>second</p></div>')
	_ = run_document_layout(document, 300, 100) or { panic('missing layout') }
	container := document.get_element_by_id('selection') or { panic('missing container') }
	mut whitespace := container.as_node().children_as_vector()[1]
	assert whitespace.is_text()
	whitespace.clear_layout_node_and_paintable()
	mut range_ := document.create_range()
	range_.select_node_contents(container.as_node()) or { panic(err) }
	selection := editing.StyledMarkupSelection.new(range_)
	accumulator := editing.StyledMarkupAccumulator.new(&selection)
	mut found := false
	for mapping in accumulator.serialized_text() {
		if voidptr(mapping.source.as_node()) == voidptr(whitespace) {
			assert mapping.serialized.data() == ' \n '
			found = true
		}
	}
	assert found
}

fn test_plain_text_clipboard_serializer_uses_rendered_structure() {
	document := html.parse_document('<!doctype html><style>body{margin:0}.hidden{display:none}.blocked{user-select:none}p{margin:0}</style><body><div id="selection"><p>first<span class="hidden">secret</span><span class="blocked">blocked</span></p><p>second<br>line<img alt="[bird]"></p><table><tr><td>A</td><td>B</td></tr><tr><td>C</td></tr></table></div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	assert editing.serialize_range_as_plain_text_for_clipboard(range) == 'first\n\nsecond\nline[bird]\n\nA\tB\nC'
}

fn test_plain_text_clipboard_serializer_respects_utf16_range_boundaries() {
	document := html.parse_document('<!doctype html><body><span id="selection">A😀BC</span></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	text_node := selection.as_node().first_child() or { panic('missing text') }
	mut range := document.create_range()
	range.set_start(text_node, 1) or { panic(err) }
	range.set_end(text_node, 4) or { panic(err) }

	assert editing.serialize_range_as_plain_text_for_clipboard(range) == '😀B'
}

fn test_styled_clipboard_serializer_uses_rendered_tree() {
	document := html.parse_document('<!doctype html><style>body{margin:0}.hidden{display:none}.contents{display:contents}</style><body><div id="selection"><div>visible<span class="hidden">secret <b>nested</b></span><span class="contents"><i>shown</i></span> tail</div></div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	markup := editing.serialize_range_as_html_for_clipboard(range)
	assert markup == '<div>visible<span class="contents"><i>shown</i></span><span>&nbsp;</span>tail</div>'
}

fn test_styled_clipboard_serializer_clips_utf16_text_range() {
	document := html.parse_document('<!doctype html><body><span id="selection">A😀BC</span></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	text_node := selection.as_node().first_child() or { panic('missing text') }
	mut range := document.create_range()
	range.set_start(text_node, 1) or { panic(err) }
	range.set_end(text_node, 4) or { panic(err) }
	assert editing.serialize_range_as_html_for_clipboard(range) == '😀B'
}

fn test_styled_clipboard_serializer_protects_collapsible_whitespace() {
	document := html.parse_document('<!doctype html><body><div id="selection"> leading  interior   trailing </div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	assert editing.serialize_range_as_html_for_clipboard(range) == '<span>&nbsp;</span>leading<span>&nbsp;</span> interior<span>&nbsp;</span> <span>&nbsp;</span>trailing<span>&nbsp;</span>'
}

fn test_styled_clipboard_serializer_preserves_preformatted_whitespace() {
	document := html.parse_document('<!doctype html><body><div id="selection" style="white-space:pre"> leading  text\nnext </div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	assert editing.serialize_range_as_html_for_clipboard(range) == ' leading  text\nnext '
}

fn test_styled_clipboard_serializer_restores_shared_list_wrapper() {
	document := html.parse_document('<!doctype html><body><ol id="selection" start="3"><li>third</li><li>fourth</li></ol></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	assert editing.serialize_range_as_html_for_clipboard(range) == '<ol id="selection" start="3"><li>third</li><li>fourth</li></ol>'
}

fn test_styled_clipboard_serializer_encodes_empty_list_item_boundaries() {
	// NB: The selection's visible paragraph boundaries are caret positions, which exist only inside an editing host.
	document := html.parse_document('<!doctype html><body><div contenteditable><ul id="selection"><li><br></li><li>content</li><li><br></li></ul></div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	assert editing.serialize_range_as_html_for_clipboard(range) == '<ul id="selection"><li><br class="Apple-interchange-newline">content</li></ul><br class="Apple-interchange-newline">'
}

fn test_styled_clipboard_serializer_materializes_partial_text_style() {
	document := html.parse_document('<!doctype html><body><div id="host" contenteditable><span id="selection" style="color:red;font-weight:700">abcdef</span></div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	text_node := selection.as_node().first_child() or { panic('missing text') }
	mut range := document.create_range()
	range.set_start(text_node, 1) or { panic(err) }
	range.set_end(text_node, 4) or { panic(err) }

	assert editing.serialize_range_as_html_for_clipboard(range) == '<span style="color: rgb(255, 0, 0);font-weight: 700;">bcd</span>'
}

fn test_styled_clipboard_serializer_materializes_legacy_font_run() {
	document := html.parse_document('<!doctype html><body><div id="selection"><font color="#0f0">legacy </font></div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	selection := document.get_element_by_id('selection') or { panic('missing selection') }
	mut range := document.create_range()
	range.select_node_contents(selection.as_node()) or { panic(err) }

	assert editing.serialize_range_as_html_for_clipboard(range) == '<span style="color: rgb(0, 255, 0);">legacy</span><span style="color: rgb(0, 255, 0);"><span>&nbsp;</span></span>'
}

fn test_legacy_font_style_helpers_materialize_and_remove_single_run() {
	quirks_document := html.parse_document('<html><body><div id="wrapper"><font color="chucknorris">legacy</font></div></body></html>')
	wrapper := quirks_document.get_element_by_id('wrapper') or { panic('missing wrapper') }
	wrapper_node := wrapper.as_node()
	editing.materialize_single_run_legacy_font_style(wrapper_node)
	assert wrapper_node.serialize_fragment(.no, .inner) or { '' } == '<span style="color: rgb(192, 0, 0);">legacy</span>'

	document := html.parse_document('<!doctype html><body><div id="wrapper"><font color="red"><b>legacy</b></font></div></body>')
	plain_wrapper := document.get_element_by_id('wrapper') or { panic('missing wrapper') }
	plain_wrapper_node := plain_wrapper.as_node()
	editing.remove_single_run_legacy_font_style(plain_wrapper_node)
	assert plain_wrapper_node.serialize_fragment(.no, .inner) or { '' } == '<b>legacy</b>'
}

fn styled_clipboard_range_between(markup string, start_id string, start_offset int, end_id string, end_offset int) string {
	document := html.parse_document('<!doctype html><style>body{margin:0}p{margin:0}</style><body><div contenteditable>${markup}</div></body>')
	_ := run_document_layout(document, 800, 600) or { panic('layout failed') }
	start_element := document.get_element_by_id(start_id) or { panic('missing start') }
	end_element := document.get_element_by_id(end_id) or { panic('missing end') }
	mut range := document.create_range()
	range.set_start(start_element.as_node().first_child() or { panic('missing start text') }, start_offset) or {
		panic(err)
	}
	range.set_end(end_element.as_node().first_child() or { panic('missing end text') }, end_offset) or {
		panic(err)
	}
	return editing.serialize_range_as_html_for_clipboard(range)
}

fn test_styled_clipboard_serializer_represents_a_lone_paragraph_break_with_a_marker() {
	assert styled_clipboard_range_between('<p id="a">first</p><p id="b">second</p>', 'a', 5, 'b',
		0) == '<br class="Apple-interchange-newline">'
}

fn test_styled_clipboard_serializer_flattens_a_partial_div_after_a_leading_paragraph_boundary() {
	assert styled_clipboard_range_between('<p id="a">first</p><div id="b">second</div>', 'a', 5,
		'b', 3) == '<br class="Apple-interchange-newline">sec'
}
