module dom

import platform

$if gcboehm ? {
	fn C.GC_gcollect()
	fn C.GC_get_total_bytes() usize
}

fn test_layout_bridge_default_storage_reads_and_resets_do_not_allocate() {
	mut node := &LayoutNode{}
	assert node.callbacks_ == unsafe { nil }
	assert node.box_model_ == unsafe { nil }
	assert sizeof(LayoutNode) <= 512
	// Warm the allocator counters before comparing repeated default reads.
	before_arena := platform.thread_arena_usage().used
	mut before_gc := usize(0)
	$if gcboehm ? {
		before_gc = C.GC_get_total_bytes()
	}
	for _ in 0 .. 64 {
		assert node.bridge_callbacks().apply_style_callback == unsafe { nil }
		assert node.box_model().margin_left == 0
		assert node.box_model().padding_bottom == 0
		node.set_box_model(LayoutBoxModel{})
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before_arena
	}
	$if gcboehm ? {
		assert C.GC_get_total_bytes() == before_gc
	}
	assert node.callbacks_ == unsafe { nil }
	assert node.box_model_ == unsafe { nil }
}

fn test_layout_box_model_replacement_preserves_value_copies_and_updates_live_aliases() {
	mut node := &LayoutNode{}
	node.set_box_model(LayoutBoxModel{
		margin_left:    -1.25
		margin_right:   2.5
		margin_top:     3.75
		margin_bottom:  4
		border_left:    5
		border_right:   6
		border_top:     7
		border_bottom:  8
		padding_left:   9
		padding_right:  10
		padding_top:    11
		padding_bottom: 12
		inset_left:     13
		inset_right:    14
		inset_top:      15
		inset_bottom:   16
	})
	snapshot := *node
	expected := *node.box_model()
	node.set_box_model(expected)
	assert voidptr(node.box_model_) == voidptr(snapshot.box_model_)
	mut alias := node
	alias.set_box_model(LayoutBoxModel{ padding_left: 21 })
	assert node.box_model().padding_left == 21
	assert node.box_model().margin_left == 0
	assert *snapshot.box_model() == expected
	assert snapshot.box_model().inset_bottom == 16
	assert snapshot.box_model().margin_left == -1.25
	alias.set_box_model(LayoutBoxModel{})
	assert node.box_model_ == unsafe { nil }
	$if gcboehm ? {
		C.GC_gcollect()
	}
	assert *snapshot.box_model() == expected
}
