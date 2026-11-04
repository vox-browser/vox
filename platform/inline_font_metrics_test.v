module platform

fn test_chromium_zero_font_has_no_inline_strut() {
	for family in ['Arial', 'Verdana', 'Times'] {
		font := &Font{ family: family, point_size: 0, font_rendering_policy: .chromium }
		assert font.inline_metrics() == FontPixelMetrics{ floor_inline_leading: true }
	}
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	font := &Font{
		family:                'TestFace'
		source_path:           source
		point_size:            0
		font_rendering_policy: .chromium
	}
	assert font.inline_metrics() == FontPixelMetrics{ floor_inline_leading: true }
	assert font.pixel_metrics().ascent > 0
}

fn test_html_compatibility_rounds_inline_metrics_without_changing_svg_metrics() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	coarse := &Font{ family: 'TestFace', point_size: 13.25, source_path: source }
	precise := &Font{ ...coarse, font_rendering_policy: .chromium }
	raw := precise.pixel_metrics()
	inline := precise.inline_metrics()
	assert coarse.inline_metrics() == coarse.pixel_metrics()
	assert precise.pixel_metrics() == raw
	assert inline.ascent == f32(int(inline.ascent))
	assert inline.descent == f32(int(inline.descent))
	assert inline.line_gap == f32(int(inline.line_gap))
	assert inline.ascent != raw.ascent
	assert inline.x_height == raw.x_height
	assert inline.floor_inline_leading
	assert !raw.floor_inline_leading
}
