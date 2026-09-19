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
