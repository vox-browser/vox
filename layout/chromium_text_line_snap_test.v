module layout

import painting
import platform

fn text_line_snap_fragment(policy platform.FontRenderingPolicy, y f64) TextFragment {
	font := &platform.Font{family: 'Test', point_size: 10, font_rendering_policy: policy}
	run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{code_point: u32(`a`), advance: 6}])
	return TextFragment{y: y, paint_line_top: 20.265625,
		paintable_fragment: painting.PaintableFragment{glyph_run: run}}
}

fn test_chromium_text_painting_rounds_the_line_origin_and_keeps_inline_alignment() {
	first := text_line_snap_fragment(.chromium, 21.5)
	second := text_line_snap_fragment(.chromium, 22.265625)
	assert text_fragment_paint_top(first) == 21.234375
	assert text_fragment_paint_top(second) == 22
	assert text_fragment_paint_top(second) - text_fragment_paint_top(first) == second.y - first.y
	assert text_fragment_paint_top(text_line_snap_fragment(.libweb, 21.5)) == 21.5
}
