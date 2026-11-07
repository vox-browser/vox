module layout

import html
import os
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

// 2ch.su's catalog titles: with separate Cyrillic and Latin subset faces the
// Latin-face " VK " merges into one fragment after Cyrillic text. Its space is
// shaped in the Cyrillic script run, apart from "VK". Blink reshapes only the
// final script run at the line end: the space-V kern must not return, and "VK"
// must lose its kern with the removed trailing space. After Latin text, or at
// the text start, the whole visible end is one run and reshapes together.
fn test_chromium_line_end_reshapes_only_the_final_script_run() {
	times := '/System/Library/Fonts/Supplemental/Times New Roman.ttf'
	if !os.exists(times) { return }
	for prefix in ['подразделений', 'subdivisions', ''] {
		text := prefix + ' VK '
		mut document := html.parse_document('<!doctype html><style>@font-face { font-family:Fixture; src:url("file://${times}") }</style><div style="font:20px Fixture">${text}</div>')
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
				if found.text_for_rendering().trim_space() == text.trim_space() {
					node = candidate
					break
				}
			}
		}
		assert voidptr(node) != unsafe { nil }
		mut font := unsafe { &platform.Font(nil) }
		for command in root.paint_commands() {
			if command.kind == 'draw_text' {
				font = (command.glyph_run or { panic('missing glyph run') }).font()
				break
			}
		}
		assert voidptr(font) != unsafe { nil }
		// The face kerns space-V when they share a shaping run.
		assert platform.shape_text(0, 0, ' V', font, .ltr).width() < platform.shape_text(0, 0, ' ', font, .ltr).width()
			+ platform.shape_text(0, 0, 'V', font, .ltr).width()
		space := platform.shape_text_with_spacing(0, 0, 0, ' ', font, .ltr).glyph_run
		latin := platform.shape_text_with_spacing(0, 0, 0, 'VK ', font, .ltr).glyph_run
		vk := platform.shape_text_with_spacing(0, 0, 0, 'VK', font, .ltr).glyph_run
		start := utf16_code_units_for_line_box(prefix).len
		for remainder in [f32(0), f32(0.125)] {
			// The page's fragment: the separately shaped space, then "VK ".
			mut glyphs := space.glyphs_.clone()
			for glyph in latin.glyphs_ {
				mut placed := glyph
				placed.position.x += space.width()
				glyphs << placed
			}
			mut run := platform.GlyphRun.new_with_face(font, .ltr, glyphs, space.face())
			mut line := LineBox.new(.ltr, .horizontal_tb)
			line.has_break_ = true
			line.add_fragment_with_trailing_whitespace(node, start, 4, CSSPixels.new(0), CSSPixels.new(0),
				CSSPixels.new(0), CSSPixels.new(0), shaped_inline_width(run, 0), CSSPixels.new(24),
				CSSPixels.new(0), CSSPixels.new(0), run, TrailingWhitespace{ length_in_code_units: 1, inline_size: CSSPixels.new(1) })
			line.fragments_[0].glyph_remainder_ = remainder
			for mut glyph in run.glyphs_ { glyph.position.x += remainder }
			run.invalidate_replay_data()
			fragment := line.fragments_[0]
			assert fragment.chromium_visible_line_end(true) or { panic('missing line end') } == ' VK'
			tail := fragment.chromium_line_end_script_tail(' VK')
			assert tail == if prefix == 'подразделений' { 1 } else { 0 }, prefix
			assert fragment.chromium_line_end_script_tail('подразделений VK') == 14
			assert fragment.chromium_line_end_script_tail('Тест 14,4 —') == 0
			assert fragment.chromium_line_end_script_tail(' Тест') == if prefix == 'subdivisions' { 1 } else { 0 }, prefix
			width := fragment.chromium_width_without_trailing_whitespace(true) or { panic('missing width') }
			shaped := fragment.chromium_shape_without_trailing_whitespace(true) or { panic('missing reshape') }
			assert shaped.width() == width
			if prefix != 'подразделений' {
				assert width == chromium_line_end_width(node, ' VK', run) or { panic('missing whole width') }
				continue
			}
			assert width == f32(f64(space.width()) + f64(vk.width()))
			assert width > chromium_line_end_width(node, ' VK', run) or { panic('missing whole width') }
			assert shaped.glyphs_.len == 1 + vk.glyphs_.len
			assert shaped.glyphs_[0] == run.glyphs_[0]
			for index, glyph in vk.glyphs_ {
				placed := shaped.glyphs_[index + 1]
				assert placed.glyph_index == glyph.glyph_index
				assert placed.advance == glyph.advance
				assert placed.position.x == f32(f64(space.width()) + f64(remainder) + f64(glyph.position.x))
			}
			line.trim_trailing_whitespace()
			assert line.fragments_[0].length_in_code_units_ == 3
			painted := line.fragments_[0].glyph_run_ or { panic('missing painted run') }
			assert painted.glyphs_ == shaped.glyphs_
		}
	}
}
