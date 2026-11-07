module layout

import html

// Brave 156: GitHub's inline code has 5.44px horizontal padding. When the
// code wraps, box-decoration-break: slice gives the first line no end padding
// and the continuation no start padding; its background starts at the line
// start instead of 5.44px before it.
fn test_wrapped_inline_padding_is_sliced_at_line_breaks() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}p{width:220px;margin:0 20px;font:16px/24px Arial}
		code{padding:2px 6px;background:rgb(200,200,200);font:13px Menlo}
	</style><p>Run this text with <code>v -cc msvc file.v</code> please.</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	fills := commands.filter(it.kind == 'fill_rect' && it.color.contains('200'))
	assert fills.len == 2, commands.map(it.kind).str()
	texts := commands.filter(it.kind == 'draw_text' && it.text.contains('msvc'))
	assert texts.len == 1
	// The first line's box ends with its text.
	assert fills[0].x + fills[0].width <= texts[0].x + texts[0].width + 1, '${fills[0].x} ${fills[0].width} ${texts[0].x} ${texts[0].width}'
	// The continuation starts at the line's content edge.
	assert fills[1].x == 20, '${fills[1].x}'
}
