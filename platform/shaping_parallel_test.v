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
			if serial_ascii_strike_advances || serial_ascii_glyph_decode {
				assert job.glyph_count == 0
				assert job.buffer != unsafe { nil }
			} else {
				assert job.glyph_count == job.advance_count
				assert job.buffer == unsafe { nil }
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
	assert jobs[0].glyph_count == 0
	assert jobs[0].buffer != unsafe { nil }
	mut scope := stage_ascii_shape_jobs(jobs)
	defer { scope.finish() }
	actual := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
	assert actual.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	assert actual.trailing_whitespace == expected.trailing_whitespace
}

fn test_short_ascii_jobs_fill_the_batch_after_long_runs_and_duplicate_keys() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium}
	long_text := 'Retained paragraph text'
	short_text := '127 points'
	requests := [long_text, long_text, short_text, 'Other short text'].map(ASCIIShapeRequest{it, font})
	jobs := prepare_ascii_shape_jobs(requests, maximum_jobs: 2)
	assert jobs.len == 2
	assert jobs[0].request.text == long_text
	assert jobs[1].request.text == short_text
	worker := spawn shape_ascii_job_range(jobs.data, 0, 2)
	worker.wait()
	mut scope := stage_ascii_shape_jobs(jobs)
	defer { scope.finish() }
	for text in [long_text, short_text] {
		expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
		actual := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
		assert actual.glyph_run.glyphs_ == expected.glyph_run.glyphs_
		assert actual.trailing_whitespace == expected.trailing_whitespace
	}
	assert !jobs[0].prepared()
	assert !jobs[1].prepared()
}

fn test_staged_ascii_shapes_are_consumed_only_by_matching_cache_requests() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	other := &Font{ family: 'SerenitySans', point_size: 16, font_rendering_policy: .chromium }
	text := 'AV office AV  '
	unused := 'Private file choices'
	safe := 'Words for line fitting'
	width_only := 'Measure these words'
	jobs := prepare_ascii_shape_jobs([
		ASCIIShapeRequest{text, font},
		ASCIIShapeRequest{text, other},
		ASCIIShapeRequest{unused, font},
		ASCIIShapeRequest{safe, font},
		ASCIIShapeRequest{width_only, font},
	])
	assert jobs.len == 5
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
	assert jobs[0].prepared()

	metrics := shaped_text_context_metrics(0, 0, text, other, .ltr) or { panic('missing metrics') }
	other_expected := shape_text_uncached(0, 0, 0, text, other, .ltr)
	assert metrics == cached_shape_context_metrics(cached_shape_from(other_expected)) or {
		panic('missing reference metrics')
	}
	assert !jobs[1].prepared()
	assert jobs[0].prepared()

	expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
	first := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	assert first.trailing_whitespace == expected.trailing_whitespace
	assert first.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	assert !jobs[0].prepared()
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
	assert !jobs[3].prepared()

	width_expected := shape_text_uncached(0, 0, 0, width_only, font, .ltr)
	assert shaped_text_width(0, 0, width_only, font, .ltr) == width_expected.glyph_run.width()
	assert !jobs[4].prepared()

	assert jobs[2].prepared()
	scope.finish()
	assert !jobs[2].prepared()
	assert cache.lookup(key, unused, params) == none
}

fn test_consumed_glyphs_outlive_the_preparation_scratch() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{ family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium }
	text := 'AV office finish  '
	scratch := begin_thread_scratch('prepared glyph lifetime test')
	jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{text, font}])
	shape_ascii_job_range(jobs.data, 0, 1)
	mut scope := stage_ascii_shape_jobs(jobs)
	persistent := enter_persistent()
	actual := shape_text_with_spacing(4.25, 0, 0, text, font, .ltr)
	leave_persistent(persistent)
	scope.finish()
	scratch.finish()
	expected := shape_text_with_spacing(4.25, 0, 0, text, font, .ltr)
	assert actual.trailing_whitespace == expected.trailing_whitespace
	assert actual.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	assert actual.glyph_run.glyph_indices() == expected.glyph_run.glyph_indices()
	assert actual.glyph_run.glyph_positions() == expected.glyph_run.glyph_positions()
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
	assert !jobs[0].prepared()
	assert active_ascii_shape_batch() == unsafe { nil }
}

struct TestASCIIShapeTicket {
	jobs []ASCIIShapeJob
mut:
	joins int
}

fn join_test_ascii_shape_ticket(ticket voidptr) bool {
	mut work := unsafe { &TestASCIIShapeTicket(ticket) }
	work.joins++
	shape_ascii_job_range(work.jobs.data, 0, i32(work.jobs.len))
	return false
}

fn test_pending_ascii_shapes_join_at_matching_cache_miss_and_only_once() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium}
	other := &Font{family: 'SerenitySans', point_size: 16, font_rendering_policy: .chromium}
	text := 'AV office finish  '
	expected := shape_text_uncached(0, 0, 0, text, font, .ltr)
	jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{text, font}])
	assert jobs.len == 1
	mut work := TestASCIIShapeTicket{jobs: jobs}
	mut scope := stage_ascii_shape_jobs(jobs,
		worker_ticket: &work
		join_workers: join_test_ascii_shape_ticket
	)
	defer { scope.finish() }
	_ = shape_text_with_spacing(0, 0, 0, 'Different phrase', font, .ltr)
	_ = shape_text_with_spacing(0, 0, 0, text, other, .ltr)
	assert work.joins == 0
	actual := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	assert work.joins == 1
	assert actual.glyph_run.glyphs_ == expected.glyph_run.glyphs_
	assert actual.trailing_whitespace == expected.trailing_whitespace
	scope.finish()
	assert work.joins == 1
}

fn test_pending_ascii_scopes_join_before_font_cache_retirement() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium}
	text := 'Retained paragraph text'
	outer_jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{text, font}])
	inner_jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{'Nested phrase', font}])
	mut outer_work := TestASCIIShapeTicket{jobs: outer_jobs}
	mut inner_work := TestASCIIShapeTicket{jobs: inner_jobs}
	mut outer := stage_ascii_shape_jobs(outer_jobs,
		worker_ticket: &outer_work
		join_workers: join_test_ascii_shape_ticket
	)
	defer { outer.finish() }
	mut inner := stage_ascii_shape_jobs(inner_jobs,
		worker_ticket: &inner_work
		join_workers: join_test_ascii_shape_ticket
	)
	defer { inner.finish() }
	release_unused_text_shaping()
	assert inner_work.joins == 1 && outer_work.joins == 1
	inner.finish()
	assert take_ascii_shape_job(shaping_cache_font_key(font), text, ShapeParams.new(.ltr, 0, 0)) == none
	outer.finish()
	assert inner_work.joins == 1 && outer_work.joins == 1
	assert !inner_jobs[0].prepared() && !outer_jobs[0].prepared()
}

fn test_unused_pending_ascii_shapes_join_and_release_at_scope_exit() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{family: 'SerenitySans', point_size: 13.25, font_rendering_policy: .chromium}
	text := 'Unused prepared text'
	jobs := prepare_ascii_shape_jobs([ASCIIShapeRequest{text, font}])
	mut work := TestASCIIShapeTicket{jobs: jobs}
	mut scope := stage_ascii_shape_jobs(jobs,
		worker_ticket: &work
		join_workers: join_test_ascii_shape_ticket
	)
	scope.finish()
	assert work.joins == 1
	assert !jobs[0].prepared()
	mut cache := shared_shaping_cache()
	assert cache.lookup(shaping_cache_font_key(font), text, ShapeParams.new(.ltr, 0, 0)) == none
}
