module dom

import platform

fn test_paintable_empty_snap_storage_retains_no_headers() {
	mut box := PaintableBox{}
	empty := box.snapped_areas()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 4096 {
		box.snap_areas_ = retained_paintable_snap_areas(empty.x, empty.y)
		assert box.snap_areas_ == unsafe { nil }
	}
	$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
	// Exercise publication separately: current V copies its destination argument
	// to the heap, independently of whether snap storage is needed.
	box.record_scroll_snap_destination(ScrollSnapDestination_{evaluated_x: true, evaluated_y: true})
	assert box.snap_areas_ == unsafe { nil }
	assert box.snapped_areas().x.len == 0
	assert box.snapped_areas().y.len == 0
}

fn test_paintable_snap_headers_preserve_axes_and_old_snapshots() {
	mut box := PaintableBox{}
	mut source := [ScrollSnapAreaReference_{element_id: 11}]
	box.record_scroll_snap_destination(ScrollSnapDestination_{evaluated_x: true, snapped_areas_x: source})
	first := box
	source[0] = ScrollSnapAreaReference_{element_id: 99}
	assert box.snapped_areas().x[0].element_id == 11
	box.record_scroll_snap_destination(ScrollSnapDestination_{
		evaluated_y: true
		snapped_areas_y: [ScrollSnapAreaReference_{element_id: 22}]
	})
	assert box.snapped_areas().x[0].element_id == 11
	assert box.snapped_areas().y[0].element_id == 22
	assert first.snapped_areas().x[0].element_id == 11
	assert first.snapped_areas().y.len == 0
	second := box
	box.record_scroll_snap_destination(ScrollSnapDestination_{evaluated_x: true})
	assert box.snapped_areas().x.len == 0
	assert box.snapped_areas().y[0].element_id == 22
	assert second.snapped_areas().x[0].element_id == 11
	box.record_scroll_snap_destination(ScrollSnapDestination_{evaluated_y: true})
	assert box.snap_areas_ == unsafe { nil }
	assert second.snapped_areas().y[0].element_id == 22
}

fn test_paintable_callback_tables_preserve_missing_callback_fallbacks() {
	for callbacks in [unsafe { &PaintableCallbacks(nil) }, &PaintableCallbacks{}] {
		mut box := PaintableBox{callbacks: callbacks, repaint_callback_target: voidptr(1)
			scrollable_overflow_rect_: CSSPixelRect_{width_: 100, height_: 100}}
		box.set_needs_repaint(.paint_commands)
		assert box.needs_repaint
		assert !box.image_provider_contents_changed()
		box.scroll_ancestor_to_offset_into_view(5)
		assert box.box_type_agnostic_position() == CSSPixelPoint_{}
		point := CSSPixelPoint_{x_: 3, y_: 4}
		assert box.inverse_transform_point(point) == point
		assert box.select_scroll_snap_destination(point, ScrollSnapSelectionStrategy_{}).position == point
	}
}
