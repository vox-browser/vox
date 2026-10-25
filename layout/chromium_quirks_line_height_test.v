module layout

import html

// HN has no doctype. Its small comment headers and reply links must not
// inherit the larger block's minimum line box, unlike standards documents.
fn test_chromium_quirks_lines_use_inline_content_metrics() {
	for doctype in ['', '<!doctype html>'] {
		mut document := html.parse_document(doctype + '<style>
			body{margin:0}div{font:40px/40px sans-serif}
			span{font:10px/12px sans-serif}
		</style><div id="line"><span>reply</span></div><div id="break"><br></div>')
		document.set_font_rendering_policy(.chromium)
		run_document_layout(document, 800, 600) or { panic('layout') }
		line := document.get_element_by_id('line') or { panic('line') }
		assert line.get_bounding_client_rect().height == if doctype == '' { 12.0 } else { 40.0 }
		line_break := document.get_element_by_id('break') or { panic('break') }
		assert line_break.get_bounding_client_rect().height == 40.0
		document.finalize()
	}
}
