// vtest build: macos
module main

import html
import layout
import stbi
import os

#flag darwin -DVOX_TEST_CSS_GRADIENT_PIXELS

fn C.vox_test_css_gradient_pixels(&u8, i32, i32, i32, &C.VoxGraphitePath) i32

fn test_css_radial_gradient_keeps_premultiplied_dither_through_the_native_boundary() {
	mut document := html.parse_document($embed_file('@VMODROOT/Tests/Browser/Brave/input/css-radial-gradient.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	commands := layout.display_list_commands(document.record_display_list() or { panic('display list') })
	command := commands.filter(it.kind == 'fill_gradient')[0]
	gradient := command.gradient or { panic('gradient') }
	tile := layout.resolved_background_gradient_tiles(command)[0]
	geometry := chromium_radial_gradient_geometry(gradient, tile)
	mut stop_data := []f32{}
	assert chromium_gradient_stop_data_into(gradient, 1, mut stop_data)
	segments := native_gradient_clip_path(command, tile)
	path := C.VoxGraphitePath{
		segments:        segments.data
		segment_count:   segments.len / layout.compatibility_clip_path_segment_stride
		gradient:        2
		gradient_premul: 1
		stop_count:      stop_data.len / 5
		stops:           stop_data.data
		gradient_points: [geometry[0], geometry[1], geometry[2], geometry[3], geometry[4], geometry[5]]!
		gradient_matrix: [geometry[6], geometry[8], geometry[10], geometry[7], geometry[9],
			geometry[11], f32(0), 0, 1]!
		opacity:         1
	}
	png := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/css-radial-gradient.png').to_bytes()
	expected := stbi.load_from_memory(png.data, png.len, desired_channels: 4) or { panic('${err}') }
	defer { expected.free() }
	assert expected.width == 800 && expected.height == 600
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	for chrome in [0, 60] {
		document_geometry_grid = DocumentGeometryGrid{ width: 832, height: 256, columns: 1, rows: 3, cells: [i32(0)] }
		mut pixels := []u8{len: 800 * (600 + chrome) * 4}
		assert C.vox_test_css_gradient_pixels(pixels.data, 800, 600, i32(chrome), &path) == 1
		mut count := 0
		for i in 0 .. 800 * 180 * 4 {
			if pixels[chrome * 800 * 4 + i] != unsafe { expected.data[i] } { count++ }
		}
		if output := os.getenv_opt('VOX_GRADIENT_TEST_OUTPUT') {
			os.write_file_array('${output}-${chrome}.rgba', pixels) or { panic('${err}') }
		}
		assert count == 0, 'chrome=${chrome} differing channels=${count}'
	}
}

fn test_css_linear_and_radial_fades_keep_rounded_clips_and_tile_dither() {
	mut document := html.parse_document($embed_file('@VMODROOT/Tests/Browser/Brave/input/css-premultiplied-fades.html').to_string())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('display list') })
	png := $embed_file('@VMODROOT/Tests/Browser/Brave/expected/css-premultiplied-fades.png').to_bytes()
	expected := stbi.load_from_memory(png.data, png.len, desired_channels: 4) or { panic('${err}') }
	defer { expected.free() }
	previous := document_geometry_grid
	defer { document_geometry_grid = previous }
	document_geometry_grid = DocumentGeometryGrid{ width: 1024, height: 256, columns: 1, rows: 4, cells: [
		i32(0),
		1,
		2,
	] }
	mut tested := 0
	for command in commands {
		if command.kind != 'fill_gradient' { continue }
		gradient := command.gradient or { panic('gradient') }
		tile := layout.resolved_background_gradient_tiles(command)[0]
		segments := native_gradient_clip_path(command, tile)
		mut stop_data := []f32{}
		assert chromium_gradient_stop_data_into(gradient, 1, mut stop_data)
		mut path := C.VoxGraphitePath{
			segments:        segments.data
			segment_count:   segments.len / layout.compatibility_clip_path_segment_stride
			gradient_premul: 1
			stop_count:      stop_data.len / 5
			stops:           stop_data.data
			opacity:         1
			has_clip:        1
			clip:            chromium_gradient_clip_data(command)
		}
		if gradient.kind == 'radial' {
			geometry := chromium_radial_gradient_geometry(gradient, tile)
			path.gradient = 2
			path.gradient_points = [geometry[0], geometry[1], geometry[2], geometry[3], geometry[4],
				geometry[5]]!
			path.gradient_matrix = [geometry[6], geometry[8], geometry[10], geometry[7], geometry[9],
				geometry[11], f32(0), 0, 1]!
		} else {
			points := chromium_linear_gradient_points(gradient, tile)
			path.gradient = 1
			path.gradient_points = [points[0], points[1], points[2], points[3], f32(0), 0]!
			path.gradient_matrix = [f32(1), 0,
				if gradient.css_angle_degrees != none { f32(tile.x) } else { f32(0) }, 0, 1,
				if gradient.css_angle_degrees != none { f32(tile.y) } else { f32(0) }, 0, 0, 1]!
		}
		mut pixels := []u8{len: 1024 * (768 + 60) * 4}
		assert C.vox_test_css_gradient_pixels(pixels.data, 1024, 768, 60, &path) == 1
		mut count := 0
		for y in int(tile.y) .. int(tile.bottom()) {
			for x in int(tile.x) .. int(tile.right()) {
				for c in 0 .. 4 {
					if pixels[((y + 60) * 1024 + x) * 4 + c] != unsafe { expected.data[(y * 1024 + x) * 4 + c] } {
						count++
					}
				}
			}
		}
		if output := os.getenv_opt('VOX_GRADIENT_TEST_OUTPUT') {
			os.write_file_array('${output}-fade-${tested}.rgba', pixels) or { panic('${err}') }
		}
		assert count == 0, 'gradient=${tested} ${gradient.kind} differing channels=${count}'
		tested++
	}
	assert tested == 4
}
