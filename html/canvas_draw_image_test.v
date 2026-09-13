@[has_globals]
module html

import dom

__global (
	canvas_draw_image_requests = []CanvasDrawImageRequest{}
)

fn record_canvas_draw_image(request CanvasDrawImageRequest) ! {
	canvas_draw_image_requests << request
}

fn test_canvas_draw_image_overloads_supply_spec_defaults() {
	canvas_draw_image_requests.clear()
	mut image_bitmap := ImageBitmap.create()
	image_bitmap.set_bitmap(&dom.Bitmap_{ width: 20, height: 10 })
	source := CanvasImageSource(ImageBitmapCanvasSource{
		value: image_bitmap
	})
	draw := CanvasDrawImage.create(record_canvas_draw_image)
	draw.draw_image(source, 4, 5) or { panic(err) }
	draw.draw_image_scaled(source, 1, 2, 40, 30) or { panic(err) }
	draw.draw_image_rect(source, 2, 3, 4, 5, 6, 7, 8, 9) or { panic(err) }
	assert canvas_draw_image_requests.len == 3
	assert canvas_draw_image_requests[0].source_width == 20
	assert canvas_draw_image_requests[0].destination_width == 20
	assert canvas_draw_image_requests[0].destination_x == 4
	assert canvas_draw_image_requests[1].source_height == 10
	assert canvas_draw_image_requests[1].destination_height == 30
	assert canvas_draw_image_requests[2].source_x == 2
	assert canvas_draw_image_requests[2].destination_height == 9
}
