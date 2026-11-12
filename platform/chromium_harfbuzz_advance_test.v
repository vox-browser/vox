module platform

// Arial at 13.333333px: Skia's strike gives "l" 2.961499px, which Blink
// truncates to 194084/65536 where HarfBuzz's own scaling rounds to 194085.
fn test_chromium_advances_truncate_native_widths_to_harfbuzz_positions() {
	assert chromium_harfbuzz_advance(2.961499, 194085, 194085) == f32(194084.0 / 65536.0)
	// The kerning HarfBuzz applied to "T" before "e" is kept at its scale.
	assert chromium_harfbuzz_advance(8.142495, 436797, 533626) == f32((533626.0 - 96829.0) / 65536.0)
	// Whole-pixel widths are exact.
	assert chromium_harfbuzz_advance(8, 524288, 524288) == 8
}
