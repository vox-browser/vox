module main

import css
import gg
import dom
import html
import layout
import painting
import math
import os
import platform
import runtime

$if macos {
	fn test_recorded_glyph_positions_match_replay_with_long_run_fallback() {
		if os.getenv('VOX_RECORD_GLYPH_REPLAY_GEOMETRY') != '1'
			|| os.getenv('VOX_SERIAL_DISPLAY_LIST_REPLAY') == '1' || serial_retained_glyph_geometry
			|| packed_retained_glyph_geometry || os.getenv('VOX_SERIAL_CPU_RASTER') == '1'
			|| runtime.nr_cpus() < 2 { return }
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}p{margin:0;height:10px;background:#f4f4ef}
		</style><header>One retained line of text with more than sixteen glyphs</header>'
			+ '<p>A <i>short</i> <b>run.</b></p>'.repeat(150))
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 700, 600)
		document.set_viewport_rect(dom.Rect{width: 700, height: 600})
		list := document.record_viewport_display_list() or { panic('missing viewport recording') }
		scene := layout.retain_display_list_scene(list)
		defer { layout.release_display_list_scene(scene) }
		commands := layout.display_list_commands(list)
		slots := layout.display_list_glyph_geometry(list, commands)
		assert slots.len == commands.len
		assert layout.display_list_glyph_geometry(list, commands.clone()).len == 0
		mut control := new_paint_canvas_bounds_batch(commands, 2, 30.25, 700, 630)
		mut cached := new_paint_canvas_bounds_batch(commands, 2, 30.25, 700, 630,
			recorded_glyphs: slots)
		assert control.finish(true) == cached.finish(true)
		mut reused := 0
		mut long_runs := 0
		for index, geometry in cached.glyph_geometry {
			if geometry.positions.len == 0 { continue }
			expected := control.glyph_geometry[index]
			assert geometry.positions == expected.positions
			assert geometry.bounds == expected.bounds
			assert geometry.validation.covers(geometry.positions, geometry.positions.len) == !layout.serial_retained_glyph_validation
			if slots[index].positions.len > 0 {
				assert geometry.positions.data == slots[index].positions.data
				reused++
			} else if geometry.positions.len > 32 {
				long_runs++
			}
		}
		assert reused > 0 && long_runs > 0
	}

	fn test_recorded_canvas_ink_applies_the_replay_canvas_offset() {
		if os.getenv('VOX_RECORD_CANVAS_INK_BOUNDS') != '1'
			|| os.getenv('VOX_SERIAL_DISPLAY_LIST_REPLAY') == '1'
			|| os.getenv('VOX_SERIAL_CPU_RASTER') == '1' || runtime.nr_cpus() < 2 { return }
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}p{margin:0;height:9px;background:#eee;transform:translateX(.25px)}
			aside{position:fixed;top:30px;left:1px;background:#ffc}
		</style><aside>Fixed</aside>' + '<p>Recorded <b>text</b> <i>with</i> <u>styles</u></p>'.repeat(180))
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 700, 600)
		document.set_viewport_rect(dom.Rect{y: 120, width: 700, height: 600})
		list := document.record_viewport_display_list() or { panic('missing viewport recording') }
		scene := layout.retain_display_list_scene(list)
		defer { layout.release_display_list_scene(scene) }
		commands := layout.display_list_commands(list)
		ink := layout.display_list_canvas_ink(list, commands)
		assert ink.len == commands.len
		assert ink.any(it.prepared())
		assert layout.display_list_canvas_ink(list, commands.clone()).len == 0
		for page_y in [0.0, -50.25, math.nan()] {
			mut batch := new_paint_canvas_bounds_batch(commands, 2, page_y, 700, 600,
				recorded_ink: ink)
			bounds := batch.finish(true)
			assert bounds.len == commands.len
			for index in 0 .. bounds.len {
				if bounds[index] == u8(PaintLeafCanvasBounds.unprepared) { continue }
				command := &commands[index]
				expected := layout.paint_leaf_is_outside_canvas(command, 0, page_y, 700, 600)
				assert (bounds[index] == u8(PaintLeafCanvasBounds.outside)) == expected
			}
		}
		document.set_viewport_rect(dom.Rect{y: 150, width: 700, height: 600})
		next := document.record_viewport_display_list() or { panic('missing scrolled recording') }
		next_commands := layout.display_list_commands(next)
		assert layout.display_list_canvas_ink(next, next_commands).any(it.prepared())
		assert layout.display_list_canvas_ink(next, commands).len == 0
		assert layout.display_list_canvas_ink(list, commands).len == commands.len
	}
}

