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
	$if macos {
		for job in jobs {
			if serial_ascii_strike_advances {
				assert job.advance_count == 0
			} else {
				assert job.advance_count > 0
				assert job.advance_count <= job.request.text.len
			}
		}
	}
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

fn test_long_ascii_jobs_resolve_strike_advances_when_consumed() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	text := 'AV office file '.repeat(16)
	jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{text, font}])
	assert jobs.len == 1
	shape_ascii_job_range(jobs.data, 0, 1)
	assert jobs[0].advance_count == 0
	mut scope := stage_ascii_shape_jobs(jobs)
	defer { scope.finish() }
	actual := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
	assert actual.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	assert actual.trailing_whitespace == expected.trailing_whitespace
}

fn test_staged_ascii_shapes_are_consumed_only_by_matching_cache_requests() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	other := &Font{ family: 'SerenitySans', point_size: 16, font_rendering_policy: .chromium }
	text := 'AV office AV  '
	unused := 'Private file choices'
	safe := 'Words for line fitting'
	jobs := prepare_ascii_shape_jobs([
		ASCIIShapeRequest{text, font},
		ASCIIShapeRequest{text, other},
		ASCIIShapeRequest{unused, font},
		ASCIIShapeRequest{safe, font},
	])
	assert jobs.len == 4
	worker := spawn shape_ascii_job_range(jobs.data, 0, 1)
	shape_ascii_job_range(jobs.data, 1, i32(jobs.len))
	worker.wait()
	mut scope := stage_ascii_shape_jobs(jobs)
	defer { scope.finish() }

	mut cache := shared_shaping_cache()
	key := shaping_cache_font_key(font)
	params := ShapeParams.new(.ltr, 0, 0)
	assert cache.lookup(key, text, params) == none
	_ = shape_text_with_spacing(0, 0.25, 0, text, font, .ltr)
	assert jobs[0].buffer != unsafe { nil }

	metrics := shaped_text_context_metrics(0, 0, text, other, .ltr) or { panic('missing metrics') }
	other_expected := shape_text_uncached(0, 0, 0, text, other, .ltr)
	assert metrics == cached_shape_context_metrics(cached_shape_from(other_expected)) or {
		panic('missing reference metrics')
	}
	assert jobs[1].buffer == unsafe { nil }
	assert jobs[0].buffer != unsafe { nil }

	expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
	first := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	assert first.trailing_whitespace == expected.trailing_whitespace
	assert first.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	assert jobs[0].buffer == unsafe { nil }
	mut mutable_run := first.glyph_run
	mutable_run.glyphs_[0].advance = -1
	assert shape_text_with_spacing(0, 0, 0, text, font, .ltr).glyph_run.glyphs_ == expected.glyph_run.glyphs_

	mut local := SafeBreakWidthCache{}
	safe_expected := shape_text_uncached(0, 0, 0, safe, font, .ltr)
	safe_width := cached_shape_safe_break_width(cached_shape_from(safe_expected), 0, safe.len,
		safe.len) or { panic('missing reference safe break') }
	assert shaped_text_safe_break_width_cached(mut local, 0, 0, safe, 0, safe.len, font, true) or {
		panic('missing prepared safe break')
	} == safe_width
	assert jobs[3].buffer == unsafe { nil }
	assert jobs[2].buffer != unsafe { nil }
	scope.finish()
	assert jobs[2].buffer == unsafe { nil }
	assert cache.lookup(key, unused, params) == none
}

fn test_staged_ascii_shapes_follow_scope_and_native_font_lifetime() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	text := 'Retained paragraph text'
	jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{text, font}])
	shape_ascii_job_range(jobs.data, 0, 1)
	mut outer := stage_ascii_shape_jobs(jobs)
	defer { outer.finish() }

	nested := prepare_ascii_shape_jobs([ASCIIShapeRequest{'Nested phrase', font}])
	shape_ascii_job_range(nested.data, 0, 1)
	mut inner := stage_ascii_shape_jobs(nested)
	assert active_ascii_shape_batch().jobs.data == nested.data
	inner.finish()
	assert active_ascii_shape_batch().jobs.data == jobs.data

	release_unused_text_shaping()
	assert take_ascii_shape_job(shaping_cache_font_key(font), text, ShapeParams.new(.ltr, 0, 0)) == none
	outer.finish()
	assert jobs[0].buffer == unsafe { nil }
	assert active_ascii_shape_batch() == unsafe { nil }
}
