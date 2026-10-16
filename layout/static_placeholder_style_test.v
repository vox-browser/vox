module layout

import html

fn test_static_input_and_textarea_placeholders_apply_author_pseudo_element_colors() {
	mut document := html.parse_document('<!doctype html><style>
		input,textarea{width:200px;height:30px;color:black}
		input::placeholder,textarea::placeholder{color:#2468ac}
	</style><input placeholder="input hint"><textarea placeholder="textarea hint"></textarea>')
	mut root := layout_document_typed_in_viewport(document, 500, 300)
	commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text.contains('hint'))
	assert commands.len == 2
	for command in commands { assert command.color == 'rgb(36 104 172)' }
}

fn test_static_chromium_placeholder_uses_the_control_default_color() {
	mut document := html.parse_document('<!doctype html><input style="color:black" placeholder="hint">')
	document.set_font_rendering_policy(.chromium)
	mut root := layout_document_typed_in_viewport(document, 300, 100)
	commands := root.paint_commands().filter(it.kind == 'draw_text' && it.text == 'hint')
	assert commands.len == 1
	assert commands[0].color == 'rgb(117 117 117)'
}
