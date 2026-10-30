module main

import html
import layout

fn svg_compositor_test_path() layout.PaintCommand {
	return layout.PaintCommand{
		kind:     'draw_svg_path'
		color:    '#3b4045'
		svg_data: &layout.PaintSVGPathData{
			path_data: [f32(0), 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		}
	}
}

fn svg_compositor_test_plan() layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			composited_contents: true
			command_indices:     [1, 2, 3]
		}]
		command_layers: [0, 1, 1, 1, 0]
	}
}

fn test_svg_compositor_isolation_keeps_its_background_and_text_together() {
	commands := [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'fill_rect', color: 'white' }, svg_compositor_test_path(),
		layout.PaintCommand{ kind: 'draw_text', text: 'Home' },
		layout.PaintCommand{ kind: 'fill_rect' }]
	plan := svg_compositor_test_plan()
	assert chromium_svg_compositor_layer_supported(commands, plan, 1)
	for index in [-1, 0, 2] {
		assert !chromium_svg_compositor_layer_supported(commands, plan, index)
	}
	mut ordinary := svg_compositor_test_plan()
	ordinary.layers[1].composited_contents = false
	assert !chromium_svg_compositor_layer_supported(commands, ordinary, 1)
	ordinary.layers[1].composited_contents = true
	ordinary.layers[1].legacy_raster = true
	assert !chromium_svg_compositor_layer_supported(commands, ordinary, 1)
}

fn test_svg_compositor_isolation_rejects_effects_resources_and_missing_vectors() {
	base := [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'fill_rect', color: 'white' }, svg_compositor_test_path(),
		layout.PaintCommand{ kind: 'draw_text', text: 'Home' },
		layout.PaintCommand{ kind: 'fill_rect' }]
	plan := svg_compositor_test_plan()
	for replacement in [layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ kind: 'end_css_effect_layer' },
		layout.PaintCommand{ kind: 'draw_replaced_image' },
		layout.PaintCommand{ kind: 'paint_nested_display_list' },
		layout.PaintCommand{ kind: 'draw_svg_path' },
		layout.PaintCommand{ kind: 'draw_text', text: 'No SVG' },
		layout.PaintCommand{ ...base[2], opacity: .5 },
		layout.PaintCommand{ ...base[2], group_opacity: .5 },
		layout.PaintCommand{ ...base[2], blur: 1 },
		layout.PaintCommand{ ...base[2], clip_outs: [f64(0), 0, 10, 10] },
		layout.PaintCommand{ ...base[2], scrollbar_axis: 'vertical' }] {
		mut changed := base.clone()
		changed[2] = replacement
		assert !chromium_svg_compositor_layer_supported(changed, plan, 1)
	}
}

fn test_svg_compositor_isolation_rejects_incomplete_or_noncontiguous_ownership() {
	commands := [layout.PaintCommand{ kind: 'fill_rect' }, svg_compositor_test_path(),
		svg_compositor_test_path(), svg_compositor_test_path(),
		layout.PaintCommand{ kind: 'fill_rect' }]
	for indices in [[1, 3], [2, 1, 3], [-1, 1, 2], [1, 2, 5]] {
		mut changed := svg_compositor_test_plan()
		changed.layers[1].command_indices = indices
		assert !chromium_svg_compositor_layer_supported(commands, changed, 1)
	}
	for owners in [[0, 1, 0, 1, 0], [1, 1, 1, 1, 0], [0, 1, 1, 1, 1], [0, 1]] {
		mut changed := svg_compositor_test_plan()
		changed.command_layers = owners
		assert !chromium_svg_compositor_layer_supported(commands, changed, 1)
	}
}

fn test_fixed_svg_layer_plan_retains_its_compositor_identity_with_a_background() {
	for background in ['transparent', '#f3f5f7'] {
		mut document := html.parse_document('<!doctype html><style>
			body {margin:0;background:white}
			div {position:fixed;left:24px;top:24px;width:200px;height:40px;
				background:${background};color:#3b4045;font:13px Arial}
			svg {fill:currentColor}
		</style><div><svg width="18" height="18"><path d="M0 0L18 18H0Z"/></svg>Home</div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 300, 200)
		commands := layout.display_list_commands(document.record_display_list() or {
			panic('missing recorded paint')
		})
		plan := layout.chromium_raster_layer_plan(document, commands, 1)
		mut svg_layer := -1
		for index, command in commands {
			if command.kind == 'draw_svg_path' { svg_layer = plan.command_layers[index] }
		}
		assert svg_layer > 0
		assert plan.layers[svg_layer].composited_contents
		assert chromium_svg_compositor_layer_supported(commands, plan, svg_layer)
	}
}
