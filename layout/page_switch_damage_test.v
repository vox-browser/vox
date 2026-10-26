module layout

import platform
import painting
import html
import math

fn test_page_switch_tiles_repaint_changed_removed_and_unknown_inputs() {
	before := [PaintCommand{ kind: 'fill_rect', x: 10, y: 10, width: 20, height: 20, color: 'red' }]
	snapshot := page_switch_tiles(before, 384, 256)
	assert snapshot.keys.len == 6
	assert snapshot.keys.all(it != '')
	assert snapshot.damage(page_switch_tiles(before, 384, 256)).len == 0
	changed := [PaintCommand{ ...before[0], color: 'blue' }]
	assert snapshot.damage(page_switch_tiles(changed, 384, 256)) == [LayoutRect{0, 0, 128, 128}]
	assert snapshot.damage(page_switch_tiles([], 384, 256)) == [LayoutRect{0, 0, 128, 128}]
	unknown := [PaintCommand{
		kind:       'draw_background_image'
		image_data: &PaintImageData{
			image_clip_x:      10
			image_clip_y:      10
			image_clip_width:  20
			image_clip_height: 20
		}
	}]
	assert page_switch_tiles(unknown, 384, 256).keys[0] == ''
	assert page_switch_tiles(unknown, 384, 256).damage(page_switch_tiles(unknown, 384, 256)).len == 1
	assert snapshot.damage(page_switch_tiles(before, 385, 256)) == [LayoutRect{0, 0, 385, 256}]
}

fn test_page_switch_text_keys_include_glyph_positions_and_concrete_face() {
	mut run := platform.GlyphRun.new(&platform.Font{ family: 'Arial', point_size: 12 }, .ltr,
		[platform.Glyph{ glyph_index: 3, position: platform.GlyphPosition{10, 10} }])
	command := PaintCommand{ kind: 'draw_text', text: 'a', glyph_run: run }
	before := page_switch_leaf_key(command) or { panic('missing text key') }
	run.glyphs_[0].position.x++
	assert before != page_switch_leaf_key(command) or { panic('missing text key') }
	changed := page_switch_leaf_key(command) or { panic('missing changed text key') }
	smoothed := page_switch_leaf_key(PaintCommand{ ...command, font_smoothing: .antialiased }) or { panic('missing smoothed text key') }
	assert changed != smoothed
	assert page_switch_leaf_key(PaintCommand{ kind: 'draw_text', text: 'fallback font' }) == none
	assert page_switch_leaf_key(PaintCommand{ kind: 'fill_rect', local_border_data: &PaintLocalBorderData{} }) == none
}

fn test_page_switch_tiles_include_order_clips_and_transform_and_bound_unknown_groups() {
	a := PaintCommand{ kind: 'fill_rect', x: 10, y: 10, width: 20, height: 20, color: 'red' }
	b := PaintCommand{ ...a, color: 'blue' }
	before := page_switch_tiles([a, b], 384, 256)
	assert before.damage(page_switch_tiles([b, a], 384, 256)).len == 1
	clipped := PaintCommand{ ...a, recording_clip: LayoutRect{10, 10, 5, 5} }
	assert page_switch_leaf_key(a) != page_switch_leaf_key(clipped)
	clip := PaintClip{rect: LayoutRect{10, 10, 5, 5}}
	with_clip := PaintCommand{...a, clip_list: &PaintClipList{items: [clip]}}
	assert page_switch_leaf_key(with_clip) != none
	assert page_switch_leaf_key(with_clip) != page_switch_leaf_key(PaintCommand{...a,
		clip_list: &PaintClipList{items: [PaintClip{...clip, rect: LayoutRect{10, 10, 6, 5}}]}})
	assert page_switch_leaf_key(PaintCommand{...a,
		clip_list: &PaintClipList{items: [PaintClip{...clip, is_path: true}]}}) == none
	moved := PaintCommand{ ...a, transform: [1.0, 0.0, 0.0, 1.0, 140.0, 0.0]! }
	assert page_switch_tiles([a], 384, 256).damage(page_switch_tiles([moved], 384, 256)).len == 2
	border := PaintCommand{ ...a, kind: 'paint_uniform_border', stroke_width: 1 }
	assert page_switch_tiles([border], 384, 256).keys.all(it != '')
	grouped := page_switch_tiles([PaintCommand{kind: 'begin_skia_command_group'}, a,
		PaintCommand{kind: 'end_skia_command_group'}], 384, 256)
	assert grouped.keys[0] == ''
	assert grouped.keys.filter(it == '').len == 1
}

