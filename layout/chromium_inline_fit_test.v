module layout

import css
import html

fn test_chromium_fractional_max_content_text_does_not_emergency_wrap() {
	for text in ['N. America', 'S. America', 'Middle East', 'Other Subs:'] {
		mut document := html.parse_document('<!doctype html><style>#chip{width:max-content;font:13.333333px Verdana;line-height:20px;overflow-wrap:break-word}</style><div id="chip">${text}</div>')
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 320, 100)
		chip := css.query_selector(document.as_node(), '#chip') or { panic('chip missing') }
		assert chip.get_bounding_client_rect().height == 20
	}
}
