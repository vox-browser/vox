module main

import dom
import encoding.base64
import layout

fn test_native_request_pixels_are_shared_only_for_compatible_pngs() {
	bytes := base64.decode(asymmetric_raster_png)
	decoded := browser_decoded_image_data(dom.URL{ value: 'https://image-reuse.test/rows.png' }, bytes)!
	frame := decoded.frame(0) or { panic('missing PNG frame') }
	bitmap := frame.bitmap()
	$if macos {
		assert browser_raster_can_share_native_pixels(bytes)
		assert bitmap.native_resource_replay_compatible
	} $else {
		assert !bitmap.native_resource_replay_compatible
	}
	assert bitmap.native_rows_are_top_down
	assert bitmap.data == [u8(255), 0, 0, 255, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255]
	assert !browser_raster_can_share_native_pixels(base64.decode(native_jpeg_test_image))
	assert !browser_raster_can_share_native_pixels('RIFF0000WEBP'.bytes())
	assert !browser_raster_can_share_native_pixels([]u8{})
}

fn test_native_request_pixel_sharing_keeps_profiled_pngs_on_the_url_path() {
	$if !macos {
		return
	}
	// Insert a valid gAMA chunk before IDAT in the same asymmetric PNG.
	chunk := base64.decode('AAAABGdBTUEAAYagMeiWXw==')
	mut profiled := base64.decode(asymmetric_raster_png)
	profiled.insert(33, chunk)
	assert !browser_raster_can_share_native_pixels(profiled)
	decoded := browser_decoded_image_data(dom.URL{ value: 'https://image-reuse.test/gamma.png' }, profiled)!
	frame := decoded.frame(0) or { panic('missing profiled PNG frame') }
	assert !frame.bitmap().native_resource_replay_compatible
	assert frame.bitmap().data.len == 16
}

fn test_shared_request_bitmap_selection_preserves_portable_resource_uploads() {
	bitmap := &dom.Bitmap_{ native_resource_replay_compatible: true }
	command := layout.PaintCommand{ replaced_image_bitmap: bitmap }
	native := replaced_image_bitmap_for_renderer(&command, true) or { panic('missing shared bitmap') }
	assert voidptr(native) == voidptr(bitmap)
	assert replaced_image_bitmap_for_renderer(&command, false) == none
	object_bitmap := &dom.Bitmap_{}
	object_command := layout.PaintCommand{ replaced_image_bitmap: object_bitmap }
	portable := replaced_image_bitmap_for_renderer(&object_command, false) or { panic('missing object bitmap') }
	assert voidptr(portable) == voidptr(object_bitmap)
	assert replaced_image_bitmap_for_renderer(&layout.PaintCommand{}, true) == none
}
