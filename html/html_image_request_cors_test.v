module html

import dom

fn test_image_request_preserves_fetch_reported_taint_for_an_initially_same_origin_url() {
	mut document := dom.Document.create(dom.URL{ value: 'https://image-origin.test/page' })
	defer { document.finalize() }
	mut image := HTMLImageElementModel.create(document, document.url)
	image.set_fetch_hook(fn (_ dom.URL) !DecodedImageData {
		bitmap := &dom.Bitmap_{ width: 1, height: 1, pitch: 4, data: [u8(255), 0, 0, 255] }
		decoded := BitmapDecodedImageData.create([
			BitmapDecodedImageFrame{
				frame: dom.DecodedImageFrame_.create(bitmap)
			},
		], 0, false)
		decoded.set_is_cors_cross_origin(true)
		return decoded
	})
	image.set_src('/redirected.png')
	image.update_the_image_data(false, false)
	decoded := image.decoded_image_data() or { panic('missing decoded image') }
	assert decoded.is_cors_cross_origin()
}
