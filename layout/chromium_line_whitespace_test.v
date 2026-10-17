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

// Non-wrapping text still removes spaces at the line start and collapses a
// space sequence across element boundaries into its first space.
fn test_chromium_nowrap_spaces_collapse_across_elements() {
	mut collapsed := chromium_whitespace_document('<div style="white-space:nowrap"><span>\n<bdi id="n" dir="ltr">\n1,000,000+\n</bdi>\n<span id="t">\narticles\n</span>\n</span></div>')
	defer { collapsed.finalize() }
	mut reference := chromium_whitespace_document('<div style="white-space:nowrap"><span><bdi id="n" dir="ltr">1,000,000+ </bdi><span id="t">articles</span></span></div>')
	defer { reference.finalize() }
	assert chromium_whitespace_rect(collapsed, 'n').x == 0
	assert chromium_whitespace_rect(collapsed, 'n').width == chromium_whitespace_rect(reference, 'n').width
	assert chromium_whitespace_rect(collapsed, 't').x == chromium_whitespace_rect(reference, 't').x
	// Trimming the trailing space can move the text item's rounded end by 1/64.
	width_delta := chromium_whitespace_rect(collapsed, 't').width - chromium_whitespace_rect(reference, 't').width
	assert width_delta < 0.02 && width_delta > -0.02
}
