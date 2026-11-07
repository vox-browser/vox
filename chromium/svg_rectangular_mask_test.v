module main

import layout

fn svg_rectangular_mask_test_commands() []layout.PaintCommand {
	data := svg_background_test_rectangle()
	clip := &layout.PaintClip{
		is_svg_mask: true
		cache_key: 7
		scope_id: 11
		path_components: [layout.PaintPath{path_data: data}]
	}
	return [
		layout.PaintCommand{kind: 'begin_svg_mask_layer', mask_clip_data: clip},
		layout.PaintCommand{kind: 'draw_svg_path', color: '#fff',
			svg_data: &layout.PaintSVGPathData{path_data: data}},
		layout.PaintCommand{kind: 'end_svg_mask_layer', mask_clip_data: clip},
	]
}

fn test_svg_rectangular_mask_batches_only_complete_same_owner_scopes() {
	commands := svg_rectangular_mask_test_commands()
	assert chromium_svg_rectangular_mask_end(commands, [], 0) == 3
	assert chromium_svg_rectangular_mask_end(commands, [2, 2, 2], 0) == 3
	assert chromium_svg_rectangular_mask_end(commands, [2, 3, 2], 0) == 0
	assert chromium_svg_rectangular_mask_end(commands, [2, 2, 3], 0) == 0
	assert chromium_svg_rectangular_mask_end(commands, [2], 0) == 0
	assert chromium_svg_rectangular_mask_end(commands, [], -1) == -1
	assert chromium_svg_rectangular_mask_end(commands, [], 3) == 3
	assert chromium_svg_rectangular_mask_end(commands, [], 1) == 1
	assert chromium_svg_rectangular_mask_end(commands[..2], [], 0) == 0
	assert chromium_svg_rectangular_mask_end([commands[0], commands[2]], [], 0) == 0
	assert chromium_svg_rectangular_mask_end([commands[0], commands[1], commands[1], commands[2]], [], 0) == 4
}

fn test_svg_rectangular_mask_rejects_effects_strokes_and_nonrectangular_clips() {
	commands := svg_rectangular_mask_test_commands()
	for changed in [
		layout.PaintCommand{...commands[1], opacity: .5},
		layout.PaintCommand{...commands[1], group_opacity: .5},
		layout.PaintCommand{...commands[1], stroke_color: '#000', stroke_width: 1},
		layout.PaintCommand{...commands[1], transform: [f64(1), .5, 0, 1, 0, 0]!},
		layout.PaintCommand{...commands[1], clip_outs: [f64(0), 0, 1, 1]},
		layout.PaintCommand{kind: 'begin_effect_group'},
		commands[0],
	] {
		assert chromium_svg_rectangular_mask_end([commands[0], changed, commands[2]], [], 0) == 0
	}
	clip := commands[0].mask_clip()
	for changed in [
		layout.PaintClip{...clip, is_svg_content_mask: true},
		layout.PaintClip{...clip, path_components: [clip.path_components[0], clip.path_components[0]]},
		layout.PaintClip{...clip, path_components: [layout.PaintPath{
			path_data: clip.path_components[0].path_data
			transform: [f64(1), 0, .5, 1, 0, 0]!
		}]},
	] {
		begin := layout.PaintCommand{...commands[0], mask_clip_data: &changed}
		end := layout.PaintCommand{...commands[2], mask_clip_data: &changed}
		assert chromium_svg_rectangular_mask_end([begin, commands[1], end], [], 0) == 0
	}
}

fn test_svg_rectangular_mask_requires_matching_boundary_identity() {
	commands := svg_rectangular_mask_test_commands()
	clip := commands[2].mask_clip()
	for changed in [
		layout.PaintClip{...clip, scope_id: 12},
		layout.PaintClip{...clip, cache_key: 8},
		layout.PaintClip{...clip, rect: layout.LayoutRect{1, 2, 3, 4}},
		layout.PaintClip{...clip, transform: [f64(1), 0, 0, 1, 1, 0]!},
		layout.PaintClip{...clip, path_components: [layout.PaintPath{
			path_data: clip.path_components[0].path_data
			transform: [f64(1), 0, 0, 1, 1, 0]!
		}]},
	] {
		end := layout.PaintCommand{...commands[2], mask_clip_data: &changed}
		assert chromium_svg_rectangular_mask_end([commands[0], commands[1], end], [], 0) == 0
	}
	for boundary in [
		layout.PaintCommand{...commands[0], opacity: .5},
		layout.PaintCommand{...commands[0], has_clip: true},
		layout.PaintCommand{...commands[0], transform: [f64(1), 0, 0, 1, 2, 0]!},
	] {
		assert chromium_svg_rectangular_mask_end([boundary, commands[1], commands[2]], [], 0) == 0
	}
}
