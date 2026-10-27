module platform

fn test_safe_break_metrics_require_exact_known_coverage_and_both_boundaries() {
	shape := CachedShape{
		glyphs: [
			Glyph{ advance: 5, offset_x: 0.25, length_in_code_units: 1, shaping_break_safety: 1 },
			Glyph{ advance: 3, length_in_code_units: 2, shaping_break_safety: 2 },
			Glyph{ advance: 7, offset_x: 0.5, length_in_code_units: 1, shaping_break_safety: 1 },
			Glyph{ advance: 2, offset_x: 8, length_in_code_units: 1, shaping_break_safety: 1 },
		]
	}
	assert cached_shape_safe_break_width(shape, 0, 3, 5) or { panic('safe prefix missing') } == 7.75
	assert cached_shape_safe_break_width(shape, 3, 1, 5) or { panic('safe middle missing') } == 6.5
	assert cached_shape_safe_break_width(shape, 3, 2, 5) or { panic('safe suffix missing') } == 8.5
	for range in [[0, 1], [1, 2], [2, 1], [-1, 1], [0, 0], [4, 2]] {
		assert cached_shape_safe_break_width(shape, range[0], range[1], 5) == none
	}
	assert cached_shape_safe_break_width(shape, 0, 3, 6) == none
	assert cached_shape_safe_break_width(CachedShape{ ...shape, face: .emoji }, 0, 3, 5) == none
	for field in ['unknown', 'invalid', 'zero', 'negative'] {
		mut glyphs := shape.glyphs.clone()
		match field {
			'unknown' { glyphs[3].shaping_break_safety = 0 }
			'invalid' { glyphs[3].shaping_break_safety = 3 }
			'zero' { glyphs[3].length_in_code_units = 0 }
			else { glyphs[3].length_in_code_units = -1 }
		}
		assert cached_shape_safe_break_width(CachedShape{ glyphs: glyphs }, 0, 3, 5) == none
	}
	precise := CachedShape{
		glyphs: [
			Glyph{ advance: 16_777_216, length_in_code_units: 1, shaping_break_safety: 1 },
			Glyph{ advance: 1, length_in_code_units: 1, shaping_break_safety: 1 },
			Glyph{ advance: -16_777_216, length_in_code_units: 1, shaping_break_safety: 1 },
		]
	}
	assert cached_shape_safe_break_width(precise, 0, 3, 3) or { panic('precise sum missing') } == 1
}

fn test_harfbuzz_safe_ascii_ranges_match_independently_shaped_pieces() {
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	mut accepted := 0
	mut rejected := 0
	for text in ['AVATAR ffi To Wa Y word', 'normal words and spaces'] {
		for spacing in [[f32(0), 0], [f32(0.25), 1.25], [f32(-0.75), 0], [f32(-40), -40]] {
			platform_shaping_cache = &ShapingCache{}
			assert shaped_text_safe_break_width(spacing[0], spacing[1], text, 0, text.len, font) == none
			full := shape_text_with_spacing(0, spacing[0], spacing[1], text, font, .ltr)
			for start in 0 .. text.len {
				for end in start + 1 .. text.len + 1 {
					if width := shaped_text_safe_break_width(spacing[0], spacing[1], text, start, end - start, font) {
						piece := shape_text_with_spacing(0, spacing[0], spacing[1], text[start..end], font, .ltr)
						expected := cached_shape_context_metrics(cached_shape_from(piece)) or { panic('missing piece metrics') }
						assert width == expected.width
						accepted++
					} else {
						rejected++
					}
				}
			}
			// Public runs cannot mutate the owned cache's break metadata.
			mut changed := full.glyph_run
			for mut glyph in changed.glyphs_ { glyph.shaping_break_safety = 0 }
			assert shaped_text_safe_break_width(spacing[0], spacing[1], text, 0, text.len, font) != none
		}
	}
	assert accepted > 0
	assert rejected > 0
}

fn test_safe_break_lookup_keeps_font_spacing_direction_and_scratch_ownership() {
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	platform_shaping_cache = &ShapingCache{}
	scratch := begin_thread_scratch('safe break caller')
	text := 'Independent cached words'.clone()
	_ = shape_text_with_spacing(0, 0.25, 1, text, font, .ltr)
	width := shaped_text_safe_break_width(0.25, 1, text, 0, text.len, font) or { panic('missing cache hit') }
	scratch.finish()
	assert shaped_text_safe_break_width(0.25, 1, 'Independent cached words', 0, 24, font) or { panic('retired cache key') } == width
	assert shaped_text_safe_break_width(0, 1, 'Independent cached words', 0, 24, font) == none
	assert shaped_text_safe_break_width(0.25, 0, 'Independent cached words', 0, 24, font) == none
	other := &Font{ family: 'Arial', point_size: 21, font_rendering_policy: .chromium }
	assert shaped_text_safe_break_width(0.25, 1, 'Independent cached words', 0, 24, other) == none
	for kind in [GlyphRunTextType.common, .rtl] {
		platform_shaping_cache = &ShapingCache{}
		shaped := shape_text_with_spacing(0, 0, 0, 'known ASCII', font, kind)
		for glyph in shaped.glyph_run.glyphs_ {
			assert glyph.shaping_break_safety == 0
		}
		assert shaped_text_safe_break_width(0, 0, 'known ASCII', 0, 11, font) == none
	}
	for unicode_text in ['Тест', 'a\u0301', '文😀'] {
		shaped := shape_text_with_spacing(0, 0, 0, unicode_text, font, .ltr)
		for glyph in shaped.glyph_run.glyphs_ {
			assert glyph.shaping_break_safety == 0
		}
		assert shaped_text_safe_break_width(0, 0, unicode_text, 0, unicode_text.len, font) == none
	}
}
