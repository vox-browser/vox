module cpuraster

import crypto.sha256
import os

fn test_retained_glyphs_match_the_unchanged_brave_origin_fixture() {
	$if !macos {
		return
	}
	run := CanvasGlyphRun{
		font_path:         os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/glyph-origin.ttf')
		font_size:         15
		glyphs:            [u16(2), 3, 3, 3, 1, 2, 3, 3, 3]
		positions:         [f32(17.5), 48, 21.009995, 48, 34.374985, 48, 47.740005, 48, 61.10501,
			48, 64.85501, 48, 68.365005, 48, 81.73001, 48, 95.09502, 48]
		baseline_snap:     true
		smoothing:         2
		retained:          true
		chromium_coverage: true
	}
	mut pixels := []u8{len: 94 * 15 * 4, init: [u8(9), 11, 15, 255][index % 4]}
	mut cached := pixels.clone()
	transform := [f32(1), 0, 0, 1, -16, -35]!
	mut cache := new_glyph_cache()
	assert fill_canvas_glyphs(mut pixels, 94, 15, 376, 2, run, transform,
		0xffaac6e8, none, 1, .src_over, [], none)
	assert fill_canvas_glyphs_cached(mut cache, mut cached, 94, 15, 376, 2, run, transform,
		0xffaac6e8, none, 1, .src_over, [], none)
	assert pixels == cached
	// The first run's crop from the pre-existing Brave reference, with no fuzz.
	assert sha256.hexhash(pixels.bytestr()) == 'de30ade9f047bb97a6ba0c7c2855643f4ea30a5b7e2b855296dae76138d96692'
}

fn test_retained_glyphs_keep_fractional_author_color_through_coverage() {
	$if !macos {
		return
	}
	run := CanvasGlyphRun{
		font_path:         os.join_path(@VMODROOT, 'Tests/Browser/Brave/resources/glyph-origin.ttf')
		font_size:         15
		glyphs:            [u16(2), 3, 3, 3, 1, 2, 3, 3, 3]
		positions:         [f32(17.5), 48, 21.009995, 48, 34.374985, 48, 47.740005, 48, 61.10501,
			48, 64.85501, 48, 68.365005, 48, 81.73001, 48, 95.09502, 48]
		baseline_snap:     true
		smoothing:         2
		retained:          true
		chromium_coverage: true
		paint_color:       [f32(0.2), 0.2, 0.2, 0.59]!
	}
	mut pixels := []u8{len: 94 * 15 * 4, init: 255}
	mut cached := pixels.clone()
	transform := [f32(1), 0, 0, 1, -16, -35]!
	mut cache := new_glyph_cache()
	assert fill_canvas_glyphs(mut pixels, 94, 15, 376, 2, run, transform, 0x96333333, none, 1, .src_over, [], none)
	assert fill_canvas_glyphs_cached(mut cache, mut cached, 94, 15, 376, 2, run, transform, 0x96333333, none, 1, .src_over, [], none)
	assert pixels == cached
	// Exact x16..110, y35..50 crop of glyph-fractional-color.png from Brave.
	assert sha256.hexhash(pixels.bytestr()) == 'f2eecadae69daf2f97308da3d03536e307e65e1671c834eb34e859509db5863c'
}
