module main

import layout

fn test_fixed_opacity_scope_borrows_only_its_proved_immediate_parent_grid() {
	mut commands := opaque_effect_gap_commands()
	for mut command in commands { command.fixed_to_viewport = true }
	mut plan := opaque_effect_gap_plan()
	plan.layers[2].has_fixed_opacity_paint_origin = true
	assert chromium_opacity_raster_parent(commands, plan, 2) == 1
	assert chromium_opacity_raster_parent(commands, plan, 0) == 0
	assert chromium_opacity_raster_parent(commands, plan, 1) == 1
	assert chromium_opacity_raster_parent(commands, plan, -1) == -1
	assert chromium_opacity_raster_parent(commands, plan, 3) == 3
	mut storage := ChromiumMSAAStorage{}
	storage.update(commands, plan, 800, 600, 0, 2)
	assert storage.raster_parents[..3] == [0, 1, 1]
	plan.layers[2].has_fixed_opacity_paint_origin = false
	storage.update(commands, plan, 800, 600, 0, 2)
	assert storage.raster_parents[..3] == [0, 1, 2]
	plan.layers[2].has_fixed_opacity_paint_origin = true
	plan.layers[1].composited_contents = false
	assert chromium_opacity_raster_parent(commands, plan, 2) == 2
	plan.layers[1].composited_contents = true
	plan.command_layers[5] = 0
	assert chromium_opacity_raster_parent(commands, plan, 2) == 2
	plan.command_layers[5] = 1
	commands[0].color = '#fffffffe'
	assert chromium_opacity_raster_parent(commands, plan, 2) == 2
}

fn opaque_effect_gap_commands() []layout.PaintCommand {
	effect := &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 71, opacity: .5 }
	return [
		layout.PaintCommand{ kind: 'fill_rect', width: 300, height: 120, radius: 24, color: 'white' },
		layout.PaintCommand{ kind: 'begin_css_effect_layer', visual_layer_data: effect },
		layout.PaintCommand{
			kind:          'fill_rect'
			x:             200
			y:             40
			width:         32
			height:        32
			radius:        16
			color:         '#3566f0'
			opacity:       .5
			group_opacity: .5
		},
		layout.PaintCommand{
			kind:          'paint_uniform_border'
			x:             200.5
			y:             40.5
			width:         31
			height:        31
			stroke_width:  1
			color:         '#3566f0'
			opacity:       .5
			group_opacity: .5
			corner_radii:  layout.BoxRadii{
				top_left:     layout.CornerRadius{15.5, 15.5}
				top_right:    layout.CornerRadius{15.5, 15.5}
				bottom_right: layout.CornerRadius{15.5, 15.5}
				bottom_left:  layout.CornerRadius{15.5, 15.5}
			}
		},
		layout.PaintCommand{ kind: 'end_css_effect_layer', visual_layer_data: effect },
		layout.PaintCommand{ kind: 'fill_rect', x: 28, y: 48, width: 16, height: 4, color: '#0d0d0d' },
	]
}

fn opaque_effect_gap_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [
				0,
				5,
			]
		}, layout.ChromiumRasterLayer{
			legacy_raster:   true
			command_indices: [
				1,
				2,
				3,
				4,
			]
		}]
		command_layers: [1, 2, 2, 2, 2, 1]
	}
}

fn test_opaque_rounded_prefix_resumes_across_a_disjoint_normal_opacity_scope() {
	commands := opaque_effect_gap_commands()
	plan := opaque_effect_gap_plan()
	assert chromium_opaque_compositor_effect_gap(commands, plan, 1, 1, 5)
	assert chromium_compositor_opaque_effect_resume(commands, plan, 1, 5)
	assert !chromium_compositor_opaque_effect_resume(commands, plan, 1, 0)
	assert !chromium_compositor_opaque_effect_resume(commands, plan, 2, 5)
	assert chromium_compositor_gap_can_flush_parent(commands, plan, 1, 1, 5,
		layout.LayoutRect{0, 0, 800, 600})
	assert !chromium_compositor_gap_can_flush_parent(commands, plan, 1, 1, 5,
		layout.LayoutRect{})
}

