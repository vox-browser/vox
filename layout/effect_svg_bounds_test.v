module layout

import html
import math

fn effect_svg_fixture_command() PaintCommand {
	return PaintCommand{
		kind:     'draw_svg_path'
		color:    'red'
		svg_data: &PaintSVGPathData{
			path_data: [f32(0), 10, 20, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 30, 20, 0, 0, 0, 0, 0, 0,
				0, 0, 0, 1, 30, 40, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 10, 40, 0, 0, 0, 0, 0, 0, 0,
				0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	}
}

fn test_solid_svg_effect_bounds_include_serialized_geometry_and_both_transforms() {
	command := effect_svg_fixture_command()
	assert effect_svg_fill_ink_bounds(&command)? == LayoutRect{9, 19, 22, 22}
	data := command.svg_data
	transformed := PaintCommand{
		...command
		transform: [f64(0), 2, -3, 0, 500, 7]!
		svg_data:  &PaintSVGPathData{ ...*data, path_transform: [f64(2), 0, 0, 0.5, 3, 4]! }
	}
	assert effect_svg_fill_ink_bounds(&transformed)? == LayoutRect{427, 52, 32, 82}
	mut commands := [PaintCommand{ kind: 'begin_css_effect_layer' }, command,
		PaintCommand{ kind: 'end_css_effect_layer' }]
	bound_visual_effect_contents(mut commands)
	assert commands[0].has_clip == !retain_unbounded_svg_effects
	if !retain_unbounded_svg_effects {
		assert commands[0].clip_width == 22 && commands[0].clip_height == 22
	}
}

fn test_solid_svg_effect_bounds_enclose_bezier_controls_and_arcs() {
	base := effect_svg_fixture_command()
	curve := PaintCommand{
		...base
		svg_data: &PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 20, 20, -10, 100, 80, -20,
				0, 0, 0, 0, 0]
		}
	}
	assert effect_svg_fill_ink_bounds(&curve)? == LayoutRect{-11, -21, 92, 122}
	arc := PaintCommand{
		...base
		svg_data: &PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 40, 0, 0, 0, 0, 0, 20, 10,
				0, 0, 1]
		}
	}
	bounds := effect_svg_fill_ink_bounds(&arc)?
	assert bounds.x <= -1 && bounds.x + bounds.width >= 41
	assert bounds.y <= -10.999 && bounds.y + bounds.height >= 1
}

fn test_solid_svg_effect_bounds_retain_unknown_strokes_payloads_and_precision_loss() {
	base := effect_svg_fixture_command()
	for command in [PaintCommand{ ...base, color: '' },
		PaintCommand{ ...base, stroke_color: 'blue', stroke_width: 1 },
		PaintCommand{ ...base, outer_shadow: true }, PaintCommand{ ...base, blur: 2 },
		PaintCommand{ ...base, svg_data: unsafe { nil } },
		PaintCommand{ ...base, svg_data: &PaintSVGPathData{ path_data: [f32(0), 1] } }, PaintCommand{
			...base
			svg_data: &PaintSVGPathData{
				path_data: [f32(0), math.nan(), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
			}
		}, PaintCommand{ ...base, transform: [f64(1), 0, 0, 1, 2_000_000, 0]! }] {
		assert effect_svg_fill_ink_bounds(&command) == none
	}
}

fn test_recorded_svg_effect_bounds_follow_geometry_mutation_and_preserve_old_recording() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><svg width="100" height="100" style="opacity:.5"><path id="shape" d="M10 20H30V40H10Z" fill="red"/></svg>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 200, 200)
	first := display_list_commands(document.record_display_list() or { panic('missing paint') })
	effects := first.filter(it.kind == 'begin_css_effect_layer')
	assert effects.len > 0
	if retain_unbounded_svg_effects { return }
	assert effects[0].has_clip && effects[0].clip_width < 100
	width := effects[0].clip_width
	mut path := document.get_element_by_id('shape')?
	path.set_attribute_value('d', 'M10 20H60V40H10Z')
	document.update_layout(.debugging)
	second := display_list_commands(document.record_display_list() or { panic('missing updated paint') })
	updated := second.filter(it.kind == 'begin_css_effect_layer')
	assert updated.len > 0 && updated[0].has_clip
	assert updated[0].clip_width > width
	assert effects[0].clip_width == width
}
