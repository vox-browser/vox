module layout

import dom
import html

fn column_measurement_find(root &Node, id string) ?&Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := column_measurement_find(child, id) { return found }
	}
	return none
}

fn test_constrained_column_avoids_max_content_probe_without_changing_measures() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		for collapse in ['separate', 'collapse'] {
			for sizing in ['content-box', 'border-box'] {
				mut document := html.parse_document('<!doctype html><style>
					table{border-collapse:${collapse};border-spacing:0}
					td{width:40px;min-width:30px;max-width:20px;padding:3px;border:2px solid;box-sizing:${sizing}}
				</style><table><tr><td id="cell">alpha beta gamma delta</td></tr></table>')
				document.set_font_rendering_policy(policy)
				result := run_document_layout(document, 800, 600) or { panic('layout') }
				cell := column_measurement_find(result.root, 'cell') or { panic('cell') }
				mut box := cell.as_box() or { panic('box') }
				mut state := result.state
				box.reset_cached_intrinsic_sizes()
				first := table_cell_intrinsic_width_measures(mut state, cell, collapse == 'collapse', true, false, CSSPixels.new(800))
				assert box.cached_intrinsic_sizes().min_content_width != none
				assert box.cached_intrinsic_sizes().max_content_width == none
				assert first.outer_max_width.raw_value() >= first.outer_min_width.raw_value()
				_ = calculate_max_content_width(mut state, box)
				assert box.cached_intrinsic_sizes().max_content_width != none
				warmed := table_cell_intrinsic_width_measures(mut state, cell, collapse == 'collapse', true, false, CSSPixels.new(800))
				assert first == warmed
				document.finalize()
			}
		}
	}
}

fn test_unconstrained_column_keeps_both_intrinsic_widths() {
	mut document := html.parse_document('<!doctype html><table><tr><td id="cell" style="padding:0">alpha beta gamma delta</td></tr></table>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	cell := column_measurement_find(result.root, 'cell') or { panic('cell') }
	mut box := cell.as_box() or { panic('box') }
	mut state := result.state
	box.reset_cached_intrinsic_sizes()
	measures := table_cell_intrinsic_width_measures(mut state, cell, false, false, false, CSSPixels.new(800))
	assert box.cached_intrinsic_sizes().min_content_width != none
	assert box.cached_intrinsic_sizes().max_content_width != none
	assert measures.outer_max_width.raw_value() > measures.outer_min_width.raw_value()
}

fn test_fixed_column_keeps_specified_width_without_intrinsic_probes() {
	mut document := html.parse_document('<!doctype html><table style="table-layout:fixed;width:200px"><tr><td id="cell" style="width:40px;padding:0">alpha beta gamma delta</td></tr></table>')
	defer { document.finalize() }
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	cell := column_measurement_find(result.root, 'cell') or { panic('cell') }
	mut box := cell.as_box() or { panic('box') }
	mut state := result.state
	box.reset_cached_intrinsic_sizes()
	measures := table_cell_intrinsic_width_measures(mut state, cell, false, true, true, CSSPixels.new(800))
	assert measures.outer_min_width.to_double() == 40
	assert measures.outer_max_width.to_double() == 40
	assert box.cached_intrinsic_sizes().min_content_width == none
	assert box.cached_intrinsic_sizes().max_content_width == none
}
