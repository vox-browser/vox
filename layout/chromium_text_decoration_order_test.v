module layout

import css
import html
import painting

fn decoration_order_fragment(chromium bool) TextFragment {
	return TextFragment{
		x:                     8
		y:                     4.25
		width:                 24
		height:                20
		text:                  'gypq'
		font_size:             15
		font_ascent:           14
		font_descent:          4
		glyph_height:          18
		font_metrics_set:      true
		color:                 css.Color{170, 198, 232, 255}
		decoration:            'line-through overline underline'
		decoration_color:      css.Color{102, 128, 156, 128}
		decoration_color_set:  true
		decoration_skip_ink:   false
		text_underline_offset: 3
		chromium_decorations:  chromium
		paintable_fragment:    painting.PaintableFragment{ length_in_code_units: 4 }
	}
}

fn test_chromium_underlines_and_overlines_precede_glyphs_but_strikes_follow() {
	commands := unselected_text_fragment_commands([decoration_order_fragment(true)], 1)
	assert commands.map(it.kind) == ['fill_rect', 'draw_line', 'draw_text', 'draw_line']
	assert commands[0].y > commands[2].y
	assert commands[1].points[1] < commands[3].points[1]
	assert commands[0].color == css.Color{102, 128, 156, 128}.serialize()
}

fn test_chromium_selected_span_keeps_decorations_on_both_sides_of_glyphs() {
	mut commands := []PaintCommand{}
	paint_text_fragment(mut commands, decoration_order_fragment(true), TextRenderSpan{
		end_code_unit:    4
		text_color:       css.Color{255, 255, 255, 255}
		decoration:       'underline line-through'
		decoration_color: css.Color{128, 0, 0, 255}
		decoration_style: 'solid'
		decoration_set:   true
	}, 1)
	assert commands.map(it.kind) == ['fill_rect', 'draw_text', 'draw_line']
	assert commands[0].color == 'rgb(128 0 0)'
	assert commands[1].color == 'rgb(255 255 255)'
	assert commands[2].color == 'rgb(128 0 0)'
}

fn test_chromium_ancestor_strike_remains_above_descendant_underlined_text() {
	mut document := html.parse_document('<!doctype html><style>
		body{color:black} s{color:red} a{color:blue;text-decoration:underline}
	</style><s><a>gypq</a></s>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 400, 100)
	commands := root.paint_commands().filter(it.kind == 'draw_text' || it.kind == 'draw_line'
		|| (it.kind == 'fill_rect' && it.antialiased_rect))
	assert commands.map(it.kind) == ['fill_rect', 'draw_text', 'draw_line']
	assert commands[0].color == 'rgb(0 0 255)'
	assert commands[2].color == 'rgb(255 0 0)'
}

fn test_libweb_text_keeps_its_translated_decoration_order() {
	commands := unselected_text_fragment_commands([decoration_order_fragment(false)], 1)
	assert commands[0].kind == 'draw_text'
	assert commands[1..].all(it.kind == 'draw_line')
}
