module platform

// Deferred at the user's request until the browser reaches Brave parity.
fn test_latin_punctuation_ranges_preserve_independent_shape_and_utf16_offsets() {
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	mut accepted := 0
	mut rejected := 0
	for text in ['“AVATAR” To Y word', 'it’s a “normal” word…', 'word—other–word'] {
		units := utf16_code_units(text)
		assert units.len < text.len
		for spacing in [[f32(0), 0], [f32(0.25), 1.25], [f32(-0.75), 0], [f32(-40), -40]] {
			platform_shaping_cache = &ShapingCache{}
			assert shaped_text_safe_break_width(spacing[0], spacing[1], text, 0, units.len, font) == none
			_ = shape_text_with_spacing(0, spacing[0], spacing[1], text, font, .ltr)
			for start in 0 .. units.len {
				for end in start + 1 .. units.len + 1 {
					if width := shaped_text_safe_break_width(spacing[0], spacing[1], text, start, end - start, font) {
						// All accepted scalars are BMP, so runes are the UTF-16 oracle.
						piece := text.runes()[start..end].string()
						shaped := shape_text_with_spacing(0, spacing[0], spacing[1], piece, font, .ltr)
						metrics := cached_shape_context_metrics(cached_shape_from(shaped)) or { panic('missing independent metrics') }
						assert width == metrics.width
						accepted++
					} else { rejected++ }
				}
			}
			for start in [-1, units.len, units.len + 1] {
				assert shaped_text_safe_break_width(spacing[0], spacing[1], text, start, 1, font) == none
			}
			assert shaped_text_safe_break_width(spacing[0], spacing[1], text, 0, text.len, font) == none
		}
	}
	assert accepted > 0
	assert rejected > 0
}

fn test_latin_punctuation_safety_rejects_script_changes_and_ambiguous_text() {
	for text in ['A “word”', 'A–B', 'A…B', 'word’s'] {
		assert harfbuzz_latin_punctuation_units(utf16_code_units(text))
	}
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	for text in ['“”…', 'A\u0301', 'café', 'A😀B', 'AТест', 'A文', 'A\u200dB'] {
		assert !harfbuzz_latin_punctuation_units(utf16_code_units(text))
		platform_shaping_cache = &ShapingCache{}
		shape := shape_text_with_spacing(0, 0, 0, text, font, .ltr)
		for glyph in shape.glyph_run.glyphs_ { assert glyph.shaping_break_safety == 0 }
		assert shaped_text_safe_break_width(0, 0, text, 0, utf16_code_units(text).len, font) == none
	}
	platform_shaping_cache = &ShapingCache{}
	_ = shape_text_with_spacing(0, 0, 0, 'A “word”', font, .ltr)
	// Punctuation-only pieces retain the original independent-shaping path.
	assert shaped_text_safe_break_width(0, 0, 'A “word”', 2, 1, font) == none
}
