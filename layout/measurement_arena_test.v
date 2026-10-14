module layout

import css
import dom

$if gcboehm ? {
	fn C.GC_gcollect()
}

fn test_measurement_arena_keeps_addresses_and_nested_data_through_growth() {
	mut arena := &MeasurementUsedValuesArena{}
	mut store := UsedValuesPagedStore{
		measurement_arena: arena
	}
	mut entries := []&UsedValues{}
	for i in 0 .. 512 {
		mut values := store.allocate(u32(i * 17))
		values.set_content_width(CSSPixels.new(i))
		values.set_grid_template_columns([CSSPixels.new(i + 10)])
		values.line_boxes << LineBox.new(.ltr, .horizontal_tb)
		entries << values
	}
	assert arena.chunks.len == 32
	$if gcboehm ? { C.GC_gcollect() }
	for i, entry in entries {
		stored := store.get(u32(i * 17)) or { panic('missing geometry') }
		assert voidptr(stored) == voidptr(entry)
		assert stored.content_width().to_double() == i
		assert stored.grid_template_columns()[0].to_double() == i + 10
		assert stored.line_boxes.len == 1
	}
}

fn test_releasing_measurement_preserves_committed_geometry_and_allows_fresh_probe() {
	document := dom.Document.create(dom.url_about_blank())
	box := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	mut original := source.get_mutable(box)
	original.set_content_width(CSSPixels.new(123))
	original.set_grid_template_columns([CSSPixels.new(40)])
	original.line_boxes << LineBox.new(.ltr, .horizontal_tb)
	mut measurement := LayoutState.new_for_subtree(box)
	mut copied := measurement.populate_node_from(mut source, box)
	copied.set_grid_template_columns([CSSPixels.new(80)])
	measurement.release_measurement()
	measurement.release_measurement()
	$if gcboehm ? { C.GC_gcollect() }
	assert source.get(box).content_width().to_double() == 123
	assert source.get(box).grid_template_columns()[0].to_double() == 40
	assert source.get(box).line_boxes.len == 1
	assert measurement.try_get(box) == none
	arena := measurement.used_values_store.measurement_arena or { panic('missing arena') }
	assert arena.chunks.len == 0
	fresh := measurement.populate_node_from(mut source, box)
	assert fresh.content_width().to_double() == 123
	assert fresh.grid_template_columns()[0].to_double() == 40
	assert arena.chunks.len == 1
	measurement.release_measurement()
}

fn test_measurement_slots_start_with_complete_defaults_across_chunk_boundaries() {
	mut arena := &MeasurementUsedValuesArena{}
	for i in 0 .. measurement_arena_chunk_size * 2 + 1 {
		mut values := arena.allocate()
		assert values.node_ == unsafe { nil }
		assert values.containing_block_used_values() == none
		assert values.content_width().to_double() == 0
		assert values.content_height().to_double() == 0
		assert !values.has_definite_width()
		assert !values.has_definite_height()
		assert values.width_constraint == .none
		assert values.height_constraint == .none
		assert values.containing_line_box_fragment == none
		assert values.scrollable_overflow_rect_ == none
		assert !values.has_rare_data()
		assert values.line_boxes.len == 0
		values.set_content_width(CSSPixels.new(i + 1))
		values.line_boxes << LineBox.new(.ltr, .horizontal_tb)
		assert values.line_boxes.len == 1
	}
	assert arena.chunks.len == 3
	arena.release()
	assert arena.chunks.len == 0
	mut fresh := arena.allocate()
	assert fresh.content_width().to_double() == 0
	assert fresh.line_boxes.len == 0
	assert fresh.containing_block_used_values() == none
	fresh.line_boxes << LineBox.new(.rtl, .vertical_rl)
	$if gcboehm ? { C.GC_gcollect() }
	assert fresh.line_boxes.len == 1
	arena.release()
}

fn measurement_arena_from_returned_producer() &MeasurementUsedValuesArena {
	mut arena := &MeasurementUsedValuesArena{}
	for i in 0 .. measurement_arena_chunk_size * 3 {
		mut values := arena.allocate()
		values.set_grid_template_columns([CSSPixels.new(i + 100)])
		values.line_boxes << LineBox.new(.ltr, .horizontal_tb)
	}
	return arena
}

fn test_measurement_chunk_retains_nested_allocations_after_the_producer_returns() {
	mut arena := measurement_arena_from_returned_producer()
	for _ in 0 .. 3 {
		$if gcboehm ? { C.GC_gcollect() }
		for chunk_index, chunk in arena.chunks {
			for i in 0 .. chunk.used {
				values := unsafe { &chunk.values[i] }
				assert values.grid_template_columns()[0].to_double() == chunk_index * measurement_arena_chunk_size + i + 100
				assert values.line_boxes.len == 1
			}
		}
	}
	arena.release()
}
