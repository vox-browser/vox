module platform

fn test_downloaded_font_metrics_follow_the_platform_renderer_policy() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing fixture') }
	libweb := &Font{ family: 'MetricPolicyFixture', source_path: path, point_size: 26 }
	chromium := &Font{ family: 'MetricPolicyFixture', source_path: path, point_size: 26, font_rendering_policy: .chromium }
	// OS/2 USE_TYPO_METRICS selects 819/-205; hhea is 800/-134,
	// at 1024 units/em. The macOS values are independently checked against
	// CTFontGetAscent/Descent on the same concrete file.
	assert libweb.pixel_metrics().ascent == f32(20.794921875)
	assert libweb.pixel_metrics().descent == f32(5.205078125)
	$if macos {
		assert chromium.pixel_metrics().ascent == f32(20.3125)
		assert chromium.pixel_metrics().descent == f32(3.40234375)
	} $else {
		assert chromium.pixel_metrics().ascent == libweb.pixel_metrics().ascent
	}
	assert chromium.pixel_metrics().line_gap == libweb.pixel_metrics().line_gap
	for _ in 0 .. 3 {
		assert libweb.pixel_metrics().ascent == f32(20.794921875)
		assert chromium.pixel_metrics() == chromium.pixel_metrics_uncached()
	}
}

fn test_hhea_selection_only_changes_the_vertical_metric_triplet() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing fixture') }
	font := &Font{ family: 'MetricPolicyFixture', source_path: path, point_size: 26 }
	face := font_face(font) or { panic('missing decoded face') }
	typo := decoded_face_metric_units_with_preference(face, true)
	hhea := decoded_face_metric_units_with_preference(face, false)
	assert typo.ascent == 819
	assert hhea.ascent == 800
	assert typo.descent == 205
	assert hhea.descent == 134
	assert typo.line_gap == hhea.line_gap
	assert typo.units_per_em == hhea.units_per_em
	assert typo.x_height == hhea.x_height
	assert typo.cap_height == hhea.cap_height
}
