module platform

fn baseline_miss_retained_bytes(font &Font, text string, legacy bool) u64 {
	platform_shaping_cache = &ShapingCache{}
	mut owner := new_arena('baseline miss storage')
	entry := owner.enter()
	before := owner.usage().used
	shaped := if legacy {
		font_key := shaping_cache_font_key(font)
		params := ShapeParams.new(.ltr, 0, 0)
		mut cache := shared_shaping_cache()
		_ = cache.lookup(font_key, text, params)
		original := shape_text_uncached(0, 0, 0, text, font, .ltr)
		view := cached_shape_from(original)
		cache.store(font_key, text, params, view)
		shaped_text_with_baseline(view, 19.25, font, .ltr)
	} else {
		shape_text_cached(19.25, 0, 0, text, font, .ltr)
	}
	assert shaped.glyph_run.glyphs_.len == text.len
	assert shaped.glyph_run.glyphs_[0].position.x == 19.25
	assert shaped.glyph_run.glyph_positions()[0] == 19.25
	used := owner.usage().used - before
	owner.leave(entry)
	owner.release()
	return used
}

fn test_cold_nonzero_baseline_reuses_its_owned_glyph_and_playback_buffers() {
	font := &Font{family: 'SerenitySans', point_size: 16}
	text := 'x'.repeat(1024)
	// Resolve native font caches before comparing document-owned allocation.
	_ = shape_text_with_spacing(19.25, 0, 0, text, font, .ltr)
	legacy := baseline_miss_retained_bytes(font, text, true)
	actual := baseline_miss_retained_bytes(font, text, false)
	$if prealloc {
		assert legacy > actual + u64(text.len * int(sizeof(Glyph)))
	}
}
