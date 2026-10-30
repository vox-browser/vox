module layout

import css
import dom
import html

fn atomic_multicol_rect(document &dom.Document, id string) dom.Rect {
	element := css.query_selector(document.as_node(), '#${id}') or { panic('missing ${id}') }
	return element.get_bounding_client_rect()
}

fn atomic_multicol_document(heights []int, count int, extra string) &dom.Document {
	mut items := ''
	for index, height in heights {
		items += '<div class="item" id="item${index}" style="height:${height}px"></div>'
	}
	return html.parse_document('<!doctype html><style>
		body{margin:0}#columns{width:500px;columns:${count};column-gap:25px;${extra}}
		.item{break-inside:avoid;margin-bottom:10px}
	</style><div id="columns">${items}</div><div id="after"></div>')
}

// Brave 156: unequal atomic blocks balance to 170px. The 10px margin
// between the fourth and fifth blocks is discarded at the column break.
fn test_multicol_atomic_blocks_balance_without_splitting_items() {
	for rtl in [false, true] {
		mut document := atomic_multicol_document([20, 40, 20, 60, 20, 20, 40], 2,
			if rtl { 'direction:rtl' } else { '' })
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		for index, y in [0.0, 30, 80, 110, 0, 30, 60] {
			rect := atomic_multicol_rect(document, 'item${index}')
			column := if (index < 4) != rtl { 0.0 } else { 262.5 }
			assert rect.x == column
			assert rect.y == y
			assert rect.width == 237.5
		}
		assert atomic_multicol_rect(document, 'columns').height == 170
		assert atomic_multicol_rect(document, 'after').y == 170
	}
}

fn test_multicol_atomic_balance_preserves_flow_end_margin_in_initial_estimate() {
	for count in [2, 3] {
		heights := if count == 2 { [30, 30, 30, 30] } else { [20, 20, 20, 20, 20, 20, 20] }
		xs := if count == 2 { [0.0, 0, 262.5, 262.5] } else { [0.0, 0, 0, 175, 175, 175, 350] }
		ys := if count == 2 { [0.0, 40, 0, 40] } else { [0.0, 30, 60, 0, 30, 60, 0] }
		mut document := atomic_multicol_document(heights, count, '')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		for index in 0 .. heights.len {
			rect := atomic_multicol_rect(document, 'item${index}')
			assert rect.x == xs[index]
			assert rect.y == ys[index]
		}
		assert atomic_multicol_rect(document, 'columns').height == 80
	}
}

fn test_libweb_multicol_blocks_keep_single_column_layout() {
	mut document := atomic_multicol_document([20, 40, 20, 60, 20, 20, 40], 2, '')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	assert atomic_multicol_rect(document, 'columns').height == 290
	assert atomic_multicol_rect(document, 'item4').x == 0
	assert atomic_multicol_rect(document, 'item4').y == 180
}

fn test_multicol_atomic_blocks_contribute_balanced_height_to_ancestor_grid_rows() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}.grid{display:grid;width:500px;gap:18px;align-items:start}
		#columns{columns:2;column-gap:25px}.item{height:30px;margin-bottom:10px;break-inside:avoid}
	</style><div class="grid" id="grid"><div id="parent"><div id="columns">
		<div class="item"></div><div class="item"></div><div class="item"></div><div class="item"></div>
	</div></div><div id="after" style="height:20px"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	assert atomic_multicol_rect(document, 'columns').height == 80
	assert atomic_multicol_rect(document, 'parent').height == 80
	assert atomic_multicol_rect(document, 'after').y == 98
	assert atomic_multicol_rect(document, 'grid').height == 118
}

fn test_multicol_list_items_keep_markers_and_balance_inside_grid_rows() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:15px/30px Arial}.grid{display:grid;width:500px;gap:18px;align-items:start}
		#columns{width:500px;columns:2;column-gap:25px;margin:0;padding-left:17px}
		li{height:30px;margin-bottom:10px;break-inside:avoid}
	</style><div class="grid" id="grid"><div id="parent"><ul id="columns">
		<li id="first">One</li><li>Two</li><li id="third"><b>Three</b></li><li>Four</li>
	</ul></div><div id="after" style="height:20px"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	assert atomic_multicol_rect(document, 'first').x == 17
	assert atomic_multicol_rect(document, 'third').x == 279.5
	assert atomic_multicol_rect(document, 'third').y == 0
	assert atomic_multicol_rect(document, 'columns').height == 80
	assert atomic_multicol_rect(document, 'parent').height == 80
	assert atomic_multicol_rect(document, 'after').y == 98
}
