module layout

import css
import dom

fn measurement_pool_test_node() &NodeWithStyle {
	return NodeWithStyle.new(dom.Document.create(dom.url_about_blank()), none,
		css.ComputedProperties.new())
}

fn measurement_pool_test_arena(state &LayoutState) &MeasurementUsedValuesArena {
	return state.used_values_store.measurement_arena or { panic('missing measurement arena') }
}

fn test_measurement_chunk_pool_is_opt_in_and_preserves_public_unpooled_probe_lifetime() {
	node := measurement_pool_test_node()
	mut source := LayoutState.new()
	mut standalone := LayoutState.new_for_subtree(node)
	mut inherited := source.new_measurement_for_subtree(node)
	assert measurement_pool_test_arena(standalone).chunk_pool_ == unsafe { nil }
	assert measurement_pool_test_arena(inherited).chunk_pool_ == unsafe { nil }
	_ = standalone.get_mutable(node)
	_ = inherited.get_mutable(node)
	standalone.release_measurement()
	inherited.release_measurement()
	assert measurement_pool_test_arena(standalone).chunks.len == 0
	assert measurement_pool_test_arena(inherited).chunks.len == 0
	assert source.measurement_chunk_pool_ == unsafe { nil }
}

fn measurement_pool_test_released_producer() &LayoutState {
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	mut probe := source.new_measurement_for_subtree(measurement_pool_test_node())
	mut arena := measurement_pool_test_arena(probe)
	for index in 0 .. measurement_arena_chunk_size * 3 + 1 {
		mut values := arena.allocate()
		values.node_ = measurement_pool_test_node()
		values.set_content_width(CSSPixels.new(index + 1))
		values.set_content_height(CSSPixels.new(index + 2))
		values.set_has_definite_width(true)
		values.width_constraint = .max_content
		values.margin_left = CSSPixels.new(index + 3)
		values.set_relative_inset_basis(CSSPixels.new(100), CSSPixels.new(200))
		values.set_grid_template_columns([CSSPixels.new(index + 4)])
		values.set_inline_end_static_position_rect(StaticPositionRect{})
		values.line_boxes << LineBox.new(.rtl, .vertical_rl)
	}
	assert source.measurement_chunk_pool_.active_arenas == 1
	probe.release_measurement()
	assert source.measurement_chunk_pool_.active_arenas == 0
	return source
}

fn test_measurement_chunk_pool_clears_gc_edges_and_restores_complete_slot_defaults() {
	mut source := measurement_pool_test_released_producer()
	pool := source.measurement_chunk_pool_
	assert pool.chunks.len == 4
	gc_collect()
	mut addresses := []voidptr{}
	for chunk in pool.chunks {
		addresses << voidptr(chunk)
		assert chunk.used == 0
		// Inactive slots have not yet been constructed as V values. Check all
		// raw bytes are zero (including every conservative-GC edge); full
		// Option/default semantics are checked after allocate() below.
		memory := unsafe { &u8(chunk) }
		for byte_index in 0 .. int(sizeof(MeasurementUsedValuesChunk)) {
			assert unsafe { memory[byte_index] } == 0
		}
	}
	mut next := source.new_measurement_for_subtree(measurement_pool_test_node())
	mut arena := measurement_pool_test_arena(next)
	for _ in 0 .. measurement_arena_chunk_size * 4 {
		value := arena.allocate()
		assert value.node_ == unsafe { nil }
		assert value.containing_block_used_values() == none
		assert value.content_width().raw_value() == 0
		assert value.content_height().raw_value() == 0
		assert !value.has_definite_width()
		assert !value.has_definite_height()
		assert value.width_constraint == .none
		assert value.height_constraint == .none
		assert value.margin_left.raw_value() == 0
		assert value.relative_inset_basis_width() == none
		assert value.relative_inset_basis_height() == none
		assert !value.has_rare_data()
		assert value.line_boxes.len == 0
		assert value.containing_line_box_fragment == none
		assert value.scrollable_overflow_rect_ == none
		assert voidptr(value.inline_end_snapshot_arena_) == voidptr(arena)
	}
	for chunk in arena.chunks {
		assert voidptr(chunk) in addresses
	}
	assert pool.chunks.len == 0
	next.release_measurement()
	source.release_measurement_chunk_pool()
	assert pool.closed
	assert pool.chunks.len == 0
	assert source.measurement_chunk_pool_ == unsafe { nil }
}

