// vtest build: macos
module main

import html
import layout

fn test_shadowed_png_text_keeps_clipped_effectful_or_foreign_text_on_ordinary_replay() {
	mut document := html.parse_document($embed_file('@VMODROOT/Tests/Browser/Brave/diagnostic/shadowed-elliptical-avatar.html').to_string() +
		'<span style="position:absolute;left:54px;top:327px">hello</span>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	source := root.paint_commands()
	mut start, mut text := -1, -1
	for i, c in source {
		if c.kind == 'paint_outer_box_shadow' { start = i }
		if c.kind == 'draw_text' { text = i }
	}
	assert start >= 0 && text >= 0
	commands := [source[start], source[start + 1], source[text]]
	layers := []int{len: 3}
	assert shadowed_png_text_supported(commands, layers, 0)
	for replacement in [
		layout.PaintCommand{ ...commands[2], has_clip: true },
		layout.PaintCommand{ ...commands[2], blur: 1 },
		layout.PaintCommand{ ...commands[2], opacity: 0.5 },
		layout.PaintCommand{ ...commands[2], group_opacity: 0.5 },
		layout.PaintCommand{ ...commands[2], fixed_to_viewport: true },
		layout.PaintCommand{ ...commands[2], transform: [f64(1), 0, 0, 1, 0.5, 0]! },
	] {
		assert !shadowed_png_text_supported([commands[0], commands[1], replacement], layers, 0)
	}
	assert !shadowed_png_text_supported(commands, [0, 0, 1], 0)
	assert !shadowed_png_text_supported(commands, [], 0)
	assert !shadowed_png_text_supported(commands[..2], layers[..2], 0)
}
