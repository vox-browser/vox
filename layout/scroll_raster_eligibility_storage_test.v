module layout

import html
import platform

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_borrowed_raster_eligibility_walk_preserves_group_rejections() {
	mut document := html.parse_document('<!doctype html><p>Raster groups</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	mut commands := [
		PaintCommand{kind: 'begin_skia_command_group'},
		PaintCommand{kind: 'fill_rect', width: 10, height: 10},
		PaintCommand{kind: 'end_skia_command_group'},
	]
	assert viewport_scroll_raster_reusable(document, commands, 320, 200)
	commands[1].kind = 'unsupported_raster_leaf'
	assert !viewport_scroll_raster_reusable(document, commands, 320, 200)
	assert commands[1].kind == 'unsupported_raster_leaf'
	assert !viewport_scroll_raster_reusable(document, commands[..1], 320, 200)
}

fn test_repeated_scroll_raster_eligibility_checks_borrow_paint_commands() {
	mut document := html.parse_document('<!doctype html><p>Retained raster</p>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	commands := []PaintCommand{len: 128, init: PaintCommand{
		kind: 'fill_rect'
		width: 10
		height: 10
	}}
	assert viewport_scroll_raster_reusable(document, commands, 320, 200)
	before := platform.thread_arena_usage().used
	mut gc_before := uint(0)
	$if gcboehm ? { gc_before = C.GC_get_total_bytes() }
	for _ in 0 .. 32 {
		assert viewport_scroll_raster_reusable(document, commands, 320, 200)
	}
	$if prealloc {
		allocated := platform.thread_arena_usage().used - before
		assert allocated < 4096, 'raster eligibility retained ${allocated} bytes'
	}
	$if gcboehm ? {
		allocated := C.GC_get_total_bytes() - gc_before
		assert allocated < 16384, 'raster eligibility allocated ${allocated} bytes'
	}
	assert commands.len == 128
	assert commands[0].kind == 'fill_rect' && commands[0].width == 10
	assert !viewport_scroll_raster_reusable(document, []PaintCommand{}, 320, 200)
}
