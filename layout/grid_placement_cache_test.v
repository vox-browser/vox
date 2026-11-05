module layout

import css
import dom
import html
import platform

fn grid_placement_test_root(document &dom.Document, id string) &Node {
	element := document.get_element_by_id(id) or { panic('missing ' + id) }
	return unsafe { &Node(element.as_node().unsafe_layout_node() or { panic('missing layout') }.real_layout_handle()) }
}

fn grid_placement_test_signature(result GridPlacementResult) []string {
	mut signature := ['${result.implicit_columns_before} ${result.implicit_rows_before}']
	for p in result.placements {
		signature << '${u64(voidptr(p.item))} ${p.row} ${p.column} ${p.row_span} ${p.column_span} ${p.inline_start_extra} ${p.inline_end_extra} ${p.block_start_extra} ${p.block_end_extra}'
	}
	return signature
}

fn grid_placement_test_last(state &LayoutState, root &Node) voidptr {
	entries := state.measurement_chunk_pool_.grid_placements_[u64(voidptr(root))] or { return unsafe { nil } }
	return if entries.len > 0 { voidptr(entries.last()) } else { unsafe { nil } }
}

fn grid_placement_test_compare(mut state LayoutState, root &Node,
	columns [][]css.GridLineName, rows [][]css.GridLineName, subcolumns bool, subrows bool) bool {
	before := grid_placement_test_last(state, root)
	actual := place_grid_items_in_state(mut state, root, columns, rows, subcolumns, subrows)
	actual_signature := grid_placement_test_signature(actual)
	expected := place_grid_items(root, columns, rows, subcolumns, subrows)
	assert actual_signature == grid_placement_test_signature(expected)
	after := grid_placement_test_last(state, root)
	return before != unsafe { nil } && before == after
}

fn grid_placement_test_apply_style(mut document dom.Document, node &Node, rules string) {
	mut element := document.create_element('div') or { panic(err) }
	element.set_attribute_value('style', rules)
	mut styled := node.as_node_with_style() or { panic('missing style') }
	styled.apply_style(css.css_style_computer_for(document).compute_style(dom.AbstractElement.new(element, none)))
}

fn test_grid_placement_owns_scratch_lines_and_writable_results_and_restores_item_flags() {
	for flow in ['row', 'row dense', 'column', 'column dense'] {
		mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid;grid-auto-flow:${flow}"><div id="a" style="grid-column:span 2;order:1">a</div><div style="grid-row:2;grid-column:-5">b</div><div style="grid-column:named">c</div><div style="grid-column:span 2">d</div></section>')
		document.enable_native_storage()
		mut owner := document.enter_native_storage()
		defer {
			owner.finish()
			document.finalize()
			document.release_native_storage()
		}
		_ = layout_document_typed_in_viewport(document, 500, 400)
		root := grid_placement_test_root(document, 'grid')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		mut probe := source.new_measurement_for_subtree(root.as_node_with_style()?)
		mut columns := [][]css.GridLineName{len: 4}
		columns[1] = [css.GridLineName{ name: 'named'.clone() }]
		rows := [][]css.GridLineName{len: 3}
		first := place_grid_items_in_state(mut probe, root, columns, rows, false, false)
		mut retained := platform.enter_retained_allocations()
		expected := grid_placement_test_signature(first)
		retained.finish()
		mut writable := unsafe { first.placements }
		writable[0].row = 999
		columns[1][0].name = 'changed'
		probe.release_measurement()
		gc_collect()
		fresh_columns := [[]css.GridLineName{}, [css.GridLineName{ name: 'named' }],
			[]css.GridLineName{}, []css.GridLineName{}]
		mut item := unsafe { &Node(grid_placement_test_root(document, 'a')) }
		item.set_grid_item(false)
		before := grid_placement_test_last(source, root)
		second := place_grid_items_in_state(mut source, root, fresh_columns, [][]css.GridLineName{len: 3}, false, false)
		assert grid_placement_test_signature(second) == expected
		assert item.is_grid_item()
		assert (before != unsafe { nil } && grid_placement_test_last(source, root) == before) == !disable_grid_placement_reuse
		mut second_writable := unsafe { second.placements }
		second_writable[0].row = 888
		third := place_grid_items_in_state(mut source, root, fresh_columns, [][]css.GridLineName{len: 3}, false, false)
		assert grid_placement_test_signature(third) == expected
		pool := source.measurement_chunk_pool_
		source.release_measurement_chunk_pool()
		assert pool.closed && pool.grid_placements_.len == 0
	}
}