fn test_grouped_native_replay_closes_resource_culling_scopes() {
	mut culling := PaintCanvasCulling{enabled: true}
	assert !culling.skip(layout.PaintCommand{kind: 'begin_svg_mask_layer'}, 0, 0, 100, 100)
	assert culling.depth == 1 && culling.resource_depth == 1
	for kind in ['fill_rect', 'begin_css_effect_layer', 'draw_svg_path',
		'end_css_effect_layer', 'end_svg_mask_layer'] {
		culling.replayed_command(&layout.PaintCommand{kind: kind})
	}
	if !disable_cull_replay_scope_sync {
		assert culling.depth == 0 && culling.resource_depth == 0
		assert culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}, 0, 0, 100, 100)
	} else {
		assert culling.depth == 1 && culling.resource_depth == 1
	}
}

fn test_grouped_replay_keeps_an_enclosing_resource_scope_active() {
	if disable_cull_replay_scope_sync { return }
	mut culling := PaintCanvasCulling{enabled: true}
	assert !culling.skip(layout.PaintCommand{kind: 'begin_css_filter_layer'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'begin_svg_mask_layer'}, 0, 0, 100, 100)
	for kind in ['fill_rect', 'end_svg_mask_layer'] {
		culling.replayed_command(&layout.PaintCommand{kind: kind})
	}
	assert culling.depth == 1 && culling.resource_depth == 1
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_filter_layer'}, 0, 0, 100, 100)
	assert culling.depth == 0 && culling.resource_depth == 0
}

fn test_video_canvas_culling_uses_the_final_clip_before_gpu_command_selection() {
	mut culling := PaintCanvasCulling{enabled: true}
	mut video := layout.PaintCommand{kind: 'draw_video', x: 0, y: 0, width: 20, height: 20,
		video_paintable: &painting.VideoPaintable{video_rect: painting.Rect{10, -100, 20, 20}}}
	assert culling.skip(video, 0, 60, 800, 660) == !disable_offscreen_video_culling
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{10, -83, 20, 20}}
	assert !culling.skip(video, 0, 60, 800, 660)
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{10, -100, 20, 20}}
	video.transform = [f64(1), 0, 0, 1, 0, 40]!
	assert !culling.skip(video, 0, 60, 800, 660)
	video.transform = [6]f64{}
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{-100, 20, 20, 20}}
	assert !culling.skip(video, 100, 0, 800, 660)
	video.video_paintable = &painting.VideoPaintable{video_rect: painting.Rect{10, math.nan(), 20, 20}}
	assert !culling.skip(video, 0, 60, 800, 660)
	video.video_paintable = none
	assert !culling.skip(video, 0, 60, 800, 660)
}

fn test_video_canvas_culling_preserves_offscreen_filter_and_mask_inputs() {
	video := layout.PaintCommand{kind: 'draw_video',
		video_paintable: &painting.VideoPaintable{video_rect: painting.Rect{10, -100, 20, 20}}}
	for kind in ['begin_css_filter_layer', 'begin_svg_mask_layer', 'begin_background_blend_group'] {
		mut culling := PaintCanvasCulling{enabled: true}
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 60, 800, 660)
		assert !culling.skip(video, 0, 60, 800, 660)
	}
	mut culling := PaintCanvasCulling{enabled: true}
	assert !culling.skip(layout.PaintCommand{kind: 'begin_css_effect_layer'}, 0, 60, 800, 660)
	assert culling.skip(video, 0, 60, 800, 660) == !disable_offscreen_video_culling
}

