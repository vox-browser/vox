// vtest build: macos
module main

import stbi

fn test_repeated_background_callback_keeps_brave_pixels_in_owning_tiles_and_gutters() {
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{ width: 1024, height: 256, columns: 1, rows: 4, cells: [
		i32(0),
		1,
		2,
		3,
	] }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/resources/reddit-ui-sprite.png').to_bytes()
	image := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { image.free() }
	expected_bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/rounded-repeated-sprite-border.png').to_bytes()
	expected := stbi.load_from_memory(expected_bytes.data, expected_bytes.len, desired_channels: 4) or { panic(err) }
	defer { expected.free() }
	color := [u8(255), 255, 255, 255]!
	for top in [186, 247, 440] {
		first_x, first_y := 715, top - 4
		clip := [f32(4), 4, 35, 16, 3, 3, 3, 3, 3, 3, 3, 3]!
		border := C.VoxGraphiteShape{
			matrix:     [f32(1), 0, -f32(first_x), 0, 1, -f32(first_y), 0, 0, 1]!
			rect:       [f32(719.5), f32(top) + 0.5, 34, 15, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5,
				2.5]!
			fill:       0
			thickness:  1
			anti_alias: 1
			red:        68
			green:      68
			blue:       68
			alpha:      255
		}
		mut pixels := []u8{len: 43 * 24 * 4, init: 255}
		assert document_repeated_background_pixels(pixels.data, 43, 24, 43 * 4, i32(first_x), i32(first_y),
			image.data, i32(image.width), i32(image.height), 5, 5, &clip[0], &color[0], &border) == 1
		for y in 0 .. 24 {
			for x in 0 .. 43 {
				// Translate the fixed Brave decoration crop, excluding its separately painted label.
				rx, ry := x + 715, y + 182
				if rx >= 725 && rx < 748 && ry >= 188 && ry < 201 { continue }
				i := (y * 43 + x) * 4
				ri := (ry * 1024 + rx) * 4
				assert pixels[i..i + 4] == unsafe { expected.data.vbytes(1024 * 768 * 4)[ri..ri + 4] }
			}
		}
	}
}

fn test_repeated_background_callback_rejects_invalid_stride_before_touching_pixels() {
	mut pixels := []u8{len: 16, init: 137}
	clip := [f32(0), 0, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1]!
	color := [u8(255), 255, 255, 255]!
	border := C.VoxGraphiteShape{}
	assert document_repeated_background_pixels(pixels.data, 2, 2, 4, 0, 0, pixels.data, 2, 2,
		0, 0, &clip[0], &color[0], &border) == 0
	assert pixels == []u8{len: 16, init: 137}
}
