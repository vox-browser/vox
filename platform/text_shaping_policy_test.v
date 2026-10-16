module platform

import math

fn test_shaping_precision_keeps_fractional_advances_and_isolates_cached_runs() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	coarse := &Font{family: 'TestFace', point_size: 13.25, source_path: source}
	precise := &Font{ ...coarse, text_shaping_policy: .chromium }
	advance, _ := precise.glyph_metrics(u32(`x`))
	coarse_advance := f32(math.round(f64(advance) * 64) / 64)
	precise_advance := f32(math.round(f64(advance) * 65536) / 65536)
	assert coarse_advance != precise_advance
	assert !coarse.has_same_identity(precise)
	assert shaping_cache_font_key(coarse) != shaping_cache_font_key(precise)
	for _ in 0 .. 3 {
		for font in [coarse, precise, &Font{ ...precise }, &Font{ ...coarse }] {
			shape := shape_text(0, 0, 'xxxxxxxx', font, .ltr)
			expected := if font.text_shaping_policy == .chromium { precise_advance } else { coarse_advance }
			for i, glyph in shape.glyphs() {
				assert math.abs(glyph.position.x - f32(i) * expected) < 0.00001
				assert math.abs(glyph.advance - expected) < 0.00001
			}
		}
	}
}