fn test_canvas_culling_preserves_complete_resource_and_effect_groups() {
	mut culling := PaintCanvasCulling{enabled: true}
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}
	assert culling.skip(leaf, 0, 0, 100, 100)
	for kind in ['begin_css_filter_layer', 'begin_background_text_clip', 'begin_svg_mask_layer'] {
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
		assert !culling.skip(leaf, 0, 0, 100, 100)
	}
	for kind in ['end_svg_mask_layer', 'end_background_text_clip', 'end_css_filter_layer'] {
		assert !culling.skip(leaf, 0, 0, 100, 100)
		assert !culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
	}
	assert culling.skip(leaf, 0, 0, 100, 100)
	assert culling.depth == 0
}

fn test_canvas_culling_keeps_visible_opacity_scopes_but_discards_their_offscreen_leaves() {
	mut culling := PaintCanvasCulling{enabled: true}
	assert !culling.skip(layout.PaintCommand{kind: 'begin_css_effect_layer'}, 0, 0, 100, 100)
	assert culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 10, y: 10, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'begin_css_filter_layer'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_filter_layer'}, 0, 0, 100, 100)
	assert culling.resource_depth == 0 && culling.depth == 1
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_effect_layer'}, 0, 0, 100, 100)
	assert culling.depth == 0
}

fn test_canvas_culling_discards_a_complete_offscreen_opacity_scope_with_balanced_nested_groups() {
	mut culling := PaintCanvasCulling{enabled: true}
	outside := layout.PaintCommand{kind: 'begin_css_effect_layer', has_clip: true,
		clip_x: 0, clip_y: 104, clip_width: 100, clip_height: 30}
	assert culling.skip(outside, 0, 0, 100, 100)
	for kind in ['begin_svg_mask_layer', 'begin_css_effect_layer', 'fill_rect',
		'end_css_effect_layer', 'end_svg_mask_layer', 'end_css_effect_layer'] {
		assert culling.skip(layout.PaintCommand{kind: kind}, 0, 0, 100, 100)
	}
	assert culling.skipped_depth == 0 && culling.depth == 0 && culling.resource_depth == 0
	assert !culling.skip(layout.PaintCommand{kind: 'fill_rect', x: 10, y: 10, width: 10, height: 10}, 0, 0, 100, 100)
	// Preserve the native clip's fringe and translated clips which reach ink.
	assert !culling.skip(outside, 0, -2, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_css_effect_layer'}, 0, 0, 100, 100)
	// A resource's source-space opacity scope may be consumed onscreen later.
	assert !culling.skip(layout.PaintCommand{kind: 'begin_background_text_clip'}, 0, 0, 100, 100)
	assert !culling.skip(outside, 0, 0, 100, 100)
}

fn test_canvas_culling_skips_the_complete_output_of_an_offscreen_text_mask() {
	mut culling := PaintCanvasCulling{enabled: true}
	outside := layout.PaintCommand{kind: 'begin_background_text_clip', x: 500, y: 500,
		width: 40, height: 20}
	assert culling.skip(outside, 0, 0, 100, 100)
	assert culling.skip(layout.PaintCommand{kind: 'fill_gradient'}, 0, 0, 100, 100)
	assert culling.skip(layout.PaintCommand{kind: 'end_background_text_clip'}, 0, 0, 100, 100)
	assert culling.depth == 0 && culling.skipped_depth == 0
	// Map the final output rectangle before deciding whether its inputs matter.
	translated := layout.PaintCommand{...outside, transform: [1.0, 0, 0, 1, -500, -500]!}
	assert !culling.skip(translated, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'fill_gradient'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_background_text_clip'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'begin_svg_mask_layer'}, 0, 0, 100, 100)
	assert !culling.skip(outside, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_background_text_clip'}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_svg_mask_layer'}, 0, 0, 100, 100)
	assert culling.depth == 0 && culling.resource_depth == 0
}

fn test_canvas_culling_falls_through_when_disabled_or_unknown() {
	mut culling := PaintCanvasCulling{}
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 500, y: 500, width: 20, height: 20}
	assert !culling.skip(leaf, 0, 0, 100, 100)
	culling.enabled = true
	assert !culling.skip(layout.PaintCommand{kind: 'future_paint_operation', x: 500, y: 500}, 0, 0, 100, 100)
	assert !culling.skip(layout.PaintCommand{kind: 'end_unknown_group'}, 0, 0, 100, 100)
	assert culling.depth == 0
	assert culling.skip(leaf, 0, 0, 100, 100)
}

