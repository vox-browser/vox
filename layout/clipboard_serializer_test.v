module layout

import editing
import html

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
	document := html.parse_document('<!doctype html><body><ul id="selection"><li><br></li><li>content</li><li><br></li></ul></body>')
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
