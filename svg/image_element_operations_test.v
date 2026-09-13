module svg

fn decode_test_svg_image(url string) !DecodedImageData {
	if url == 'broken.svg' {
		return error('decode failed')
	}
	return DecodedImageData{
		width:                 40
		height:                20
		surface_bytes:         [u8(1), 2, 3, 4]
		display_list_commands: ['save', 'paint', 'restore']
		frame_count:           2
	}
}

fn test_image_element_resource_pipeline_uses_decoded_state() {
	mut image := new_element('image')
	image.attributes['href'] = 'picture.svg'
	image.image_fetch_decode_hook_ = decode_test_svg_image

	image.process_the_url()

	assert image.image_resource.state == .ready
	assert image.is_image_available()
	assert image.intrinsic_width()? == 40
	assert image.intrinsic_height()? == 20
	assert image.intrinsic_aspect_ratio()? == 2
	assert image.content_rect()? == Rect{ width: 40, height: 20 }
	assert image.current_image_frame()?.width() == 40
	assert image.current_image_frame_sized(10, 10)?.bitmap().data == [u8(1), 2, 3, 4]
	assert image.default_image_frame_sized(10, 10)?.bitmap().data == [u8(1), 2, 3, 4]
	assert image.decoded_image_data()?.record_display_list() == ['save', 'paint', 'restore']
	assert image.decoded_image_data()?.paint() == [u8(1), 2, 3, 4]

	assert image.current_frame_index() == 0
	image.animate()
	assert image.current_frame_index() == 1
	image.animate()
	assert image.current_frame_index() == 0
}

fn test_image_element_resource_pipeline_tracks_empty_and_failed_urls() {
	mut image := new_element('image')
	image.image_fetch_decode_hook_ = decode_test_svg_image

	image.process_the_url()
	assert image.image_resource.state == .unavailable
	assert !image.is_image_available()

	image.attributes['href'] = 'broken.svg'
	image.process_href()
	assert image.image_resource.state == .failed
	assert !image.is_image_available()
}
