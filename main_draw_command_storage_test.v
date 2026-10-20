module main

import layout

fn test_draw_command_working_copies_survive_nested_replay_and_reuse_storage() {
	mut app := BrowserApp{}
	source := layout.PaintCommand{ kind: 'fill_rect', x: 7, opacity: 0.5 }
	mut outer := app.enter_draw_command(source)
	outer.x = 19
	outer.transform[4] = 23
	mut nested := app.enter_draw_command(layout.PaintCommand{ kind: 'draw_line', x: 31 })
	assert voidptr(outer) != voidptr(nested)
	nested.x = 41
	assert outer.kind == 'fill_rect' && outer.x == 19 && outer.transform[4] == 23
	assert source.x == 7 && source.transform[4] == 0
	app.draw_command_depth--
	app.draw_command_depth--
	reused := app.enter_draw_command(source)
	assert voidptr(reused) == voidptr(outer)
	assert reused.x == 7 && reused.transform[4] == 0 && reused.opacity == 0.5
	app.draw_command_depth--
}
