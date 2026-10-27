module layout

import platform

struct ChromiumCollapsedContextText {
	text           string
	source_offsets []int
	source_length  int
}

// Blink shapes the collapsed text. Shaping the original "a  T" and later
// discarding a space loses the kern between the displayed space and T.
// Retain a source map so chunks, DOM ranges and caret offsets still refer to
// the original UTF-16 text, including each discarded space.
fn chromium_collapsed_context_text(node &TextNode, text string) ChromiumCollapsedContextText {
	if node.Node.computed_values().white_space_collapse() !in [.collapse, .preserve_breaks]
		|| !text.contains('  ') {
		return ChromiumCollapsedContextText{ text: text }
	}
	units := utf16_code_units_for_line_box(text)
	mut collapsed := []u16{cap: units.len}
	mut offsets := []int{cap: units.len}
	for index, unit in units {
		if unit == u16(` `) && index > 0 && units[index - 1] == u16(` `) { continue }
		collapsed << unit
		offsets << index
	}
	return ChromiumCollapsedContextText{
		text: string_from_utf16_code_units_for_line_box(collapsed)
		source_offsets: offsets
		source_length: units.len
	}
}

fn (context &ChromiumCollapsedContextText) restore_source_offsets(run &platform.GlyphRun) ?&platform.GlyphRun {
	if context.source_offsets.len == 0 { return run }
	mut glyphs := []platform.Glyph{cap: run.glyphs_.len}
	mut offset := 0
	mut source_end := 0
	for glyph in run.glyphs_ {
		length := glyph.length_in_code_units
		if length <= 0 || offset + length > context.source_offsets.len { return none }
		start := context.source_offsets[offset]
		end := context.source_offsets[offset + length - 1] + 1
		// Do not split a cluster across a discarded source span.
		if end - start != length { return none }
		if start > source_end {
			glyphs << platform.Glyph{
				code_point: u32(` `)
				position: glyph.position
				offset_x: glyph.offset_x
				length_in_code_units: start - source_end
				should_paint: false
			}
		}
		glyphs << glyph
		offset += length
		source_end = end
	}
	if source_end < context.source_length {
		glyphs << platform.Glyph{
			code_point: u32(` `)
			position: platform.GlyphPosition{ x: run.width() }
			length_in_code_units: context.source_length - source_end
			should_paint: false
		}
	}
	mut mapped := platform.GlyphRun.new_with_face(run.font(), run.text_type(), glyphs, run.face())
	mapped.width_ = run.width()
	mapped.space_width = run.space_width
	return mapped
}
