module platform

import math

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
	fn C.GC_gcollect()
}

fn transient_legacy_ascii_index(text string, params ShapeParams) int {
	units := utf16_units_for_shaping(text)
	if units.len == 1 && int(units[0]) < single_ascii_shape_cache_size
		&& params.text_type == .common && params.letter_spacing_bits & u32(0x7fff_ffff) == 0
		&& params.word_spacing_bits & u32(0x7fff_ffff) == 0 {
		return int(units[0])
	}
	return -1
}

fn test_ascii_cache_lane_matches_legacy_unicode_and_spacing_decisions_without_allocating() {
	negative_zero := math.f32_from_bits(u32(0x8000_0000))
	mut texts := ['', 'ab', 'é', '文', '😀', 'a\u0301', '\r\n']
	for value in 0 .. 256 {
		texts << [u8(value)].bytestr()
	}
	// The pinned old backend rejects overlong encodings, isolated continuation
	// bytes, surrogate encodings, truncated sequences, and values above U+10FFFF.
	for bytes in [[u8(0xc0), 0x80], [u8(0xc1), 0xbf], [u8(0xe0), 0x80, 0x80],
		[u8(0xf0), 0x80, 0x80, 0x80], [u8(0xc2)], [u8(0xe2), 0x82],
		[u8(0xf0), 0x9f, 0x98], [u8(0xed), 0xa0, 0x80],
		[u8(0xf4), 0x90, 0x80, 0x80], [u8(0xf5), 0x80, 0x80, 0x80],
		[u8(0xc2), 0x41], [u8(0xe2), 0x28, 0xa1], [u8(0x41), 0x80]] {
		texts << bytes.bytestr()
	}
	for text in texts {
		for kind in [GlyphRunTextType.common, .context_dependent, .end_padding, .ltr, .rtl] {
			for spacing in [f32(0), negative_zero, 1, math.f32_from_bits(u32(0x7fc0_0000))] {
				params := ShapeParams.new(kind, spacing, spacing)
				assert single_ascii_cache_index(text, params) == transient_legacy_ascii_index(text, params)
			}
		}
	}
	params := ShapeParams.new(.common, 0, 0)
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut total := 0
	for _ in 0 .. 1000 {
		total += single_ascii_cache_index('x', params)
		total += single_ascii_cache_index('é', params)
		total += single_ascii_cache_index('long text', params)
	}
	$if gcboehm ? { assert C.GC_get_total_bytes() == before }
	assert total == 118_000
}

fn test_transient_shape_view_borrows_until_store_owns_its_independent_snapshot() {
	font := &Font{family: 'SerenitySans', point_size: 16}
	shaped := shape_text_uncached(0, 0, 0, 'borrowed glyphs', font, .ltr)
	view := cached_shape_from(shaped)
	assert view.glyphs.data == shaped.glyph_run.glyphs_.data
	original := view.glyphs.clone()
	mut cache := ShapingCache{}
	params := ShapeParams.new(.ltr, 0, 0)
	_ = cache.lookup('font', 'borrowed glyphs', params)
	cache.store('font', 'borrowed glyphs', params, view)
	stored := cache.lookup('font', 'borrowed glyphs', params) or { panic('shape missing') }
	assert stored.glyphs.data != shaped.glyph_run.glyphs_.data
	mut run := shaped.glyph_run
	run.glyphs_[0].position.x = 999
	run.glyphs_ << Glyph{advance: 123}
	$if gcboehm ? { C.GC_gcollect() }
	assert stored.glyphs == original
	assert cache.lookup('font', 'borrowed glyphs', params) or { panic('shape missing') }.glyphs == original
}

fn transient_assert_runs_equal(first ShapedText, second ShapedText) {
	assert first.glyph_run.glyphs_ == second.glyph_run.glyphs_
	assert first.glyph_run.glyph_indices() == second.glyph_run.glyph_indices()
	assert first.glyph_run.glyph_positions() == second.glyph_run.glyph_positions()
	assert first.glyph_run.bounding_box() == second.glyph_run.bounding_box()
	assert first.glyph_run.width() == second.glyph_run.width()
	assert first.glyph_run.space_width == second.glyph_run.space_width
	assert first.glyph_run.font() == second.glyph_run.font()
	assert first.glyph_run.face() == second.glyph_run.face()
	assert first.glyph_run.text_type() == second.glyph_run.text_type()
	assert first.trailing_whitespace == second.trailing_whitespace
}

