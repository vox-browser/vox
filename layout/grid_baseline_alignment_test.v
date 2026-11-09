module layout

import html

fn test_grid_first_and_last_baselines_share_rows_and_synthesize_orthogonal_items() {
	for preference,expected in {'first':[10.0,0.0,20.0],'last':[40.0,20.0,70.0]} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-auto-flow:column;grid-template-rows:120px;align-items:${preference} baseline;width:200px;line-height:0}span{display:inline-block;width:1em;height:1em}#a{font-size:20px;margin-bottom:20px;padding-bottom:20px}#b{font-size:30px}#c{font-size:10px;writing-mode:vertical-lr}</style><div id="grid"><div id="a"><span></span><br><span></span></div><div id="b"><span></span><br><span></span></div><div id="c"><span></span><br><span></span></div></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document,800,600)
		for index,id in ['a','b','c'] {
			actual := (document.get_element_by_id(id) or { panic(id) }).get_bounding_client_rect().y
			assert actual == expected[index], '${preference} ${id}: ${actual}'
		}
	}
}

fn test_grid_uses_first_and_last_flex_content_baselines() {
	for preference,expected in {'first':5.0,'last':25.0} {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-auto-flow:column;align-items:${preference} baseline;width:200px;line-height:0;font-size:20px}span{display:inline-block;width:1em;height:1em}#inner{display:flex;border:5px solid;padding:10px}</style><div id="grid"><div id="a"><span></span></div><div id="inner"><div style="font-size:10px"><span></span></div><div style="font-size:30px"><span></span></div></div></div>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document,800,600)
		assert (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().y == expected
	}
}

fn test_grid_nested_baselines_prefer_shared_track_and_visual_flex_order() {
 for reverse,expected in {'row':5.0,'row-reverse':25.0,'column':5.0,'column-reverse':25.0} {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid;grid-auto-flow:column;align-items:first baseline;width:200px;line-height:0;font-size:20px}span{display:inline-block;width:1em;height:1em}#inner{display:flex;flex-direction:${reverse};border:5px solid;padding:10px}</style><div id="grid"><div id="a"><span></span></div><div id="inner"><div style="font-size:10px"><span></span></div><div style="font-size:30px"><span></span></div></div></div>')
  defer { document.finalize() }
  _ = layout_document_typed_in_viewport(document,800,600)
  assert (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().y == expected, reverse
 }
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{display:grid;grid-auto-flow:column;align-items:first baseline;line-height:0;font-size:20px}span{display:inline-block;width:1em;height:1em}#inner{display:grid;grid-template-columns:50px 50px 50px;align-items:first baseline;border:5px solid;padding:10px}#first{align-self:start}</style><div id="outer"><div id="a"><span></span></div><div id="inner"><div id="first"><span></span></div><div style="font-size:10px"><span></span></div><div style="font-size:30px"><span></span></div></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 assert (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().y == 25.0
}
