module layout

import html
import platform

fn test_safe_context_widths_and_projected_rounding_match_independent_shaping() {
	mut hits := 0
	for text in ['AVATAR ffi To Wa Y word', 'ordinary text and spaces'] {
		for spacing in ['', 'letter-spacing:0.25px;word-spacing:1px', 'letter-spacing:-0.75px'] {
			mut document := html.parse_document('<!doctype html><p style="font:20px Arial;${spacing}">${text}</p>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			paintable := layout_document_typed_in_viewport(document, 400, 300)
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
			for command in paintable.paint_commands() {
				if command.kind != 'draw_text' { continue }
				run := command.glyph_run or { panic('missing glyph run') }
				font = run.font()
				break
			}
			assert voidptr(font) != unsafe { nil }
			letter := f32(resolved_text_spacing_for_node(node, .letter_spacing).to_double())
			word := f32(resolved_text_spacing_for_node(node, .word_spacing).to_double())
			full := platform.shape_text_with_spacing(0, letter, word, text, font, .ltr).glyph_run
			for start in 0 .. text.len {
				for end in start + 1 .. text.len + 1 {
					visible := text[start..end]
					oracle := chromium_shape_line_end(node, visible, full, 0) or { panic('missing oracle') }
					if width := chromium_cached_safe_line_end(node, start, end - start, full) {
						assert width == oracle.width()
						hits++
					}
					for remainder in [f64(0), 0.0078125, 0.125] {
						precise := f64(oracle.width()) + remainder + 5.125
						rounded := inline_advance_to_css_pixels(precise, font)
						projection := ProjectedTextAdvance{
							node:           node
							run:            full
							precise:        precise
							rounded:        rounded
							segment_start:  start
							segment_length: end - start
							end:            end
							segment_width:  f64(oracle.width()) + 0.25
						}
						expected := inline_advance_to_css_pixels(precise - projection.segment_width + f64(oracle.width()), font)
						assert projection.chromium_line_end_correction() == expected.minus(rounded)
					}
				}
			}
		}
	}
	assert hits > 0
}

fn test_safe_context_width_rejects_source_maps_unicode_and_invalid_ranges() {
	for text in ['ordinary  collapsed spaces', 'Тест Т'] {
		mut document := html.parse_document('<!doctype html><p style="font:20px Arial">${text}</p>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		paintable := layout_document_typed_in_viewport(document, 400, 300)
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
		for command in paintable.paint_commands() {
			if command.kind != 'draw_text' { continue }
			run := command.glyph_run or { panic('missing run') }
			assert chromium_cached_safe_line_end(node, 0, 3, run) == none
			assert chromium_cached_safe_line_end(node, -1, 3, run) == none
			assert chromium_cached_safe_line_end(node, 0, text.len + 1, run) == none
			checked = true
		}
		assert checked
	}
}