fn test_shaping_miss_preserves_legacy_run_geometry_and_cache_mutation_isolation() {
	for invisible in [false, true] {
		font := &Font{family: 'SerenitySans', point_size: 13.25, is_invisible: invisible}
		for text in ['', 'AV word ', 'a\u200db ', 'مرحبا', '文😀'] {
			for baseline in [f32(0), 17.25, math.f32_from_bits(u32(0x8000_0000))] {
				platform_shaping_cache = &ShapingCache{}
				original := shape_text_uncached(0, 0.25, 1.5, text, font, .ltr)
				legacy := shaped_text_with_baseline(cached_shape_from(original), baseline, font, .ltr)
				first := shape_text_with_spacing(baseline, 0.25, 1.5, text, font, .ltr)
				transient_assert_runs_equal(first, legacy)
				if first.glyph_run.glyphs_.len > 0 {
					mut changed := first.glyph_run
					changed.glyphs_[0].position.x = 999
					if changed.glyph_indices_.len > 0 {
						changed.glyph_indices_[0] = u16(65535)
						changed.glyph_positions_[0] = 999
					}
				}
				$if gcboehm ? { C.GC_gcollect() }
				second := shape_text_with_spacing(baseline, 0.25, 1.5, text, font, .ltr)
				transient_assert_runs_equal(second, legacy)
			}
		}
	}
}

fn test_width_queries_preserve_shaped_advances_and_float_accumulation_order() {
	font := &Font{family: 'SerenitySans', point_size: 13.25}
	for kind in [GlyphRunTextType.common, .ltr, .rtl] {
		for spacing in [f32(0), -0.75, 2.25] {
			for text in ['', 'A', 'AV word ', 'a\u200db ', 'مرحبا', '文😀'] {
				platform_shaping_cache = &ShapingCache{}
				original := shape_text_uncached(0, spacing, 1.25, text, font, kind)
				assert shaped_text_width(spacing, 1.25, text, font, kind) == original.glyph_run.width()
				assert shaped_text_width(spacing, 1.25, text, font, kind) == original.glyph_run.width()
				transient_assert_runs_equal(shape_text_with_spacing(0, spacing, 1.25, text, font, kind), original)
			}
		}
	}
	platform_shaping_cache = &ShapingCache{}
	glyphs := [Glyph{advance: 16_777_216}, Glyph{advance: 1}, Glyph{advance: -16_777_216}, Glyph{advance: 0.125}]
	shape := CachedShape{glyphs: glyphs}
	params := ShapeParams.new(.ltr, 0, 0)
	platform_shaping_cache.store(shaping_cache_font_key(font), 'synthetic width', params, shape)
	expected := shaped_text_with_baseline(shape, 0, font, .ltr).glyph_run.width()
	assert math.f32_bits(shaped_text_width(0, 0, 'synthetic width', font, .ltr)) == math.f32_bits(expected)
}

fn transient_cache_recency(cache &ShapingCache) []u64 {
	mut values := [cache.tick, u64(cache.fonts.len)]
	for font in cache.fonts {
		values << font.last_used_tick
		values << u64(font.shapes_by_text.len)
		for entry in font.shapes_by_text {
			values << entry.last_used_tick
			values << u64(entry.shapes.len)
		}
	}
	return values
}

fn test_width_queries_advance_the_same_cache_recency_and_population_as_full_runs() {
	font := &Font{family: 'SerenitySans', point_size: 16}
	full := &ShapingCache{}
	width := &ShapingCache{}
	for text in ['A', 'word', 'A', 'word', 'other', 'word'] {
		for kind in [GlyphRunTextType.common, .ltr] {
			platform_shaping_cache = full
			run := shape_text_with_spacing(0, 0, 0, text, font, kind)
			platform_shaping_cache = width
			assert shaped_text_width(0, 0, text, font, kind) == run.glyph_run.width()
			assert transient_cache_recency(full) == transient_cache_recency(width)
		}
	}
}

fn test_cached_width_hits_allocate_less_than_materializing_mutable_glyph_runs() {
	platform_shaping_cache = &ShapingCache{}
	font := &Font{family: 'SerenitySans', point_size: 16}
	text := 'width-only cached text'
	expected := shape_text_with_spacing(0, 0, 0, text, font, .ltr).glyph_run.width()
	_ = shaped_text_width(0, 0, text, font, .ltr)
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut width_sum := f32(0)
	for _ in 0 .. 1000 { width_sum += shaped_text_width(0, 0, text, font, .ltr) }
	mut width_allocated := uint(0)
	$if gcboehm ? { width_allocated = C.GC_get_total_bytes() - before }
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut run_sum := f32(0)
	for _ in 0 .. 1000 { run_sum += shape_text_with_spacing(0, 0, 0, text, font, .ltr).glyph_run.width() }
	$if gcboehm ? { assert width_allocated < C.GC_get_total_bytes() - before }
	assert width_sum == run_sum
	assert width_sum > expected
}
