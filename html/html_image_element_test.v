module html

import dom

fn image_test_fetch(url dom.URL) !DecodedImageData {
	if url.serialize().contains('broken') {
		return error('decode failed')
	}
	bitmap := &dom.ImmutableBitmap_{
		width:  200
		height: 100
		pitch:  800
		data:   []u8{len: 200 * 100 * 4}
	}
	return BitmapDecodedImageData.create([
		BitmapDecodedImageFrame{ bitmap: bitmap, duration: 10 },
		BitmapDecodedImageFrame{ bitmap: bitmap, duration: 10 },
	], 1, true)
}

fn test_image_source_selection_load_dimensions_and_decode() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/page' })
	mut image := HTMLImageElementModel.create(document, document.base_url())
	image.set_fetch_hook(image_test_fetch)
	image.set_src('/fallback.png')
	image.set_srcset('/one.png 1x, /two.png 2x')
	image.update_the_image_data(false, false)
	assert image.complete()
	assert image.current_src() == 'https://example.test/one.png'
	assert image.natural_width() == 200
	assert image.natural_height() == 100
	assert image.width() == 200
	assert image.height() == 100
	assert image.event_count('load') == 1
	assert image.decode().state() == .fulfilled
	image.set_width(50)
	image.set_height(25)
	assert image.width() == 50
	assert image.height() == 25
}

fn test_image_failure_empty_lazy_sizes_and_animation() {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut empty := HTMLImageElementModel.create(document, document.base_url())
	assert empty.complete()
	empty.set_loading(.lazy)
	empty.set_sizes('AUTO, 100vw')
	assert empty.allows_auto_sizes()

	mut broken := HTMLImageElementModel.create(document, document.base_url())
	broken.set_fetch_hook(image_test_fetch)
	broken.set_src('/broken.png')
	broken.update_the_image_data(false, false)
	assert broken.complete()
	assert broken.current_request().state() == .broken
	assert broken.event_count('error') == 1
	assert broken.decode().state() == .rejected

	mut animated := HTMLImageElementModel.create(document, document.base_url())
	animated.set_fetch_hook(image_test_fetch)
	animated.set_src('/animated.png')
	animated.update_the_image_data(false, false)
	animated.animate()
	assert animated.current_frame_index() == 1
	animated.animate()
	assert animated.current_frame_index() == 1
	animated.restart_the_animation()
	assert animated.current_frame_index() == 0
}