fn test_opacity_continuation_requires_opaque_covered_and_disjoint_parent_ink() {
	commands := opaque_effect_gap_commands()
	plan := opaque_effect_gap_plan()
	for changed in [
		layout.PaintCommand{ ...commands[0], color: '#fffffffe' },
		layout.PaintCommand{ ...commands[0], opacity: .5 },
		layout.PaintCommand{ ...commands[0], radius: 120 },
		layout.PaintCommand{ ...commands[0], has_clip: true, clip_width: 20, clip_height: 20 },
		layout.PaintCommand{ ...commands[0], transform: [f64(1), 0, .1, 1, 0, 0]! },
	] {
		mut input := commands.clone()
		input[0] = changed
		assert !chromium_opaque_compositor_effect_gap(input, plan, 1, 1, 5)
	}
	for changed in [
		layout.PaintCommand{ ...commands[5], x: 198 },
		layout.PaintCommand{ ...commands[5], x: 0, y: 0 },
		layout.PaintCommand{ ...commands[5], fixed_to_viewport: true },
		layout.PaintCommand{ kind: 'draw_text', text: 'unbounded' },
	] {
		mut input := commands.clone()
		input[5] = changed
		assert !chromium_opaque_compositor_effect_gap(input, plan, 1, 1, 5)
	}
}

fn test_opacity_continuation_rejects_incomplete_or_independent_child_surfaces() {
	commands := opaque_effect_gap_commands()
	plan := opaque_effect_gap_plan()
	for changed in [
		layout.PaintCommand{
			kind:              'end_css_effect_layer'
			visual_layer_data: &layout.PaintVisualLayer{ kind: .css_effect, scope_id: 72, opacity: .5 }
		},
		layout.PaintCommand{ kind: 'end_svg_mask_layer', visual_layer_data: commands[4].visual_layer_data },
	] {
		mut input := commands.clone()
		input[4] = changed
		assert !chromium_opaque_compositor_effect_gap(input, plan, 1, 1, 5)
	}
	mut foreign := opaque_effect_gap_plan()
	foreign.command_layers[2] = 0
	assert !chromium_opaque_compositor_effect_gap(commands, foreign, 1, 1, 5)
	mut independent := opaque_effect_gap_plan()
	independent.layers[2].legacy_raster = false
	assert !chromium_opaque_compositor_effect_gap(commands, independent, 1, 1, 5)
}

fn test_opaque_coverage_checks_rounded_corners_after_their_transform() {
	identity := [f64(1), 0, 0, 1, 0, 0]!
	r := layout.CornerRadius{20, 20}
	radii := layout.BoxRadii{r, r, r, r}
	assert chromium_opaque_round_rect_contains(layout.LayoutRect{0, 0, 100, 80}, radii,
		identity, layout.LayoutRect{10, 10, 80, 60})
	assert !chromium_opaque_round_rect_contains(layout.LayoutRect{0, 0, 100, 80}, radii,
		identity, layout.LayoutRect{0, 0, 10, 10})
	assert chromium_opaque_round_rect_contains(layout.LayoutRect{0, 0, 100, 80}, radii,
		[f64(2), 0, 0, 2, 30, 40]!, layout.LayoutRect{50, 60, 160, 120})
}

fn test_opacity_continuation_bounds_clipped_svg_geometry_without_scalar_batch_eligibility() {
	mut commands := opaque_effect_gap_commands()
	commands[3] = layout.PaintCommand{
		kind:           'draw_svg_path'
		color:          'white'
		opacity:        .5
		group_opacity:  .5
		recording_clip: layout.LayoutRect{190, 30, 60, 60}
		svg_data:       &layout.PaintSVGPathData{
			path_transform: [f64(1), 0, 0, 1, 200, 40]!
			path_data:      [f32(0), 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 15, 1, 0, 0, 0, 0, 0,
				0, 0, 0, 0, 1, 15, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, 0, 0, 0, 0,
				0, 0]
		}
	}
	assert chromium_opaque_compositor_effect_gap(commands, opaque_effect_gap_plan(), 1, 1, 5)
	commands[3] = layout.PaintCommand{
		...commands[3]
		color:        ''
		stroke_color: 'red'
		stroke_width: 1
		svg_data:     &layout.PaintSVGPathData{ ...*commands[3].svg_data, non_scaling_stroke: true }
	}
	assert !chromium_opaque_compositor_effect_gap(commands, opaque_effect_gap_plan(), 1, 1, 5)
}

fn test_empty_text_and_transparent_borders_do_not_expand_opaque_continuation_ink() {
	mut commands := opaque_effect_gap_commands()
	commands << layout.PaintCommand{ kind: 'draw_text' }
	commands << layout.PaintCommand{
		kind:         'paint_uniform_border'
		width:        3000
		height:       3000
		stroke_width: 1
		color:        'transparent'
	}
	mut plan := opaque_effect_gap_plan()
	plan.layers[1].command_indices << [6, 7]
	plan.command_layers << [1, 1]
	assert chromium_opaque_compositor_effect_gap(commands, plan, 1, 1, 5)
}
