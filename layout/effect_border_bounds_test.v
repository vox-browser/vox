module layout

import dom
import html
import math

fn effect_border_fixture_command() PaintCommand {
	return PaintCommand{
		kind:         'paint_uniform_border'
		x:            20
		y:            30
		width:        80
		height:       50
		stroke_width: 3
		color:        'red'
		opacity:      0.5
	}
}

fn effect_border_group(children []PaintCommand) []PaintCommand {
	mut commands := [PaintCommand{ kind: 'begin_css_effect_layer' }]
	commands << children
	commands << PaintCommand{ kind: 'end_css_effect_layer' }
	bound_visual_effect_contents(mut commands)
	return commands
}

fn test_uniform_border_effect_bounds_enclose_native_and_portable_strokes() {
	border := effect_border_fixture_command()
	for width in [f64(0), 0.25, 3, 100] {
		command := PaintCommand{ ...border, stroke_width: width }
		bounds := effect_uniform_border_ink_bounds(&command)?
		assert bounds == LayoutRect{20 - width - 1, 30 - width - 1, 80 + 2 * (width + 1), 50 + 2 * (width + 1)}
	}
	commands := effect_border_group([border])
	assert commands.len == 3
	assert commands[1].x == border.x && commands[1].stroke_width == border.stroke_width
	assert commands[0].has_clip == !retain_unbounded_border_effects
	if !retain_unbounded_border_effects {
		assert commands[0].clip_x == 16 && commands[0].clip_y == 26
		assert commands[0].clip_width == 88 && commands[0].clip_height == 58
	}
}

fn test_uniform_border_effect_bounds_map_rotation_scale_and_fractional_positions() {
	border := effect_border_fixture_command()
	command := PaintCommand{ ...border, transform: [f64(0), 2, -3, 0, 500, 7]! }
	assert effect_uniform_border_ink_bounds(&command)? == LayoutRect{248, 39, 174, 176}
	fractional := PaintCommand{
		...border
		x:            0.125
		y:            0.375
		stroke_width: 0.5
		transform:    [f64(1.25), 0, 0, 0.75, 0.25, 0.5]!
	}
	assert effect_uniform_border_ink_bounds(&fractional)? == LayoutRect{-1.46875, -0.71875, 103.75, 40.5}
	shrunk := PaintCommand{ ...border, transform: [f64(0.01), 0, 0, 0.01, 0, 0]! }
	assert effect_uniform_border_ink_bounds(&shrunk)? == LayoutRect{-3.8, -3.7, 8.8, 8.5}
	collapsed := PaintCommand{ ...border, transform: [f64(0), 0, 0, 0, 50, 50]! }
	assert effect_uniform_border_ink_bounds(&collapsed)? == LayoutRect{46, 46, 8, 8}
}

fn test_uniform_border_effect_bounds_reject_unknown_ink_and_native_precision_loss() {
	border := effect_border_fixture_command()
	for command in [PaintCommand{ ...border, outer_shadow: true }, PaintCommand{ ...border, blur: 2 },
		PaintCommand{ ...border, stroke_width: -1 },
		PaintCommand{ ...border, stroke_width: math.nan() }, PaintCommand{ ...border, width: 0 },
		PaintCommand{ ...border, height: -1 }, PaintCommand{ ...border, width: math.inf(1) },
		PaintCommand{ ...border, x: math.nan() }, PaintCommand{ ...border, x: 2_000_000 },
		PaintCommand{ ...border, transform: [f64(1), 0, 0, 1, -2_000_000, 0]! },
		PaintCommand{ ...border, transform: [f64(1), math.nan(), 0, 1, 0, 0]! },
		PaintCommand{ ...border, corner_radii: BoxRadii{ top_left: CornerRadius{ x: 81, y: 1 } } }] {
		assert effect_uniform_border_ink_bounds(&command) == none
	}
	for kind in ['draw_svg_path', 'paint_partial_rounded_border', 'paint_outer_box_shadow',
		'future_operation'] {
		command := PaintCommand{ ...border, kind: kind }
		assert effect_content_leaf_ink_bounds(&command) == none
	}
}

fn test_uniform_border_effect_bounds_preserve_nested_unknown_scopes_and_ancestor_clip() {
	border := effect_border_fixture_command()
	mut commands := [PaintCommand{
		kind:        'begin_css_effect_layer'
		has_clip:    true
		clip_x:      10
		clip_y:      15
		clip_width:  500
		clip_height: 600
	}, PaintCommand{ kind: 'begin_css_effect_layer' }, border,
		PaintCommand{ kind: 'end_css_effect_layer' }, PaintCommand{ kind: 'future_operation' },
		PaintCommand{ kind: 'end_css_effect_layer' }]
	bound_visual_effect_contents(mut commands)
	assert commands[0].clip_width == 500 && commands[0].clip_height == 600
	assert commands[1].has_clip == !retain_unbounded_border_effects
	mut clipped := [PaintCommand{
		kind:        'begin_css_effect_layer'
		has_clip:    true
		clip_x:      30
		clip_y:      40
		clip_width:  10
		clip_height: 15
	}, border, PaintCommand{ kind: 'end_css_effect_layer' }]
	bound_visual_effect_contents(mut clipped)
	assert clipped[0].clip_x == 30 && clipped[0].clip_y == 40
	assert clipped[0].clip_width == 10 && clipped[0].clip_height == 15
}

fn test_recorded_uniform_border_opacity_bounds_follow_scroll_without_mutating_old_commands() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#border{position:absolute;left:30px;top:400px;width:80px;height:50px;border:3px solid red;border-radius:12px;opacity:.5}#overflow{height:900px}</style><div id="border"></div><div id="overflow"></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 320, 200)
	first := display_list_commands(document.record_display_list() or { panic('missing paint') })
	initial := first.filter(it.kind == 'begin_css_effect_layer')
	assert initial.len == 1
	assert first.any(it.kind == 'paint_uniform_border')
	assert initial[0].has_clip == !retain_unbounded_border_effects
	if retain_unbounded_border_effects { return }
	before_y := initial[0].clip_y
	width := initial[0].clip_width
	assert width > 0 && width < 100
	document.set_viewport_rect(dom.Rect{0, 300, 320, 200})
	second := display_list_commands(document.record_display_list() or { panic('missing scroll paint') })
	scrolled := second.filter(it.kind == 'begin_css_effect_layer')
	assert scrolled.len == 1 && scrolled[0].has_clip
	assert scrolled[0].clip_y == before_y - 300
	assert scrolled[0].clip_width == width
	assert initial[0].clip_y == before_y
}
