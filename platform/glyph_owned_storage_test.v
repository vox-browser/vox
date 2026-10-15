module platform

import math

fn owned_glyph_test_values() []Glyph {
	return [
		Glyph{ code_point: u32(`A`), glyph_index: 1, position: GlyphPosition{1.25, -2}, advance: 7.5 },
		Glyph{ code_point: u32(` `), glyph_index: 2, position: GlyphPosition{8.75, 0}, advance: 3.25 },
		Glyph{ code_point: u32(`x`), glyph_index: 3, position: GlyphPosition{12, 2.5}, advance: 4, should_paint: false },
	]
}

fn owned_glyph_test_equal(first &GlyphRun, second &GlyphRun) {
	assert first.glyphs_ == second.glyphs_
	assert first.glyph_indices() == second.glyph_indices()
	assert first.glyph_positions() == second.glyph_positions()
	assert first.bounding_box() == second.bounding_box()
	assert first.width() == second.width()
	assert first.space_width == second.space_width
	assert voidptr(first.font()) == voidptr(second.font())
	assert first.face() == second.face()
	assert first.text_type() == second.text_type()
}

fn test_public_glyph_constructor_keeps_independent_input_storage() {
	font := &Font{ family: 'SerenitySans', point_size: 13.25 }
	mut input := owned_glyph_test_values()
	run := GlyphRun.new_with_face(font, .rtl, input, .document)
	expected := input.clone()
	assert run.glyphs_.data != input.data
	input[0].position.x = 12345
	input[0].advance = 12345
	input << Glyph{ advance: 500 }
	gc_collect()
	assert run.glyphs_ == expected
	assert run.glyph_indices() == [u16(1), 2]
	assert run.glyph_positions() == [f64(1.25), -2, 8.75, 0]
	assert run.width() == 14.75
	assert run.space_width == 3.25
}

fn owned_glyph_test_returned_producer(font &Font) &GlyphRun {
	owned := owned_glyph_test_values()
	run := glyph_run_with_owned_glyphs(font, .common, owned, .document)
	assert run.glyphs_.data == owned.data
	return run
}

fn test_owned_glyph_storage_survives_producer_exit_and_gc_without_an_extra_copy() {
	font := &Font{ family: 'SerenitySans', point_size: 16 }
	run := owned_glyph_test_returned_producer(font)
	for _ in 0 .. 3 {
		gc_collect()
		assert run.glyphs_ == owned_glyph_test_values()
		assert run.glyph_positions() == [f64(1.25), -2, 8.75, 0]
	}
}

fn test_cached_shape_owned_transfer_preserves_baselines_faces_and_mutation_isolation() {
	for invisible in [false, true] {
		font := &Font{ family: 'SerenitySans', point_size: 13.25, is_invisible: invisible }
		for glyphs in [owned_glyph_test_values(), []Glyph{}] {
			for face in [GlyphRunFace.document, .emoji] {
				shape := CachedShape{ glyphs: glyphs, face: face, trailing_whitespace: TrailingWhitespace{1, 3.25} }
				for baseline in [f32(0), 17.25, -9.5, math.f32_from_bits(u32(0x8000_0000))] {
					mut legacy_glyphs := shape.glyphs.clone()
					if baseline != 0 {
						for mut glyph in legacy_glyphs { glyph.position.x += baseline }
					}
					legacy := GlyphRun.new_with_face(font, .rtl, legacy_glyphs, face)
					first := shaped_text_with_baseline(shape, baseline, font, .rtl)
					owned_glyph_test_equal(first.glyph_run, legacy)
					assert first.trailing_whitespace == shape.trailing_whitespace
					if glyphs.len > 0 {
						assert first.glyph_run.glyphs_.data != shape.glyphs.data
						mut changed := first.glyph_run
						changed.glyphs_[0].position.x = 999
						changed.glyph_indices_[0] = u16(65535)
						changed.glyph_positions_[0] = 999
					}
					gc_collect()
					second := shaped_text_with_baseline(shape, baseline, font, .rtl)
					owned_glyph_test_equal(second.glyph_run, legacy)
					assert shape.glyphs == glyphs
				}
			}
		}
	}
}
