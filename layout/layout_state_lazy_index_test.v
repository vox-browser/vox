module layout

import css
import dom
import html as html_parser

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn lazy_layout_index_test_node(index u32) &NodeWithStyle {
	document := dom.Document.create(dom.url_about_blank())
	mut node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	node.set_layout_index(index)
	return node
}

fn test_lazy_layout_indexes_read_misses_do_not_allocate_or_materialize_storage() {
	node := lazy_layout_index_test_node(7)
	state := LayoutState.new()
	mut probe := LayoutState.new_for_subtree(node)
	assert state.subgrid_storage_ == unsafe { nil }
	assert state.height_dependency_storage_ == unsafe { nil }
	assert probe.subgrid_storage_ == unsafe { nil }
	assert probe.height_dependency_storage_ == unsafe { nil }
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut misses := 0
	for _ in 0 .. 1024 {
		if state.subgrid_axis_data(node, true) == none { misses++ }
		if state.subgrid_axis_data(node, false) == none { misses++ }
		if state.cached_definite_height_dependency(node.layout_index()) == none { misses++ }
		if probe.subgrid_axis_data(node, true) == none { misses++ }
		if probe.cached_definite_height_dependency(node.layout_index()) == none { misses++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert misses == 5120
	assert allocated == 0
	assert state.subgrid_storage_ == unsafe { nil }
	assert state.height_dependency_storage_ == unsafe { nil }
	assert probe.subgrid_storage_ == unsafe { nil }
	assert probe.height_dependency_storage_ == unsafe { nil }
	probe.release_measurement()
}

fn test_lazy_layout_indexes_materialize_separately_and_keep_cached_false() {
	node := lazy_layout_index_test_node(9)
	mut first := LayoutState.new()
	mut second := LayoutState.new()
	first.cache_definite_height_dependency(node.layout_index(), false)
	assert first.height_dependency_storage_ != unsafe { nil }
	assert first.subgrid_storage_ == unsafe { nil }
	assert !(first.cached_definite_height_dependency(9) or { panic('false entry is missing') })
	assert first.cached_definite_height_dependency(31) == none
	assert second.cached_definite_height_dependency(9) == none
	second.cache_definite_height_dependency(9, true)
	assert voidptr(first.height_dependency_storage_) != voidptr(second.height_dependency_storage_)
	assert second.cached_definite_height_dependency(9) or { false }
	assert second.cached_definite_height_dependency(31) == none
	first.cache_definite_height_dependency(9, true)
	first.cache_definite_height_dependency(9, false)
	assert first.height_dependency_storage_.values.len == 1
	assert !(first.cached_definite_height_dependency(9) or { panic('false replacement is missing') })
	first.set_subgrid_axis_data(node, true, GridSubgridAxisData{gap: CSSPixels.new(17)})
	gc_collect()
	assert first.subgrid_storage_ != unsafe { nil }
	assert second.subgrid_storage_ == unsafe { nil }
	assert first.subgrid_axis_data(node, false) == none
	assert (first.subgrid_axis_data(node, true) or { panic('missing column axis') }).gap.to_double() == 17
	assert second.cached_definite_height_dependency(9) or { false }
}

fn test_lazy_layout_subgrid_population_keeps_independent_axis_records_after_gc() {
	node := lazy_layout_index_test_node(5)
	mut source := LayoutState.new()
	source.set_subgrid_axis_data(node, true, GridSubgridAxisData{
		tracks: [GridTrack{base_size: CSSPixels.new(40)}]
		line_names: [[css.GridLineName{name: 'start'}], [css.GridLineName{name: 'end'}]]
		gap: CSSPixels.new(7)
	})
	source.cache_definite_height_dependency(5, false)
	mut original := source.get_mutable(node)
	original.set_content_width(CSSPixels.new(240))
	mut probe := LayoutState.new_for_subtree(node)
	copied := probe.populate_node_from(mut source, node)
	assert copied.content_width().to_double() == 240
	assert copied.containing_block_used_values() == none
	assert voidptr(source.subgrid_storage_) != voidptr(probe.subgrid_storage_)
	assert probe.height_dependency_storage_ == unsafe { nil }
	probe.set_subgrid_axis_data(node, false, GridSubgridAxisData{gap: CSSPixels.new(11)})
	source.set_subgrid_axis_data(node, true, GridSubgridAxisData{gap: CSSPixels.new(29)})
	gc_collect()
	axis := probe.subgrid_axis_data(node, true) or { panic('missing copied column axis') }
	assert axis.gap.to_double() == 7
	assert axis.tracks[0].base_size.to_double() == 40
	assert axis.line_names[0][0].name == 'start'
	assert axis.line_names[1][0].name == 'end'
	assert (source.subgrid_axis_data(node, true) or { panic('missing source column') }).gap.to_double() == 29
	assert source.subgrid_axis_data(node, false) == none
	assert (probe.subgrid_axis_data(node, false) or { panic('missing copied row') }).gap.to_double() == 11
	probe.release_measurement()
	gc_collect()
	assert (source.subgrid_axis_data(node, true) or { panic('released source column') }).gap.to_double() == 29
	assert !(source.cached_definite_height_dependency(5) or { panic('missing source cache') })
}

fn test_lazy_layout_population_of_unindexed_node_keeps_both_indexes_absent() {
	node := lazy_layout_index_test_node(4)
	other := lazy_layout_index_test_node(12)
	mut source := LayoutState.new()
	source.set_subgrid_axis_data(other, false, GridSubgridAxisData{gap: CSSPixels.new(13)})
	source.cache_definite_height_dependency(4, true)
	mut original := source.get_mutable(node)
	original.set_content_height(CSSPixels.new(33))
	mut probe := LayoutState.new_for_subtree(node)
	copied := probe.populate_node_from(mut source, node)
	gc_collect()
	assert copied.content_height().to_double() == 33
	assert probe.subgrid_axis_data(node, true) == none
	assert probe.subgrid_axis_data(node, false) == none
	assert probe.subgrid_storage_ == unsafe { nil }
	assert probe.cached_definite_height_dependency(4) == none
	assert probe.height_dependency_storage_ == unsafe { nil }
	probe.release_measurement()
}

fn lazy_layout_find_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if found := lazy_layout_find_node(child, id) { return found }
	}
	return none
}

