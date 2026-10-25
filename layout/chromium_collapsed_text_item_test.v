module layout

import css
import dom
import math
import platform

fn test_chromium_collapsed_spaces_keep_fractional_pen_and_source_offsets() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := BlockContainer.new(document, none, css.ComputedProperties.new())
	dom_text := document.create_text_node('a  b')
	text := TextNode.new(document, dom_text.as_node(), 'a  b')
	parent.append_child(unsafe { &Node(text) })
	node := unsafe { &Node(text) }
	font := &platform.Font{ family: 'Test', point_size: 16, font_rendering_policy: .chromium }
	first := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`a`), advance: 8.001, length_in_code_units: 1 },
		platform.Glyph{ code_point: u32(` `), advance: 4, length_in_code_units: 1 },
	])
	second := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`b`), advance: 8, length_in_code_units: 1 },
	])
	zero := CSSPixels.new(0)
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.add_fragment(node, 0, 2, zero, zero, zero, zero, shaped_inline_width(first, 0), CSSPixels.new(16), zero, zero, first)
	line.add_fragment(node, 3, 1, zero, zero, zero, zero, shaped_inline_width(second, 0), CSSPixels.new(16), zero, zero, second)
	assert line.fragments().len == 2
	fragment := line.fragments()[1]
	run := fragment.glyph_run() or { panic('missing second run') }
	assert fragment.start() == 3
	assert fragment.length_in_code_units() == 1
	assert math.abs(fragment.inline_offset_.to_double() + f64(run.glyphs_[0].position.x) - f64(first.width())) < 0.000001
	assert !chromium_text_item_continues(node, 0, 3)
}
