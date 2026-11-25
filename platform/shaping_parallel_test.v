module platform

fn test_prepared_ascii_shapes_match_the_existing_shaping_cache() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	texts := ['AV office AV  ', 'Private file choices', 'AV office AV  ']
	jobs := prepare_ascii_shape_jobs(texts.map(ASCIIShapeRequest{it, font}))
	assert jobs.len == 2
	worker := spawn shape_ascii_job_range(jobs.data, 0, 1)
	shape_ascii_job_range(jobs.data, 1, i32(jobs.len))
	worker.wait()
	assert store_ascii_shape_jobs(jobs) == 2
	for text in texts {
		cached := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
		expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
		assert cached.trailing_whitespace == expected.trailing_whitespace
		assert cached.glyph_run.face() == expected.glyph_run.face()
		assert cached.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	}
	assert prepare_ascii_shape_jobs(texts.map(ASCIIShapeRequest{it, font})).len == 0
}
