module layout

import dom
import html

fn test_absolute_viewport_containing_block_uses_retained_viewport_scroll_frame() {
	document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}body{width:1000px;height:1000px}#absolute,#fixed{left:100px;top:90px;width:20px;height:20px}#absolute{position:absolute}#fixed{position:fixed}</style><div id="absolute"></div><div id="fixed"></div>')
	mut window := html.WindowModel.create_top_level(document, none, 'viewport-geometry')!
	_ = layout_document_typed_in_viewport(document, 200, 100)
	absolute := document.get_element_by_id('absolute') or { panic('absolute') }
	fixed := document.get_element_by_id('fixed') or { panic('fixed') }
	_ = window.scroll(html.ScrollToOptions{ left: 40, top: 70, behavior: .instant })
	assert window.scroll_x() == 40 && window.scroll_y() == 70
	assert absolute.get_bounding_client_rect() == dom.Rect{60, 20, 20, 20}
	assert fixed.get_bounding_client_rect() == dom.Rect{100, 90, 20, 20}
	_ = window.scroll(html.ScrollToOptions{ left: 55, top: 80, behavior: .instant })
	assert absolute.get_bounding_client_rect() == dom.Rect{45, 10, 20, 20}
	assert fixed.get_bounding_client_rect() == dom.Rect{100, 90, 20, 20}
}
