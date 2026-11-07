module main

import html
import layout
import math

fn leaf_compositor_test_commands() []layout.PaintCommand {
	return [layout.PaintCommand{ kind: 'fill_rect' }, layout.PaintCommand{
		kind:            'paint_outer_box_shadow'
		width:           160
		height:          80
		blur:            16
		box_shadow_data: &layout.PaintBoxShadowData{}
		has_clip:        true
		clip_width:      200
		clip_height:     100
	}, layout.PaintCommand{ kind: 'fill_rect', radius: 20, width: 160, height: 80 },
		layout.PaintCommand{ kind: 'draw_text', text: 'A rounded box' },
		layout.PaintCommand{ kind: 'fill_rect' }]
}

fn leaf_compositor_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			command_indices:     [1, 2, 3]
			composited_contents: true
		}]
		command_layers: [0, 1, 1, 1, 0]
	}
}

fn test_leaf_compositor_surface_accepts_clipped_shadow_background_and_text() {
	commands := leaf_compositor_test_commands()
	plan := leaf_compositor_test_plan()
	assert chromium_leaf_compositor_layer_supported(commands, plan, 1)
	assert !chromium_leaf_compositor_layer_supported(commands, plan, 0)
	assert !chromium_leaf_compositor_layer_supported(commands, plan, -1)
	assert !chromium_leaf_compositor_layer_supported(commands, plan, 2)
	for replacement in [layout.PaintCommand{ kind: 'paint_outer_box_shadow' },
		layout.PaintCommand{ kind: 'paint_outer_box_shadow', blur: -1, box_shadow_data: &layout.PaintBoxShadowData{} },
		layout.PaintCommand{ kind: 'fill_rect' }, layout.PaintCommand{ kind: 'draw_replaced_image' },
		layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ kind: 'draw_text', opacity: .5 },
		layout.PaintCommand{ kind: 'draw_text', group_opacity: .5 },
		layout.PaintCommand{ kind: 'draw_text', transform: [f64(1), 0, 0, 1, math.inf(1), 0]! },
		layout.PaintCommand{ kind: 'fill_rect', clip_outs: [f64(0), 0, -1, 10] }] {
		mut changed := commands.clone()
		changed[1] = replacement
		assert !chromium_leaf_compositor_layer_supported(changed, plan, 1)
	}
	mut gap := leaf_compositor_test_plan()
	gap.layers[1].command_indices = [1, 3]
	assert !chromium_leaf_compositor_layer_supported(commands, gap, 1)
	mut legacy := leaf_compositor_test_plan()
	legacy.layers[1].legacy_raster = true
	assert !chromium_leaf_compositor_layer_supported(commands, legacy, 1)
}

fn test_fixed_clipped_rounded_box_retains_the_leaf_compositor_surface() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;background:#fcfcfc}
		section{position:fixed;left:0;top:40px;width:400px;height:160px;overflow:hidden}
		article{margin:16px;width:360px;height:120px;box-sizing:border-box;background:white;
		border:1px solid #0000000d;border-radius:30px;box-shadow:0 4px 16px #0000000d}
	</style><section><article>A rounded box</article></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 400, 200)
	commands := layout.display_list_commands(document.record_display_list() or { panic('missing box recording') })
	plan := layout.chromium_raster_layer_plan(document, commands, 1)
	mut shadows := 0
	for index, command in commands {
		if command.kind != 'paint_outer_box_shadow' { continue }
		shadows++
		owner := plan.command_layers[index]
		assert owner > 0
		assert chromium_leaf_compositor_layer_supported(commands, plan, owner)
		assert !chromium_svg_compositor_layer_supported(commands, plan, owner)
	}
	assert shadows == 1
}
