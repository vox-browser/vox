module layout

import html

fn inline_clip_commands(markup string, width f64) []PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:24px/32px Arial}.clip{background:linear-gradient(110deg,#cbdff7,#6c82a4);background-clip:text;-webkit-text-fill-color:transparent}</style>' + markup)
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, width, 240)
	return root.paint_commands()
}

fn test_inline_background_text_clip_retains_glyphs_and_leaves_neighbors_outside_mask() {
	commands := inline_clip_commands('<div>Before <span class="clip">0.5</span> After</div>', 600)
	clips := commands.filter(it.kind == 'begin_background_text_clip')
	assert clips.len == 2
	for clip in clips {
		assert clip.text_clip_runs.len == 1
		assert clip.text_clip_runs[0].text == '0.5'
		run := clip.text_clip_runs[0].glyph_run or { panic('missing shaped clip glyphs') }
		assert run.glyphs().len == 3
	}
	assert commands.filter(it.kind == 'end_background_text_clip').len == clips.len
	mut depth := 0
	for command in commands {
		if command.kind == 'begin_background_text_clip' { depth++ }
		if command.kind == 'end_background_text_clip' { depth-- }
		if command.kind == 'draw_text' { assert depth == 0 }
	}
	assert depth == 0
}

fn test_inline_background_text_clip_covers_nested_text_in_each_line_piece() {
	commands := inline_clip_commands('<div><span class="clip">One <b>two</b> three four five six</span> outside</div>', 145)
	clips := commands.filter(it.kind == 'begin_background_text_clip')
	assert clips.len >= 4
	mut texts := []string{}
	for clip in clips {
		assert clip.text_clip_runs.len > 0
		for run in clip.text_clip_runs {
			assert !run.text.contains('outside')
			assert run.y >= clip.y - 1 && run.y < clip.y + clip.height
			texts << run.text
		}
	}
	assert texts.any(it.contains('two'))
	assert texts.any(it.contains('six'))
}

fn test_inline_background_text_clip_does_not_clip_borders_or_other_background_layers() {
	commands := inline_clip_commands('<div><span style="background:linear-gradient(red,blue) border-box,linear-gradient(white,black) text;background-color:green;border:2px solid red">Text</span></div>', 600)
	mut depth := 0
	mut clipped_backgrounds := 0
	mut plain_backgrounds := 0
	for command in commands {
		if command.kind == 'begin_background_text_clip' { depth++ }
		if command.kind == 'end_background_text_clip' { depth-- }
		if command.kind == 'fill_gradient' {
			if depth > 0 { clipped_backgrounds++ } else { plain_backgrounds++ }
		}
		if command.kind.contains('border') { assert depth == 0 }
	}
	assert depth == 0
	assert clipped_backgrounds == 1
	assert plain_backgrounds == 1
}
