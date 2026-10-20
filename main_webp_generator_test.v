module main

import os

fn test_webp_generator_retains_rgb_only_after_a_partial_decodable_header() {
	bytes := os.read_bytes(os.join_path(@DIR, 'Tests/Browser/Brave/input/decode-texture.webp'))!
	assert !webp_has_incremental_generator(bytes, 0)
	assert !webp_has_incremental_generator(bytes, 29)
	assert webp_has_incremental_generator(bytes, 30)
	assert webp_has_incremental_generator(bytes, 128)
	assert !webp_has_incremental_generator(bytes[..20], 128)
	assert !webp_has_incremental_generator('not a webp'.bytes(), 128)
}

fn test_webp_paint_generator_does_not_reuse_progress_from_replaced_response_bytes() {
	bytes := os.read_bytes(os.join_path(@DIR, 'Tests/Browser/Brave/input/decode-texture.webp'))!
	address := 'https://image.test/stream.webp'
	mut app := BrowserApp{resource_cache: {address: PreloadedResource{
		url: address
		body: bytes.bytestr()
		bytes_available_before_completion: 128
	}}}
	assert app.webp_generator_requires_rgb(address, bytes)
	assert !app.webp_generator_requires_rgb('https://image.test/other.webp', bytes)
	mut replacement := bytes.clone()
	replacement[replacement.len - 1] ^= 1
	assert !app.webp_generator_requires_rgb(address, replacement)
	app.resource_cache[address] = PreloadedResource{url: address, body: bytes.bytestr()}
	assert !app.webp_generator_requires_rgb(address, bytes)
}
