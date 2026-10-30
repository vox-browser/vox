module layout

import html

fn table_grid_height_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := table_grid_height_node(child, id) { return found }
	}
	return none
}

fn table_grid_height_used(result DocumentLayoutResult, id string) &UsedValues {
	node := table_grid_height_node(result.root, id) or { panic('missing ${id}') }
	return result.used_values_for(node.as_node_with_style() or { panic('missing style') }) or {
		panic('missing geometry')
	}
}

fn table_grid_height_case(chromium bool, border int, captions bool, authored_border bool) bool {
	rows := '<tr><td>Alpha</td><td>Beta</td><td>Gamma</td></tr>'.repeat(3)
	caption_markup := if captions {
		'<caption>Top</caption><caption style="caption-side:bottom">Bottom</caption>'
	} else {
		''
	}
	table_border := if authored_border { 'border:${border}px solid;' } else { '' }
	mut document := html.parse_document('<!doctype html><style>
				body{margin:0;font:15px/1.65 Arial}
				.grid{display:grid;grid-template-columns:583px 583px;gap:18px}
				.card{display:flow-root;padding:30px;border:1px solid}
				table{border-collapse:collapse;width:100%;font-size:11px;line-height:18.140625px;margin:20px 0;${table_border}}
				td{border:${border}px solid;padding:10px}
				caption{height:20px;line-height:20px;margin:0}
				.control{width:583px;box-sizing:border-box;margin-top:20px}
			</style><div class="grid" id="grid"><div class="card" id="card"><table>${caption_markup}${rows}</table></div>
			<div class="card">Grid control</div></div><div class="card control" id="control"><table>${caption_markup}${rows}</table></div>')
	defer { document.finalize() }
	if chromium { document.set_font_rendering_policy(.chromium) }
	result := run_document_layout(document, 1280, 800) or { panic('missing layout') }
	grid_height := table_grid_height_used(result, 'grid').content_height().to_double()
	card_height := table_grid_height_used(result, 'card').border_box_height().to_double()
	control_height := table_grid_height_used(result, 'control').border_box_height().to_double()
	wanted := (18.140625 + 20 + border) * 3 + border + 40 + 62 + if captions { 40 } else { 0 }
	println('table grid chromium=${chromium} border=${border} captions=${captions} authored=${authored_border} grid=${grid_height} card=${card_height} control=${control_height} expected=${wanted}')
	return grid_height == wanted && card_height == wanted && control_height == wanted
}

fn test_intrinsic_grid_rows_count_table_outer_borders_once() {
	mut matches := true
	for chromium in [true, false] {
		for border in [1, 2, 3] {
			for captions in [false, true] {
				for authored_border in [false, true] {
					if !table_grid_height_case(chromium, border, captions, authored_border) {
						matches = false
					}
				}
			}
		}
	}
	assert matches
}
