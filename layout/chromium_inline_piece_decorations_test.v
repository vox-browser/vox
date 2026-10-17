module layout

import css
import html

// A decorated inline box whose content is nested inline boxes paints its
// background across the whole box, as Blink paints the box fragment.
fn test_chromium_inline_background_spans_nested_inline_boxes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:13px Helvetica}#o{background:rgb(9 8 7);padding:0 8px}</style><div><span id="o"><b>one</b> <i>two</i></span></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 400, 100)
	outer := css.query_selector(document.as_node(), '#o') or { panic('missing outer') }
	box := outer.get_bounding_client_rect()
	list := document.record_display_list() or { panic('missing display list') }
	mut widest := 0.0
	for command in display_list_commands(list) {
		if command.kind == 'fill_rect' && command.color == 'rgb(9 8 7)' && command.width > widest {
			widest = command.width
		}
	}
	assert widest >= box.width - 1 && widest <= box.width + 1
}