fn test_page_switch_native_checkmark_dirties_only_its_bounds() {
	mut commands := []PaintCommand{}
	append_chromium_checked_checkbox(mut commands, painting.IntRect{20, 20, 13, 13}, 1, 1)
	assert commands.last().kind == 'draw_svg_path'
	tiles := page_switch_tiles(commands, 384, 256)
	assert tiles.keys.filter(it == '').len == 1
	assert tiles.keys[0] == ''
	path := commands.last()
	moved := PaintCommand{...path, transform: [1.0, 0.0, 0.0, 1.0, 140.0, 0.0]!}
	assert page_switch_tiles([moved], 384, 256).keys[1] == ''
	assert page_switch_tiles([moved], 384, 256).keys.filter(it == '').len == 1
	// Missing initial moves, malformed segments and non-scaling strokes stay unbounded.
	path_data := path.svg()
	for data in [PaintSVGPathData{...path_data, non_scaling_stroke: true},
		PaintSVGPathData{path_data: [f32(2)].repeat(compatibility_clip_path_segment_stride)},
		PaintSVGPathData{path_data: [f32(1)]}] {
		assert page_switch_tiles([PaintCommand{...path, svg_data: &data}], 384, 256).keys.all(it == '')
	}
}

fn test_page_switch_bounds_include_bezier_controls_arc_radius_correction_and_strokes() {
	move := [f32(0), 20, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	for segment in [
		[f32(2), 40, 40, 80, 80, 0, 0, 0, 0, 0, 0, 0],
		[f32(3), 40, 40, 80, 80, 60, 70, 0, 0, 0, 0, 0],
		[f32(4), 40, 40, 0, 0, 0, 0, 2, 2, 0.5, 1, 1],
	] {
		mut packed := move.clone()
		packed << segment
		command := PaintCommand{kind: 'draw_svg_path', stroke_width: 2,
			svg_data: &PaintSVGPathData{path_data: packed}}
		assert page_switch_tiles([command], 384, 256).keys.filter(it == '').len == 1
		// A changed/removed unsupported path always invalidates its own tile.
		assert page_switch_tiles([command], 384, 256).damage(page_switch_tiles([], 384, 256)).len == 1
		assert page_switch_tiles([PaintCommand{...command, transform: [1.0, 0, 0, 1, 140, 0]!}], 384, 256).keys[1] == ''
	}
	mut packed := move.clone()
	packed << [f32(3), 40, 40, 170, 80, 60, 70, 0, 0, 0, 0, 0]
	curve := PaintCommand{kind: 'draw_svg_path', svg_data: &PaintSVGPathData{path_data: packed}}
	assert page_switch_tiles([curve], 384, 256).keys[1] == '' // control hull crosses tile
	packed[15] = f32(math.nan())
	assert page_switch_tiles([PaintCommand{...curve, svg_data: &PaintSVGPathData{path_data: packed}}], 384, 256).keys.all(it == '')
}

fn test_page_switch_rounded_sidebar_borders_do_not_disable_raster_or_dirty_posts() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;background:white}aside{margin-left:270px;width:90px;height:40px;
		border-radius:3px;background:#4f86b5;border-bottom:2px solid #4270a2}
	</style><aside></aside>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document, 384, 256)
	commands := root.paint_commands()
	assert commands.any(it.kind == 'paint_rounded_border_bottom')
	assert viewport_scroll_raster_reusable(document, commands, 384, 256)
	tiles := page_switch_tiles(commands, 384, 256)
	assert tiles.keys[0] != ''
	border := commands.filter(it.kind == 'paint_rounded_border_bottom')[0]
	assert page_switch_leaf_key(border) != none
	assert page_switch_leaf_key(border) != page_switch_leaf_key(PaintCommand{...border, points: [1.0, 1, 3, 1]})
	assert page_switch_tiles([border], 384, 256).damage(page_switch_tiles([], 384, 256)).len == 1
	assert !viewport_scroll_raster_reusable(document, [PaintCommand{kind: 'unknown'}], 384, 256)
}
