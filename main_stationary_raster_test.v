module main

import layout
import dom
import painting
import math

fn test_stationary_offscreen_video_uses_retained_clip_and_transform() {
	mut video := layout.PaintCommand{
		kind: 'draw_video'
		x: 5000
		y: 5000
		width: 20
		height: 20
		video_frame_source: &painting.VideoFrameSource{}
		video_paintable: &painting.VideoPaintable{video_rect: painting.Rect{10, 10, 20, 20}}
	}
	assert !stationary_document_raster_viewport_eligible([video], 60, 800, 660)
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{10, -100, 20, 20}}
	assert stationary_document_raster_viewport_eligible([video], 60, 800, 660)
	assert !stationary_document_raster_eligible([video])
	video.transform = [f64(1), 0, 0, 1, 0, 50]!
	assert !stationary_document_raster_viewport_eligible([video], 60, 800, 660)
	video.transform = [f64(1), 0, 0, 1, 0, 0]!
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{10, -83, 20, 20}}
	assert !stationary_document_raster_viewport_eligible([video], 60, 800, 660)
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{10, math.nan(), 20, 20}}
	assert !stationary_document_raster_viewport_eligible([video], 60, 800, 660)
	video.video_paintable = none
	assert !stationary_document_raster_viewport_eligible([video], 60, 800, 660)
}

fn test_stationary_offscreen_video_keeps_resource_inputs_and_other_live_content() {
	video := layout.PaintCommand{kind: 'draw_video', video_frame_source: &painting.VideoFrameSource{},
		video_paintable: &painting.VideoPaintable{video_rect: painting.Rect{10, -100, 20, 20}}}
	assert stationary_document_raster_viewport_eligible([video], 60, 800, 660)
	for kind in ['begin_css_filter_layer', 'begin_svg_mask_layer', 'begin_background_text_clip'] {
		assert !stationary_document_raster_viewport_eligible([
			layout.PaintCommand{kind: kind}, video, layout.PaintCommand{kind: 'end_scope'}], 60, 800, 660)
	}
	assert stationary_document_raster_viewport_eligible([
		layout.PaintCommand{kind: 'begin_css_effect_layer'}, video,
		layout.PaintCommand{kind: 'end_css_effect_layer'}], 60, 800, 660)
	// A whole skipped opacity group cannot contribute pixels, including a
	// nested filter whose source would otherwise require conservative replay.
	assert stationary_document_raster_viewport_eligible([
		layout.PaintCommand{kind: 'begin_css_effect_layer', has_clip: true,
			clip_x: 0, clip_y: -200, clip_width: 100, clip_height: 100},
		layout.PaintCommand{kind: 'begin_css_filter_layer'}, video,
		layout.PaintCommand{kind: 'end_css_filter_layer'},
		layout.PaintCommand{kind: 'end_css_effect_layer'}], 60, 800, 660)
	for live in [layout.PaintCommand{kind: 'draw_canvas'},
		layout.PaintCommand{kind: 'draw_nested_document'},
		layout.PaintCommand{kind: 'paint_nested_display_list', nested_viewport_commands: [video]}] {
		assert !stationary_document_raster_viewport_eligible([video, live], 60, 800, 660)
	}
}

fn test_stationary_raster_skips_initial_frame_without_a_document() {
	app := BrowserApp{}
	assert !app.begin_stationary_document_raster()
}

fn test_stationary_raster_excludes_independently_updated_content() {
	ordinary := [layout.PaintCommand{kind: 'fill_rect'},
		layout.PaintCommand{kind: 'draw_replaced_image'},
		layout.PaintCommand{kind: 'draw_svg_path'}]
	assert stationary_document_raster_eligible(ordinary)
	for kind in ['draw_canvas', 'draw_nested_document'] {
		mut commands := ordinary.clone()
		commands << layout.PaintCommand{kind: kind}
		assert !stationary_document_raster_eligible(commands), kind
	}
}

fn test_stationary_raster_reuses_static_nested_snapshots_and_empty_video() {
	commands := [layout.PaintCommand{
		kind: 'paint_nested_display_list'
		nested_viewport_commands: [layout.PaintCommand{kind: 'draw_svg_path'},
			layout.PaintCommand{kind: 'draw_video', video_representation: .transparent_black}]
	}]
	assert stationary_document_raster_eligible(commands)
	for live in [layout.PaintCommand{kind: 'draw_canvas'},
		layout.PaintCommand{kind: 'draw_nested_document'},
		layout.PaintCommand{kind: 'draw_video', video_frame_source: &painting.VideoFrameSource{}},
		layout.PaintCommand{kind: 'draw_video', video_bitmap: &dom.Bitmap_{}}] {
		assert !stationary_document_raster_eligible([live])
		assert !stationary_document_raster_eligible([layout.PaintCommand{
			kind: 'paint_nested_display_list'
			nested_viewport_commands: [layout.PaintCommand{
				kind: 'paint_nested_display_list'
				nested_viewport_commands: [live]
			}]
		}])
	}
}

fn test_stationary_raster_limits_nested_snapshot_depth() {
	mut commands := [layout.PaintCommand{kind: 'draw_svg_path'}]
	for _ in 0 .. 32 {
		commands = [layout.PaintCommand{kind: 'paint_nested_display_list', nested_viewport_commands: commands}]
	}
	assert stationary_document_raster_eligible(commands)
	commands = [layout.PaintCommand{kind: 'paint_nested_display_list', nested_viewport_commands: commands}]
	assert !stationary_document_raster_eligible(commands)
}

fn test_stationary_raster_rechecks_mutated_retained_commands() {
	mut nested := [layout.PaintCommand{kind: 'draw_svg_path'}]
	mut commands := [layout.PaintCommand{
		kind: 'paint_nested_display_list'
		nested_viewport_commands: unsafe { nested }
	}]
	assert stationary_document_raster_eligible(commands)
	// The scan must read the current vector, even when its address and length
	// stay unchanged. A cached eligibility bit would miss these live changes.
	nested[0].kind = 'draw_canvas'
	assert !stationary_document_raster_eligible(commands)
	nested[0].kind = 'draw_svg_path'
	assert stationary_document_raster_eligible(commands)
	commands[0].kind = 'draw_video'
	commands[0].video_bitmap = &dom.Bitmap_{}
	assert !stationary_document_raster_eligible(commands)
	commands[0].video_bitmap = none
	assert stationary_document_raster_eligible(commands)
}

fn test_stationary_blank_raster_declines_without_a_native_frame() {
	// Callers fill the blank frame themselves unless a retained one is selected.
	assert !begin_stationary_blank_raster()
	assert stationary_blank_raster_owner != 0
}

fn test_frames_without_a_document_or_commands_are_blank() {
	mut app := BrowserApp{}
	assert app.frame_canvas_is_blank(true)
	assert app.frame_canvas_is_blank(false)
	app.paint_commands << layout.PaintCommand{
		kind: 'fill_rect'
	}
	assert !app.frame_canvas_is_blank(true)
	assert app.frame_canvas_is_blank(false)
}
