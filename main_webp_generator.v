module main

// Blink's DeferredImageDecoder retains an RGB generator when enough image
// data arrived to create it before the response completed. Completing that
// stream must not replace its pixels with a new YUV decode. A complete body
// from the HTTP cache can still select YUV on its first decode.
fn webp_has_incremental_generator(bytes []u8, available_before_completion u64) bool {
	// The simple lossy VP8 header exposes its size in the first 30 bytes.
	// Extended, tagged, lossless and animated streams already retain RGB.
	return available_before_completion >= 30 && bytes.len >= 30
		&& bytes[..4].bytestr() == 'RIFF' && bytes[8..16].bytestr() == 'WEBPVP8 '
}

fn (app &BrowserApp) webp_generator_requires_rgb(address string, bytes []u8) bool {
	resource := app.resource_cache[address] or { return false }
	return resource.body.len == bytes.len && resource.body == bytes.bytestr()
		&& webp_has_incremental_generator(bytes, resource.bytes_available_before_completion)
}
