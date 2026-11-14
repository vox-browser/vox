// vtest build: macos
module main

import html
import layout
import os
import math

fn test_elliptical_text_picture_requires_one_clip_and_owner_and_a_glyph_suffix() {
	source := os.read_file('${@VMODROOT}/Tests/Browser/Brave/diagnostic/large-clipped-orbit.html')!
	mut document := html.parse_document(source.replace('<div class="orbit"></div>',
		'<div class="orbit"></div><p style="position:absolute;left:450px;top:170px;color:#9daabe;font:18px Arial">Retained samples</p>'))
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1024, 768)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing paint') })
	layers := []int{len: commands.len}
	viewport := layout.LayoutRect{0, 0, 1024, 768}
	mut start := -1
	for i, c in commands {
		if c.kind == 'paint_outer_box_shadow' && normalized_paint_transform(c.transform)[1] != 0 {
			start = i
			break
		}
	}
	assert start >= 0
	selected := elliptical_text_group_indices(commands, layers, start, viewport)
	assert selected.len == 4
	text := selected.last()
	assert commands[text].kind == 'draw_text'
	// Byte colors have no optional retained float payload. They still use the
	// same face, mask gamma and source color as ordinary document glyph replay.
	byte_color := layout.PaintCommand{ ...commands[text], srgb_color_data: unsafe { nil } }
	mask := elliptical_text_coverage(&byte_color, [i32(0), 0, 1024, 768, 1, 1024, 768]!, 0) or { panic('missing byte-color coverage') }
	assert mask.pixels.any(it > 0)
	assert mask.color == [f32(157) / 255, f32(170) / 255, f32(190) / 255, 1]!
	for case_index, replacement in [
		layout.PaintCommand{ ...commands[text], opacity: .5 },
		layout.PaintCommand{ ...commands[text], font_size: math.nan() },
		layout.PaintCommand{ ...commands[text], blur: 2 },
		layout.PaintCommand{ ...commands[text], kind: 'draw_text_shadow' },
		layout.PaintCommand{ ...commands[text], glyph_run: none },
		layout.PaintCommand{ ...commands[text], clip_list: unsafe { nil } },
		layout.PaintCommand{ ...commands[text], clip_outs: [f64(0), 0, 5, 5] },
	] {
		mut altered := commands.clone()
		altered[text] = replacement
		assert elliptical_text_group_indices(altered, layers, start, viewport).len == 0, 'case ${case_index}'
	}
	mut foreign := layers.clone()
	foreign[text] = 1
	assert elliptical_text_group_indices(commands, foreign, start, viewport).len == 0
	assert elliptical_text_group_indices(commands, [], start, viewport).len == 0
	assert elliptical_text_group_indices(commands, layers, -1, viewport).len == 0
}
