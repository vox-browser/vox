module layout

import html

fn test_font_synthesis_inherits_through_font_shorthand_and_controls_caps_fallback() {
	mut document := html.parse_document('<!doctype html><style>
		html{font-synthesis:none}body{margin:0;font:20px Arial}
		.caps{font-variant-caps:small-caps}.enabled{font-synthesis:small-caps}
	</style><div><i>italic</i></div><div class="caps">lowercase</div>
	<div class="caps enabled">enabled</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 800, 600)
	commands := root.paint_commands().filter(it.kind == 'draw_text')
	assert commands.len > 0
	mut italic_found := false
	mut normal_caps_found := false
	mut synthetic_caps_found := false
	for command in commands {
		run := command.glyph_run or { continue }
		font := run.font()
		if command.text == 'italic' {
			assert font.italic
			assert font.font_synthesis_disabled == 15
			italic_found = true
		} else if command.text == 'lowercase' {
			assert !font.synthesize_ascii_caps
			assert font.font_synthesis_disabled == 15
			normal_caps_found = true
		} else if font.synthesize_ascii_caps {
			assert font.font_synthesis_disabled == 11
			synthetic_caps_found = true
		}
	}
	assert italic_found && normal_caps_found && synthetic_caps_found
}
