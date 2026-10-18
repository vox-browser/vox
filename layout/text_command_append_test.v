module layout

import css
import painting

fn test_text_emission_keeps_existing_phases_and_orders_plain_and_shadowed_lines() {
	plain := TextFragment{
		x: 10
		y: 20
		width: 30
		height: 16
		text: 'ink'
		color: css.Color{r: 7, g: 8, b: 9, a: 255}
		baseline: 12
		paintable_fragment: painting.PaintableFragment{length_in_code_units: 3}
	}
	mut commands := [PaintCommand{kind: 'fill_rect', color: 'prefix', opacity: 0.25}]
	append_text_fragment_commands(mut commands, [plain], 0.5)
	assert commands.map(it.kind) == ['fill_rect', 'stroke_rounded_rect', 'draw_line', 'draw_text']
	assert commands[0].color == 'prefix'
	assert commands[0].opacity == 0.25
	assert commands[1].line_box_debug && commands[2].line_box_debug
	assert commands[2].points == [f64(10), 32, 39, 32]
	assert commands[3].text == 'ink'
	assert commands[3].color == 'rgb(7 8 9)'
	assert commands[3].opacity == 0.5
	earlier := commands.clone()
	shadowed := TextFragment{
		...plain
		y: 40
		text_shadows: [
			BoxShadow{offset_x: 1, offset_y: 2, blur: 3, color: css.Color{r: 100, a: 255}},
			BoxShadow{offset_x: 4, offset_y: 5, blur: 6, color: css.Color{b: 100, a: 255}},
		]
	}
	append_text_fragment_commands(mut commands, [shadowed], 0.75)
	assert commands[4..].map(it.kind) == ['fill_rect', 'draw_text_shadow', 'draw_text_shadow',
		'stroke_rounded_rect', 'draw_line', 'draw_text']
	assert commands[4].width == 0 && commands[4].height == 0
	assert commands[5].color == 'rgb(0 0 100)'
	assert commands[5].x == 14 && commands[5].y == 45
	assert commands[6].color == 'rgb(100 0 0)'
	assert commands[6].x == 11 && commands[6].y == 42
	assert commands[4..].all(it.opacity == 0.75)
	assert commands[9].text == 'ink' && commands[9].y == 40
	append_text_fragment_commands(mut commands, [], 1)
	gc_collect()
	assert commands.len == 10
	assert earlier.len == 4
	assert earlier[0].color == 'prefix'
	assert earlier[3].opacity == 0.5 && earlier[3].y == 20
}

fn test_disabling_debug_guide_generation_preserves_plain_and_shadowed_text_commands() {
	plain := TextFragment{
		x: 10
		y: 20
		width: 30
		height: 16
		text: 'ink'
		color: css.Color{r: 7, g: 8, b: 9, a: 255}
		baseline: 12
		paintable_fragment: painting.PaintableFragment{length_in_code_units: 3}
	}
	for fragment in [plain, TextFragment{...plain, text_shadows: [BoxShadow{offset_x: 1, offset_y: 2, blur: 3, color: css.Color{r: 100, a: 255}}]}] {
		mut reference := []PaintCommand{}
		append_text_fragment_commands(mut reference, [fragment], 0.75)
		assert reference.filter(it.line_box_debug).len == 2
		mut actual := []PaintCommand{}
		append_text_fragment_commands_with_debug(mut actual, [fragment], 0.75, false)
		assert actual == reference.filter(!it.line_box_debug)
		assert actual.any(it.kind == 'draw_text' && it.text == 'ink')
	}
}
