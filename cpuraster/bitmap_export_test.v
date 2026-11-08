module cpuraster

import crypto.sha256

fn test_bitmap_export_uses_source_skia_premultiplication_flip_and_nearest_scaling() {
	bitmap := BitmapSource{
		width:  2
		height: 2
		pixels: [u8(200), 100, 50, 128, 0, 255, 0, 255, 0, 0, 255, 255, 255, 255, 0, 255]
	}
	premultiplied := export_bitmap_to_byte_buffer(bitmap, .rgba8888, false, true, none, none)!
	assert premultiplied.pixels[..4] == [u8(100), 50, 25, 128]
	flipped := export_bitmap_to_byte_buffer(bitmap, .rgba8888, true, false, none, none)!
	assert flipped.pixels[..8] == bitmap.pixels[8..]
	scaled := export_bitmap_to_byte_buffer(bitmap, .rgba8888, false, false, 4, 4)!
	assert scaled.width == 4 && scaled.height == 4
	assert scaled.pixels[..4] == [u8(200), 100, 50, 128]
	assert scaled.pixels[60..] == [u8(255), 255, 0, 255]
	alpha := export_bitmap_to_byte_buffer(bitmap, .alpha8, false, false, none, none)!
	assert alpha.pixels == [u8(128), 255, 255, 255]
	rgb := export_bitmap_to_byte_buffer(bitmap, .rgb888, true, true, 8, 8)!
	assert rgb.width == 2 && rgb.height == 2
	assert rgb.pixels == [u8(0), 0, 255, 255, 255, 0, 200, 100, 50, 0, 255, 0]
}

fn test_bitmap_export_preserves_native_alpha_layout_and_source_unsupported_format() {
	bitmap := BitmapSource{
		width:      1
		height:     1
		layout:     1
		alpha_type: 2
		pixels:     [u8(25), 50, 100, 128]
	}
	straight := export_bitmap_to_byte_buffer(bitmap, .rgba8888, false, false, none, none)!
	assert straight.pixels == [u8(199), 100, 50, 128]
	if _ := export_bitmap_to_byte_buffer(bitmap, .rgba5551, false, false, none, none) {
		assert false
	}
	assert (export_bitmap_to_byte_buffer(bitmap, .rgba8888, false, false, 0, 0)!).pixels.len == 0
	negative := export_bitmap_to_byte_buffer(bitmap, .rgba8888, false, false, -1, 1)!
	assert negative.width == -1 && negative.pixels.len == 0
}

fn export_table(layout int, alpha_type int, color_space int) BitmapSource {
	mut pixels := []u8{len: 256 * 256 * 4}
	for alpha in 0 .. 256 {
		for value in 0 .. 256 {
			offset := (alpha * 256 + value) * 4
			pixels[offset] = u8(value)
			pixels[offset + 1] = u8(255 - value)
			pixels[offset + 2] = u8(value ^ 0x5a)
			pixels[offset + 3] = u8(alpha)
		}
	}
	return BitmapSource{
		width:       256
		height:      256
		layout:      layout
		alpha_type:  alpha_type
		color_space: color_space
		pixels:      pixels
	}
}

fn export_hash(bitmap BitmapSource, format BitmapExportFormat, flip bool, premultiply bool, width ?int, height ?int) string {
	exported := export_bitmap_to_byte_buffer(bitmap, format, flip, premultiply, width, height) or {
		panic(err)
	}
	return sha256.sum(exported.pixels).hex()[..16]
}

// LibWeb Skia's exports of every channel/alpha pair (test_cpu_raster.sh
// compares every configuration): lowp premultiplication and 565 rounding,
// highp luminance and 4444 unpremultiplication, Display P3 conversion, and the
// legacy fixed-point sampler of premultiplied RGBA scaled into RGBA_8888.
fn test_bitmap_export_matches_skia_pipelines() {
	assert export_hash(export_table(1, 1, 0), .rgb565, true, false, none, none) == 'e81779f80c42b8ca'
	assert export_hash(export_table(0, 1, 0), .gray8, false, false, 300, 200) == 'c0b31daae1fd6fd9'
	assert export_hash(export_table(3, 1, 0), .rgba4444, false, false, none, none) == 'ffa6145a2d62158e'
	assert export_hash(export_table(0, 2, 1), .rgba8888, true, false, 173, 311) == '02e1e9e9dc8e541c'
	assert export_hash(export_table(2, 1, 1), .gray8, false, true, none, none) == 'c789f7ef07129beb'
	assert export_hash(export_table(0, 2, 0), .rgba8888, true, true, 97, 401) == '88d2a51f84ada28c'
}

// Native oracle_bitmap_export: [15,14,60,0,2,0,6,3,15,49]. The vertical
// scale places row 3 on a nearest-sampling boundary. The legacy N32 sampler
// selects source row 12; Linux's RGBA raster pipeline selects row 13.
fn test_bitmap_export_uses_platform_sampler_at_flipped_scale_boundary() {
	mut pixels := []u8{cap: 15 * 14 * 4}
	for y in 0 .. 14 {
		for x in 0 .. 15 {
			pixels << [u8(x * 13), u8(y * 17), u8((x + y) * 7), u8(255)]
		}
	}
	bitmap := BitmapSource{width: 15, height: 14, alpha_type: 2, pixels: pixels}
	exported := export_bitmap_to_byte_buffer(bitmap, .rgba8888, true, true, none, 49)!
	$if linux {
		assert exported.pixels[180..184] == [u8(0), 221, 91, 255]
		assert sha256.sum(exported.pixels).hex() == 'ce153c76536c482a662970ed77277ecf8654692d6fd5efb536a9a4bfdf983024'
	} $else {
		assert exported.pixels[180..184] == [u8(0), 204, 84, 255]
		assert sha256.sum(exported.pixels).hex() == '590b5ffa98fd8856a615d38a55fbd0a142d3a0d4df8691932ecff920267b24ef'
	}
}