fn test_measurement_chunk_pool_never_lends_live_parent_or_sibling_probe_chunks() {
	node := measurement_pool_test_node()
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	pool := source.measurement_chunk_pool_
	mut first := source.new_measurement_for_subtree(node)
	mut first_values := first.get_mutable(node)
	first_values.set_content_width(CSSPixels.new(123))
	mut nested := first.new_measurement_for_subtree(node)
	mut nested_values := nested.populate_node_from(mut first, node)
	nested_values.set_content_width(CSSPixels.new(456))
	first_chunk := measurement_pool_test_arena(first).chunks[0]
	nested_chunk := measurement_pool_test_arena(nested).chunks[0]
	assert voidptr(first_chunk) != voidptr(nested_chunk)
	assert pool.active_arenas == 2
	nested.release_measurement()
	assert pool.active_arenas == 1
	assert first_values.content_width().to_double() == 123
	mut sibling := first.new_measurement_for_subtree(node)
	_ = sibling.get_mutable(node)
	assert voidptr(measurement_pool_test_arena(sibling).chunks[0]) == voidptr(nested_chunk)
	assert first_values.content_width().to_double() == 123
	sibling.release_measurement()
	first.release_measurement()
	assert pool.active_arenas == 0
	assert pool.chunks.len == 2
	source.release_measurement_chunk_pool()
}

fn test_measurement_chunk_pool_has_a_fixed_bound_and_explicitly_closes_at_layout_end() {
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	pool := source.measurement_chunk_pool_
	mut probe := source.new_measurement_for_subtree(measurement_pool_test_node())
	mut arena := measurement_pool_test_arena(probe)
	for _ in 0 .. (measurement_chunk_pool_capacity + 3) * measurement_arena_chunk_size {
		_ = arena.allocate()
	}
	assert arena.chunks.len == measurement_chunk_pool_capacity + 3
	probe.release_measurement()
	assert pool.chunks.len == measurement_chunk_pool_capacity
	assert arena.chunks.len == 0
	assert pool.active_arenas == 0
	source.release_measurement_chunk_pool()
	source.release_measurement_chunk_pool()
	assert pool.closed
	assert pool.chunks.len == 0
	assert pool.chunks.cap == 0
}

fn test_measurement_chunk_pool_preserves_retained_snapshots_after_probe_reuse_and_close() {
	node := measurement_pool_test_node()
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	mut probe := source.new_measurement_for_subtree(node)
	mut values := probe.get_mutable(node)
	values.set_inline_end_static_position_rect(StaticPositionRect{
		rect: css.CSSPixelRect.new(17, 29, 0, 0)
	})
	values.set_grid_template_columns([CSSPixels.new(41)])
	values.line_boxes << LineBox.new(.rtl, .horizontal_tb)
	mut retained := LayoutState.new()
	retained_values := retained.populate_node_from(mut probe, node)
	assert retained_values.inline_end_snapshot_arena_ == unsafe { nil }
	assert voidptr(retained_values.inline_end_static_position_snapshot_) != voidptr(values.inline_end_static_position_snapshot_)
	probe.release_measurement()
	mut next := source.new_measurement_for_subtree(node)
	mut overwritten := next.get_mutable(node)
	overwritten.set_inline_end_static_position_rect(StaticPositionRect{})
	overwritten.set_grid_template_columns([CSSPixels.new(99)])
	next.release_measurement()
	source.release_measurement_chunk_pool()
	gc_collect()
	assert retained_values.inline_end_static_position_rect()?.rect.x.to_double() == 17
	assert retained_values.inline_end_static_position_rect()?.rect.y.to_double() == 29
	assert retained_values.grid_template_columns()[0].to_double() == 41
	assert retained_values.line_boxes.len == 1
}

fn test_measurement_chunk_pool_isolated_passes_do_not_share_chunks_and_closed_arenas_stay_reusable() {
	node := measurement_pool_test_node()
	mut first := LayoutState.new()
	mut second := LayoutState.new()
	first.enable_measurement_chunk_pool()
	second.enable_measurement_chunk_pool()
	mut first_probe := first.new_measurement_for_subtree(node)
	mut second_probe := second.new_measurement_for_subtree(node)
	_ = first_probe.get_mutable(node)
	_ = second_probe.get_mutable(node)
	assert voidptr(measurement_pool_test_arena(first_probe).chunks[0]) != voidptr(measurement_pool_test_arena(second_probe).chunks[0])
	first_probe.release_measurement()
	first.release_measurement_chunk_pool()
	assert second.measurement_chunk_pool_.active_arenas == 1
	second_probe.release_measurement()
	second.release_measurement_chunk_pool()
	mut fresh := first_probe.get_mutable(node)
	fresh.set_content_width(CSSPixels.new(71))
	assert fresh.content_width().to_double() == 71
	first_probe.release_measurement()
	assert measurement_pool_test_arena(first_probe).chunks.len == 0
	assert !measurement_pool_test_arena(first_probe).pool_lease_active_
}
