module platform

fn test_chromium_spacing_truncates_both_signs_to_text_run_precision() {
	font := &Font{ font_rendering_policy: .chromium }
	for spacing in [f32(.08), -.08, .013, -.013, 0, .000001, -.000001, .125, -.125] {
		expected := f32(f64(i64(f64(spacing) * 65536)) / 65536)
		assert font.quantized_shaping_spacing(spacing) == expected
	}
	assert font.quantized_shaping_spacing(.08) == f32(5242.0 / 65536)
	assert font.quantized_shaping_spacing(-.08) == f32(-5242.0 / 65536)
	assert font.quantized_shaping_spacing(40000) == f32(2147483647.0 / 65536)
	assert font.quantized_shaping_spacing(-40000) == -32768
}

fn test_shaped_chromium_glyphs_add_fixed_point_letter_and_word_spacing() {
	font := &Font{ family: 'Serif', point_size: 16, font_rendering_policy: .chromium }
	bare := shape_text_with_spacing(0, 0, 0, 'a a', font, .ltr).glyph_run.glyphs()
	assert bare.len == 3
	for letter in [f32(.08), -.08] {
		for word in [f32(.013), -.013] {
			shaped := shape_text_with_spacing(0, letter, word, 'a a', font, .ltr).glyph_run.glyphs()
			assert shaped.len == bare.len
			for index, glyph in shaped {
				expected := bare[index].advance + font.quantized_shaping_spacing(letter) +
					if index == 1 { font.quantized_shaping_spacing(word) } else { f32(0) }
				assert glyph.advance == expected
			}
		}
	}
	// A nonzero authored value still disables optional ligatures even when its
	// converted advance is zero. Keep that feature decision before conversion.
	if system_font_family_available('Times') {
		assert shape_text_with_spacing(0, .000001, 0, 'fi', font, .ltr).glyph_run.glyphs().len == 2
	}
}

fn test_libweb_text_spacing_keeps_its_original_float_precision() {
	font := &Font{ family: 'Serif', point_size: 16, font_rendering_policy: .libweb }
	assert font.quantized_shaping_spacing(.08) == f32(.08)
	assert font.quantized_shaping_spacing(-.013) == f32(-.013)
	bare := shape_text_with_spacing(0, 0, 0, 'a a', font, .ltr).glyph_run.glyphs()
	shaped := shape_text_with_spacing(0, .08, .013, 'a a', font, .ltr).glyph_run.glyphs()
	for index, glyph in shaped {
		assert glyph.advance == bare[index].advance + f32(.08) +
			if index == 1 { f32(.013) } else { f32(0) }
	}
}
