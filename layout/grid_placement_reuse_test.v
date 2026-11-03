module layout

import css
import html
import platform

fn grid_placement_test_node(root &Node, id string) ?&Node {
	if owner := root.dom_node() {
		if element := owner.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := grid_placement_test_node(child, id) { return found }
	}
	return none
}

fn assert_grid_sizing_placements_match(actual []GridItemPlacement, expected []GridItemPlacement) {
	assert actual.len == expected.len
	for index, value in actual {
		oracle := expected[index]
		assert voidptr(value.item) == voidptr(oracle.item)
		assert value.row == oracle.row && value.column == oracle.column
		assert value.row_span == oracle.row_span && value.column_span == oracle.column_span
		assert value.inline_start_extra == oracle.inline_start_extra
		assert value.inline_end_extra == oracle.inline_end_extra
		assert value.block_start_extra == oracle.block_start_extra
		assert value.block_end_extra == oracle.block_end_extra
	}
}

fn test_grid_sizing_placement_reuse_preserves_spans_implicit_tracks_and_axis_extras() {
	for contents in [
		'<div style="grid-column:1 / span 2">spanning text</div><div>other text</div>',
		'<div style="grid-row:1 / span 2">row span</div><div style="grid-column:-4">implicit</div>',
		'<div style="display:flex"><span>flex text</span></div><img width="50" height="30">',
	] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:100px 100px;grid-template-rows:auto auto;gap:7px;grid-auto-flow:dense">${contents}</section>')
		defer { document.finalize() }
		result := run_document_layout(document, 400, 300)?
		grid := grid_placement_test_node(result.root, 'grid')?
		lines := [][]css.GridLineName{len: 3}
		mut placements := place_grid_items(grid, lines, lines, false, false).placements
		assert placements.len > 0
		placements[0].inline_start_extra = CSSPixels.new(3)
		placements[0].block_end_extra = CSSPixels.new(5)
		for columns in [true, false] {
			mut oracle_state := LayoutState.new()
			mut expected := []GridItemPlacement{}
			collect_grid_track_sizing_placements(mut oracle_state, grid, placements, lines, lines,
				columns, CSSPixels.new(7), 0, mut expected)
			mut actual_state := LayoutState.new()
			actual := grid_track_sizing_placements(mut actual_state, grid, placements, lines, lines,
				columns, CSSPixels.new(7))
			assert_grid_sizing_placements_match(actual, expected)
			assert (actual.data == placements.data) == !retain_grid_placement_copies
		}
	}
}

fn test_grid_sizing_placement_reuse_projects_subgrids_only_in_the_requested_axis() {
	for axis in ['columns', 'rows', 'both'] {
		columns_css := if axis in ['columns', 'both'] {
			'grid-template-columns:subgrid;'
		} else {
			''
		}
		rows_css := if axis in ['rows', 'both'] { 'grid-template-rows:subgrid;' } else { '' }
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:100px 100px;grid-template-rows:70px 80px;gap:7px"><article style="display:grid;${columns_css}${rows_css}grid-column:1 / span 2;grid-row:1 / span 2;padding:5px;margin:3px;gap:9px"><p>first</p><p>second</p></article></section>')
		defer { document.finalize() }
		result := run_document_layout(document, 400, 300)?
		grid := grid_placement_test_node(result.root, 'grid')?
		lines := [][]css.GridLineName{len: 3}
		placements := place_grid_items(grid, lines, lines, false, false).placements
		for columns in [true, false] {
			mut oracle_state := LayoutState.new()
			mut expected := []GridItemPlacement{}
			collect_grid_track_sizing_placements(mut oracle_state, grid, placements, lines, lines,
				columns, CSSPixels.new(7), 0, mut expected)
			mut actual_state := LayoutState.new()
			actual := grid_track_sizing_placements(mut actual_state, grid, placements, lines, lines,
				columns, CSSPixels.new(7))
			assert_grid_sizing_placements_match(actual, expected)
			projected := axis == 'both' || (columns && axis == 'columns') || (!columns && axis == 'rows')
			assert (actual.data == placements.data) == (!retain_grid_placement_copies && !projected)
		}
	}
}

fn test_ordinary_grid_sizing_lists_do_not_allocate_on_repeated_queries() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-template-columns:100px 100px"><p>first</p><p>second</p></section>')
	defer { document.finalize() }
	result := run_document_layout(document, 400, 300)?
	grid := grid_placement_test_node(result.root, 'grid')?
	lines := [][]css.GridLineName{len: 3}
	placements := place_grid_items(grid, lines, lines, false, false).placements
	mut state := LayoutState.new()
	before := platform.thread_arena_usage().used
	mut count := 0
	for _ in 0 .. 512 {
		for axis in 0 .. 2 {
			columns := axis == 0
			actual := grid_track_sizing_placements(mut state, grid, placements, lines, lines,
				columns, CSSPixels.new(7))
			count += actual.len
		}
	}
	assert count == 2048
	$if prealloc {
		if !retain_grid_placement_copies {
			assert platform.thread_arena_usage().used - before < 1024
		}
	}
}
