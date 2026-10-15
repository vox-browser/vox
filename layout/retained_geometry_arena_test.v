module layout

import css
import dom

fn test_committed_geometry_slots_keep_stable_addresses_defaults_and_rare_values() {
	mut store := UsedValuesPagedStore{}
	mut pointers := []&UsedValues{}
	for index in 0 .. 257 {
		mut values := store.allocate(u32(index * 17))
		assert values.content_width().to_double() == 0
		assert !values.has_definite_height()
		assert values.containing_block_used_values() == none
		assert !values.has_rare_data()
		assert values.line_boxes.len == 0
		values.set_content_width(CSSPixels.new(index))
		values.set_grid_template_columns([CSSPixels.new(index + 100)])
		values.line_boxes << LineBox.new(.ltr, .horizontal_tb)
		pointers << values
	}
	assert store.measurement_arena == none
	assert store.retained_arena.storage.chunks.len == 17
	gc_collect()
	for index, pointer in pointers {
		values := store.get(u32(index * 17)) or { panic('lost committed geometry') }
		assert voidptr(values) == voidptr(pointer)
		assert values.content_width().to_double() == index
		assert values.grid_template_columns()[0].to_double() == index + 100
		assert values.line_boxes.len == 1
	}
}

fn retained_geometry_from_returned_store() &UsedValues {
	mut store := UsedValuesPagedStore{}
	mut retained := unsafe { &UsedValues(nil) }
	for index in 0 .. 33 {
		mut values := store.allocate(u32(index))
		values.set_content_width(CSSPixels.new(index + 300))
		values.set_grid_template_columns([CSSPixels.new(index + 500)])
		if index == 17 { retained = values }
	}
	return retained
}

fn test_escaped_committed_geometry_keeps_its_chunk_and_nested_values_alive() {
	mut retained := retained_geometry_from_returned_store()
	for _ in 0 .. 3 {
		gc_collect()
		assert retained.content_width().to_double() == 317
		assert retained.grid_template_columns()[0].to_double() == 517
		retained.set_derived_baselines(CSSPixels.new(7), CSSPixels.new(9))
		assert retained.derived_first_baseline()?.to_double() == 7
	}
}

fn test_probe_release_cannot_release_committed_arena_or_mutate_its_geometry() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	box := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut source := LayoutState.new()
	mut original := source.get_mutable(box)
	original.set_content_width(CSSPixels.new(123))
	original.set_grid_template_columns([CSSPixels.new(40)])
	mut probe := LayoutState.new_for_subtree(box)
	mut copied := probe.populate_node_from(mut source, box)
	copied.set_content_width(CSSPixels.new(456))
	copied.set_grid_template_columns([CSSPixels.new(80)])
	assert probe.used_values_store.retained_arena == unsafe { nil }
	probe.release_measurement()
	source.release_measurement()
	gc_collect()
	assert voidptr(source.get(box)) == voidptr(original)
	assert original.content_width().to_double() == 123
	assert original.grid_template_columns()[0].to_double() == 40
	assert source.used_values_store.retained_arena.storage.chunks.len == 1
	assert probe.try_get(box) == none
}
