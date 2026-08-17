module html

import dom

fn fake_png_encoder(bitmap &dom.ImmutableBitmap_) ![]u8 {
	return [u8(0x50), u8(bitmap.width), u8(bitmap.height)]
}

fn fake_jpeg_encoder(bitmap &dom.ImmutableBitmap_, quality ?int) ![]u8 {
	return [u8(0x4a), u8(quality or { 75 }), u8(bitmap.width)]
}

fn test_serialize_bitmap_selects_codec_and_quality() {
	bitmap := &dom.ImmutableBitmap_{
		width:  10
		height: 20
	}
	jpeg := serialize_bitmap(bitmap, 'IMAGE/JPEG', 0.42, fake_png_encoder, fake_jpeg_encoder)!
	assert jpeg.mime_type == 'image/jpeg'
	assert jpeg.buffer == [u8(0x4a), 42, 10]

	default_quality := serialize_bitmap(bitmap, 'image/jpeg', 2.0, fake_png_encoder,
		fake_jpeg_encoder)!
	assert default_quality.buffer == [u8(0x4a), 75, 10]

	png := serialize_bitmap(bitmap, 'image/unsupported', 0.5, fake_png_encoder, fake_jpeg_encoder)!
	assert png.mime_type == 'image/png'
	assert png.buffer == [u8(0x50), 10, 20]
}
