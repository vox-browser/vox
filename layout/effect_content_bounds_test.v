module layout

import dom
import html
import math
import painting
import platform

fn content_bounds_group(children []PaintCommand) []PaintCommand {
	mut commands := [PaintCommand{ kind: 'begin_css_effect_layer' }]
	commands << children
	commands << PaintCommand{ kind: 'end_css_effect_layer' }
	bound_visual_effect_contents(mut commands)
	return commands
}

fn content_bounds_clip(command PaintCommand) LayoutRect {
	assert command.has_clip
	return LayoutRect{command.clip_x, command.clip_y, command.clip_width, command.clip_height}
}

fn test_effect_content_bounds_union_transformed_children_and_preserve_leaf_commands() {
	children := [
		PaintCommand{ kind: 'fill_rect', x: 10, y: 20, width: 30, height: 40 },
		PaintCommand{
			kind:      'fill_rounded_rect'
			x:         2
			y:         3
			width:     5
			height:    7
			transform: [f64(0), 2, -3, 0, 100, 10]!
		},
	]
	commands := content_bounds_group(children)
	assert content_bounds_clip(commands[0]) == LayoutRect{10, 14, 81, 46}
	assert commands[1..3] == children
	assert commands.len == 4
	// The same bounds are already in viewport coordinates during nested replay.
	nested := paint_command_for_nested_viewport(commands[0], [f64(2), 0, 0, 2, 11, 17]!,
		painting.IntPoint{5, 7}, 1)
	assert content_bounds_clip(nested) == LayoutRect{41, 59, 162, 92}
}

fn test_effect_content_bounds_keep_both_nested_scopes_and_empty_groups() {
	mut commands := [
		PaintCommand{ kind: 'begin_css_effect_layer' },
		PaintCommand{ kind: 'fill_rect', x: 1, y: 2, width: 3, height: 4 },
		PaintCommand{ kind: 'begin_css_effect_layer' },
		PaintCommand{ kind: 'fill_ellipse', x: 20, y: 30, width: 5, height: 6 },
		PaintCommand{ kind: 'end_css_effect_layer' },
		PaintCommand{ kind: 'end_css_effect_layer' },
	]
	bound_visual_effect_contents(mut commands)
	assert content_bounds_clip(commands[0]) == LayoutRect{1, 2, 24, 34}
	assert content_bounds_clip(commands[2]) == LayoutRect{20, 30, 5, 6}
	assert content_bounds_clip(content_bounds_group([]PaintCommand{})[0]) == LayoutRect{}
}

fn test_effect_content_bounds_intersect_ancestor_clip_after_including_all_children() {
	mut commands := [
		PaintCommand{
			kind:        'begin_css_effect_layer'
			has_clip:    true
			clip_x:      10
			clip_y:      20
			clip_width:  50
			clip_height: 60
		},
		PaintCommand{ kind: 'fill_rect', x: 0, y: 0, width: 30, height: 40 },
		PaintCommand{ kind: 'fill_rect', x: 50, y: 70, width: 30, height: 40 },
		PaintCommand{ kind: 'end_css_effect_layer' },
	]
	bound_visual_effect_contents(mut commands)
	assert content_bounds_clip(commands[0]) == LayoutRect{10, 20, 50, 60}
	commands[1].x = 100
	commands[2].x = 200
	bound_visual_effect_contents(mut commands)
	assert commands[0].clip_width == 0
}

fn test_effect_content_bounds_use_glyph_ink_outside_the_line_box_and_stroke_extents() {
	run := &platform.GlyphRun{
		bounding_box_: platform.GlyphRunBounds{-4, -12, 40, 18}
	}
	command := PaintCommand{
		kind:                'draw_text'
		x:                   100
		y:                   100
		width:               1
		height:              1
		glyph_run:           run
		glyph_translation_x: 10
		glyph_translation_y: 20
	}
	assert content_bounds_clip(content_bounds_group([command])[0]) == LayoutRect{6, 8, 40, 18}
	line := PaintCommand{ kind: 'draw_line', points: [f64(30), 40, 10, 20], stroke_width: 4 }
	assert content_bounds_clip(content_bounds_group([line])[0]) == LayoutRect{6, 16, 28, 28}
	stroke := PaintCommand{
		kind:         'stroke_ellipse'
		x:            10
		y:            20
		width:        30
		height:       40
		stroke_width: 3
	}
	assert content_bounds_clip(content_bounds_group([stroke])[0]) == LayoutRect{7, 17, 36, 46}
}

fn test_effect_content_bounds_preserve_filters_unknown_ink_and_nonstandard_blending() {
	for kind in ['begin_css_filter_layer', 'draw_text_shadow', 'paint_outer_box_shadow', 'draw_svg_path',
		'paint_nested_display_list', 'future_operation'] {
		mut commands := [
			PaintCommand{
				kind:        'begin_css_effect_layer'
				has_clip:    true
				clip_x:      10
				clip_y:      20
				clip_width:  500
				clip_height: 600
			},
			PaintCommand{ kind: 'begin_css_effect_layer' },
			PaintCommand{ kind: kind },
			PaintCommand{ kind: 'end_css_effect_layer' },
			PaintCommand{ kind: 'end_css_effect_layer' },
		]
		before := commands.clone()
		bound_visual_effect_contents(mut commands)
		assert commands == before
	}
	assert !content_bounds_group([PaintCommand{ kind: 'draw_text', text: 'unshaped' }])[0].has_clip
	mut blend := [PaintCommand{
		kind:              'begin_css_effect_layer'
		visual_layer_data: &PaintVisualLayer{ blend_mode: .destination_in }
	}, PaintCommand{ kind: 'fill_rect', width: 10, height: 10 },
		PaintCommand{ kind: 'end_css_effect_layer' }]
	bound_visual_effect_contents(mut blend)
	assert !blend[0].has_clip
}

