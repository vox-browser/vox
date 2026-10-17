module layout

import html

fn chromium_colspan_find(root &Node, class_name string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('class') == class_name {
				return root
			}
		}
	}
	for child in root.children() {
		if found := chromium_colspan_find(child, class_name) {
			return found
		}
	}
	return none
}

fn chromium_colspan_cell_widths(chromium bool) []f64 {
	mut document := html.parse_document('<!doctype html><style>body { margin:0; font:11px Arial }
		table { width:468px; margin:auto; border-spacing:1px } td { padding:0; vertical-align:top }
		.rule { width:468px; max-width:100%; border:none; border-top:1px solid; height:0 }
		.date { width:50px }</style>
		<table><thead><tr><td colspan="2"><hr class="rule"></td></tr></thead>
		<tbody><tr><td class="date">08/21/20</td><td class="content">New boards added</td></tr></tbody>
		</table>')
	if chromium {
		document.set_font_rendering_policy(.chromium)
	}
	result := run_document_layout(document, 1024, 600) or { panic('layout failed') }
	mut widths := []f64{}
	for class_name in ['date', 'content'] {
		node := chromium_colspan_find(result.root, class_name) or { panic('missing .${class_name}') }
		styled := node.as_node_with_style() or { panic('.${class_name} has no style') }
		used := result.used_values_for(styled) or { panic('.${class_name} has no used values') }
		widths << used.border_box_width().to_double()
	}
	return widths
}

// 4chan's blotter: a full-width rule spanning both columns. Blink grows the
// auto column beyond its maximum before touching the 50px fixed column.
fn test_chromium_colspan_excess_grows_auto_columns_before_fixed_columns() {
	assert chromium_colspan_cell_widths(true) == [50.0, 417.0]
	// LibWeb distributes the spanning cell in proportion to the column maxima.
	assert chromium_colspan_cell_widths(false)[0] > 50
}
