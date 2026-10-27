module layout

import css
import html
import platform

fn test_collapsed_context_keeps_source_offsets_and_boundary_kerning() {
	mut document := html.parse_document('<!doctype html><div>é  T  </div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 400, 200)
	element := css.query_selector(document.as_node(), 'div') or { panic('element missing') }
	child := element.as_node().first_child() or { panic('text missing') }
	bridge := child.layout_node() or { panic('layout missing') }
	node := unsafe { &Node(bridge.real_layout_handle()) }
	text := node.as_text_node() or { panic('text layout missing') }
	context := chromium_collapsed_context_text(text, text.text_for_rendering())
	assert context.text == 'é T '
	assert context.source_offsets == [0, 1, 3, 4]
	font := &platform.Font{ family: 'Test', point_size: 16, font_rendering_policy: .chromium }
	original := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: 0xe9, advance: 8, length_in_code_units: 1 },
		platform.Glyph{ code_point: u32(` `), advance: 3.75, length_in_code_units: 1 },
		platform.Glyph{ code_point: u32(`T`), advance: 9.75, offset_x: -0.25, length_in_code_units: 1 },
		platform.Glyph{ code_point: u32(` `), advance: 4, length_in_code_units: 1 },
	])
	mapped := context.restore_source_offsets(original) or { panic('mapping failed') }
	space := chromium_context_slice(mapped, TextNodeChunk{ start: 1, length: 1 }) or { panic('space missing') }
	letter := chromium_context_slice(mapped, TextNodeChunk{ start: 3, length: 1 }) or { panic('letter missing') }
	assert space.glyph_run.width() == 3.5
	assert letter.glyph_run.width() == 10
	assert mapped.width() == original.width()
	assert mapped.glyphs_.len == 6
	assert !mapped.glyphs_[2].should_paint
	assert !mapped.glyphs_[5].should_paint
	assert original.glyphs_.len == 4
	assert original.glyphs_[2].offset_x == -0.25
}

fn test_collapsed_context_matches_single_spaces_through_wrapping_and_spacing() {
	for text in ['Altman.  The core completely', 'France,  They completely ruined', 'Été   Test completely'] {
		for spacing in ['', 'letter-spacing:0.25px;word-spacing:1px'] {
			mut positions := [][]f64{}
			for value in [text, text.replace('   ', ' ').replace('  ', ' ')] {
				mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:40px;width:150px;font:10pt Arial;text-align:center;${spacing}}</style><div>${value}</div>')
				document.set_font_rendering_policy(.chromium)
				document.set_layout_coordinate_scale(2)
				root := layout_document_typed_in_viewport(document, 800, 600)
				mut glyph_positions := []f64{}
				for command in root.paint_commands() {
					if command.kind != 'draw_text' { continue }
					run := command.glyph_run or { panic('missing run') }
					for glyph in run.glyphs_ {
						if !glyph.should_paint || glyph.code_point == u32(` `) { continue }
						glyph_positions << [command.x + f64(glyph.position.x), command.y, f64(glyph.glyph_index)]
					}
				}
				positions << glyph_positions
				document.finalize()
			}
			assert positions[0] == positions[1], '${text}: ${spacing}'
		}
	}
}

fn test_preserved_spaces_do_not_enter_collapsed_context_mapping() {
	for white_space in ['pre', 'pre-wrap', 'break-spaces'] {
		mut document := html.parse_document('<!doctype html><div style="font:20px Arial;white-space:${white_space}">é  T  </div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		root := layout_document_typed_in_viewport(document, 400, 200)
		mut count := 0
		for command in root.paint_commands() {
			if command.kind != 'draw_text' { continue }
			run := command.glyph_run or { panic('missing run') }
			for glyph in run.glyphs_ {
				if glyph.code_point == u32(` `) {
					assert glyph.advance > 0
					count++
				}
			}
		}
		assert count == 4, white_space
	}
}
