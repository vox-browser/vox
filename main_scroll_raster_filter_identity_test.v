module main

import dom
import layout
import painting

fn identity_blur() layout.PaintCommand {
	return layout.PaintCommand{kind: 'begin_css_filter_layer', visual_layer_data: &layout.PaintVisualLayer{
		kind: .css_filter
		filter: painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'blur', first: 4}]}
	}}
}

fn test_spatial_filter_identity_keeps_stationary_pixels_but_tracks_raster_position() {
	commands := [identity_blur(), layout.PaintCommand{kind: 'fill_rect', x: 60, y: 70,
		width: 40, height: 20, color: 'red'}, layout.PaintCommand{kind: 'end_css_filter_layer'}]
	first := scroll_raster_frame_keys(commands, 0, 1, 200, 200)
	second := scroll_raster_frame_keys(commands, 0, 1, 200, 200)
	assert first[0].hash == second[0].hash
	previous := ScrollRasterKeyFrame{valid: true, document: 7, width: 200, height: 200, keys: first}
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, second, 7, 0, 200, 200, mut stats) or {
		panic('stationary filter must reuse')
	}
	assert rects.len == 0
	assert plan_scroll_raster_skips(commands, second, [], false) == [true, true, true]
	mut translated := commands.clone()
	translated[1] = layout.PaintCommand{...commands[1], transform: [f64(1), 0, 0, 1, 0, -13]!}
	third := scroll_raster_frame_keys(translated, 13, 1, 200, 200)
	assert third[0].hash != first[0].hash
	assert scroll_raster_frame_keys(translated, 13, 1, 200, 200)[0].hash == third[0].hash
}

fn test_filter_input_changes_damage_the_complete_blur_extent() {
	begin := identity_blur()
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 60, y: 70, width: 40, height: 20, color: 'red'}
	end := layout.PaintCommand{kind: 'end_css_filter_layer'}
	before := [begin, leaf, end]
	after := [begin, layout.PaintCommand{...leaf, color: 'blue'}, end]
	old := scroll_raster_frame_keys(before, 0, 1, 200, 200)
	keys := scroll_raster_frame_keys(after, 0, 1, 200, 200)
	assert old[0].hash != keys[0].hash
	previous := ScrollRasterKeyFrame{valid: true, document: 7, width: 200, height: 200, keys: old}
	mut stats := ScrollRasterDiffStats{}
	rects := scroll_raster_content_damage(&previous, keys, 7, 0, 200, 200, mut stats) or {
		panic('changed blur input must reconcile')
	}
	// Four-pixel blur has 13px conservative extent, plus the damage fringe.
	assert rects == [layout.LayoutRect{44, 54, 72, 52}]
	assert plan_scroll_raster_skips(after, keys, rects, false) == [false, false, false]
}

fn test_filter_identity_includes_nested_group_contents_and_order() {
	leaf := layout.PaintCommand{kind: 'fill_rect', x: 60, y: 70, width: 40, height: 20, color: 'red'}
	commands := [identity_blur(), layout.PaintCommand{kind: 'begin_css_effect_layer'},
		leaf, layout.PaintCommand{...leaf, color: 'blue'},
		layout.PaintCommand{kind: 'end_css_effect_layer'}, layout.PaintCommand{kind: 'end_css_filter_layer'}]
	key := scroll_raster_frame_keys(commands, 0, 1, 200, 200)[0].hash
	assert scroll_raster_frame_keys(commands, 0, 1, 200, 200)[0].hash == key
	mut changed := commands.clone()
	changed[2] = layout.PaintCommand{...leaf, color: 'green'}
	assert scroll_raster_frame_keys(changed, 0, 1, 200, 200)[0].hash != key
	changed = commands.clone()
	changed[2], changed[3] = changed[3], changed[2]
	assert scroll_raster_frame_keys(changed, 0, 1, 200, 200)[0].hash != key
	changed = commands.clone()
	changed[0] = layout.PaintCommand{...commands[0], has_clip: true, clip_x: 40, clip_y: 40,
		clip_width: 80, clip_height: 80}
	assert scroll_raster_frame_keys(changed, 0, 1, 200, 200)[0].hash != key
}

fn test_filter_identity_tracks_live_canvas_and_video_inputs() {
	canvas := [identity_blur(), layout.PaintCommand{kind: 'draw_canvas', x: 60, y: 70,
		width: 40, height: 20}, layout.PaintCommand{kind: 'end_css_filter_layer'}]
	assert scroll_raster_frame_keys(canvas, 0, 1, 200, 200)[0].hash
		!= scroll_raster_frame_keys(canvas, 0, 1, 200, 200)[0].hash
	mut source := painting.VideoFrameSource.create()
	mut frame := painting.MediaVideoFrame.from_bitmap(&dom.Bitmap_{width: 2, height: 2,
		pitch: 8, data: []u8{len: 16}})
	source.update(frame)
	video := [identity_blur(), layout.PaintCommand{kind: 'draw_video', x: 60, y: 70,
		width: 40, height: 20, video_frame_source: source}, layout.PaintCommand{kind: 'end_css_filter_layer'}]
	before := scroll_raster_frame_keys(video, 0, 1, 200, 200)[0].hash
	assert scroll_raster_frame_keys(video, 0, 1, 200, 200)[0].hash == before
	frame.generation++
	assert scroll_raster_frame_keys(video, 0, 1, 200, 200)[0].hash != before
}
