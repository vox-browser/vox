module platform

import math

fn assert_glyph_slice_equal(actual &GlyphRun, expected &GlyphRun) {
	mut finalized := unsafe { &GlyphRun(actual) }
	finalized.refresh_replay_data()
	assert actual.glyphs_.len == expected.glyphs_.len
	for i, glyph in actual.glyphs_ {
		oracle := expected.glyphs_[i]
		assert math.f32_bits(glyph.position.x) == math.f32_bits(oracle.position.x)
		assert math.f32_bits(glyph.position.y) == math.f32_bits(oracle.position.y)
		assert math.f32_bits(glyph.advance) == math.f32_bits(oracle.advance)
		assert math.f32_bits(glyph.offset_x) == math.f32_bits(oracle.offset_x)
		assert glyph.code_point == oracle.code_point
		assert glyph.glyph_index == oracle.glyph_index
		assert glyph.length_in_code_units == oracle.length_in_code_units
		assert glyph.shaping_break_safety == oracle.shaping_break_safety
		assert glyph.should_paint == oracle.should_paint
	}
	assert math.f32_bits(actual.width()) == math.f32_bits(expected.width())
	assert math.f32_bits(actual.space_width) == math.f32_bits(expected.space_width)
	assert actual.glyph_indices() == expected.glyph_indices()
	assert actual.glyph_positions() == expected.glyph_positions()
	assert actual.bounding_box() == expected.bounding_box()
	assert actual.face() == expected.face()
	assert actual.text_type() == expected.text_type()
	assert voidptr(actual.font()) == voidptr(expected.font())
}

fn glyph_slice_values(advances []f32) []Glyph {
	mut glyphs := []Glyph{}
	for i, advance in advances {
		glyphs << Glyph{
			code_point:           if i >= 2 { u32(` `) } else { u32(`A`) }
			glyph_index:          i + 1
			position:             GlyphPosition{f32(i) * 7.125, -f32(i) * 0.25}
			advance:              advance
			offset_x:             f32(i) * -0.75
			length_in_code_units: if i == 1 { 0 } else { 1 }
			should_paint:         i != 1
			shaping_break_safety: if i == 1 { u8(2) } else { u8(1) }
		}
	}
	return glyphs
}

fn test_layout_slices_match_eager_slices_after_publication_and_keep_private_storage() {
	font := &Font{ family: 'SerenitySans', point_size: 13.25 }
	for face in [GlyphRunFace.document, .emoji] {
		for kind in [GlyphRunTextType.ltr, .rtl, .common] {
			for advances in [[f32(7.5), -2, 4, 3.25],
				[f32(16777216), 1, -16777216, 0.125], [f32(-40), 0.25, 0, -0.5]] {
				mut glyphs := glyph_slice_values(advances)
				glyphs[0].position.x = math.f32_from_bits(u32(0x80000000))
				source := GlyphRun.new_with_face(font, kind, glyphs, face)
				for first in 0 .. source.glyphs_.len + 1 {
					for end in first .. source.glyphs_.len + 1 {
						expected := source.slice(first, end - first)
						mut actual := source.slice_for_layout(first, end - first)
						assert actual.replay_data_dirty_
						assert actual.glyph_indices().len == 0
						assert actual.glyph_positions().len == 0
						gc_collect()
						assert_glyph_slice_equal(actual, expected)
						if first < end {
							assert actual.glyphs_.data != source.glyphs_.data
							actual.invalidate_replay_data()
							actual.glyphs_[0].position.x = 999
							actual.refresh_replay_data()
							assert source.glyphs_[first].position.x != 999
						}
					}
				}
			}
		}
	}
}

fn test_translated_glyph_slices_match_the_independent_constructor_for_every_range() {
	font := &Font{ family: 'SerenitySans', point_size: 13.25 }
	for face in [GlyphRunFace.document, .emoji] {
		for kind in [GlyphRunTextType.ltr, .rtl, .common] {
			mut source := GlyphRun.new_with_face(font, kind, glyph_slice_values([
				f32(7.5),
				-2,
				4,
				3.25,
			]), face)
			for first in 0 .. source.glyphs_.len + 1 {
				for end in first .. source.glyphs_.len + 1 {
					for shift in [GlyphPosition{0, 0}, GlyphPosition{-13.125, 9.25},
						GlyphPosition{math.f32_from_bits(u32(0x80000000)), -0.25}] {
						mut glyphs := source.glyphs_[first..end].clone()
						for mut glyph in glyphs { glyph.position.translate_by(shift.x, shift.y) }
						expected := GlyphRun.new_with_face(font, kind, glyphs, face)
						mut actual := source.translated_slice_for_layout(first, end - first, shift.x, shift.y)
						assert actual.replay_data_dirty_
						assert actual.glyph_indices().len == 0
						assert actual.glyph_positions().len == 0
						assert_glyph_slice_equal(actual, expected)
						if first < end {
							assert actual.glyphs_.data != source.glyphs_.data
							actual.invalidate_replay_data()
							actual.glyphs_[0].position.x = 999
							actual.refresh_replay_data()
							assert source.glyphs_[first].position.x != 999
						}
					}
				}
			}
		}
	}
}

