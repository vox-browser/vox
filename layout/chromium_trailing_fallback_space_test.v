module layout

import css
import dom
import platform

fn test_trailing_fallback_space_removal_restores_the_visible_line_advance() {
	for policy in [platform.FontRenderingPolicy.libweb, .chromium] {
		for width_only in [false, true] {
			mut document := dom.Document.create(dom.url_about_blank())
			defer { document.finalize() }
			mut parent := BlockContainer.new(document, none, css.ComputedProperties.new())
			text := document.create_text_node('a⧉ ')
			node := TextNode.new(document, text.as_node(), 'a⧉ ')
			parent.append_child(unsafe { &Node(node) })
			primary := &platform.Font{ family: 'Test', point_size: 10, font_rendering_policy: policy }
			fallback := &platform.Font{ family: 'Fallback', point_size: 10, font_rendering_policy: policy }
			mut line := LineBox.new(.ltr, .horizontal_tb)
			line.intrinsic_width_only_ = width_only
			zero := CSSPixels.new(0)
			for index, advance in [f32(6.162109375), 10.2] {
				font := if index == 0 { primary } else { fallback }
				run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{
					code_point:           if index == 0 { u32(`a`) } else { u32(`⧉`) }
					advance:              advance
					length_in_code_units: 1
				}])
				line.add_fragment(unsafe { &Node(node) }, index, 1, zero, zero, zero, zero,
					shaped_inline_width(run, 0), CSSPixels.new(12), zero, zero, run)
			}
			visible_width := line.width()
			space := platform.GlyphRun.new(primary, .ltr, [platform.Glyph{
				code_point:           u32(` `)
				advance:              3.333
				length_in_code_units: 1
			}])
			line.add_fragment_with_trailing_whitespace(unsafe { &Node(node) }, 2, 1,
				zero, zero, zero, zero, shaped_inline_width(space, 0), CSSPixels.new(12),
				zero, zero, space, TrailingWhitespace{
					length_in_code_units: 1
					inline_size:          shaped_inline_width(space, 0)
				})
			assert line.fragments().len == 3
			before_query := line.width()
			assert line.width().minus(line.get_trailing_whitespace_width()).raw_value() == visible_width.raw_value()
			assert line.width().raw_value() == before_query.raw_value()
			line.trim_trailing_whitespace()
			assert line.fragments().len == 2
			assert line.width().raw_value() == visible_width.raw_value()
			last := line.fragments().last()
			assert last.inline_offset_.plus(last.inline_length_).raw_value() == line.width().raw_value()
		}
	}
}
