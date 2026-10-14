module layout

import css
import dom

$if gcboehm ? {
	fn C.GC_gcollect()
}

struct SparsePageVisit {
mut:
	indices []int
}

fn test_sparse_used_values_pages_keep_gaps_and_stable_owned_entries() {
	mut store := UsedValuesPagedStore{}
	indices := [u32(0), 15, 16, 63, 4095, 8192]
	mut addresses := []voidptr{}
	for index in indices {
		mut value := store.allocate(index)
		value.set_content_width(CSSPixels.new(int(index)))
		value.line_boxes << LineBox.new(.ltr, .horizontal_tb)
		addresses << voidptr(value)
	}
	store.ensure_capacity(16384)
	$if gcboehm ? { C.GC_gcollect() }
	for i, index in indices {
		value := store.get(index) or { panic('missing sparse entry') }
		assert voidptr(value) == addresses[i]
		assert value.content_width().to_double() == index
		assert value.line_boxes.len == 1
	}
	for index in [u32(1), 14, 17, 32, 4094, 8191, 16383, 16384] {
		assert store.get(index) == none
	}
	seen := &SparsePageVisit{}
	store.for_each(fn [seen] (value &UsedValues) {
		mut mutable_seen := unsafe { &SparsePageVisit(seen) }
		mutable_seen.indices << int(value.content_width().to_double())
	})
	assert seen.indices == [0, 15, 16, 63, 4095, 8192]
}

fn test_subgrid_lookup_and_intrinsic_copy_preserve_optional_axes() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	assert source.subgrid_axis_data(node, true) == none
	assert source.subgrid_axis_data(node, false) == none
	source.set_subgrid_axis_data(node, true, GridSubgridAxisData{gap: CSSPixels.new(7)})
	assert source.subgrid_axis_data(node, false) == none
	mut probe := LayoutState.new_for_subtree(node)
	_ = probe.populate_node_from(mut source, node)
	axis := probe.subgrid_axis_data(node, true) or { panic('missing copied axis') }
	assert axis.gap.to_double() == 7
	assert probe.subgrid_axis_data(node, false) == none
	probe.set_subgrid_axis_data(node, false, GridSubgridAxisData{gap: CSSPixels.new(11)})
	assert source.subgrid_axis_data(node, false) == none
	probe.release_measurement()
}
