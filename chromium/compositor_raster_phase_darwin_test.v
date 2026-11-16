module main

fn test_compositor_phase_keeps_capture_and_presenting_grids_separate() {
	previous := compositor_raster_phase
	defer { compositor_raster_phase = previous }
	select_compositor_raster_phase(760.7578125, 16, 2, 1, true)
	assert compositor_raster_phase == [f64(0.5), 0]!
	select_compositor_raster_phase(760.7578125, 16, 2, 2, true)
	assert compositor_raster_phase == [f64(0), 0]!
	select_compositor_raster_phase(760.7578125, 16, 2, 1, false)
	assert compositor_raster_phase == [f64(0), 0]!
	assert compositor_phase_translation([f32(1), 0, 10, 0, 1, 20, 0, 0, 1]!)
	assert !compositor_phase_translation([f32(2), 0, 10, 0, 2, 20, 0, 0, 1]!)
}

fn test_compositor_svg_interpolates_sample_coverage_before_byte_rounding() {
	previous := compositor_raster_phase
	defer { compositor_raster_phase = previous }
	compositor_raster_phase = [f64(0.5), 0]!
	segments := [f32(3), 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]
	path := C.VoxGraphitePath{
		segments:      segments.data
		segment_count: 1
		red:           255
		green:         255
		blue:          255
		alpha:         255
	}
	for counts in [[2, 3, 159]!, [2, 4, 191]!, [1, 2, 96]!] {
		mut source := []u8{len: 3 * 3 * 4}
		encoded := [u8(0), 64, 128, 191, 255]
		for x in 0 .. 2 {
			for k in 0 .. 4 { source[(3 + x) * 4 + k] = encoded[counts[x]] }
		}
		precise := compositor_msaa_coverage(source, &path)
		assert precise.len == source.len
		mut output := []u8{len: 4}
		assert publish_compositor_svg_phase(output.data, 1, 1, 4, source, precise)
		assert output == []u8{len: 4, init: u8(counts[2])}
	}
}

fn test_compositor_svg_declines_unrecoverable_or_translucent_sample_data() {
	segments := [f32(3), 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]
	path := C.VoxGraphitePath{
		segments:      segments.data
		segment_count: 1
		red:           255
		green:         255
		blue:          255
		alpha:         255
	}
	assert compositor_msaa_coverage([u8(128), 128, 128, 128], &path).len == 4
	for data in [[u8(127), 128, 128, 128], [u8(127), 127, 127, 127]] {
		assert compositor_msaa_coverage(data, &path).len == 0
	}
	for guarded in [C.VoxGraphitePath{ ...path, alpha: 128 },
		C.VoxGraphitePath{ ...path, has_clip: 1 }, C.VoxGraphitePath{ ...path, gradient: 1 }] {
		assert compositor_msaa_coverage([u8(128), 128, 128, 128], &guarded).len == 0
	}
}

fn test_analytic_border_does_not_bleed_past_its_straight_edge() {
	old_phase := compositor_raster_phase
	old_grid := document_geometry_grid
	defer {
		compositor_raster_phase = old_phase
		document_geometry_grid = old_grid
	}
	document_geometry_grid = DocumentGeometryGrid{}
	shape := C.VoxGraphiteShape{
		matrix:     [f32(1), 0, -759, 0, 1, -14, 0, 0, 1]!
		rect:       [f32(761.5), 16.5, 41, 35, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5, 5.5]!
		fill:       0
		thickness:  1
		anti_alias: 1
		force_msaa: 1
		red:        53
		green:      61
		blue:       55
		alpha:      255
	}
	for phase in [f64(0), 0.5] {
		compositor_raster_phase = [phase, f64(0)]!
		mut pixels := []u8{len: 46 * 40 * 4}
		for i in 0 .. 46 * 40 { pixels[i * 4 + 3] = 255 }
		assert draw_document_shape_pixels(pixels.data, 46, 40, 184, 1, 759, 14, &shape) == 1
		// The right outer edge is exactly x=803. Its exterior pixel must stay
		// black; resampling the analytic coverage would introduce a new fringe.
		for y in 8 .. 32 {
			i := (y * 46 + 44) * 4
			assert pixels[i..i + 4] == [u8(0), 0, 0, 255]
		}
	}
}
