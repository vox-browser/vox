module html

import dom
import math

fn offscreen_test_png(bitmap &dom.ImmutableBitmap_) ![]u8 {
	return [u8(bitmap.width), u8(bitmap.height)]
}

fn offscreen_test_jpeg(bitmap &dom.ImmutableBitmap_, quality ?int) ![]u8 {
	return [u8(bitmap.width), u8(quality or { 0 })]
}

fn test_offscreen_canvas_2d_pixels_resize_and_transfer() {
	mut canvas := OffscreenCanvas.create(4, 3) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.fill_rect(1, 1, 2, 1)
	image := context.get_image_data(0, 0, 4, 3, none) or { panic(err) }
	assert image.data()[20..24] == [u8(255), 0, 0, 255]
	assert image.data()[0..4] == [u8(0), 0, 0, 0]

	context.clear_rect(1, 1, 1, 1)
	cleared := context.get_image_data(1, 1, 1, 1, none) or { panic(err) }
	assert cleared.data() == [u8(0), 0, 0, 0]

	context.drawing_state.global_alpha = 0.25
	canvas.set_width(2) or { panic(err) }
	assert context.global_alpha() == 1.0
	assert canvas.width() == 2
	assert canvas.height() == 3

	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ g: 255, a: 255 })
	context.fill_rect(0, 0, 2, 3)
	bitmap := canvas.transfer_to_image_bitmap() or { panic(err) }
	assert bitmap.width() == 2
	assert bitmap.bitmap() or { panic('missing bitmap') }.data[1] == 255
	assert canvas.bitmap() or { panic('missing replacement') }.data[1] == 0
}

fn test_offscreen_canvas_image_data_draw_image_blob_and_transfer() {
	mut source_pixels := &dom.ImmutableBitmap_{
		width: 1
		height: 1
		pitch: 4
		data: [u8(10), 20, 30, 255]
	}
	mut source := ImageBitmap.create()
	source.set_bitmap(source_pixels)
	mut canvas := OffscreenCanvas.create(2, 2) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.draw_image_internal(CanvasDrawImageRequest{
		image: ImageBitmapCanvasSource{
			value: source
		}
		source_width: 1
		source_height: 1
		destination_width: 2
		destination_height: 2
	}) or { panic(err) }
	assert (context.get_image_data(0, 0, 1, 1, none) or { panic(err) }).data() == [
		u8(10),
		20,
		30,
		255,
	]

	encoded := canvas.convert_to_blob(ImageEncodeOptions{ type_: 'image/jpeg', quality: 0.5 }, offscreen_test_png, offscreen_test_jpeg) or { panic(err) }
	assert encoded.mime_type == 'image/jpeg'
	assert encoded.buffer == [u8(2), 50]

	transfer_data := canvas.transfer_steps()
	assert canvas.width() == 0
	received := offscreen_canvas_transfer_receiving_steps(transfer_data) or { panic(err) }
	assert received.width() == 2
	assert received.height() == 2
}

fn test_offscreen_canvas_draw_image_snapshots_an_overlapping_self_source() {
	mut canvas := OffscreenCanvas.create(4, 1) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	bitmap := canvas.bitmap() or { panic('missing bitmap') }
	mut mutable_bitmap := unsafe { &dom.ImmutableBitmap_(bitmap) }
	mutable_bitmap.data = [
		u8(255),
		0,
		0,
		255,
		u8(0),
		0,
		255,
		255,
		u8(0),
		255,
		0,
		255,
		u8(255),
		255,
		255,
		255,
	]
	mut image := ImageBitmap.create()
	image.set_bitmap(bitmap)
	context.draw_image_internal(CanvasDrawImageRequest{
		image: ImageBitmapCanvasSource{ value: image }
		source_width: 3
		source_height: 1
		destination_x: 1
		destination_width: 3
		destination_height: 1
	}) or { panic(err) }
	assert bitmap.data == [
		u8(255),
		0,
		0,
		255,
		u8(255),
		0,
		0,
		255,
		u8(0),
		0,
		255,
		255,
		u8(0),
		255,
		0,
		255,
	]
}

fn test_offscreen_canvas_paths_transform_winding_and_clip() {
	mut canvas := OffscreenCanvas.create(12, 8) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.begin_path()
	context.rect(0, 0, 2, 2)
	context.set_transform(CanvasAffineTransform{ e: 5, f: 2 })
	assert context.is_point_in_path(5.5, 2.5, 'nonzero')
	assert !context.is_point_in_path(0.5, 0.5, 'nonzero')
	context.fill('nonzero')
	assert (context.get_image_data(5, 2, 1, 1, none) or { panic(err) }).data() == [
		u8(255),
		0,
		0,
		255,
	]
	assert (context.get_image_data(0, 0, 1, 1, none) or { panic(err) }).data() == [
		u8(0),
		0,
		0,
		0,
	]

	context.clear_rect(0, 0, 12, 8)
	context.set_transform(CanvasAffineTransform{})
	context.begin_path()
	context.rect(0, 0, 4, 4)
	context.rect(1, 1, 2, 2)
	context.fill('evenodd')
	assert (context.get_image_data(0, 0, 1, 1, none) or { panic(err) }).data()[3] == 255
	assert (context.get_image_data(1, 1, 1, 1, none) or { panic(err) }).data()[3] == 0
	context.fill('nonzero')
	assert (context.get_image_data(1, 1, 1, 1, none) or { panic(err) }).data()[3] == 255

	context.clear_rect(0, 0, 12, 8)
	context.begin_path()
	context.rect(0, 0, 2, 2)
	context.clip('nonzero')
	context.fill_rect(0, 0, 4, 4)
	assert (context.get_image_data(1, 1, 1, 1, none) or { panic(err) }).data()[3] == 255
	assert (context.get_image_data(3, 3, 1, 1, none) or { panic(err) }).data()[3] == 0
}

fn test_offscreen_canvas_rasterizes_arcs_and_reset_clears_the_current_path() {
	mut canvas := OffscreenCanvas.create(16, 16) or { panic(err) }
	mut context := canvas.get_context(.canvas_2d, none) or { panic(err) }
	context.drawing_state.fill_style = FillOrStrokeStyle.from_color(dom.Color{ r: 255, a: 255 })
	context.begin_path()
	context.arc(8, 8, 6, 0, 2 * math.pi, false) or { panic(err) }
	context.fill('nonzero')
	assert (context.get_image_data(8, 8, 1, 1, none) or { panic(err) }).data()[3] == 255
	assert (context.get_image_data(0, 0, 1, 1, none) or { panic(err) }).data()[3] == 0

	context.set_global_alpha(0.25)
	context.save()
	context.reset()
	assert context.global_alpha() == 1.0
	assert context.drawing_state_stack_depth() == 0
	assert context.CanvasPath.path().is_empty()
}
