module platform

fn width_miss_document_bytes(font &Font, text string, width_only bool) (u64, f32) {
	platform_shaping_cache = &ShapingCache{}
	mut owner := new_arena('width query caller')
	entry := owner.enter()
	before := owner.usage().used
	width := if width_only {
		shaped_text_width(0, 0, text, font, .ltr)
	} else {
		shape_text_with_spacing(0, 0, 0, text, font, .ltr).glyph_run.width()
	}
	used := owner.usage().used - before
	owner.leave(entry)
	owner.release()
	return u64(used), width
}

fn test_cold_width_query_retires_run_storage_and_keeps_its_cached_shape() {
	font := &Font{family: 'SerenitySans', point_size: 16}
	text := 'AV word '.repeat(128)
	_ = shape_text_with_spacing(0, 0, 0, text, font, .ltr)
	legacy_bytes, expected := width_miss_document_bytes(font, text, false)
	actual_bytes, actual := width_miss_document_bytes(font, text, true)
	assert actual == expected
	$if prealloc {
		assert legacy_bytes > actual_bytes + u64(text.len * int(sizeof(Glyph)))
		assert actual_bytes < 1024
	}
	// Neither the cache nor a full run requested later may borrow the retired
	// run. This also runs with scratch memory poisoned after every query.
	assert shaped_text_width(0, 0, text, font, .ltr) == expected
	assert shape_text_with_spacing(0, 0, 0, text, font, .ltr).glyph_run.width() == expected
}

fn test_width_misses_preserve_lazily_resolved_font_and_fallback_storage() {
	for family in ['SerenitySans', 'SerenitySerif', 'nonexistent width test family'] {
		font := &Font{family: family, point_size: 15.75}
		for text in ['AV spacing ', 'مرحبا', '文😀', 'a\u200db'] {
			platform_shaping_cache = &ShapingCache{}
			width := shaped_text_width(0.25, 1.5, text, font, .rtl)
			platform_shaping_cache = &ShapingCache{}
			full := shape_text_with_spacing(0, 0.25, 1.5, text, font, .rtl)
			assert full.glyph_run.width() == width
			assert shaped_text_width(0.25, 1.5, text, font, .rtl) == width
		}
	}
}
