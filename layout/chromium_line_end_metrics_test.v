module layout

import html
import platform

fn test_chromium_line_end_metrics_match_materialized_context_slices() {
	for text in ['AV Y', 'Wé T', 'Тест Т', 'a\u0301 Y', '123 – 456'] {
		for spacing in ['', 'letter-spacing:0.25px;word-spacing:1px', 'letter-spacing:-0.75px'] {
			mut document := html.parse_document('<!doctype html><div style="font:20px Arial;${spacing}">${text}</div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			root := layout_document_typed_in_viewport(document, 400, 300)
			result := document_layout_result(document) or { panic('missing layout') }
			mut pending := [result.root]
			mut node := unsafe { &Node(nil) }
			for pending.len > 0 {
				candidate := pending.pop()
				for child in candidate.children() { pending << child }
				if found := candidate.as_text_node() {
					if found.text_for_rendering() == text {
						node = candidate
						break
					}
				}
			}
			assert voidptr(node) != unsafe { nil }
			mut checked := false
			for command in root.paint_commands() {
				if command.kind != 'draw_text' { continue }
				run := command.glyph_run or { panic('missing glyph run') }
				for visible in [text, text + ' ', '', 'Latin Тест', '文😀'] {
					full := chromium_shape_line_end(node, visible, run, 0)
					width := chromium_line_end_width(node, visible, run)
					if shaped := full {
						assert width or { panic('missing scalar width') } == shaped.width()
					} else {
						assert width == none
					}
				}
				for policy in [platform.FontRenderingPolicy.libweb, .chromium] {
					font := &platform.Font{ family: 'SerenitySans', point_size: 16, font_rendering_policy: policy }
					for kind in [platform.GlyphRunTextType.ltr, .rtl] {
						for face in [platform.GlyphRunFace.document, .emoji] {
							rejected := platform.GlyphRun.new_with_face(font, kind, []platform.Glyph{}, face)
							if policy != .chromium || kind != .ltr || face != .document {
								assert chromium_line_end_width(node, text, rejected) == none
							}
						}
					}
				}
				checked = true
			}
			assert checked
		}
	}
}

fn test_chromium_trailing_width_queries_match_trim_without_mutating_fragments() {
	for visible in ['AV Y', 'Wé T', 'Тест Т'] {
		for spacing in ['', 'letter-spacing:0.25px;word-spacing:1px'] {
			text := visible + ' '
			mut document := html.parse_document('<!doctype html><div style="font:20px Arial;${spacing}">${text}</div>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			root := layout_document_typed_in_viewport(document, 400, 300)
			result := document_layout_result(document) or { panic('missing layout') }
			mut pending := [result.root]
			mut node := unsafe { &Node(nil) }
			for pending.len > 0 {
				candidate := pending.pop()
				for child in candidate.children() { pending << child }
				if found := candidate.as_text_node() {
					if found.text_for_rendering() == text {
						node = candidate
						break
					}
				}
			}
			assert voidptr(node) != unsafe { nil }
			mut font := unsafe { &platform.Font(nil) }
			for command in root.paint_commands() {
				if command.kind == 'draw_text' {
					run := command.glyph_run or { panic('missing glyph run') }
					font = run.font()
					break
				}
			}
			assert voidptr(font) != unsafe { nil }
			letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
			word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
			full := platform.shape_text_with_spacing(0, letter, word, text, font, .ltr).glyph_run
			length := utf16_code_units_for_line_box(visible).len
			cut := chromium_context_slice(full, TextNodeChunk{ length: length }) or { panic('missing slice') }
			for trailing in [0, 1] {
				for at_break in [false, true] {
					for remainder in [f32(0), f32(0.125)] {
						original := if trailing == 0 { cut.glyph_run } else { full }
						mut run := platform.GlyphRun.new_with_face(font, .ltr, original.glyphs_.clone(), original.face())
						mut line := LineBox.new(.ltr, .horizontal_tb)
						line.has_break_ = at_break
						line.add_fragment_with_trailing_whitespace(node, 0, length + trailing,
							CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0), CSSPixels.new(0),
							shaped_inline_width(run, 0), CSSPixels.new(24), CSSPixels.new(0), CSSPixels.new(0),
							run, TrailingWhitespace{ length_in_code_units: trailing, inline_size: CSSPixels.new(trailing) })
						line.fragments_[0].glyph_remainder_ = remainder
						for mut glyph in run.glyphs_ { glyph.position.x += remainder }
						run.invalidate_replay_data()
						before := line.fragments_[0]
						glyphs := run.glyphs_.clone()
						width := line.inline_length()
						oracle := before.chromium_shape_without_trailing_whitespace(at_break)
						mut advance := before.trailing_whitespace_advance(before.trailing_whitespace_)
						if shaped := oracle {
							assert before.chromium_width_without_trailing_whitespace(at_break) or { panic('missing width') } == shaped.width()
							advance = (before.precise_inline_length_ or { panic('missing precise length') }) - f64(shaped.width())
						} else {
							assert before.chromium_width_without_trailing_whitespace(at_break) == none
						}
						expected := before.chromium_width_without_trailing_advance(advance) or {
							before.inline_length_.minus(before.trailing_whitespace_.inline_size)
						}
						for _ in 0 .. 3 {
							assert line.get_trailing_whitespace_width() == width.minus(expected)
							assert line.inline_length() == width
							assert line.fragments_.len == 1
							assert line.fragments_[0].length_in_code_units_ == before.length_in_code_units_
							assert line.fragments_[0].precise_inline_length_ == before.precise_inline_length_
							assert line.fragments_[0].trailing_whitespace_ == before.trailing_whitespace_
							assert line.fragments_[0].item_width_ == before.item_width_
							assert line.fragments_[0].has_trailing_whitespace_ == before.has_trailing_whitespace_
							assert voidptr(line.fragments_[0].glyph_run_ or { panic('missing run') }) == voidptr(run)
							assert run.glyphs_ == glyphs
						}
						line.trim_trailing_whitespace()
						assert line.inline_length() == expected
						assert line.fragments_[0].length_in_code_units_ == length
						painted := line.fragments_[0].glyph_run_ or { panic('missing painted run') }
						if shaped := oracle {
							assert painted.width() == shaped.width()
							assert painted.face() == shaped.face()
							assert painted.glyphs_ == shaped.glyphs_
						}
					}
				}
			}
		}
	}
}
