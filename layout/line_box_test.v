module layout

import css
import dom
import platform

fn make_line_box_text_node(text string) (&TextNode, &BlockContainer) {
	doc := dom.Document.create(dom.url_about_blank())
	style := css.ComputedProperties.new()
	mut parent := BlockContainer.new(doc, none, style)
	dom_text := doc.create_text_node(text)
	text_node := TextNode.new(doc, dom_text.as_node(), text)
	parent.append_child(unsafe { &Node(text_node) })
	return text_node, parent
}

fn test_line_box_writing_mode_dimensions_and_fragment_offsets() {
	text_node, _ := make_line_box_text_node('x')
	mut horizontal := LineBox.new(.ltr, .horizontal_tb)
	horizontal.add_fragment(unsafe { &Node(text_node) }, 0, 1, CSSPixels.new(2), CSSPixels.new(3), CSSPixels.new(5), CSSPixels.new(7), CSSPixels.new(10), CSSPixels.new(12), CSSPixels.new(1), CSSPixels.new(4), none)
	assert horizontal.width().to_double() == 27
	assert horizontal.height().to_double() == 17
	fragment := horizontal.fragments()[0]
	assert fragment.offset().x().to_double() == 7
	assert fragment.offset().y().to_double() == 0
	assert fragment.width().to_double() == 10
	assert fragment.height().to_double() == 12

	mut vertical := LineBox.new(.ltr, .vertical_rl)
	vertical.add_fragment(unsafe { &Node(text_node) }, 0, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(10), CSSPixels.new(12), CSSPixels.new(1), CSSPixels.new(4), none)
	assert vertical.width().to_double() == 17
	assert vertical.height().to_double() == 10
	vertical_fragment := vertical.fragments()[0]
	assert vertical_fragment.width().to_double() == 12
	assert vertical_fragment.height().to_double() == 10
}

fn test_line_box_merges_contiguous_glyph_runs_and_trims_trailing_whitespace() {
	text_node, _ := make_line_box_text_node('abcd  ')
	font := &platform.Font{
		family: 'Test'
		point_size: 16
	}
	first_run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{
			code_point: u32(`a`)
			advance: 8
		},
		platform.Glyph{
			code_point: u32(`b`)
			advance: 8
		},
	])
	second_run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{
			code_point: u32(`c`)
			advance: 8
		},
		platform.Glyph{
			code_point: u32(`d`)
			advance: 8
		},
		platform.Glyph{
			code_point: u32(` `)
			advance: 8
		},
		platform.Glyph{
			code_point: u32(` `)
			advance: 8
		},
	])
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.add_fragment(unsafe { &Node(text_node) }, 0, 2, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(16), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), first_run)
	line.add_fragment_with_trailing_whitespace(unsafe { &Node(text_node) }, 2, 4, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(32), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), second_run, TrailingWhitespace{
		length_in_code_units: 2
		inline_size: CSSPixels.nearest_value_for(13.25)
	})
	assert line.fragments().len == 1
	assert line.fragments()[0].length_in_code_units() == 6
	assert line.fragments()[0].inline_length().to_double() == 48
	assert line.get_trailing_whitespace_width().to_double() == 13.25
	line.trim_trailing_whitespace()
	assert line.inline_length().to_double() == 34.75
	assert line.fragments()[0].length_in_code_units() == 4
	assert line.fragments()[0].has_trailing_whitespace()
	assert !line.is_empty_or_ends_in_whitespace()
}

fn test_merging_layout_forks_keeps_cached_shapes_unchanged() {
	text_node, _ := make_line_box_text_node('ab')
	font := &platform.Font{family: 'Test', point_size: 16}
	cached := platform.GlyphRun.new(font, .ltr, [platform.Glyph{code_point: u32(`a`), advance: 8}])
	first := cached.fork_for_layout()
	second := cached.fork_for_layout()
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.add_fragment(unsafe { &Node(text_node) }, 0, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(8), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), first)
	line.add_fragment(unsafe { &Node(text_node) }, 1, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(8), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), second)
	assert line.fragments().len == 1
	run := line.fragments()[0].glyph_run() or { panic('missing merged run') }
	assert run.glyphs_.len == 2
	assert run.glyphs_[1].position.x == 8
	assert cached.glyphs_.len == 1
	assert cached.glyphs_[0].position.x == 0
	assert second.glyphs_.len == 1
}

fn test_line_box_accumulates_whitespace_when_fully_whitespace_runs_merge() {
	text_node, _ := make_line_box_text_node('a  ')
	font := &platform.Font{
		family: 'Test'
		point_size: 16
	}
	first_run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{
		code_point: u32(`a`)
		advance: 8
	}, platform.Glyph{
		code_point: u32(` `)
		advance: 4
	}])
	second_run := platform.GlyphRun.new(font, .ltr, [platform.Glyph{
		code_point: u32(` `)
		advance: 5
	}])
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.add_fragment_with_trailing_whitespace(unsafe { &Node(text_node) }, 0, 2, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(12), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), first_run, TrailingWhitespace{
		length_in_code_units: 1
		inline_size: CSSPixels.new(4)
	})
	line.add_fragment_with_trailing_whitespace(unsafe { &Node(text_node) }, 2, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(5), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), second_run, TrailingWhitespace{
		length_in_code_units: 1
		inline_size: CSSPixels.new(5)
	})
	assert line.get_trailing_whitespace_width().to_double() == 9
	line.trim_trailing_whitespace()
	assert line.inline_length().to_double() == 8
	assert line.fragments()[0].length_in_code_units() == 1
}

fn test_line_box_does_not_merge_glyph_indices_from_different_faces() {
	text_node, _ := make_line_box_text_node('a😀')
	font := &platform.Font{
		family: 'Test'
		point_size: 16
	}
	document_run := platform.GlyphRun.new_with_face(font, .ltr, [platform.Glyph{
		glyph_index: 7
		advance: 8
		length_in_code_units: 1
	}], .document)
	emoji_run := platform.GlyphRun.new_with_face(font, .ltr, [platform.Glyph{
		glyph_index: 11
		advance: 16
		length_in_code_units: 2
	}], .emoji)
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.add_fragment(unsafe { &Node(text_node) }, 0, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(8), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), document_run)
	line.add_fragment(unsafe { &Node(text_node) }, 1, 2, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(16), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), emoji_run)
	assert line.fragments().len == 2
	first := line.fragments()[0].glyph_run() or { panic('missing document run') }
	second := line.fragments()[1].glyph_run() or { panic('missing emoji run') }
	assert first.face() == .document
	assert second.face() == .emoji
}

fn test_line_box_removes_whitespace_only_fragments() {
	text_node, _ := make_line_box_text_node('a ')
	mut line := LineBox.new(.ltr, .horizontal_tb)
	line.add_fragment(unsafe { &Node(text_node) }, 0, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(8), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), none)
	line.add_fragment(unsafe { &Node(text_node) }, 1, 1, CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(8), CSSPixels.new(16), CSSPixels.new(0), CSSPixels.new(0), none)
	assert line.is_empty_or_ends_in_whitespace()
	assert line.get_trailing_whitespace_width().to_double() == 8
	line.trim_trailing_whitespace()
	assert line.fragments().len == 1
	assert line.inline_length().to_double() == 8
	assert line.fragments()[0].has_trailing_whitespace()
}
