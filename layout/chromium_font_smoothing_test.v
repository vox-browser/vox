module layout

import html

fn font_smoothing_test_commands(markup string) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}</style>' + markup)
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 300)
	return display_list_commands(document.record_display_list() or { panic('paint') })
}

// Brave 156 rasterizes text-rendering: geometricPrecision exactly like
// -webkit-font-smoothing: antialiased (unhinted, unsmoothed). shields.io
// badges set it on their SVG labels.
fn test_chromium_geometric_precision_text_is_unsmoothed() {
	commands := font_smoothing_test_commands('<p style="text-rendering:geometricPrecision">Text</p>' +
		'<p>Text</p><svg width="100" height="40"><text x="5" y="20" text-rendering="geometricPrecision">OO</text></svg>')
	texts := commands.filter(it.kind == 'draw_text')
	assert texts.len == 3, commands.map(it.kind).str()
	assert texts[0].font_smoothing == .antialiased
	assert texts[1].font_smoothing == .auto_
	assert texts[2].font_smoothing == .antialiased
}
