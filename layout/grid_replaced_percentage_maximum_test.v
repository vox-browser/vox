module layout

import dom
import html

fn replaced_maximum_grid_columns(document &dom.Document, id string) []f64 {
	element := document.get_element_by_id(id) or { panic(id) }
	node := element.as_node().layout_node() or { panic('missing layout for ${id}') }
	return node.used_grid_data().columns
}

// Ladybird 6cdf1dac5dd5ef7ac5b385a0077e4647dc18d9ad.
fn test_replaced_grid_percentage_maximum_caps_only_the_min_content_inner_size() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}.grid{display:grid;width:400px;grid-template-columns:min-content 1fr}
		canvas{display:block;width:200px;height:50px;max-width:100%}
		#outer{display:grid;width:1400px;grid-template-columns:1fr 1fr}
		#nested{display:grid;grid-template-columns:repeat(6,1fr)}
		#nested canvas{width:1274px;height:auto;grid-column:1 / 7}
		#margins canvas{margin-inline:50px}
		#border canvas{box-sizing:border-box;padding:10px;max-width:calc(100px + 50%)}
		#maximum{grid-template-columns:max-content 1fr}
		#nonreplaced .item{width:200px;height:50px;max-width:100%}
		#rows{display:grid;grid-template-rows:min-content 1fr;width:200px;height:300px}
		#rows canvas{width:100px;max-height:100%}
	</style>
	<div id="outer"><div><div id="nested"><canvas width="1274" height="728"></canvas></div></div><div></div></div>
	<div class="grid" id="margins"><canvas width="200" height="50"></canvas><div></div></div>
	<div class="grid" id="border"><canvas width="200" height="50"></canvas><div></div></div>
	<div class="grid" id="maximum"><canvas width="200" height="50"></canvas><div></div></div>
	<div class="grid" id="nonreplaced"><div class="item"></div><div></div></div>
	<div id="rows"><canvas width="100" height="50"></canvas><div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	assert replaced_maximum_grid_columns(document, 'outer') == [700.0, 700.0]
	assert replaced_maximum_grid_columns(document, 'margins') == [100.0, 300.0]
	assert replaced_maximum_grid_columns(document, 'border') == [100.0, 300.0]
	assert replaced_maximum_grid_columns(document, 'maximum') == [200.0, 200.0]
	assert replaced_maximum_grid_columns(document, 'nonreplaced') == [200.0, 200.0]
	rows := (document.get_element_by_id('rows') or { panic('rows') }).as_node().layout_node() or { panic('rows layout') }
	assert rows.used_grid_data().rows == [50.0, 250.0]
}
