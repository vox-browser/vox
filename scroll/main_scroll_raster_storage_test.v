module main

import html
import layout
import platform

fn test_scroll_raster_preparation_does_not_retain_each_frames_keys_and_damage_maps() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div style="height:2000px"></div>')
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document}
	app.relayout(800, 600 + app.chrome_height())
	defer {
		app.release_paint_commands()
		document.finalize()
	}
	app.paint_commands = []layout.PaintCommand{len: 1024, init: layout.PaintCommand{
		kind: 'fill_rect'
		x: f64(index % 64) * 10
		y: f64(index / 64) * 20
		width: 5
		height: 10
	}}
	// A root-only plan keeps this on the viewport raster path rather than
	// selecting a complete shared vector picture.
	app.chromium_raster_plan = layout.ChromiumRasterLayerPlan{}
	mut caller := platform.new_arena('scroll raster caller')
	defer { caller.release() }
	entry := caller.enter()
	for _ in 0 .. 3 { _ = app.begin_scroll_raster() }
	before := caller.usage().used
	for frame in 0 .. 128 {
		app.paint_commands[0].y = f64(frame % 20)
		_ = app.begin_scroll_raster()
	}
	growth := caller.usage().used - before
	caller.leave(entry)
	assert app.scroll_raster_content_eligible
	assert app.scroll_raster_keys.valid
	assert app.scroll_raster_keys.keys.len == 1024
	eprintln('SCROLL_RASTER_RETAINED caller_bytes=${growth} frames=128 commands=1024')
	$if prealloc {
		assert growth == 0, '${growth} bytes retained by repeated scroll raster preparation'
		used := app.scroll_raster_keys.storage.current.usage().used
			+ app.scroll_raster_keys.storage.previous.usage().used
		assert used < 2 * 1024 * 1024
	}
}

fn test_scroll_raster_keys_and_replay_decisions_outlive_their_command_scene() {
	mut previous := ScrollRasterKeyFrame{}
	defer { previous.release() }
	for frame in 0 .. 8 {
		commands_work := platform.begin_thread_scratch('scroll raster source commands')
		commands := [layout.PaintCommand{
			kind: ['fill', 'rect'].join('_')
			x: 20
			y: 20 + f64(frame)
			width: 30
			height: 10
		}]
		mut work := previous.storage.begin_frame()
		keys := scroll_raster_frame_keys(commands, 0, 1, 800, 600)
		mut stats := ScrollRasterDiffStats{}
		mut damage := ScrollRasterDamage{}
		if previous.valid {
			damage.rects = scroll_raster_content_damage(&previous, keys, 7, 0, 800, 600,
				mut stats) or { panic('bounded changed fill must be reusable') }
			damage.skip_plan = plan_scroll_raster_skips_with_restores(commands, keys,
				damage.rects, [], false)
			assert previous.keys[0].kind == 'fill_rect'
			assert previous.keys[0].ink.y == 19 + f64(frame)
		}
		previous = ScrollRasterKeyFrame{
			...previous
			valid: true
			document: 7
			width: 800
			height: 600
			keys: keys
		}
		work.finish()
		commands_work.finish()
		assert previous.keys[0].kind == 'fill_rect'
		assert previous.keys[0].ink.y == 20 + f64(frame)
		if frame > 0 {
			assert damage.rects.len == 1
			assert damage.skip_plan.len == 1
			assert !damage.skip_plan[0]
		}
	}
}

fn test_discarding_document_paint_releases_both_scroll_frame_workspaces() {
	mut app := BrowserApp{}
	for _ in 0 .. 3 {
		for _ in 0 .. 2 {
			mut work := app.scroll_raster_keys.storage.begin_frame()
			app.scroll_raster_keys.keys = [ScrollRasterCommandKey{kind: 'fill_rect'.clone()}]
			app.scroll_raster_keys.valid = true
			work.finish()
		}
		app.release_paint_commands()
		assert !app.scroll_raster_keys.valid
		assert app.scroll_raster_keys.keys.len == 0
		assert app.scroll_raster_keys.storage.current == unsafe { nil }
		assert app.scroll_raster_keys.storage.previous == unsafe { nil }
		app.release_paint_commands()
	}
}
