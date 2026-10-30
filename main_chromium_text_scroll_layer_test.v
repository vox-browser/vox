module main

import layout

fn text_scroll_test_plan(scrolling bool) layout.ChromiumRasterLayerPlan {
	return layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			command_indices: [1, 2]
			scroll_contents: scrolling
		}]
		command_layers: [0, 1, 1, 0]
	}
}

fn test_text_scroll_isolation_requires_contiguous_scrolling_text() {
	commands := [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'draw_text', text: 'Hello' },
		layout.PaintCommand{ kind: 'draw_text', text: 'world' },
		layout.PaintCommand{ kind: 'fill_rect' }]
	plan := text_scroll_test_plan(true)
	assert chromium_text_scroll_layer_supported(commands, plan, 1)
	assert !chromium_text_scroll_layer_supported(commands, text_scroll_test_plan(false), 1)
	assert !chromium_text_scroll_layer_supported(commands, plan, 0)
	assert !chromium_text_scroll_layer_supported(commands, plan, -1)
	assert !chromium_text_scroll_layer_supported(commands, plan, 2)
	for replacement in [layout.PaintCommand{ kind: 'begin_css_effect_layer' },
		layout.PaintCommand{ kind: 'draw_replaced_image' }, layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'draw_text', opacity: .5 },
		layout.PaintCommand{ kind: 'draw_text', group_opacity: .5 },
		layout.PaintCommand{ kind: 'draw_text', blur: 1 },
		layout.PaintCommand{ kind: 'draw_text', scrollbar_axis: 'vertical' }] {
		mut changed := commands.clone()
		changed[1] = replacement
		assert !chromium_text_scroll_layer_supported(changed, plan, 1)
	}
	mut legacy := text_scroll_test_plan(true)
	legacy.layers[1].legacy_raster = true
	assert !chromium_text_scroll_layer_supported(commands, legacy, 1)
	mut gap := text_scroll_test_plan(true)
	gap.layers[1].command_indices = [1, 3]
	assert !chromium_text_scroll_layer_supported(commands, gap, 1)
	mut order := text_scroll_test_plan(true)
	order.layers[1].command_indices = [2, 1]
	assert !chromium_text_scroll_layer_supported(commands, order, 1)
}