fn test_effect_content_bounds_follow_background_clip_instead_of_positioning_area() {
	image := &PaintImageData{
		image_clip_x:      2
		image_clip_y:      3
		image_clip_width:  90
		image_clip_height: 80
	}
	for kind in ['draw_background_image', 'fill_gradient'] {
		command := PaintCommand{
			kind:                      kind
			x:                         20
			y:                         30
			width:                     10
			height:                    10
			image_data:                image
			gradient_background_layer: true
			transform:                 [f64(3), 0, 0, 2, 5, 7]!
		}
		expected := if kind == 'fill_gradient' {
			LayoutRect{11, 13, 270, 160}
		} else {
			LayoutRect{8, 11, 276, 164}
		}
		assert content_bounds_clip(content_bounds_group([command])[0]) == expected
	}
}

fn test_recorded_opacity_bounds_follow_scrolling_and_do_not_modify_previous_recordings() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#tiny{position:absolute;top:400px;left:30px;width:12px;height:14px;opacity:.5;background:red}#overflow{height:900px}</style><div id="tiny"></div><div id="overflow"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := display_list_commands(document.record_display_list() or { panic('missing paint') })
	initial := first.filter(it.kind == 'begin_css_effect_layer')
	assert initial.len == 1
	assert content_bounds_clip(initial[0]) == LayoutRect{30, 400, 12, 14}
	document.set_viewport_rect(dom.Rect{0, 300, 320, 200})
	second := display_list_commands(document.record_display_list() or { panic('missing scrolled paint') })
	scrolled := second.filter(it.kind == 'begin_css_effect_layer')
	assert scrolled.len == 1
	assert content_bounds_clip(scrolled[0]) == LayoutRect{30, 100, 12, 14}
	assert content_bounds_clip(initial[0]) == LayoutRect{30, 400, 12, 14}
}

fn test_effect_content_bounds_retain_pointwise_filters_and_reject_spatial_or_unknown_filters() {
	for filter in [
		painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'color', first: 1, color_operation: .grayscale}]},
		painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'hue-rotate', first: 90}]},
	] {
		layer := &PaintVisualLayer{kind: .css_filter, filter: filter}
		commands := content_bounds_group([
			PaintCommand{kind: 'begin_css_filter_layer', visual_layer_data: layer},
			PaintCommand{kind: 'begin_css_effect_layer'},
			PaintCommand{kind: 'fill_rect', x: 20, y: 10000, width: 50, height: 30},
			PaintCommand{kind: 'end_css_effect_layer'},
			PaintCommand{kind: 'end_css_filter_layer'},
		])
		assert content_bounds_clip(commands[0]) == LayoutRect{20, 10000, 50, 30}
		assert content_bounds_clip(commands[2]) == LayoutRect{20, 10000, 50, 30}
	}
	for filter in [
		painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'blur', first: 5}]},
		painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'drop-shadow', first: 5}]},
		painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'future-filter'}]},
		painting.GfxFilter{operations: [painting.GfxFilterOperation{kind: 'color', first: math.nan()}]},
		painting.GfxFilter{nodes: [painting.GfxFilterNode{kind: 'flood'}], root_id: 0},
	] {
		commands := content_bounds_group([
			PaintCommand{kind: 'begin_css_filter_layer', visual_layer_data: &PaintVisualLayer{kind: .css_filter, filter: filter}},
			PaintCommand{kind: 'fill_rect', x: 20, y: 10000, width: 50, height: 30},
			PaintCommand{kind: 'end_css_filter_layer'},
		])
		assert !commands[0].has_clip
	}
	mut document := html.parse_document('<!doctype html><style>body{margin:0}div{position:absolute;left:20px;top:10000px;width:50px;height:30px;background:red;opacity:.85;filter:grayscale(1)}</style><div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	effects := commands.filter(it.kind == 'begin_css_effect_layer')
	assert effects.len == 1
	assert content_bounds_clip(effects[0]) == LayoutRect{20, 10000, 50, 30}
}

fn test_effect_content_bounds_use_the_hosted_viewport_clip_for_overflowing_nested_content() {
	command := PaintCommand{
		kind: 'paint_nested_display_list'
		x: -1000
		y: -1000
		width: 9000
		height: 9000
		nested_viewport_paintable: &painting.NavigableContainerViewportPaintable{
			viewport_rect: painting.Rect{20, 10000, 50, 30}
			nested_rect: painting.Rect{-1000, -1000, 9000, 9000}
		}
	}
	assert content_bounds_clip(content_bounds_group([command])[0]) == LayoutRect{19, 9999, 52, 32}
	assert paint_leaf_is_outside_canvas(command, 0, 60, 800, 660)
	visible := PaintCommand{...command, transform: [f64(1), 0, 0, 1, 0, -10000]!}
	assert !paint_leaf_is_outside_canvas(visible, 0, 60, 800, 660)
	assert !paint_leaf_is_outside_canvas(PaintCommand{...command,
		nested_viewport_paintable: none}, 0, 60, 800, 660)
}
