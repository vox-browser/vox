module layout

import css
import dom

fn test_paged_lookup_absence_covers_empty_slots_pages_and_directory_bounds() {
	mut store := UsedValuesPagedStore{}
	assert store.get(0) == none
	assert store.get(0xffffffff) == none
	mut value := store.allocate(17)
	value.set_content_width(CSSPixels.new(89))
	value.line_boxes << LineBox.new(.rtl, .vertical_rl)
	store.ensure_capacity(1024)
	length := store.pages.len
	capacity := store.pages.cap
	data := store.pages.data
	for index in [u32(0), 15, 16, 18, 31, 32, 511, 1023, 1024, 0xffffffff] {
		assert store.get(index) == none
		assert store.pages.len == length
		assert store.pages.cap == capacity
		assert store.pages.data == data
	}
	gc_collect()
	found := store.get(17) or { panic('missing stored entry') }
	assert voidptr(found) == voidptr(value)
	assert found.content_width() == CSSPixels.new(89)
	assert found.line_boxes.len == 1
	assert found.line_boxes[0].writing_mode_ == .vertical_rl
}

fn test_public_used_value_hits_preserve_cached_geometry_and_ancestor_identity() {
	document := dom.Document.create(dom.url_about_blank())
	root := BlockContainer.new(document, none, css.ComputedProperties.new())
	child := BlockContainer.new(document, none, css.ComputedProperties.new())
	mut root_node := unsafe { &Node(root) }
	root_node.append_child(unsafe { &Node(child) })
	assign_layout_indexes(root_node)
	recompute_containing_blocks(root_node)
	root_style := unsafe { &NodeWithStyle(root) }
	child_style := unsafe { &NodeWithStyle(child) }
	mut state := LayoutState.new()
	mut parent := state.get_mutable(root_style)
	parent.set_content_width(CSSPixels.new(137))
	parent.set_has_definite_width(true)
	mut original := state.get_mutable(child_style)
	original.set_content_width(CSSPixels.new(83))
	original.set_content_height(CSSPixels.new(41))
	for _ in 0 .. 64 {
		found := state.get(child_style)
		assert voidptr(found) == voidptr(original)
		assert found.content_width() == CSSPixels.new(83)
		assert found.content_height() == CSSPixels.new(41)
		assert voidptr(found.containing_block_used_values() or { panic('missing ancestor') }) == voidptr(parent)
		assert voidptr(state.try_get_mutable(child_style) or { panic('missing optional hit') }) == voidptr(original)
	}
	gc_collect()
	assert voidptr(state.get_mutable(child_style)) == voidptr(original)
	assert parent.content_width() == CSSPixels.new(137)
}

fn test_populated_measurement_lookup_stays_independent_after_release_and_reuse() {
	document := dom.Document.create(dom.url_about_blank())
	node := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	mut original := source.get_mutable(node)
	original.set_content_width(CSSPixels.new(101))
	original.line_boxes << LineBox.new(.ltr, .horizontal_tb)
	mut probe := LayoutState.new_for_subtree(node)
	for _ in 0 .. 3 {
		assert probe.try_get(node) == none
		mut copied := probe.populate_node_from(mut source, node)
		assert voidptr(copied) != voidptr(original)
		assert copied.content_width() == CSSPixels.new(101)
		assert copied.line_boxes.len == 1
		assert copied.containing_block_used_values() == none
		assert voidptr(probe.get_mutable(node)) == voidptr(copied)
		assert voidptr(probe.try_get(node) or { panic('missing populated optional hit') }) == voidptr(copied)
		copied.set_content_width(CSSPixels.new(7))
		assert original.content_width() == CSSPixels.new(101)
		probe.release_measurement()
	}
	assert original.line_boxes.len == 1
}
