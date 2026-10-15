module layout

import css
import dom
import svg

fn inline_snapshot_test_node() &NodeWithStyle {
	document := dom.Document.create(dom.url_about_blank())
	return NodeWithStyle.new(document, none, css.ComputedProperties.new())
}

fn inline_snapshot_test_position(index int) StaticPositionRect {
	return StaticPositionRect{
		rect: css.CSSPixelRect{
			x: css.CSSPixels.from_raw(index * 17 - 100)
			y: css.CSSPixels.from_raw(index * 29 + 50)
			width: css.CSSPixels.from_raw(index * 31)
			height: css.CSSPixels.from_raw(index * 43)
		}
		horizontal_alignment: if index % 2 == 0 { .end } else { .center }
		vertical_alignment: if index % 3 == 0 { .center } else { .end }
	}
}

fn test_inline_snapshot_preserves_absence_zero_presence_and_other_rare_defaults() {
	mut values := &UsedValues{}
	assert !values.has_rare_data()
	assert values.inline_end_static_position_rect() == none
	assert values.inline_end_snapshot_arena_ == unsafe { nil }
	values.set_inline_end_static_position_rect(StaticPositionRect{})
	assert values.has_rare_data()
	assert values.inline_end_static_position_rect()? == StaticPositionRect{}
	assert values.rare_ == none
	assert values.relative_inset_basis_width() == none
	assert values.abspos_containing_block_rect() == none
	assert values.computed_svg_path() == none
	assert values.svg_viewport_transform() == none
	assert values.svg_viewbox_transform() == svg.AffineTransform{}
	assert !values.has_computed_svg_transforms()
	assert !values.has_line_clamp_point()
	values.set_has_line_clamp_point(true)
	values.set_static_position_rect(inline_snapshot_test_position(2))
	assert values.inline_end_static_position_rect()? == StaticPositionRect{}
	assert values.has_line_clamp_point()
	assert values.rare_ != none
}

fn test_inline_snapshot_retained_source_aliases_but_each_writer_replaces_independently() {
	node := inline_snapshot_test_node()
	mut source := LayoutState.new()
	mut original := source.get_mutable(node)
	assert original.inline_end_snapshot_arena_ == unsafe { nil }
	original.set_inline_end_static_position_rect(inline_snapshot_test_position(1))
	mut first := LayoutState.new_for_subtree(node)
	mut a := first.populate_node_from(mut source, node)
	mut second := LayoutState.new_for_subtree(node)
	mut b := second.populate_node_from(mut source, node)
	assert voidptr(a.inline_end_static_position_snapshot_) == voidptr(original.inline_end_static_position_snapshot_)
	assert voidptr(b.inline_end_static_position_snapshot_) == voidptr(original.inline_end_static_position_snapshot_)
	original.set_inline_end_static_position_rect(inline_snapshot_test_position(2))
	a.set_inline_end_static_position_rect(inline_snapshot_test_position(3))
	gc_collect()
	assert original.inline_end_static_position_rect()? == inline_snapshot_test_position(2)
	assert a.inline_end_static_position_rect()? == inline_snapshot_test_position(3)
	assert b.inline_end_static_position_rect()? == inline_snapshot_test_position(1)
	first.release_measurement()
	second.release_measurement()
	gc_collect()
	assert original.inline_end_static_position_rect()? == inline_snapshot_test_position(2)
}

fn inline_snapshot_test_producer() &MeasurementUsedValuesArena {
	mut arena := &MeasurementUsedValuesArena{}
	for index in 0 .. inline_end_snapshot_chunk_size * 3 + 1 {
		mut values := arena.allocate()
		values.set_inline_end_static_position_rect(inline_snapshot_test_position(index))
	}
	return arena
}

fn test_inline_snapshot_measurement_chunks_keep_scalars_alive_after_growth_and_producer_exit() {
	mut arena := inline_snapshot_test_producer()
	assert arena.inline_end_snapshots.len == 4
	for _ in 0 .. 3 {
		gc_collect()
		for chunk_index, chunk in arena.chunks {
			for index in 0 .. chunk.used {
				values := unsafe { &chunk.values[index] }
				assert values.inline_end_static_position_rect()? == inline_snapshot_test_position(chunk_index * measurement_arena_chunk_size + index)
				assert values.rare_ == none
			}
		}
	}
	arena.release()
	assert arena.chunks.len == 0
	assert arena.inline_end_snapshots.len == 0
	arena.release()
	mut fresh := arena.allocate()
	assert fresh.inline_end_static_position_rect() == none
	fresh.set_inline_end_static_position_rect(inline_snapshot_test_position(999))
	assert fresh.inline_end_static_position_rect()? == inline_snapshot_test_position(999)
	assert arena.inline_end_snapshots.len == 1
	arena.release()
}

fn test_inline_snapshot_measurement_source_is_copied_before_independent_source_release() {
	node := inline_snapshot_test_node()
	mut source := LayoutState.new_for_subtree(node)
	mut original := source.get_mutable(node)
	original.set_inline_end_static_position_rect(inline_snapshot_test_position(10))
	mut probe := LayoutState.new_for_subtree(node)
	copied := probe.populate_node_from(mut source, node)
	assert voidptr(copied.inline_end_static_position_snapshot_) != voidptr(original.inline_end_static_position_snapshot_)
	mut retained := LayoutState.new()
	retained_copy := retained.populate_node_from(mut source, node)
	assert voidptr(retained_copy.inline_end_static_position_snapshot_) != voidptr(original.inline_end_static_position_snapshot_)
	source.release_measurement()
	gc_collect()
	assert copied.inline_end_static_position_rect()? == inline_snapshot_test_position(10)
	assert retained_copy.inline_end_static_position_rect()? == inline_snapshot_test_position(10)
	probe.release_measurement()
	gc_collect()
	assert retained_copy.inline_end_static_position_rect()? == inline_snapshot_test_position(10)
}

fn test_inline_snapshot_every_publication_is_immutable_until_measurement_release() {
	mut arena := &MeasurementUsedValuesArena{}
	mut values := arena.allocate()
	mut snapshots := []&StaticPositionRect{}
	for index in 0 .. inline_end_snapshot_chunk_size * 2 + 1 {
		values.set_inline_end_static_position_rect(inline_snapshot_test_position(index))
		snapshots << values.inline_end_static_position_snapshot_
	}
	gc_collect()
	for index, snapshot in snapshots {
		assert *snapshot == inline_snapshot_test_position(index)
	}
	assert values.inline_end_static_position_rect()? == inline_snapshot_test_position(inline_end_snapshot_chunk_size * 2)
	arena.release()
}
