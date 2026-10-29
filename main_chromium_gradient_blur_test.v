module main

import html
import layout

fn test_chromium_gradient_blur_accepts_only_complete_represented_filter_inputs() {
	for background in ['radial-gradient(ellipse,#263d5d28,transparent 68%)',
		'linear-gradient(90deg,red,blue)'] {
		mut document := html.parse_document('<!doctype html><style>div{width:200px;height:100px;filter:blur(30px);background:' + background + '}</style><div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		list := document.record_display_list() or { panic('missing retained paint') }
		commands := layout.display_list_commands(list)
		mut checked := 0
		for index, command in commands {
			if command.kind != 'begin_css_filter_layer' { continue }
			assert chromium_gradient_blur_input_supported(commands, index)
			mut unsupported := commands.clone()
			unsupported[index + 1] = layout.PaintCommand{ kind: 'draw_text' }
			assert !chromium_gradient_blur_input_supported(unsupported, index)
			mut close := index + 1
			for close < commands.len && commands[close].kind != 'end_css_filter_layer' { close++ }
			assert !chromium_gradient_blur_input_supported(commands[..close], index)
			checked++
		}
		assert checked == 1
	}
	assert !chromium_gradient_blur_input_supported([], 0)
	assert !chromium_gradient_blur_input_supported([], -1)
}

fn test_chromium_generated_gradient_blur_keeps_its_filter_input() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}.showcase{position:relative;height:500px;isolation:isolate}.showcase::before{content:"";position:absolute;inset:10% 0 5%;background:radial-gradient(ellipse at center,#263d5d28,transparent 68%);filter:blur(30px);pointer-events:none}</style><section class="showcase"></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 1280, 800)
	list := document.record_display_list() or { panic('missing generated paint') }
	commands := layout.display_list_commands(list)
	mut checked := 0
	for index, command in commands {
		if command.kind != 'begin_css_filter_layer' { continue }
		assert chromium_gradient_blur_input_supported(commands, index)
		checked++
	}
	assert checked == 1
}
