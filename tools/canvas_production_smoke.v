// Run with -enable-globals -prod -gc none. This is a regular
// executable so assertions cannot accidentally retain library drawing calls.
module main

import html

fn main() {
	mut canvas := html.OffscreenCanvas.create(8, 8)!
	mut context := canvas.get_context(.canvas_2d, none)!
	context.fill_rect(0, 0, 8, 8)
	if (context.get_image_data(2, 2, 1, 1, none)!).data() != [u8(0), 0, 0, 255] {
		panic('production canvas path did not draw')
	}
	context.set_filter('invert(100%)')
	context.fill_rect(0, 0, 8, 8)
	if (context.get_image_data(2, 2, 1, 1, none)!).data() != [u8(255), 255, 255, 255] {
		panic('production canvas filter did not draw')
	}
	context.clear_rect(0, 0, 8, 8)
	if (context.get_image_data(2, 2, 1, 1, none)!).data() != [u8(0), 0, 0, 0] {
		panic('production canvas clearing did not draw')
	}
	image := context.create_image_data(1, 1, none)!
	mut data := image.data()
	data[0] = 255
	data[3] = 255
	context.put_image_data(image, 0, 0)
	context.draw_image_internal(html.CanvasDrawImageRequest{ image: html.ImageBitmapCanvasSource{ value: canvas.transfer_to_image_bitmap()! }, source_width: 1, source_height: 1, destination_x: 4, destination_y: 4, destination_width: 1, destination_height: 1 })!
	if (context.get_image_data(4, 4, 1, 1, none)!).data() != [u8(0), 255, 255, 255] {
		panic('production canvas bitmap did not draw')
	}
	mut text_canvas := html.OffscreenCanvas.create(48, 48)!
	mut text_context := text_canvas.get_context(.canvas_2d, none)!
	text_context.set_font('24px sans-serif')
	text_context.fill_text('O', 0, 30, none)
	text_pixels := (text_context.get_image_data(0, 0, 48, 48, none)!).data()
	mut painted_text_pixels := 0
	for index := 3; index < text_pixels.len; index += 4 {
		if text_pixels[index] > 0 { painted_text_pixels++ }
	}
	if painted_text_pixels == 0 {
		panic('production canvas glyph text did not draw')
	}
	println('production canvas path, filter, clear, bitmap and glyph smoke passed')
}
