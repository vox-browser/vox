// vtest build: macos
module main

import stbi
import layout

fn test_svg_analytic_path_keeps_the_picture_sample_count() {
	old := document_geometry_grid
	defer { document_geometry_grid = old }
	bytes := $embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/svg-promoted-analytic-edges.png').to_bytes()
	reference := stbi.load_from_memory(bytes.data, bytes.len, desired_channels: 4) or { panic(err) }
	defer { reference.free() }
	// The first dot shares the root's multisampled tile. The next dot belongs
	// to a promoted picture with no tessellated paths and uses one sample.
	for multisampled in [false, true] {
		for origin in [0, 800] {
			for column in [0, 1] {
				document_geometry_grid = DocumentGeometryGrid{
					width:    64
					height:   64
					columns:  2
					rows:     1
					origin_x: origin
					origin_y: origin
					cells:    if multisampled { [i32(column)] } else { []i32{} }
				}
				segment := [f32(6), 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0]!
				path := C.VoxGraphitePath{
					matrix:        [f32(1), 0, 2, 0, 1, 2, 0, 0, 1]!
					segments:      unsafe { &segment[0] }
					segment_count: 1
					red:           204
					alpha:         255
					opacity:       1
				}
				mut pixels := []u8{len: 12 * 12 * 4, init: 255}
				assert draw_document_path_tiles(pixels.data, 12, 12, 48, 1,
					origin + column * 62 + 12, origin + 14, &path) == 1
				for y in 0 .. 8 {
					for x in 0 .. 8 {
						i := ((y + 2) * 12 + x + 2) * 4
						j := ((y + 16 + if multisampled { 0 } else { 48 }) * 320 + x + 14) * 4
						for c in 0 .. 4 {
							channel := if c == 0 {
								2
							} else if c == 2 {
								0
							} else {
								c
							}
							assert pixels[i + channel] == unsafe { reference.data[j + c] }, 'samples=${multisampled}, origin=${origin}, column=${column}, x=${x}, y=${y}, channel=${c}'
						}
					}
				}
			}
		}
	}
}

fn test_filled_oval_does_not_request_an_msaa_pass() {
	path := layout.PaintCommand{
		kind:     'draw_svg_path'
		color:    '#cc0000'
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(6), 0, 0, 8, 8, 0, 0, 0, 0, 0, 0, 0]
		}
	}
	assert chromium_msaa_triggers([path]).len == 0
	assert chromium_msaa_triggers([layout.PaintCommand{ ...path, stroke_color: 'red', stroke_width: 1 }]).len == 1
	mut multiple := path.svg_data.path_data.clone()
	multiple << path.svg_data.path_data
	assert chromium_msaa_triggers([layout.PaintCommand{ ...path, svg_data: &layout.PaintSVGPathData{ path_data: multiple } }]).len == 1
}
