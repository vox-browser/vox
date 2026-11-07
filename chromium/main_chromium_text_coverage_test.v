module main

import html
import layout
import math

fn text_coverage_test_commands() []layout.PaintCommand {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;font:13px/19.5px Arial}a{color:#066;text-decoration:underline}</style><a>From the blog <em>It\'s FOSS</em></a>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	return root.paint_commands().filter(it.kind == 'draw_text' || (it.kind == 'fill_rect' && it.antialiased_rect))
}

fn test_split_underlines_keep_one_coverage_resolve_with_their_text() {
	commands := text_coverage_test_commands()
	assert commands.len == 4
	layers := []int{len: commands.len}
	assert chromium_text_coverage_run_end(commands, layers, 0) == 4
	assert chromium_text_coverage_run_end(commands, layers, 2) == 2
	assert chromium_text_coverage_run_end(commands, []int{}, 0) == 0
	assert chromium_text_coverage_run_end(commands, layers, -1) == -1
	for replacement in [
		layout.PaintCommand{...commands[2], x:commands[2].x + 1},
		layout.PaintCommand{...commands[2], opacity:0.5},
		layout.PaintCommand{...commands[2], radius:2},
		layout.PaintCommand{...commands[2], color:'red'},
		layout.PaintCommand{...commands[2], height:math.nan()},
		layout.PaintCommand{...commands[2], kind:'begin_css_effect_layer'},
	] {
		mut changed := commands.clone()
		changed[2] = replacement
		assert chromium_text_coverage_run_end(changed, layers, 0) == 0
	}
	mut foreign := layers.clone()
	foreign[2] = 1
	assert chromium_text_coverage_run_end(commands, foreign, 0) == 0
	mut absent := commands.clone()
	absent[3].glyph_run = none
	assert chromium_text_coverage_run_end(absent, layers, 0) == 0
}

fn test_single_glyph_keeps_its_contained_rounded_background() {
	mut document := html.parse_document('<!doctype html><span style="font:20px Arial">M</span>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout.layout_document_typed_in_viewport(document, 1024, 768)
	texts := root.paint_commands().filter(it.kind == 'draw_text')
	assert texts.len == 1
	text := texts[0]
	background := layout.PaintCommand{kind:'fill_rect', x:text.x+2, y:text.y+2,
		width:10, height:15, radius:2, color:'white', opacity:1}
	commands := [background, text]
	assert chromium_text_coverage_run_end(commands, [0,0], 0) == 2
	assert chromium_text_coverage_run_end(commands, [1,1], 0) == 2
	assert chromium_text_coverage_run_end(commands, [0,1], 0) == 0
	// Negative-z generated backgrounds precede their inline foregrounds.
	second_background := layout.PaintCommand{...background, x:background.x+30}
	second_text := layout.PaintCommand{...text, x:text.x+30}
	separated := [background,second_background,text,second_text]
	assert chromium_text_coverage_run_end(separated, [0,0,0,0], 0) == 4
	assert chromium_text_coverage_run_end(separated, [0,0,1,0], 0) == 0
	for replacement in [
		layout.PaintCommand{...background, radius:0},
		layout.PaintCommand{...background, x:text.x-1},
		layout.PaintCommand{...background, opacity:0.5},
		layout.PaintCommand{...background, clip_outs:[f64(1),2,3,4]},
		layout.PaintCommand{...background, transform:[f64(1),0.2,0,1,0,0]!},
	] {
		assert chromium_text_coverage_run_end([replacement,text], [0,0], 0) == 0
	}
}
