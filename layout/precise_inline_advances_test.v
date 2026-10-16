module layout

import css
import dom
import math
import platform

fn test_precise_word_advances_round_once_after_merging_and_restart_on_new_lines() {
	document := dom.Document.create(dom.url_about_blank())
	mut parent := BlockContainer.new(document, none, css.ComputedProperties.new())
	text := document.create_text_node('abcd')
	node := TextNode.new(document, text.as_node(), 'abcd')
	parent.append_child(unsafe { &Node(node) })
	for policy in [platform.FontRenderingPolicy.libweb, .chromium] {
		font := &platform.Font{
			family:                'Test'
			point_size:            10
			font_rendering_policy: policy
		}
		advance := f32(6.162109375)
		mut line := LineBox.new(.ltr, .horizontal_tb)
		for index in 0 .. 4 {
			run := platform.GlyphRun.new(font, .ltr, [
				platform.Glyph{ code_point: u32(`a`), advance: advance },
			])
			line.add_fragment(unsafe { &Node(node) }, index, 1, CSSPixels.new(0), CSSPixels.new(0),
				CSSPixels.new(0), CSSPixels.new(0), shaped_inline_width(run, 0), CSSPixels.new(12),
				CSSPixels.new(0), CSSPixels.new(0), run)
		}
		assert line.fragments().len == 1
		fragment := line.fragments()[0]
		run := fragment.glyph_run() or { panic('missing glyphs') }
		step := if policy == .chromium {
			advance
		} else {
			f32(CSSPixels.nearest_value_for(f64(advance)).to_double())
		}
		for index, glyph in run.glyphs_ {
			assert math.abs(glyph.position.x - step * index) < 0.00001
		}
		expected := if policy == .chromium {
			CSSPixels.from_raw(1578)
		} else {
			CSSPixels.from_raw(1576)
		}
		assert fragment.inline_length() == expected
		assert line.width() == expected
		// A fresh line has its own origin, independent of the previous residual.
		mut next := LineBox.new(.ltr, .horizontal_tb)
		next_run := platform.GlyphRun.new(font, .ltr, [
			platform.Glyph{ code_point: u32(`d`), advance: advance },
		])
		next.add_fragment(unsafe { &Node(node) }, 3, 1, CSSPixels.new(0), CSSPixels.new(0),
			CSSPixels.new(0), CSSPixels.new(0), shaped_inline_width(next_run, 0),
			CSSPixels.new(12), CSSPixels.new(0), CSSPixels.new(0), next_run)
		assert (next.fragments()[0].glyph_run() or { panic('missing glyphs') }).glyphs_[0].position.x == 0
	}
}
