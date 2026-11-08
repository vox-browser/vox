module dom

fn test_decoded_image_frame_retains_bitmap_geometry_and_color_space() {
	bitmap := &Bitmap_{
		width:      3
		height:     2
		pitch:      12
		format:     7
		alpha_type: 1
		data:       [u8(1), 2, 3, 4]
	}
	frame := DecodedImageFrame_.create_with_color_space(bitmap, .display_p3)
	assert frame.bitmap() == bitmap
	assert frame.width() == 3
	assert frame.height() == 2
	assert frame.color_space() == .display_p3
}

fn test_decoded_image_frame_clones_only_for_alpha_type_conversion() {
	bitmap := &Bitmap_{
		width:                             1
		height:                            1
		pitch:                             4
		format:                            7
		alpha_type:                        1
		data:                              [u8(10), 20, 30, 40]
		native_rows_are_top_down:          true
		native_resource_replay_compatible: true
	}
	unchanged := DecodedImageFrame_.create_with_alpha_type(bitmap, 1, .srgb)
	assert unchanged.bitmap() == bitmap

	converted := DecodedImageFrame_.create_with_alpha_type(bitmap, 2, .display_p3)
	assert converted.bitmap() != bitmap
	assert converted.bitmap().alpha_type == 2
	assert converted.bitmap().format == 7
	assert converted.bitmap().data == bitmap.data
	assert converted.bitmap().native_rows_are_top_down
	assert converted.bitmap().native_resource_replay_compatible
	clone := bitmap.clone()
	assert clone.native_resource_replay_compatible
	assert clone.native_rows_are_top_down
	assert clone.data.data != bitmap.data.data
	assert converted.color_space() == .display_p3
}

fn test_capture_the_image_returns_a_decoded_frame() {
	element := &Element{}
	frame := element.capture_the_image()
	assert frame.width() == 1
	assert frame.height() == 1
	assert frame.color_space() == .srgb
}

__global deferred_bitmap_decodes int

fn test_deferred_bitmap_reports_its_size_and_decodes_once_on_first_pixel_read() {
	deferred_bitmap_decodes = 0
	bitmap := Bitmap_.create_deferred(3, 2, fn (mut target Bitmap_) {
		deferred_bitmap_decodes++
		target.data = []u8{len: target.pitch * target.height, init: u8(index)}
	})
	frame := DecodedImageFrame_.create(bitmap)
	assert frame.width() == 3 && frame.height() == 2
	assert frame.deferred_bitmap() == bitmap
	assert !bitmap.has_pixels()
	assert bitmap.pitch == 12
	assert bitmap.pixel_byte_size() == 24
	assert deferred_bitmap_decodes == 0
	pixels := frame.bitmap()
	assert pixels == bitmap
	assert bitmap.has_pixels()
	assert deferred_bitmap_decodes == 1
	assert pixels.data.len == 24 && pixels.data[5] == 5
	_ = frame.bitmap()
	bitmap.ensure_pixels()
	assert deferred_bitmap_decodes == 1
	assert bitmap.pixel_byte_size() == 24
}

fn test_cloning_or_converting_a_deferred_bitmap_decodes_its_pixels() {
	deferred_bitmap_decodes = 0
	decoder := fn (mut target Bitmap_) {
		deferred_bitmap_decodes++
		target.data = []u8{len: target.pitch * target.height, init: 7}
	}
	first := Bitmap_.create_deferred(1, 1, decoder)
	copy := first.clone()
	assert first.has_pixels() && copy.has_pixels()
	assert copy.data == [u8(7), 7, 7, 7]
	second := Bitmap_.create_deferred(1, 1, decoder)
	converted := DecodedImageFrame_.create_with_alpha_type(second, 2, .srgb)
	assert converted.bitmap().data == [u8(7), 7, 7, 7]
	assert converted.bitmap().alpha_type == 2
	assert deferred_bitmap_decodes == 2
}
