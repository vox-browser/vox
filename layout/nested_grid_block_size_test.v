module layout

import css
import dom
import html

fn nested_grid_test_rect(document &dom.Document, id string) dom.Rect {
	element := css.query_selector(document.as_node(), '#${id}') or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

fn test_auto_grid_rows_include_a_block_childs_nested_grid_height() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}.outer{display:grid;width:600px;gap:18px;align-items:start}
			.body{display:grid;grid-template-columns:1fr 1fr;gap:18px}
			.card{padding:30px;border:1px solid black}
		</style><div class="outer" id="outer">
			<div><div class="body" id="first"><div class="card"><div style="height:140px"></div></div><div class="card"><div style="height:80px"></div></div></div></div>
			<div><div class="body" id="second"><div class="card"><div style="height:60px"></div></div><div class="card"><div style="height:40px"></div></div></div></div>
		</div><div id="footer" style="height:20px"></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert nested_grid_test_rect(document, 'first').height == 202
		assert nested_grid_test_rect(document, 'second').y == 220
		assert nested_grid_test_rect(document, 'second').height == 122
		assert nested_grid_test_rect(document, 'outer').height == 342
		assert nested_grid_test_rect(document, 'footer').y == 342
	}
}
