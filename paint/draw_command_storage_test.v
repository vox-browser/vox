module main

import layout
import gg
import platform

fn test_draw_command_effect_early_returns_restore_depth_and_reuse_arena_storage() {
	mut app := BrowserApp{ctx: &gg.Context{width: 64, height: 64}}
	begin := layout.PaintCommand{kind: 'begin_css_effect_layer', opacity: 0.75}
	end := layout.PaintCommand{kind: 'end_css_effect_layer'}
	sk_begin := layout.PaintCommand{kind: 'begin_skia_command_group'}
	sk_end := layout.PaintCommand{kind: 'end_skia_command_group'}
	app.draw_command(begin, 0, 0, 64)
	app.draw_command(end, 0, 0, 64)
	app.draw_command(sk_begin, 0, 0, 64)
	app.draw_command(sk_end, 0, 0, 64)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		app.draw_command(begin, 0, 0, 64)
		assert app.draw_command_depth == 0 && app.paint_effect_depth == 0
		app.draw_command(end, 0, 0, 64)
		assert app.draw_command_depth == 0 && app.paint_effect_depth == 0
		app.draw_command(sk_begin, 0, 0, 64)
		assert app.draw_command_depth == 0 && app.paint_effect_depth == 1
		app.draw_command(sk_end, 0, 0, 64)
		assert app.draw_command_depth == 0 && app.paint_effect_depth == 0
	}
	assert begin.opacity == 0.75 && begin.kind == 'begin_css_effect_layer'
	assert app.draw_command_copies.len == 1
	$if prealloc { assert platform.thread_arena_usage().used - before < 1024 }
}

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
