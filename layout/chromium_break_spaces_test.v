module layout

import dom
import html

fn chromium_break_spaces_layout(markup string) &dom.Document {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		div{font:20px Arial;white-space:break-spaces}</style>' + markup)
	document.set_font_rendering_policy(.chromium)
	run_document_layout(document, 400, 300) or { panic('layout') }
	return document
}

// Brave 156: break-spaces spaces never hang, and the line can only break after
// them. In a line wide enough for "aaaa bbbb" but not "aaaa bbbb ", the space
// after "bbbb" does not fit, so "bbbb" moves to the second line: Brave lays
// out "aaaa " / "bbbb cccc". GitHub's inline code uses break-spaces.
fn test_chromium_break_spaces_words_fit_with_their_trailing_spaces() {
	mut probe := chromium_break_spaces_layout('<div><span id="m">aaaa bbbb</span></div>')
	width := (probe.get_element_by_id('m') or { panic('probe') }).get_bounding_client_rect().width
	probe.finalize()
	mut document := chromium_break_spaces_layout('<div style="width:${width + 2}px">' +
		'<span id="a">aaaa </span><span id="b">bbbb</span><span id="c"> cccc</span></div>')
	defer { document.finalize() }
	a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
	b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
	c := (document.get_element_by_id('c') or { panic('c') }).get_bounding_client_rect()
	assert b.x == 0, '${b}'
	assert b.y > a.y
	assert c.y == b.y
	// The space stays on the first line and keeps its advance.
	assert a.width > width / 2
}