fn test_lazy_layout_height_cache_tracks_percentage_topology_and_reuses_false() {
	document := html_parser.parse_document('<!doctype html><style>body{margin:0}#plain{width:100px}#dependent{width:100px}#percentage{height:50%}</style><div id="plain">plain</div><div id="dependent"><div id="percentage">half</div></div>')
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	plain := lazy_layout_find_node(result.root, 'plain') or { panic('missing plain box') }
	dependent := lazy_layout_find_node(result.root, 'dependent') or { panic('missing dependent box') }
	percentage := lazy_layout_find_node(result.root, 'percentage') or { panic('missing percentage box') }
	plain_style := plain.as_node_with_style() or { panic('missing plain style') }
	dependent_style := dependent.as_node_with_style() or { panic('missing parent style') }
	percentage_style := percentage.as_node_with_style() or { panic('missing percentage style') }
	mut state := LayoutState.new()
	assert !flex_subtree_depends_on_definite_height(mut state, plain)
	assert !(state.cached_definite_height_dependency(plain_style.layout_index()) or { panic('uncached false') })
	assert flex_subtree_depends_on_definite_height(mut state, dependent)
	assert state.cached_definite_height_dependency(dependent_style.layout_index()) or { false }
	assert state.cached_definite_height_dependency(percentage_style.layout_index()) or { false }
	gc_collect()
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut false_hits := 0
	for _ in 0 .. 1024 {
		if !flex_subtree_depends_on_definite_height(mut state, plain) { false_hits++ }
	}
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert false_hits == 1024
	assert allocated == 0
	assert state.subgrid_storage_ == unsafe { nil }
}
