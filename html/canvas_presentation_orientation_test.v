module html

import dom

fn test_canvas_raster_commands_preserve_top_down_native_surface_rows() {
	mut canvas := OffscreenCanvas.create(2, 3)!
	mut context := canvas.get_context(.canvas_2d, none)!
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.fill_rect(0, 0, 2, 1)
	bitmap := canvas.bitmap() or { panic('canvas surface missing') }
	assert bitmap.native_rows_are_top_down
	assert bitmap.data[0..4] == [u8(255), 0, 0, 255]
	assert bitmap.data[16..20] == [u8(0), 0, 0, 0]
	context.clear_rect(0, 0, 2, 1)
	assert bitmap.native_rows_are_top_down
}
