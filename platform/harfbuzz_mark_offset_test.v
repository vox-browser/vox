// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module platform

import math

// Ladybird 3c3783ccd1f0604e769eef26a5a126da0719f9ab: Noto Sans Arabic
// shapes yeh as a dotless base plus a mark displaced 0.232em down. The dots
// must extend below the base in both ink bounds and retained paint positions.
fn test_harfbuzz_yeh_mark_extends_below_its_dotless_base() {
	for policy in [FontRenderingPolicy.libweb, .chromium] {
		font := &Font{
			family: 'YehSubset'
			point_size: 100
			source_path: @VMODROOT + '/platform/testdata/NotoSansArabic-yeh-subset.ttf'
			font_rendering_policy: policy
		}
		yeh := shape_text_with_harfbuzz(0, 0, 0, 'ي', font, .rtl) or { panic('HarfBuzz did not shape yeh') }
		dotless := shape_text_with_harfbuzz(0, 0, 0, 'ى', font, .rtl) or { panic('HarfBuzz did not shape dotless yeh') }
		assert yeh.glyph_run.glyphs().len == 2
		assert dotless.glyph_run.glyphs().len == 1
		yeh_ink := yeh.glyph_run.outline_ink_bounds() or { panic('missing yeh ink bounds') }
		dotless_ink := dotless.glyph_run.outline_ink_bounds() or { panic('missing dotless yeh ink bounds') }
		assert math.abs(yeh_ink.y + yeh_ink.height - 43.4) < 0.02
		assert math.abs(dotless_ink.y + dotless_ink.height - 23.2) < 0.02
		assert yeh.glyph_run.width() == dotless.glyph_run.width()
		positions := yeh.glyph_run.glyph_positions()
		assert positions.len == 4
		assert math.abs(positions[1] - 23.2) < 0.02
		assert positions[3] == 0
	}
}
