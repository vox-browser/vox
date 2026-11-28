// vtest build: macos
module cpuraster

import os

fn test_filtered_glyph_masks_ignore_paint_preblend_and_keep_separate_cache_entries() {
	font := os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/glyph-origin.ttf')
	run := CanvasGlyphRun{
		font_path:         font
		font_size:         15
		glyphs:            [u16(2), 3, 3, 3, 1, 2, 3, 3, 3]
		positions:         [f32(17.5), 48, 21.009995, 48, 34.374985, 48, 47.740005, 48, 61.10501,
			48, 64.85501, 48, 68.365005, 48, 81.73001, 48, 95.09502, 48]
		baseline_snap:     true
		smoothing:         0
		retained:          true
		chromium_coverage: true
	}
	transform := [f32(1), 0, 0, 1, -16, -35]!
	mut cache := new_glyph_cache()
	mut ordinary := []u8{len: 94 * 15 * 4}
	assert fill_canvas_glyphs_cached(mut cache, mut ordinary, 94, 15, 376, 2, run, transform, 0xff000000, none, 1, .src_over, [], none)
	mut linear := []u8{len: ordinary.len}
	filtered := CanvasGlyphRun{ ...run, linear_coverage: true }
	assert fill_canvas_glyphs_cached(mut cache, mut linear, 94, 15, 376, 2, filtered, transform, 0xff000000, none, 1, .src_over, [], none)
	mut white := []u8{len: ordinary.len}
	assert fill_canvas_glyphs_cached(mut cache, mut white, 94, 15, 376, 2, filtered, transform, 0xffffffff, none, 1, .src_over, [], none)
	assert []u8{len: linear.len / 4, init: linear[index * 4 + 3]} == []u8{len: white.len / 4, init: white[index * 4 + 3]}
	mut again := []u8{len: ordinary.len}
	assert fill_canvas_glyphs_cached(mut cache, mut again, 94, 15, 376, 2, run, transform, 0xff000000, none, 1, .src_over, [], none)
	assert again == ordinary
	mut uncached := []u8{len: ordinary.len}
	assert fill_canvas_glyphs(mut uncached, 94, 15, 376, 2, filtered, transform, 0xff000000, none, 1, .src_over, [], none)
	assert uncached == linear
	assert linear != ordinary
}