fn test_local_context_slices_preserve_exact_rounding_trailing_spaces_and_owned_buffers() {
	font := &Font{ family: 'SerenitySans', point_size: 13.25 }
	for advances in [[f32(7.5), -2, 4, 3.25], [f32(16777216), 1, -16777216, 0.125],
		[f32(-40), 0.25, 0, -0.5]] {
		for face in [GlyphRunFace.document, .emoji] {
			mut source := GlyphRun.new_with_face(font, .ltr, glyph_slice_values(advances), face)
			source.space_width = 123.25
			for first in 0 .. source.glyphs_.len {
				for end in first + 1 .. source.glyphs_.len + 1 {
					expected := reference_ltr_glyph_slice(source, first, end)
					actual := source.ltr_context_slice_for_layout(first, end)
					assert_glyph_slice_equal(actual.glyph_run, expected.glyph_run)
					assert actual.trailing_whitespace == expected.trailing_whitespace
					assert actual.glyph_run.glyphs_.data != source.glyphs_.data
					assert actual.glyph_run.glyph_indices().data != source.glyph_indices().data
					assert actual.glyph_run.glyph_positions().data != source.glyph_positions().data
					gc_collect()
					assert_glyph_slice_equal(actual.glyph_run, expected.glyph_run)
				}
			}
		}
	}
}

fn test_real_shaped_context_slices_leave_the_shared_source_unchanged() {
	font := &Font{ family: 'Arial', point_size: 20, font_rendering_policy: .chromium }
	for text in ['AVATAR ffi To Wa Y word  ', 'Кириллица слова ', 'A  B '] {
		for spacing in [f32(0), 0.25, -0.75, -40] {
			source := shape_text_with_spacing(0, spacing, 1.25, text, font, .ltr).glyph_run
			snapshot := source.clone_for_layout()
			for first in 0 .. source.glyphs_.len {
				for end in first + 1 .. source.glyphs_.len + 1 {
					expected := reference_ltr_glyph_slice(source, first, end)
					actual := source.ltr_context_slice_for_layout(first, end)
					assert_glyph_slice_equal(actual.glyph_run, expected.glyph_run)
					assert actual.trailing_whitespace == expected.trailing_whitespace
				}
			}
			assert_glyph_slice_equal(source, snapshot)
		}
	}
}

fn reference_ltr_glyph_slice(run &GlyphRun, first int, end int) ShapedText {
	// Blink sums the 16.16 advances of a line's part of an item exactly from
	// its first glyph, then converts each sum to float. Subtracting the float
	// pens of a paragraph-long run instead moves glyphs hundreds of pixels in
	// by a few ULPs, enough to change their quarter-pixel raster position.
	// The slice starts at its first glyph's placement, which HarfBuzz's split
	// 'kern' adjustments can move, and ends at the next glyph's.
	mut glyphs := run.glyphs_[first..end].clone()
	origin := f64(glyphs[0].offset_x)
	mut local := f64(0)
	for mut glyph in glyphs {
		glyph.position.x = f32(local + f64(glyph.offset_x) - origin)
		local += f64(glyph.advance)
	}
	next_offset := if end < run.glyphs_.len { f64(run.glyphs_[end].offset_x) } else { f64(0) }
	mut sliced := GlyphRun.new_with_face(run.font(), .ltr, glyphs, run.face())
	sliced.width_ = f32(local + next_offset - origin)
	sliced.space_width = run.space_width
	mut trailing_length := 0
	mut trailing_advance := f32(0)
	for index := glyphs.len - 1; index >= 0; index-- {
		glyph := glyphs[index]
		if glyph.code_point != u32(` `) {
			break
		}
		trailing_length += glyph.length_in_code_units
		trailing_advance += glyph.advance
	}
	return ShapedText{
		glyph_run:           sliced
		trailing_whitespace: TrailingWhitespace{
			length_in_code_units: trailing_length
			advance:              trailing_advance
		}
	}
}

fn test_deferred_layout_slice_forks_publish_independent_replay_after_gc() {
	font := &Font{ family: 'SerenitySans', point_size: 13.25 }
	source := GlyphRun.new(font, .ltr, glyph_slice_values([f32(7.5), -2, 4, 3.25]))
	mut pending := source.ltr_context_slice_for_layout(0, source.glyphs_.len).glyph_run
	mut cloned := pending.clone_for_layout()
	mut forked := pending.fork_for_layout()
	assert pending.replay_data_dirty_ && cloned.replay_data_dirty_ && forked.replay_data_dirty_
	assert pending.glyph_indices().len == 0 && pending.glyph_positions().len == 0
	assert cloned.glyph_indices().len == 0 && cloned.glyph_positions().len == 0
	assert forked.glyph_indices().len == 0 && forked.glyph_positions().len == 0
	forked.invalidate_replay_data()
	forked.glyphs_[0].position.x = 999
	forked.refresh_replay_data()
	assert pending.replay_data_dirty_ && cloned.replay_data_dirty_
	assert pending.glyphs_[0].position.x != 999 && cloned.glyphs_[0].position.x != 999
	assert source.glyphs_[0].position.x != 999
	gc_collect()
	expected := reference_ltr_glyph_slice(source, 0, source.glyphs_.len).glyph_run
	assert_glyph_slice_equal(pending, expected)
	assert_glyph_slice_equal(cloned, expected)
	assert !pending.replay_data_dirty_ && !cloned.replay_data_dirty_
	assert forked.glyph_positions()[0] == 999
	assert pending.glyph_positions().data != cloned.glyph_positions().data
	assert pending.glyph_positions().data != forked.glyph_positions().data
}
