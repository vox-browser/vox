module main

import css
import gg
import html
import layout
import painting
import platform

fn test_native_replay_cache_fills_outlive_the_first_frame_workspace() {
	$if !macos {
		return
	}
	mut app := &BrowserApp{ ctx: &gg.Context{ native_rendering: true } }
	gradient := layout.LinearGradient{ colors: [css.Color{255, 0, 0, 255}, css.Color{0, 0, 255, 255}] }
	mut work := app.begin_native_replay_scratch()
	source := 'rgb(${17}, ${23}, ${29})'
	color := app.paint_colors.color(source, 1)
	native_gradient_stop_data_into(gradient, 1, mut app.native_gradient_storage.stops,
		mut app.native_gradient_storage.samples)
	assert chromium_linear_gradient_stop_data_into(gradient, 1, mut app.native_gradient_storage.gpu_stops)
	native_gradient_clip_path_into(layout.PaintCommand{}, painting.Rect{1, 2, 30, 40},
		mut app.native_gradient_storage.path)
	work.finish()
	assert app.paint_colors.color('rgb(17, 23, 29)', 1) == color
	assert app.native_gradient_storage.stops.len > 0
	assert app.native_gradient_storage.gpu_stops.len == 10
	assert app.native_gradient_storage.path[1] == 1
	$if prealloc {
		assert app.native_replay_scratch.usage().used == 0
	}
	for _ in 0 .. 3 {
		mut next := app.begin_native_replay_scratch()
		native_gradient_stop_data_into(gradient, .5, mut app.native_gradient_storage.stops,
			mut app.native_gradient_storage.samples)
		next.finish()
		assert app.native_gradient_storage.stops[3] == .5
	}
	app.release_native_replay_scratch()
}

fn test_svg_background_layout_cache_outlives_the_replay_that_created_it() {
	$if !macos {
		return
	}
	mut document := html.parse_document('<!doctype html><svg width="60" height="40"><path d="M0 0L60 0L30 40Z" fill="green"/></svg>')
	defer { document.finalize() }
	mut app := &BrowserApp{ ctx: &gg.Context{ native_rendering: true } }
	mut work := app.begin_native_replay_scratch()
	list := svg_image_document_display_list(document, 60, 40) or { panic('missing SVG layout') }
	work.finish()
	assert layout.display_list_commands(list).any(it.kind == 'draw_svg_path')
	mut next := app.begin_native_replay_scratch()
	cached := svg_image_document_display_list(document, 60, 40) or { panic('missing cached SVG layout') }
	assert voidptr(cached) == voidptr(list)
	next.finish()
	assert layout.display_list_commands(cached).len > 0
	app.release_native_replay_scratch()
}
