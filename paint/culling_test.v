module main

import gg
import layout
import painting
import math
import os
import platform
import runtime

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
}