fn test_canvas_culling_discards_empty_effect_clips_outside_resource_inputs() {
	for width in [0.0, 10.0] {
		outside := layout.PaintCommand{kind: 'begin_css_effect_layer', has_clip: true,
			clip_width: width, clip_height: 0}
		mut culling := PaintCanvasCulling{enabled: true}
		assert culling.skip(outside, 0, 60, 800, 660)
		assert culling.skip(layout.PaintCommand{kind: 'begin_css_filter_layer'}, 0, 60, 800, 660)
		assert culling.skip(layout.PaintCommand{kind: 'fill_rect', width: 100, height: 100}, 0, 60, 800, 660)
		assert culling.skip(layout.PaintCommand{kind: 'end_css_filter_layer'}, 0, 60, 800, 660)
		assert culling.skip(layout.PaintCommand{kind: 'end_css_effect_layer'}, 0, 60, 800, 660)
		assert culling.depth == 0 && culling.skipped_depth == 0
		assert !culling.skip(layout.PaintCommand{kind: 'begin_svg_mask_layer'}, 0, 60, 800, 660)
		assert !culling.skip(outside, 0, 60, 800, 660)
	}
}

fn test_prepared_canvas_leaf_bounds_preserve_scope_decisions() {
	offscreen := layout.PaintCommand{kind: 'fill_rect', x: 300, y: 300, width: 20, height: 20}
	translated := layout.PaintCommand{
		...offscreen
		transform: [f64(1), 0, 0, 1, -290, -290]!
	}
	commands := [
		offscreen,
		layout.PaintCommand{kind: 'begin_css_filter_layer'},
		offscreen,
		layout.PaintCommand{kind: 'end_css_filter_layer'},
		layout.PaintCommand{kind: 'begin_css_effect_layer', has_clip: true, clip_x: 300, clip_y: 300,
			clip_width: 20, clip_height: 20},
		translated,
		layout.PaintCommand{kind: 'end_css_effect_layer'},
		translated,
		layout.PaintCommand{kind: 'draw_video'},
	]
	mut bytes := []u8{len: commands.len}
	work := PaintCanvasBoundsWork{
		commands: commands
		bounds: unsafe { &u8(bytes.data) }
		threads: unsafe { nil }
		width: 100
		height: 100
	}
	prepare_paint_canvas_bounds_range(&work, 0, i32(commands.len))
	bounds := bytes.map(unsafe { PaintLeafCanvasBounds(it) })
	assert bounds[0] == .outside && bounds[2] == .outside
	assert bounds[1] == .unprepared && bounds[8] == .unprepared
	assert bounds[5] == .retain && bounds[7] == .retain
	mut serial := PaintCanvasCulling{enabled: true}
	mut prepared := PaintCanvasCulling{enabled: true}
	for index in 0 .. commands.len {
		command := unsafe { &commands[index] }
		assert prepared.skip_with_leaf_bounds(command, 0, 0, 100, 100, bounds[index]) ==
			serial.skip(command, 0, 0, 100, 100)
	}
	assert prepared.depth == 0 && prepared.resource_depth == 0 && prepared.skipped_depth == 0
}

