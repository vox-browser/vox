// vtest build: macos
module ggshape

$if !macos {
	$compile_error('The gg.canvas browser adapters currently require macOS')
}

// A compositor tile much larger than the leaf drawn inside it.
const tile_width = 96

const tile_height = 56

const leaf = SurfaceRegion{
	surface_width:  tile_width
	surface_height: tile_height
	x:              11
	y:              7
	width:          45
	height:         33
}

// Row padding that a transfer must neither read as pixels nor overwrite.
const leaf_pitch = leaf.width * 4 + 12

fn tile_backdrop() []u8 {
	mut pixels := []u8{len: tile_width * tile_height * 4}
	for y in 0 .. tile_height {
		for x in 0 .. tile_width {
			i := (y * tile_width + x) * 4
			alpha := 96 + (x * 5 + y * 11) % 160
			pixels[i] = u8((x * 17) % (alpha + 1))
			pixels[i + 1] = u8((y * 23) % (alpha + 1))
			pixels[i + 2] = u8(((x + 2 * y) * 7) % (alpha + 1))
			pixels[i + 3] = u8(alpha)
		}
	}
	return pixels
}

// The leaf's rows of a whole-tile buffer, with marked row padding.
fn leaf_rows(tile []u8) []u8 {
	mut rows := []u8{len: leaf_pitch * leaf.height, init: 0xa5}
	for y in 0 .. leaf.height {
		source := ((leaf.y + y) * tile_width + leaf.x) * 4
		for i in 0 .. leaf.width * 4 {
			rows[y * leaf_pitch + i] = tile[source + i]
		}
	}
	return rows
}

fn leaf_shape() C.VoxGraphiteShape {
	mut shape := C.VoxGraphiteShape{}
	// Inside the leaf: 2 * 6.25 + 1 = 13.5 through 2 * 24.5 + 1 = 50.
	shape.matrix = [f32(2), 0, 1, 0, 1, 2, 0, 0, 1]!
	shape.rect = [f32(6.25), 7.5, 18.25, 26.25, 6, 6, 4, 3, 8, 8, 2, 5]!
	shape.fill = 1
	shape.anti_alias = 1
	shape.red = 35
	shape.green = 167
	shape.blue = 79
	shape.alpha = 200
	return shape
}

fn leaf_path(segments []f32) C.VoxGraphitePath {
	return C.VoxGraphitePath{
		matrix:        [f32(1), 0, 13, 0, 1, 9, 0, 0, 1]!
		segments:      segments.data
		segment_count: i32(segments.len / 12)
		even_odd:      1
		green:         255
		alpha:         150
	}
}

// Two contours with the same winding and curved corners from offset edges,
// so both antialiased and interior coverage reach the leaf's rows.
const leaf_segments = [
	f32(0), 2.5, 3.25, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 38.25, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 36, 27.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 4, 25.75, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 12, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 26.5, 9, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 26.5, 19.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	1, 12, 19.5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
]

fn assert_padding_kept(rows []u8) {
	for y in 0 .. leaf.height {
		end := (y + 1) * leaf_pitch
		assert rows[end - 12..end] == []u8{len: 12, init: 0xa5}, 'row ${y}'
	}
}

fn test_shape_regions_match_whole_tile_draws() {
	context() or {
		eprintln('skipping: ${err}')
		return
	}
	for backdrop in [i32(1), 0] {
		for msaa in [i32(0), 1] {
			mut shape := leaf_shape()
			shape.force_msaa = msaa
			mut whole := tile_backdrop()
			assert draw(whole.data, tile_width, tile_height, tile_width * 4, backdrop, &shape) == 1
			mut rows := leaf_rows(tile_backdrop())
			assert draw_region(rows.data, leaf_pitch, leaf, backdrop, &shape) == 1
			assert rows == leaf_rows(whole), 'backdrop ${backdrop} msaa ${msaa}'
			assert rows != leaf_rows(tile_backdrop())
			assert_padding_kept(rows)
		}
	}
	// A stroked ring with an underlay uses several draws in one pass.
	mut ring := leaf_shape()
	ring.fill = 0
	ring.thickness = 1.5
	ring.rect = [f32(6.25), 7.5, 18.25, 26.25, 6, 6, 4, 4, 8, 8, 2, 2]!
	ring.has_float_color = 1
	ring.float_color = [f32(0.3), 0.5, 0.71, 0.9]!
	ring.has_underlay = 1
	ring.underlay_rect = [f32(7), 9, 16, 22, 3, 3, 3, 3, 3, 3, 3, 3]!
	ring.has_float_underlay_color = 1
	ring.underlay_float_color = [f32(0.9), 0.2, 0.1, 0.6]!
	mut whole := tile_backdrop()
	assert draw(whole.data, tile_width, tile_height, tile_width * 4, 1, &ring) == 1
	mut rows := leaf_rows(tile_backdrop())
	assert draw_region(rows.data, leaf_pitch, leaf, 1, &ring) == 1
	assert rows == leaf_rows(whole)
	assert_padding_kept(rows)
}

