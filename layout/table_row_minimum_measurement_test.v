module layout

import html

fn row_minimum_find(root &Node, id string) ?&Node {
	if node := root.dom_node() {
		if element := node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := row_minimum_find(child, id) { return found }
	}
	return none
}

fn test_chromium_minimum_only_cell_height_preserves_box_model_constraints() {
	for doctype in ['<!doctype html>', ''] {
		for sizing in ['content-box', 'border-box'] {
			for collapse in ['separate', 'collapse'] {
				mut document := html.parse_document('${doctype}<style>
					table{border-collapse:${collapse};border-spacing:0}
					td{height:40px;min-height:20px;padding:3px;border:2px solid;box-sizing:${sizing}}
				</style><table><tr><td id="cell"><div style="height:30px;width:25px"></div></td></tr></table>')
				document.set_font_rendering_policy(.chromium)
				result := run_document_layout(document, 800, 600) or { panic('layout') }
				cell := row_minimum_find(result.root, 'cell') or { panic('cell') }
				mut box := cell.as_box() or { panic('box') }
				mut state := result.state
				box.reset_cached_intrinsic_sizes()
				minimum := table_cell_intrinsic_height_measures(mut state, cell, collapse == 'collapse', false, CSSPixels.new(0), false)
				cache := box.cached_intrinsic_sizes()
				assert cache.min_content_width == none && cache.max_content_width == none
				assert cache.min_content_height_ == unsafe { nil }
				assert cache.max_content_height_ == unsafe { nil }
				full := table_cell_intrinsic_height_measures(mut state, cell, collapse == 'collapse', false, CSSPixels.new(0), true)
				assert minimum.outer_min_height == full.outer_min_height
				assert minimum.outer_specified_height == full.outer_specified_height
				assert box.cached_intrinsic_sizes().max_content_height_ != unsafe { nil }
				if collapse == 'separate' {
					expected_minimum := if sizing == 'border-box' { 20.0 } else { 30.0 }
					expected_specified := if sizing == 'border-box' || doctype == '' { 40.0 } else { 50.0 }
					assert minimum.outer_min_height.to_double() == expected_minimum
					assert minimum.outer_specified_height.to_double() == expected_specified
				}
				document.finalize()
			}
		}
	}
}

fn test_chromium_nonspanning_rows_leave_intrinsic_heights_unmeasured() {
	mut document := html.parse_document('<!doctype html><style>
		table{border-spacing:0}td{height:40px;min-height:20px;padding:3px;border:2px solid}
	</style><table id="table"><tr><td><div style="height:30px">first</div></td><td>second</td></tr>
	<tr><td>third</td><td>fourth</td></tr></table>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	table := row_minimum_find(result.root, 'table') or { panic('table') }
	mut rows := []&Node{}
	collect_typed_table_rows(table, mut rows)
	placements, _ := calculate_table_cell_placements(rows)
	for placement in placements {
		mut box := placement.cell.as_box() or { panic('cell') }
		box.reset_cached_intrinsic_sizes()
	}
	mut state := result.state
	heights := compute_table_row_minimum_heights(mut state, rows, placements, false, CSSPixels.new(0), CSSPixels.new(0))
	assert heights == [CSSPixels.new(50), CSSPixels.new(50)]
	for placement in placements {
		mut box := placement.cell.as_box() or { panic('cell') }
		cache := box.cached_intrinsic_sizes()
		assert cache.min_content_width == none && cache.max_content_width == none
		assert cache.min_content_height_ == unsafe { nil }
		assert cache.max_content_height_ == unsafe { nil }
	}
}

fn test_chromium_spanning_rows_keep_complete_intrinsic_height_measures() {
	mut document := html.parse_document('<!doctype html><style>table{border-spacing:0}td{padding:0}</style>
	<table id="table"><tr><td rowspan="2" style="min-height:80px"><div style="height:60px">span</div></td>
	<td><div style="height:20px">first</div></td></tr><tr><td><div style="height:30px">second</div></td></tr></table>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	table := row_minimum_find(result.root, 'table') or { panic('table') }
	mut rows := []&Node{}
	collect_typed_table_rows(table, mut rows)
	placements, _ := calculate_table_cell_placements(rows)
	assert placements[0].row_span == 2
	for placement in placements {
		mut box := placement.cell.as_box() or { panic('cell') }
		box.reset_cached_intrinsic_sizes()
	}
	mut state := result.state
	heights := compute_table_row_minimum_heights(mut state, rows, placements, false, CSSPixels.new(0), CSSPixels.new(0))
	assert heights[0].plus(heights[1]).to_double() >= 80
	for placement in placements {
		mut box := placement.cell.as_box() or { panic('cell') }
		assert box.cached_intrinsic_sizes().max_content_height_ != unsafe { nil }
	}
}

fn test_libweb_minimum_only_measurement_keeps_content_height() {
	mut document := html.parse_document('<!doctype html><table><tr><td id="cell" style="padding:0"><div style="height:30px">content</div></td></tr></table>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.libweb)
	result := run_document_layout(document, 800, 600) or { panic('layout') }
	cell := row_minimum_find(result.root, 'cell') or { panic('cell') }
	mut box := cell.as_box() or { panic('box') }
	box.reset_cached_intrinsic_sizes()
	mut state := result.state
	minimum := table_cell_intrinsic_height_measures(mut state, cell, false, false, CSSPixels.new(0), false)
	assert minimum.outer_min_height.to_double() == 30
	assert box.cached_intrinsic_sizes().max_content_height_ != unsafe { nil }
}
