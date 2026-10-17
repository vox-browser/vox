module layout

import css
import html

// 4chan's post header: Blink can wrap the text after the thread status icon,
// even though it starts with a no-break space glued to the following text.
fn test_chromium_text_can_wrap_after_an_atomic_inline() {
	for chromium in [true, false] {
		for following in ['<span id="after">&nbsp;[Reply]</span>', '<span id="after">[Reply]</span>',
			'<span id="after">,Reply</span>', '&nbsp;<span id="after">[Reply]</span>'] {
			mut document := html.parse_document('<!doctype html><style>
				body { margin:0; font:10px/12px monospace }
				#container { width:80px }
				#icon { display:inline-block; width:16px; height:12px; vertical-align:top }
			</style><div id="container">abcdef<span id="icon"></span>${following}</div>')
			if chromium {
				document.set_font_rendering_policy(.chromium)
			}
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document, 200, 100)
			icon := css.query_selector(document.as_node(), '#icon') or { panic('icon missing') }
			after := css.query_selector(document.as_node(), '#after') or { panic('text missing') }
			assert icon.get_bounding_client_rect().y == 0
			// LibWeb keeps the following text on the overflowing first line.
			y := after.get_bounding_client_rect().y
			assert (y == 12) == chromium, 'chromium=${chromium} ${following} y=${y}'
		}
	}
}
