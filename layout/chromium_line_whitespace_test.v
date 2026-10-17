module layout

import css
import dom
import html

fn chromium_whitespace_document(markup string) &dom.Document {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:13px Helvetica}</style>${markup}')
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	return document
}

fn chromium_whitespace_rect(document &dom.Document, id string) dom.Rect {
	element := css.query_selector(document.as_node(), '#${id}') or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

// Blink removes a line's trailing collapsible spaces before centering it.
fn test_chromium_centered_line_excludes_its_trailing_space() {
	mut document := chromium_whitespace_document('<div style="width:200px;text-align:center"><span id="a" style="display:inline-block;width:150px">a</span> <span style="display:inline-block;width:150px">b</span></div>')
	defer { document.finalize() }
	assert chromium_whitespace_rect(document, 'a').x == 25
}
