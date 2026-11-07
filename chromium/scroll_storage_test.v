module main

import html
import layout
import painting
import platform

fn test_nested_svg_msaa_preparation_borrows_geometry_without_heap_copying() {
	command := layout.PaintCommand{
		kind: 'fill_rect'
		x: 10
		y: 20
		width: 30
		height: 40
		clip_outs: [f64(20), 20, 25, 60, 30, 20, 35, 60]
	}
	transform := [f64(1), 0, 0, 1, 0, 100]!
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100 {
		bounds := chromium_nested_svg_msaa_trigger_rect(&command, transform,
			painting.IntPoint{5, 10}) or { panic('missing nested bounds') }
		assert bounds == layout.LayoutRect{15, 130, 30, 40}
	}
	$if prealloc { assert platform.thread_arena_usage().used == before }
}

fn test_scroll_raster_preparation_does_not_heap_copy_paint_commands() {
	mut commands := []layout.PaintCommand{}
	for index in 0 .. 80 {
		commands << layout.PaintCommand{
			kind: 'fill_rect'
			x: 10
			y: f64(index * 20)
			width: 100
			height: 10
		}
	}
	// Include a command that actually selects MSAA as well as ordinary fills.
	commands << layout.PaintCommand{
		kind: 'fill_rect'
		x: 10
		y: 200
		width: 100
		height: 1
		clip_outs: [f64(20), 199, 30, 202, 50, 199, 60, 202]
	}
	plan := layout.ChromiumRasterLayerPlan{
		layers: [layout.ChromiumRasterLayer{bounds: layout.LayoutRect{width:320,height:2000}}]
		command_layers: []int{len: commands.len}
	}
	mut storage := ChromiumMSAAStorage{}
	for _ in 0 .. 3 { storage.update(commands, plan, 320, 200, 0, 2) }
	before := platform.thread_arena_usage().used
	for frame in 0 .. 100 {
		storage.update(commands, plan, 320, 200, f64(frame % 20) * 10, 2)
		assert storage.triggers.len == 1
		assert storage.triggers[0].command_index == commands.len - 1
	}
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth == 0, '${growth} bytes retained by repeated MSAA preparation'
	}
}

fn test_scroll_image_decode_preparation_does_not_heap_copy_paint_commands() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><p>image decode preparation</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut app := BrowserApp{document: document}
	for index in 0 .. 80 {
		app.paint_commands << layout.PaintCommand{
			kind: if index % 2 == 0 { 'draw_replaced_image' } else { 'fill_rect' }
			image_data: &layout.PaintImageData{image_url: 'https://images.example/test.png'}
		}
	}
	app.begin_chromium_image_decode_frame()
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100 { app.begin_chromium_image_decode_frame() }
	$if prealloc {
		growth := platform.thread_arena_usage().used - before
		assert growth == 0, '${growth} bytes retained by repeated image decode preparation'
	}
}
