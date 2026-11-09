module layout

import html

fn test_flex_distributed_gaps_margins_and_growth_preserve_the_final_edge() {
	for rules in ['justify-content:space-between','', 'align-content:space-between;flex-wrap:wrap;width:10px'] {
		for step in 0 .. 10 {
			auto_margin := if rules == '' { 'margin-left:auto;' } else { '' }
			vertical := rules.contains('align-content')
			width := if vertical { 10.0 } else { 40+f64(step)/10 }
			height := if vertical { 40+f64(step)/10 } else { 10.0 }
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#flex{display:flex;width:${width}px;height:${height}px;${rules}}#flex>div{width:${if vertical { 10 } else { 5 }}px;height:${if vertical { 5 } else { 10 }}px;${auto_margin}}</style><div id="flex">${'<div></div>'.repeat(7)}<div id="last"></div></div>')
			defer { document.finalize() }
			_ = layout_document_typed_in_viewport(document,800,600)
			last := (document.get_element_by_id('last') or { panic('last') }).get_bounding_client_rect()
			flex := (document.get_element_by_id('flex') or { panic('flex') }).get_bounding_client_rect()
			assert if vertical { last.y+last.height == flex.y+flex.height } else { last.x+last.width == flex.x+flex.width }, '${rules} ${step}'
		}
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#flex{display:flex;width:55px}#flex>div{flex-grow:1}</style><div id="flex">${'<div></div>'.repeat(6)}<div id="last"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document,800,600)
	last := (document.get_element_by_id('last') or { panic('last') }).get_bounding_client_rect()
	assert last.x+last.width == 55
}

fn test_wrapping_column_flex_grows_each_line_against_a_definite_max_height() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#flex{display:flex;flex-flow:column wrap;width:150px;max-height:100px}#flex>div{width:50px}</style><div id="flex"><div id="a" style="height:20px;flex-grow:1;max-height:40px"></div><div id="b" style="height:30px;flex-grow:1"></div><div style="height:100px"></div></div>')
 defer { document.finalize() }
 _ = layout_document_typed_in_viewport(document,800,600)
 assert (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect().height == 40
 assert (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect().height == 60
}
