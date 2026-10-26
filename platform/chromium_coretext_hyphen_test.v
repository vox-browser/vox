module platform

fn test_chromium_coretext_hyphens_keep_the_selected_system_face() {
	$if macos {
		for family in ['Arial', 'Times'] {
			font := &Font{ family: family, point_size: 20, font_rendering_policy: .chromium }
			face := document_harfbuzz_face(font) or { panic('missing system face') }
			raw := scaled_harfbuzz_font(face, 20, font.shaping_resolution(), font.variations()) or { panic('no raw font') }
			mut raw_glyph := u32(0)
			assert C.hb_font_get_nominal_glyph(raw, 0x2011, &raw_glyph) == 0
			ascii := shape_text_with_harfbuzz(0, 0, 0, '-', font, .ltr) or { panic('no dash') }
			for text in ['‐', '‑'] {
				assert font.contains_glyph(u32(text.runes()[0]))
				shaped := shape_text_with_harfbuzz(0, 0, 0, text, font, .ltr) or { panic('no hyphen') }
				assert shaped.glyph_run.glyphs().len == 1
				glyph := shaped.glyph_run.glyphs()[0]
				assert glyph.glyph_index == ascii.glyph_run.glyphs()[0].glyph_index
				assert glyph.advance == ascii.glyph_run.glyphs()[0].advance
				assert glyph.code_point == u32(text.runes()[0])
				assert glyph.length_in_code_units == 1
			}
			assert !font.contains_glyph(0x10ffff)
		}
	}
}

fn test_chromium_coretext_hyphens_apply_to_file_backed_faces() {
	$if macos {
		system := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
		path := system.font_path() or { panic('missing Arial path') }
		font := &Font{ family: 'Downloaded face', source_path: path, point_size: 20, font_rendering_policy: .chromium }
		assert font.system_face() == none
		assert font.contains_glyph(0x2011)
		shaped := shape_text_with_harfbuzz(0, 0, 0, 'A‑B', font, .ltr) or { panic('no run') }
		ascii := shape_text_with_harfbuzz(0, 0, 0, 'A-B', font, .ltr) or { panic('no run') }
		assert shaped.glyph_run.glyphs().len == 3
		for i, glyph in shaped.glyph_run.glyphs() {
			assert glyph.glyph_index == ascii.glyph_run.glyphs()[i].glyph_index
			assert glyph.advance == ascii.glyph_run.glyphs()[i].advance
			assert glyph.position == ascii.glyph_run.glyphs()[i].position
			assert glyph.length_in_code_units == 1
		}
		// A cache entry made for one policy must not change another's coverage.
		legacy := &Font{ ...font, font_rendering_policy: .libweb }
		assert !legacy.contains_glyph(0x2010)
		assert !legacy.contains_glyph(0x2011)
		assert !font.contains_glyph(0x10ffff)
		assert font.contains_glyph(0x2011)
	}
}

fn test_chromium_coretext_hyphens_preserve_real_cmap_glyphs() {
	$if macos {
		font := &Font{ family: 'Helvetica', point_size: 20, font_rendering_policy: .chromium }
		face := document_harfbuzz_face(font) or { panic('missing Helvetica') }
		raw := scaled_harfbuzz_font(face, 20, font.shaping_resolution(), font.variations()) or { panic('no raw font') }
		ascii := shape_text_with_harfbuzz(0, 0, 0, '-', font, .ltr) or { panic('no dash') }
		for text in ['‐', '‑'] {
			mut expected := u32(0)
			assert C.hb_font_get_nominal_glyph(raw, u32(text.runes()[0]), &expected) != 0
			assert expected != 0
			assert font.contains_glyph(u32(text.runes()[0]))
			shaped := shape_text_with_harfbuzz(0, 0, 0, text, font, .ltr) or { panic('no hyphen') }
			assert shaped.glyph_run.glyphs()[0].glyph_index == int(expected)
			assert shaped.glyph_run.glyphs()[0].glyph_index != ascii.glyph_run.glyphs()[0].glyph_index
		}
	}
}

fn test_chromium_coretext_hyphens_survive_native_cache_retirement() {
	$if macos {
		font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
		old := shape_text_with_harfbuzz(0, 0, 0, 'A‑B', font, .ltr) or { panic('no run') }
		expected := old.glyph_run.glyphs().clone()
		for _ in 0 .. 3 {
			release_unused_text_shaping()
			assert font.contains_glyph(0x2011)
			shaped := shape_text_with_harfbuzz(0, 0, 0, 'A‑B', font, .ltr) or { panic('no run') }
			assert shaped.glyph_run.glyphs() == expected
			assert old.glyph_run.glyphs() == expected
		}
	}
}
