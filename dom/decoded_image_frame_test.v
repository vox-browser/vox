module dom

fn test_decoded_image_frame_retains_bitmap_geometry_and_color_space() {
	bitmap := &ImmutableBitmap_{
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
	bitmap := &ImmutableBitmap_{
		width:      1
		height:     1
		pitch:      4
		format:     7
		alpha_type: 1
		data:       [u8(10), 20, 30, 40]
	}
	unchanged := DecodedImageFrame_.create_with_alpha_type(bitmap, 1, .srgb)
	assert unchanged.bitmap() == bitmap

	converted := DecodedImageFrame_.create_with_alpha_type(bitmap, 2, .display_p3)
	assert converted.bitmap() != bitmap
	assert converted.bitmap().alpha_type == 2
	assert converted.bitmap().format == 7
	assert converted.bitmap().data == bitmap.data
	assert converted.color_space() == .display_p3
}
