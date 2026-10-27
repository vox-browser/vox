module layout

import css
import dom
import html

$if gcboehm ? {
	fn C.GC_size(voidptr) uint
	fn C.GC_base(voidptr) voidptr
	fn C.GC_get_total_bytes() uint
}

fn test_layout_grid_data_defaults_and_empty_updates_do_not_allocate_payloads() {
	mut node := &dom.LayoutNode{}
	assert node.used_grid_data_ == unsafe { nil }
	assert node.used_grid_data() == dom.LayoutGridData{}
	node.set_used_grid_data(dom.LayoutGridData{})
	assert node.used_grid_data_ == unsafe { nil }
	assert sizeof(dom.LayoutNode) <= 768
	$if gcboehm ? {
		before := C.GC_get_total_bytes()
		for _ in 0 .. 32 {
			node.set_used_grid_data(dom.LayoutGridData{})
			data := node.used_grid_data()
			if data.columns.len != 0 || data.rows.len != 0 { panic('unexpected tracks') }
		}
		after := C.GC_get_total_bytes()
		assert after == before
		allocated := C.GC_size(voidptr(node))
		println('layout_node_bytes=${sizeof(dom.LayoutNode)} managed_allocation_bytes=${allocated} grid_payload_bytes=${sizeof(dom.LayoutGridData)}')
		assert allocated <= 1024
	}
}

fn test_layout_grid_data_replacement_preserves_value_copies_and_live_aliases() {
	mut node := &dom.LayoutNode{}
	node.set_used_grid_data(dom.LayoutGridData{
		columns: [100.0, 200.0]
		rows: [20.0]
		column_line_names: [['a'], ['b'], ['c']]
		row_line_names: [['r1'], ['r2']]
	})
	$if gcboehm ? {
		assert C.GC_base(voidptr(node.used_grid_data_)) == voidptr(node.used_grid_data_)
	}
	mut snapshot := *node
	mut alias := node
	alias.set_used_grid_data(dom.LayoutGridData{ columns: [12.0] })
	assert node.used_grid_data().columns == [12.0]
	assert snapshot.used_grid_data().columns == [100.0, 200.0]
	assert snapshot.used_grid_data().rows == [20.0]
	assert snapshot.used_grid_data().column_line_names == [['a'], ['b'], ['c']]
	assert snapshot.used_grid_data().row_line_names == [['r1'], ['r2']]
	snapshot.set_used_grid_data(dom.LayoutGridData{})
	assert snapshot.used_grid_data_ == unsafe { nil }
	assert node.used_grid_data().columns == [12.0]
	alias.set_used_grid_data(dom.LayoutGridData{})
	assert node.used_grid_data_ == unsafe { nil }
}

fn test_layout_grid_data_keeps_existing_nested_array_alias_semantics() {
	mut columns := [13.0, 21.0]
	mut names := [['first'], ['last']]
	mut node := &dom.LayoutNode{}
	node.set_used_grid_data(dom.LayoutGridData{columns: columns, column_line_names: names})
	snapshot := *node
	columns[0] = 34.0
	names[0][0] = 'updated'
	assert snapshot.used_grid_data().columns == [34.0, 21.0]
	assert node.used_grid_data().column_line_names == [['updated'], ['last']]
}

fn test_layout_grid_data_retains_subgrid_and_line_name_only_records() {
	mut node := &dom.LayoutNode{}
	node.set_used_grid_data(dom.LayoutGridData{columns_are_subgrid: true})
	assert node.used_grid_data_ != unsafe { nil }
	assert node.used_grid_data().columns_are_subgrid
	assert !node.used_grid_data().rows_are_subgrid
	node.set_used_grid_data(dom.LayoutGridData{rows_are_subgrid: true})
	assert !node.used_grid_data().columns_are_subgrid
	assert node.used_grid_data().rows_are_subgrid
	node.set_used_grid_data(dom.LayoutGridData{row_line_names: [['only']]})
	assert node.used_grid_data_ != unsafe { nil }
	assert node.used_grid_data().row_line_names == [['only']]
	assert !node.used_grid_data().rows_are_subgrid
}

fn test_dom_grid_bridge_resolved_tracks_follow_live_layout_and_keep_value_snapshots() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#grid{display:grid;width:300px;grid-template-columns:[a] 1fr [b] 2fr [c];grid-template-rows:[r1] 20px [r2]}</style><div id="grid"><i></i><i></i></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	mut grid := document.get_element_by_id('grid') or { panic('missing grid') }
	initial_node := grid.as_node().layout_node() or { panic('missing grid layout') }
	snapshot := *initial_node
	assert snapshot.used_grid_data().columns == [100.0, 200.0]
	assert snapshot.used_grid_data().rows == [20.0]
	resolved := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(grid, none))
	assert resolved.get_property_value('grid-template-columns') == '[a] 100px [b] 200px [c]'
	assert resolved.get_property_value('grid-template-rows') == '[r1] 20px [r2]'
	grid.set_attribute_value('style', 'width:450px')
	_ = layout_document_typed_in_viewport(document, 800, 600)
	assert resolved.get_property_value('grid-template-columns') == '[a] 150px [b] 300px [c]'
	assert snapshot.used_grid_data().columns == [100.0, 200.0]
	grid.set_attribute_value('style', 'display:block;grid-template-columns:none;grid-template-rows:none')
	_ = layout_document_typed_in_viewport(document, 800, 600)
	current := grid.as_node().layout_node() or { panic('missing block layout') }
	assert current.used_grid_data_ == unsafe { nil }
	assert resolved.get_property_value('grid-template-columns') == 'none'
	assert resolved.get_property_value('grid-template-rows') == 'none'
}

fn test_dom_grid_bridge_reusing_a_placeholder_discards_retired_grid_payload() {
	mut placeholder := &dom.LayoutNode{}
	mut grid := &UsedValues{}
	grid.set_grid_template_columns([CSSPixels.new(40), CSSPixels.new(80)])
	grid.set_grid_template_rows([CSSPixels.new(12)])
	grid.set_grid_line_names([['start'], ['middle'], ['end']], [][]string{})
	copy_used_box_model_to_dom_layout_node(mut placeholder, grid)
	snapshot := *placeholder
	assert snapshot.used_grid_data().columns == [40.0, 80.0]
	assert snapshot.used_grid_data().column_line_names == [['start'], ['middle'], ['end']]
	copy_used_box_model_to_dom_layout_node(mut placeholder, &UsedValues{})
	assert placeholder.used_grid_data_ == unsafe { nil }
	assert snapshot.used_grid_data().columns == [40.0, 80.0]
	assert snapshot.used_grid_data().rows == [12.0]
}