fn test_path_regions_match_whole_tile_draws() {
	context() or {
		eprintln('skipping: ${err}')
		return
	}
	for backdrop in [i32(1), 0] {
		for multisampled in [false, true] {
			for stroke in [i32(0), 1] {
				mut path := leaf_path(leaf_segments)
				path.stroke = stroke
				path.stroke_width = 2.5
				path.miter_limit = 4
				mut whole := tile_backdrop()
				drawn := if multisampled {
					draw_multisampled_path(whole.data, tile_width, tile_height, tile_width * 4,
						backdrop, &path)
				} else {
					draw_path(whole.data, tile_width, tile_height, tile_width * 4, backdrop,
						&path)
				}
				assert drawn == 1
				mut rows := leaf_rows(tile_backdrop())
				assert draw_path_region(rows.data, leaf_pitch, leaf, backdrop, &path, multisampled) == 1
				assert rows == leaf_rows(whole), 'backdrop ${backdrop} msaa ${multisampled} stroke ${stroke}'
				assert rows != leaf_rows(tile_backdrop())
				assert_padding_kept(rows)
			}
		}
	}
}

fn test_svg_image_regions_match_whole_tile_draws() {
	context() or {
		eprintln('skipping: ${err}')
		return
	}
	parent := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	viewport := [f32(0), 0, f32(tile_width), f32(tile_height)]!
	stops := [f32(1), 0.2, 0, 1, 0, 0, 0.4, 1, 0.5, 1]
	// A solid path and a dithered gradient, which depends on device coordinates.
	for gradient in [i32(0), 1] {
		mut path := leaf_path(leaf_segments)
		if gradient != 0 {
			path.gradient = 1
			path.gradient_points = [f32(2.5), 3, 38, 27, 0, 0]!
			path.gradient_matrix = [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
			path.stop_count = 2
			path.stops = stops.data
			path.opacity = 0.75
		}
		// Backdrop, forced MSAA and the hard document viewport.
		for flags in [i32(0), 1, 1 | 2, 1 | 4, 1 | 2 | 4] {
			mut whole := tile_backdrop()
			assert draw_svg_image(whole.data, tile_width, tile_height, tile_width * 4, flags,
				&path, 1, &parent[0], &viewport[0], unsafe { nil }) == 1
			mut rows := leaf_rows(tile_backdrop())
			assert draw_svg_image_region(rows.data, leaf_pitch, leaf, flags, &path, 1, &parent[0],
				&viewport[0], unsafe { nil }) == 1
			assert rows == leaf_rows(whole), 'gradient ${gradient} flags ${flags}'
			assert rows != leaf_rows(tile_backdrop())
			assert_padding_kept(rows)
		}
	}
}

fn test_shape_group_regions_match_whole_tile_draws() {
	context() or {
		eprintln('skipping: ${err}')
		return
	}
	mut ring := leaf_shape()
	ring.fill = 0
	ring.thickness = 2
	ring.rect = [f32(7), 9, 16, 22, 3, 3, 3, 3, 3, 3, 3, 3]!
	ring.has_float_color = 1
	ring.float_color = [f32(0.8), 0.1, 0.3, 0.7]!
	for backdrop in [i32(1), 0] {
		for msaa in [i32(0), 1] {
			mut shapes := [leaf_shape(), ring]
			shapes[1].force_msaa = msaa
			mut whole := tile_backdrop()
			assert draw_shapes(whole.data, tile_width, tile_height, tile_width * 4, backdrop,
				shapes.data, i32(shapes.len)) == 1
			mut rows := leaf_rows(tile_backdrop())
			assert draw_shapes_region(rows.data, leaf_pitch, leaf, backdrop, shapes.data, i32(shapes.len)) == 1
			assert rows == leaf_rows(whole), 'backdrop ${backdrop} msaa ${msaa}'
			assert rows != leaf_rows(tile_backdrop())
			assert_padding_kept(rows)
		}
	}
}

fn test_unsupported_regions_leave_pixels_untouched() {
	context() or {
		eprintln('skipping: ${err}')
		return
	}
	shape := leaf_shape()
	path := leaf_path(leaf_segments)
	identity := [f32(1), 0, 0, 0, 1, 0, 0, 0, 1]!
	whole_viewport := [f32(0), 0, f32(tile_width), f32(tile_height)]!
	before := leaf_rows(tile_backdrop())
	for region in [
		SurfaceRegion{ ...leaf, x: tile_width - leaf.width + 1 },
		SurfaceRegion{ ...leaf, y: tile_height - leaf.height + 1 },
		SurfaceRegion{ ...leaf, x: -1 },
		SurfaceRegion{ ...leaf, width: 0 },
		SurfaceRegion{ ...leaf, surface_height: 0 },
	] {
		mut rows := before.clone()
		assert draw_region(rows.data, leaf_pitch, region, 1, &shape) == 0
		assert draw_shapes_region(rows.data, leaf_pitch, region, 1, &shape, 1) == 0
		assert draw_path_region(rows.data, leaf_pitch, region, 1, &path, false) == 0
		assert draw_svg_image_region(rows.data, leaf_pitch, region, 1, &path, 1, &identity[0],
			&whole_viewport[0], unsafe { nil }) == 0
		assert rows == before
	}
	mut rows := before.clone()
	// A pitch shorter than the region's row.
	assert draw_region(rows.data, leaf.width * 4 - 4, leaf, 1, &shape) == 0
	mut unknown := leaf_shape()
	unknown.fill = 99
	assert draw_region(rows.data, leaf_pitch, leaf, 1, &unknown) == 0
	assert rows == before
}
