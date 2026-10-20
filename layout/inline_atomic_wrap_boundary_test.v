module layout

import css
import html

fn test_nowrap_atomic_inline_does_not_force_the_preceding_word_onto_its_line() {
	for parent_wrap in ['normal', 'nowrap'] {
		mut document := html.parse_document('<!doctype html><style>
			body { margin:0 }
			#container { width:50px; font:10px/12px monospace; white-space:${parent_wrap} }
			#badge { display:inline-block; width:30px; height:12px; vertical-align:top; white-space:nowrap }
			#reference { font:10px/12px monospace; white-space:nowrap }
		</style><div id="container"><span id="text">ab cd</span><span id="badge">badge</span></div><span id="reference">ab cd</span>')
		document.set_font_rendering_policy(.chromium)
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 100, 100)
		text := css.query_selector(document.as_node(), '#text') or { panic('text missing') }
		badge := css.query_selector(document.as_node(), '#badge') or { panic('badge missing') }
		reference := css.query_selector(document.as_node(), '#reference') or { panic('reference missing') }
		assert text.get_bounding_client_rect().height == reference.get_bounding_client_rect().height
		assert badge.get_bounding_client_rect().y == if parent_wrap == 'normal' {
			f64(12)
		} else {
			f64(0)
		}
	}
}
