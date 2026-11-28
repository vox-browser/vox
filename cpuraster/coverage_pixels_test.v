module cpuraster

fn test_straight_rgba_clip_keeps_color_in_partial_coverage() {
	width := 45
	height := 33
	round := rounded_rect(Rect{2, 3, 43, 29}, [f32(9), 9, 7, 12, 0, 0, 0, 0]!)
	clip := canvas_raster_clip(width, height, [round.path()])
	mut reference := []u8{len: width * height * 4}
	assert fill_clipped_color(mut reference, width, height, width * 4, 0xffffffff, clip)
	source := [u8(210), 93, 29, 157]!
	mut pixels := []u8{len: reference.len, init: source[index % 4]}
	assert clip.apply_to_straight_rgba(mut pixels, width, height)
	mut transparent := 0
	mut opaque := 0
	mut antialiased := 0
	for i := 0; i < pixels.len; i += 4 {
		coverage := reference[i + 3]
		if coverage == 0 {
			assert pixels[i..i + 4] == [u8(0), 0, 0, 0]
			transparent++
		} else {
			assert pixels[i..i + 3] == source[..3]
			assert pixels[i + 3] == u8((int(source[3]) * int(coverage) + 127) / 255)
			if coverage == 255 { opaque++ } else { antialiased++ }
		}
	}
	assert transparent > 0 && opaque > 0 && antialiased > 0
}

fn test_clip_coverage_rectangles_match_disjoint_raster_coverage() {
	width, height := 800, 36
	shape := rounded_rect(Rect{3, 2, 798, 34}, [f32(13), 13, 8, 9, 5, 7, 0, 0]!)
	clip := canvas_raster_clip(width, height, [shape.path()])
	spans := clip.coverage_rects(256) or { panic('rounded clip exceeded the span budget') }
	assert spans.len > 1
	assert clip.coverage_rects(spans.len - 1) == none
	assert spans.any(it.alpha == 255 && it.rect.right - it.rect.left > 700)
	mut coverage := []u8{len: width * height}
	for span in spans {
		for y in span.rect.top .. span.rect.bottom {
			for x in span.rect.left .. span.rect.right {
				i := y * width + x
				assert coverage[i] == 0
				coverage[i] = span.alpha
			}
		}
	}
	mut reference := []u8{len: width * height * 4}
	assert fill_clipped_color(mut reference, width, height, width * 4, 0xffffffff, clip)
	for i, value in coverage {
		assert value == reference[i * 4 + 3]
	}
	plain := canvas_raster_clip(20, 10, [])
	assert (plain.coverage_rects(1) or { [] }) == [ClipCoverageRect{IRect{0, 0, 20, 10}, 255}]
	circle := rounded_rect(Rect{0, 0, 24, 24}, [f32(12), 12, 12, 12, 12, 12, 12, 12]!)
	assert canvas_raster_clip(24, 24, [circle.path()]).coverage_rects(128) != none
}
