module cpuraster

fn test_document_shadow_keeps_unrounded_author_alpha() {
	shape := rounded_rect(Rect{0, 0, 4, 4}, [8]f32{})
	transform := [f32(1), 0, 0, 1, 0, 0]!
	legacy := rasterize_outer_shadow(4, 4, shape, RoundedRect{}, transform,
		0x19000000, 0, []) or { panic('legacy shadow') }
	document := rasterize_outer_shadow_with_coverage(4, 4, shape, RoundedRect{}, transform,
		0x19000000, 0, [], 0.1) or { panic('document shadow') }
	// CSS alpha 0.1 rounds to 26 at readback. Quantizing it before coverage
	// loses one level, making every shadow on a white page too light.
	assert legacy[3] == 25
	assert document[3] == 26
}

fn test_outer_shadow_preserves_elliptical_corners_and_content_hole() {
	shape := rounded_rect(Rect{8, 8, 24, 24}, [f32(6), 4, 2, 6, 4, 2, 2, 2]!)
	pixels := rasterize_outer_shadow(32, 32, shape, shape, [f32(1), 0, 0, 1, 0, 0]!, 0xff0000ff, 4, []) or { panic('shadow') }
	assert pixels[(16 * 32 + 16) * 4 + 3] == 0
	assert pixels[(16 * 32 + 5) * 4 + 3] > 0
	assert pixels[(16 * 32 + 5) * 4 + 3] < 255
	assert pixels[16 * 32 * 4 + 3] == 0
}

fn test_outer_shadow_retains_path_clips() {
	mut b := PathBuilder{}
	b.move_to(0, 0)
	b.line_to(32, 0)
	b.line_to(0, 32)
	b.close()
	pixels := rasterize_outer_shadow(32, 32, rounded_rect(Rect{0, 0, 32, 32}, [8]f32{}),
		RoundedRect{}, [f32(1), 0, 0, 1, 0, 0]!, 0xff0000ff, 0, [b.detach()]) or { panic('shadow') }
	assert pixels[(4 * 32 + 4) * 4 + 3] == 255
	assert pixels[(28 * 32 + 28) * 4 + 3] == 0
}

fn test_outer_shadow_rejects_local_fast_bounds_before_device_blur() {
	outer := rounded_rect(Rect{-7.977699, 32.2419, 1.4868231, 43.921085}, [f32(100), 100, 100, 100, 100, 100, 100, 100]!)
	content := rounded_rect(Rect{55.67158, 5.6374946, 63.767273, 8.251768}, [f32(4.0436845), 30.197882, 0.5034486, 19.539291, 29.556997, 24.28015, 26.625626, 30.156988]!)
	pixels := rasterize_outer_shadow(40, 15, outer, content,
		[f32(2.6346233), 0, 0, 0.38824087, 19.2367, 12.575357]!, 0xc7b389cf, 10.091329, []) or { panic('shadow') }
	assert pixels.all(it == 0)
}

fn test_outer_shadow_snaps_nearly_integral_rectangular_content_clip() {
	shape := rounded_rect(Rect{53.906555, -2.0712817, f32(53.906555) + f32(21.131067), f32(-2.0712817) + f32(13.188125)}, [8]f32{})
	pixels := rasterize_outer_shadow(65, 58, shape, shape, [f32(1), 0, 0, 1, 0, 0]!,
		1710523175, 6.87203, []) or { panic('shadow') }
	// Independent Skia ee20d565 oracle, including straight-alpha readback.
	// RGBA is native N32 on macOS; Linux takes the non-native pipeline.
	$if linux {
		assert pixels[212..216] == [u8(241), 128, 35, 36]
	} $else {
		assert pixels[212..216] == [u8(248), 131, 36, 35]
	}
}

fn test_unblurred_rectangular_shadow_uses_rect_scan_coverage() {
	outer := rounded_rect(Rect{-15.101781, -1.6967947, f32(-15.101781) + f32(54.417038),
		f32(-1.6967947) + f32(44.63612)}, [8]f32{})
	content := rounded_rect(Rect{40.757374, 35.326378, f32(40.757374) + f32(55.041065),
		f32(35.326378) + f32(63.865044)}, [8]f32{})
	pixels := rasterize_outer_shadow(35, 52, outer, content, [f32(1), 0, 0, 1, 0, 0]!,
		679617509, -1, []) or { panic('shadow') }
	// The same oracle distinguishes native and non-native RGBA coverage.
	$if linux {
		assert pixels[42 * 35 * 4] == 128
	} $else {
		assert pixels[42 * 35 * 4] == 124
	}
}
