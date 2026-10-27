module layout

import platform

fn context_cursor_test_run() &platform.GlyphRun {
	font := &platform.Font{ family: 'Test', point_size: 16, font_rendering_policy: .chromium }
	return platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: `A`, advance: 7, length_in_code_units: 1 },
		platform.Glyph{ code_point: 0x1f600, advance: 11, length_in_code_units: 2 },
		platform.Glyph{ code_point: `f`, advance: 9, length_in_code_units: 2 },
		platform.Glyph{ code_point: ` `, advance: 3, length_in_code_units: 1 },
		platform.Glyph{ code_point: `Z`, advance: 8, length_in_code_units: 1 },
	])
}

fn test_context_cursor_tracks_utf16_boundaries_and_keeps_owned_glyphs() {
	run := context_cursor_test_run()
	mut cursor := ChromiumContextSliceCursor{}
	for index, boundary in [0, 1, 3, 5, 6] {
		length := if index in [1, 2] { 2 } else { 1 }
		shaped := chromium_context_slice_with_cursor(run,
			TextNodeChunk{ start: boundary, length: length }, mut cursor) or { panic('missing chunk') }
		assert shaped.glyph_run.glyphs_.len == 1
		assert shaped.glyph_run.glyphs_[0].code_point == run.glyphs_[index].code_point
		assert shaped.glyph_run.width() == run.glyphs_[index].advance
		assert cursor.index == index + 1
		assert cursor.offset == boundary + length
		assert voidptr(shaped.glyph_run.glyphs_.data) != voidptr(run.glyphs_.data)
		assert shaped.trailing_whitespace.length_in_code_units == if index == 3 { 1 } else { 0 }
	}
}

fn test_context_cursor_rejects_split_clusters_and_restarts_for_backward_requests() {
	run := context_cursor_test_run()
	mut cursor := ChromiumContextSliceCursor{}
	_ = chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 1, length: 2 }, mut cursor) or { panic('missing emoji') }
	assert chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 3, length: 1 }, mut cursor) == none
	assert chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 4, length: 1 }, mut cursor) == none
	assert cursor.index == 2 && cursor.offset == 3
	ligature := chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 3, length: 2 }, mut cursor) or { panic('missing ligature') }
	assert ligature.glyph_run.width() == 9
	first := chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 0, length: 1 }, mut cursor) or { panic('missing first glyph') }
	assert first.glyph_run.glyphs_[0].code_point == `A`
	assert cursor.index == 1 && cursor.offset == 1
	assert chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 7, length: 0 }, mut cursor) == none
	assert chromium_context_slice_with_cursor(run, TextNodeChunk{ start: 8, length: 1 }, mut cursor) == none
}

fn test_segmented_context_cursor_restarts_at_each_run_and_skips_gaps() {
	first := context_cursor_test_run()
	second := context_cursor_test_run()
	runs := [ChromiumTextContextRun{10, 17, first}, ChromiumTextContextRun{20, 27, second}]
	mut cursor := ChromiumContextSliceCursor{}
	for start in [16, 26, 10, 20] {
		shaped := chromium_segmented_context_slice_with_cursor(runs,
			TextNodeChunk{ start: start, length: 1 }, mut cursor) or { panic('missing segment') }
		assert shaped.glyph_run.glyphs_[0].code_point == if start in [16, 26] {
			u32(`Z`)
		} else {
			u32(`A`)
		}
		assert voidptr(cursor.run) == voidptr(if start >= 20 { second } else { first })
	}
	assert chromium_segmented_context_slice_with_cursor(runs, TextNodeChunk{ start: 17, length: 3 }, mut cursor) == none
	assert chromium_segmented_context_slice_with_cursor(runs, TextNodeChunk{ start: 16, length: 5 }, mut cursor) == none
}