fn test_grid_placement_rechecks_child_style_order_position_and_container_flow() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid"><div id="a">a</div><div>b</div><div>c</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_placement_test_root(document, 'grid')
	item := grid_placement_test_root(document, 'a')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	columns := [][]css.GridLineName{len: 4}
	rows := [][]css.GridLineName{len: 3}
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	for rules in ['display:block;order:2', 'display:block;grid-column:span 2;grid-row:2',
		'display:block;position:absolute',
		'display:grid;grid-template-columns:subgrid [one] [two] [three]'] {
		grid_placement_test_apply_style(mut document, item, rules)
		assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
		assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	}
	grid_placement_test_apply_style(mut document, root, 'display:grid;grid-auto-flow:column dense')
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	if !disable_grid_placement_reuse {
		assert state.measurement_chunk_pool_.grid_placements_[u64(voidptr(root))].len == 4
	}
}

fn test_grid_placement_rechecks_named_lines_auto_repeat_counts_and_subgrid_axes() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid"><div style="grid-column:named;grid-row:span 5">a</div><div style="grid-column:span 4">b</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_placement_test_root(document, 'grid')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	for count in 2 .. 8 {
		mut columns := [][]css.GridLineName{len: count}
		columns[1] = [css.GridLineName{ name: 'named', implicit: count % 2 == 0 }]
		rows := [][]css.GridLineName{len: 3}
		for subcolumns in [false, true] {
			for subrows in [false, true] {
				assert !grid_placement_test_compare(mut state, root, columns, rows, subcolumns, subrows)
				assert grid_placement_test_compare(mut state, root, columns, rows, subcolumns, subrows) == !disable_grid_placement_reuse
			}
		}
	}
}

fn test_grid_placement_rechecks_tree_identity_and_anonymous_text_membership() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid"><div id="a">a</div><div>b</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	mut root := unsafe { &Node(grid_placement_test_root(document, 'grid')) }
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	columns := [][]css.GridLineName{len: 3}
	rows := [][]css.GridLineName{len: 2}
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	first := root.children()[0]
	root.remove_child(first)
	root.append_child(first)
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	mut anonymous := BlockContainer.new(document, none, css.ComputedProperties.new())
	mut anonymous_node := unsafe { &Node(anonymous) }
	anonymous_node.anonymous_ = true
	mut text := TextNode.new(document, document.create_text_node(' ').as_node(), ' ')
	anonymous_node.append_child(unsafe { &Node(text) })
	root.append_child(anonymous_node)
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	mut data := text.dom_node()?.as_character_data()?
	data.set_data('visible')
	text.source_text_ = 'visible'
	text.invalidate_text_for_rendering()
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
}

fn test_grid_placement_rechecks_typed_flow_order_axes_and_subgrid_without_raw_style_mutation() {
	mut document := html.parse_document('<!doctype html><section id="grid" style="display:grid"><div id="a" style="display:grid;grid-template-columns:subgrid">a</div><div>b</div><div>c</div></section>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 500, 400)
	root := grid_placement_test_root(document, 'grid')
	item := grid_placement_test_root(document, 'a')
	mut state := LayoutState.new()
	state.enable_measurement_chunk_pool()
	defer { state.release_measurement_chunk_pool() }
	columns := [][]css.GridLineName{len: 5}
	rows := [][]css.GridLineName{len: 4}
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	root_revision := root.computed_values().mutation_revision()
	item_revision := item.computed_values().mutation_revision()
	mut item_values := unsafe { &css.MutableComputedValues(item.computed_values()) }
	for step in 0 .. 5 {
		match step {
			0 { item_values.set_order(2) }
			1 {
				item_values.set_grid_column_start(css.GridTrackPlacement.make_line(css.IntegerStyleValue.create(1), none))
			}
			2 {
				item_values.set_grid_row_start(css.GridTrackPlacement.make_line(css.IntegerStyleValue.create(1), none))
			}
			3 {
				item_values.set_grid_column_end(css.GridTrackPlacement.make_span(css.IntegerStyleValue.create(2), none))
			}
			else {
				item_values.set_grid_row_end(css.GridTrackPlacement.make_span(css.IntegerStyleValue.create(2), none))
			}
		}
		assert item.computed_values().mutation_revision() == item_revision
		assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
		assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	}
	mut root_values := unsafe { &css.MutableComputedValues(root.computed_values()) }
	root_values.set_grid_auto_flow(css.GridAutoFlow{ row: false, dense: true })
	assert root.computed_values().mutation_revision() == root_revision
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
	item_values.set_grid_column_start(css.GridTrackPlacement.make_auto())
	item_values.set_grid_column_end(css.GridTrackPlacement.make_auto())
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	mut subgrid := css.GridTrackSizeList.make_subgrid()
	for _ in 0 .. 4 { subgrid.append_line_names(css.GridLineNames{}) }
	item_values.set_grid_template_columns(subgrid)
	assert item.computed_values().mutation_revision() == item_revision
	assert !grid_placement_test_compare(mut state, root, columns, rows, false, false)
	assert grid_placement_test_compare(mut state, root, columns, rows, false, false) == !disable_grid_placement_reuse
}
