module platform

fn test_chromium_letter_spacing_disables_optional_ligatures_without_changing_other_policies() {
	$if macos {
		for policy in [FontRenderingPolicy.libweb, .chromium] {
			font := &Font{family:'Times', point_size:23, font_rendering_policy:policy}
			for spacing in [f32(0), -.8, .8, 0] {
				run := shape_text_with_spacing(0, spacing, 0, 'fi', font, .ltr).glyph_run
				expected := if policy == .chromium && spacing == 0 { 1 } else { 2 }
				assert run.glyphs().len == expected
				if expected == 2 {
					assert run.glyphs()[0].length_in_code_units == 1
					assert run.glyphs()[1].length_in_code_units == 1
				}
			}
			// Word spacing alone does not disable the font's fi ligature.
			expected_unspaced := if policy == .chromium { 1 } else { 2 }
			assert shape_text_with_spacing(0, 0, 1, 'fi', font, .ltr).glyph_run.glyphs().len == expected_unspaced
		}
	}
}
