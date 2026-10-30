module layout

import dom
import html

fn unchanged_grid_item_rect(document &dom.Document, id string) dom.Rect {
	element := document.get_element_by_id(id) or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

fn test_unchanged_grid_item_height_preserves_nested_auto_rows_and_live_resizing() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}#outer{display:grid;width:300px}
			#inner{display:grid;grid-template-columns:1fr 2fr;gap:10px}
			#first{height:40px}#second{height:60px}#third{height:20px}
		</style><div id="outer"><div id="inner"><div id="first"></div><div id="second"></div><div id="third"></div></div></div><div id="after"></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert unchanged_grid_item_rect(document, 'inner').height == 90
		assert unchanged_grid_item_rect(document, 'third').y == 70
		assert unchanged_grid_item_rect(document, 'after').y == 90
		mut second := document.get_element_by_id('second') or { panic('missing second') }
		second.set_attribute_value('style', 'height:80px')
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert unchanged_grid_item_rect(document, 'inner').height == 110
		assert unchanged_grid_item_rect(document, 'third').y == 90
		assert unchanged_grid_item_rect(document, 'after').y == 110
	}
}

fn test_unchanged_grid_item_height_still_resolves_percentage_descendants() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}#outer{display:grid;width:200px;grid-template-rows:100px}
			#fixed{height:100px}#percentage{height:50%}
		</style><div id="outer"><div id="item"><div id="fixed"></div><div id="percentage"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert unchanged_grid_item_rect(document, 'item').height == 100
		assert unchanged_grid_item_rect(document, 'percentage').y == 100
		assert unchanged_grid_item_rect(document, 'percentage').height == 50
	}
}

fn test_unchanged_grid_item_height_still_resolves_percentage_row_gaps() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}#outer{display:grid;width:200px;grid-template-rows:80px}
			#inner{display:grid;row-gap:10%}.child{height:40px}
		</style><div id="outer"><div id="inner"><div class="child"></div><div class="child" id="second"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert unchanged_grid_item_rect(document, 'inner').height == 80
		assert unchanged_grid_item_rect(document, 'second').y == 48
	}
}

fn test_changed_grid_item_height_still_realigns_nested_flex_contents() {
	for chromium in [false, true] {
		mut document := html.parse_document('<!doctype html><style>
			html,body{margin:0}#outer{display:grid;width:200px;grid-template-rows:100px}
			#item{display:flex;align-items:center}#child{height:40px;width:40px}
		</style><div id="outer"><div id="item"><div id="child"></div></div></div>')
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		_ = layout_document_typed_in_viewport(document, 800, 600)
		assert unchanged_grid_item_rect(document, 'item').height == 100
		assert unchanged_grid_item_rect(document, 'child').y == 30
	}
}
