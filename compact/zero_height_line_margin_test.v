module main

import html
import layout

fn test_zero_height_text_line_separates_trailing_margins() {
	for content, expected in {
		'': f64(120)
		'.': f64(130)
		' ': f64(120)
		'<span style="display:inline-block;height:0;width:0"></span>': f64(130)
	} {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;font:13px/19.5px Arial}
			#box{display:flow-root;width:300px}
			#content{height:100px;margin-bottom:20px}
			#footer{margin-bottom:10px}
			#line{font-size:0;line-height:0;height:0}
		</style><div id="box"><div id="content"></div><div id="footer"><div id="line">${content}</div></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		box := document.get_element_by_id('box') or { panic('missing box') }
		actual := box.get_bounding_client_rect().height
		assert actual == expected, content
	}
}