$if macos {
	fn test_canvas_workers_classify_transparent_background_gradients() {
		if runtime.nr_cpus() < 2 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1' { return }
		clear := css.Color{255, 0, 128, 0}
		visible := css.Color{0, 255, 255, 1}
		transparent := layout.LinearGradient{
			colors: [clear, clear]
		}
		override := layout.LinearGradient{
			...transparent
			stops: [layout.GradientStop{clear, 0}, layout.GradientStop{visible, 1}]
		}
		zero_stops := layout.LinearGradient{
			colors: [visible, visible]
			stops: [layout.GradientStop{clear, 0}, layout.GradientStop{clear, 1}]
		}
		image := layout.PaintImageData{image_clip_width: 20, image_clip_height: 20}
		leaf := layout.PaintCommand{
			kind: 'fill_gradient'
			gradient_background_layer: true
			gradient: &transparent
			image_data: &image
			width: 20
			height: 20
		}
		commands := [leaf, layout.PaintCommand{...leaf, gradient: &override},
			layout.PaintCommand{...leaf, x: 200, image_data: &layout.PaintImageData{...image, image_clip_x: 200}},
			layout.PaintCommand{...leaf, gradient: &zero_stops},
			layout.PaintCommand{...leaf, image_data: &layout.PaintImageData{...image, background_blend_mode: .multiply}},
			layout.PaintCommand{...leaf, scrollbar_axis: 'vertical'},
			layout.PaintCommand{...leaf, gradient_background_layer: false},
			layout.PaintCommand{kind: 'begin_css_filter_layer'}]
		expected := [PaintLeafCanvasBounds.transparent_gradient, .retain, .outside,
			.transparent_gradient, .retain, .retain, .retain, .unprepared]
		mut batch := new_paint_canvas_bounds_batch(commands, 2, 0, 100, 100,
			classify_transparent_gradients: true)
		batch.submit(replay_ranges: true)
		assert batch.background_lanes == 2 && batch.begin_replay(true)
		for index, result in expected {
			assert batch.replay_bounds_at(index) == result
		}
		assert batch.finish(true).len == commands.len
		mut culling := PaintCanvasCulling{enabled: true}
		assert !culling.skip_with_leaf_bounds(leaf, 0, 0, 100, 100, .transparent_gradient)
		assert !culling.skip(commands.last(), 0, 0, 100, 100)
		assert culling.depth == 1 && culling.resource_depth == 1
		assert !culling.skip_with_leaf_bounds(leaf, 0, 0, 100, 100, .transparent_gradient)
	}

	fn test_canvas_workers_prepare_gradient_stops_for_ordered_replay() {
		if runtime.nr_cpus() < 2 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1' { return }
		red := css.Color{255, 0, 0, 255}
		blue := css.Color{0, 0, 255, 128}
		gradient := layout.LinearGradient{
			colors: [red, red, blue, blue]
			stops: [layout.GradientStop{red, .125}, layout.GradientStop{red, .5},
				layout.GradientStop{blue, .5}, layout.GradientStop{blue, .875}]
			interpolation_method: css.ColorInterpolationMethod(css.RectangularColorSpace.oklab)
		}
		leaf := layout.PaintCommand{
			kind: 'fill_gradient'
			width: 20
			height: 20
			gradient: &gradient
			opacity: .25
			group_opacity: .5
		}
		other_stops := layout.LinearGradient{
			...gradient
			stops: [layout.GradientStop{red, .1}, layout.GradientStop{blue, .4},
				layout.GradientStop{red, .6}, layout.GradientStop{blue, .9}]
		}
		legacy := layout.LinearGradient{colors: [blue]}
		large := layout.LinearGradient{colors: [red, blue, red, blue, red]}
		commands := [leaf, layout.PaintCommand{...leaf, x: 150},
			layout.PaintCommand{...leaf, scrollbar_axis: 'vertical'},
			layout.PaintCommand{...leaf, gradient: &other_stops, opacity: .75, group_opacity: 1.0},
			layout.PaintCommand{...leaf, gradient: &legacy, group_opacity: 0.0},
			layout.PaintCommand{...leaf, gradient: &large}]
		mut batch := new_paint_canvas_bounds_batch(commands, 2, 0, 100, 100,
			prepare_gradient_stops: true)
		batch.submit(replay_ranges: true)
		assert batch.background_lanes == 2
		assert batch.begin_replay(true)
		assert batch.replay_bounds_at(0) == .retain
		assert batch.gradient_stops_at(0).packed() == native_gradient_stop_data(gradient, .5)
		assert batch.replay_bounds_at(1) == .outside
		assert batch.gradient_stops_at(1) == unsafe { nil }
		assert batch.gradient_stops_at(2) == unsafe { nil }
		assert batch.replay_bounds_at(3) == .retain
		assert batch.gradient_stops_at(3).packed() == native_gradient_stop_data(other_stops, .75)
		assert batch.gradient_stops_at(4).packed() == native_gradient_stop_data(legacy, 1)
		assert batch.gradient_stops_at(5) == unsafe { nil }
		assert batch.finish(true).len == commands.len
		mut serial := new_paint_canvas_bounds_batch(commands, 0, 0, 100, 100,
			prepare_gradient_stops: true)
		assert !serial.begin_replay(true)
		assert serial.gradient_stops_at(0) == unsafe { nil }
	}

	fn test_replay_workers_project_screen_rectangles_for_unchanged_leaves() {
		if runtime.nr_cpus() < 2 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1'
			|| serial_paint_screen_geometry { return }
		leaf := layout.PaintCommand{kind: 'fill_rect', x: 10.25, y: 20, width: 16, height: 8}
		transformed := layout.PaintCommand{
			...leaf
			transform: [f64(-1), 0.25, 0.5, 1, 50, -4]!
		}
		commands := [leaf, transformed, layout.PaintCommand{...leaf, x: 900},
			layout.PaintCommand{...leaf, checkbox_theme_data: &layout.PaintCheckboxThemeData{}},
			layout.PaintCommand{kind: 'begin_css_effect_layer'},
			layout.PaintCommand{kind: 'draw_video'}]
		page_y := f32(12.5)
		mut batch := new_paint_canvas_bounds_batch(commands, 2, f64(page_y), 100, 100)
		batch.submit()
		assert batch.background_lanes == 2
		assert batch.finish(true).len == commands.len
		for index in 0 .. 2 {
			command := &commands[index]
			prepared := batch.screen_geometry_at(index)
			assert prepared != unsafe { nil }
			x, y := paint_screen_point(*command, command.x, command.y, 0, page_y, 0)
			assert prepared.points[0] == x && prepared.points[1] == y
			assert prepared.points == transformed_rect_points(*command, 0, page_y, 0)
			assert prepared.matrix == normalized_paint_transform(command.transform)
		}
		identity := batch.screen_geometry_at(0)
		assert [identity.x, identity.y, identity.width, identity.height]! == [f32(10.25), 32.5, 16, 8]!
		affine := batch.screen_geometry_at(1)
		assert [affine.x, affine.y, affine.width, affine.height]! == [f32(33.75), 31.0625, 20, 12]!
		for index in 2 .. commands.len {
			assert batch.screen_geometry_at(index) == unsafe { nil }
		}
	}

	fn test_replay_workers_prepare_glyph_positions_in_their_command_slots() {
		if runtime.nr_cpus() < 2 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1'
			|| serial_retained_glyph_geometry { return }
		glyphs := [
			platform.Glyph{glyph_index: 1, position: platform.GlyphPosition{5.25, -1.5}},
			platform.Glyph{glyph_index: 2, position: platform.GlyphPosition{-3.5, 2.25}},
		]
		chromium := platform.GlyphRun.new(&platform.Font{font_rendering_policy: .chromium},
			.ltr, glyphs)
		libweb := platform.GlyphRun.new(&platform.Font{font_rendering_policy: .libweb},
			.ltr, glyphs)
		text := layout.PaintCommand{kind: 'draw_text', glyph_run: chromium,
			glyph_translation_x: 10.5, glyph_translation_y: 20.25}
		commands := [text, layout.PaintCommand{kind: 'fill_rect'},
			layout.PaintCommand{...text, glyph_run: libweb}, text]
		mut batch := new_paint_canvas_bounds_batch(commands, 2, 0, 100, 100)
		batch.submit()
		assert batch.background_lanes == 2
		assert batch.finish(true).len == commands.len
		geometry := batch.glyph_geometry
		assert geometry[0].positions == [f32(15.75), 18.75, 7, 22.5]
		assert geometry[0].bounds.left == 7 && geometry[0].bounds.top == 18.75
		assert geometry[0].bounds.right == 15.75 && geometry[0].bounds.bottom == 22.5
		assert geometry[1].positions.len == 0
		assert geometry[2].positions == [f32(5.25), -1.5, -3.5, 2.25]
		assert geometry[2].bounds.left == -3.5 && geometry[2].bounds.right == 5.25
		assert geometry[3].positions == geometry[0].positions
		for index in [0, 2, 3] {
			assert geometry[index].validation.covers(geometry[index].positions, 4) == !layout.serial_retained_glyph_validation
		}
		assert !geometry[0].validation.covers(geometry[3].positions, 4)
		assert chromium.glyph_positions() == libweb.glyph_positions()
	}

	fn test_worker_glyph_ranges_skip_unneeded_and_oversized_runs() {
		if runtime.nr_cpus() < 2 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1'
			|| serial_retained_glyph_geometry || packed_retained_glyph_geometry { return }
		font := &platform.Font{point_size: 12, font_rendering_policy: .chromium}
		glyph := platform.Glyph{glyph_index: 1, position: platform.GlyphPosition{5, 2}}
		short := platform.GlyphRun.new(font, .ltr, [glyph])
		long := platform.GlyphRun.new(font, .ltr, []platform.Glyph{
			len: retained_glyph_positions_per_command + 1
			init: glyph
		})
		text := layout.PaintCommand{kind: 'draw_text', glyph_run: short,
			glyph_translation_x: 10, glyph_translation_y: 20}
		commands := [
			layout.PaintCommand{...text, glyph_run: long},
			text,
			layout.PaintCommand{...text, glyph_translation_y: 500},
			text,
			text,
		]
		mut batch := new_paint_canvas_bounds_batch(commands, 2, 0, 100, 100)
		batch.submit()
		assert batch.background_lanes == 2
		bounds := batch.finish(true)
		assert bounds.len == commands.len
		assert bounds[2] == u8(PaintLeafCanvasBounds.outside)
		geometry := batch.glyph_geometry
		assert geometry[0].positions.len == 0 && geometry[2].positions.len == 0
		assert geometry[1].positions == [f32(15), 22]
		assert geometry[3].positions == geometry[1].positions
		assert geometry[4].positions == geometry[1].positions
		assert voidptr(geometry[1].positions.data) != voidptr(geometry[3].positions.data)
	}

	fn test_canvas_bounds_can_join_after_other_frame_setup_allocations() {
		if runtime.nr_cpus() < 2 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1' { return }
		visible := layout.PaintCommand{kind: 'fill_rect', width: 20, height: 20}
		outside := layout.PaintCommand{...visible, y: 250}
		commands := []layout.PaintCommand{len: 443, init: if index % 2 == 0 { visible } else { outside }}
		mut app := BrowserApp{
			ctx: &gg.Context{native_rendering: true}
		}
		mut scratch := app.begin_native_replay_scratch()
		mut batch := new_paint_canvas_bounds_batch(commands, 4, 0, 100, 100)
		batch.submit()
		scratch.leave_for_frame_setup()
		assert batch.background_lanes >= 2
		setup := []int{len: 4096, init: index}
		mut replay := app.begin_native_replay_scratch()
		result := batch.finish(true)
		assert result.len == commands.len
		for index, byte in result {
			expected := if index % 2 == 0 { PaintLeafCanvasBounds.retain } else { PaintLeafCanvasBounds.outside }
			assert byte == u8(expected)
		}
		replay.finish()
		app.release_native_replay_scratch()
		assert setup.last() == 4095
	}

	fn test_canvas_bounds_replay_can_skip_a_worker_range() {
		if runtime.nr_cpus() < 3 || os.getenv('VOX_SERIAL_CPU_RASTER') == '1'
			|| serial_paint_screen_geometry { return }
		visible := layout.PaintCommand{kind: 'fill_rect', width: 20, height: 20}
		outside := layout.PaintCommand{...visible, y: 250}
		commands := []layout.PaintCommand{len: 11, init: if index % 2 == 0 { visible } else { outside }}
		mut batch := new_paint_canvas_bounds_batch(commands, 3, 0, 100, 100)
		batch.submit(replay_ranges: true)
		assert batch.background_lanes == 3
		assert batch.begin_replay(true)
		assert batch.replay_bounds_at(0) == .retain
		assert batch.range_end == 3 && batch.ranges_observed == 1
		assert batch.replay_bounds_at(2) == .retain
		assert batch.screen_geometry_at(2).ready
		assert batch.ranges_observed == 1
		assert batch.replay_bounds_at(7) == .outside
		assert batch.replay_bounds_at(8) == .retain
		assert batch.screen_geometry_at(8).ready
		assert batch.range_end == 11 && batch.ranges_observed == 2
		assert batch.ticket != unsafe { nil }
		bounds := batch.finish(true)
		assert batch.ticket == unsafe { nil } && !batch.replay_ranges
		assert bounds[4] == u8(PaintLeafCanvasBounds.retain)
		assert bounds[5] == u8(PaintLeafCanvasBounds.outside)
	}
}
