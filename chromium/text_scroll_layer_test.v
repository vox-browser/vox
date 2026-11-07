module main

import layout
import html

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

fn test_promoted_text_isolation_accepts_fixed_and_sticky_layers_without_scrolling_contents() {
	commands := [layout.PaintCommand{kind:'fill_rect'},
		layout.PaintCommand{kind:'draw_text', text:'Tags'},
		layout.PaintCommand{kind:'draw_text', text:'Users'},
		layout.PaintCommand{kind:'fill_rect'}]
	mut plan := text_scroll_test_plan(false)
	assert !chromium_text_scroll_layer_supported(commands, plan, 1)
	plan.layers[1].composited_contents = true
	assert chromium_text_scroll_layer_supported(commands, plan, 1)
	for replacement in [layout.PaintCommand{kind:'begin_css_effect_layer'},
		layout.PaintCommand{kind:'end_css_effect_layer'},
		layout.PaintCommand{kind:'draw_svg_path'},
		layout.PaintCommand{kind:'draw_replaced_image'},
		layout.PaintCommand{kind:'draw_text', opacity:0.5},
		layout.PaintCommand{kind:'draw_text', clip_outs:[f64(0),0,10,10]}] {
		mut changed := commands.clone()
		changed[1] = replacement
		assert !chromium_text_scroll_layer_supported(changed, plan, 1)
	}
	plan.layers[1].legacy_raster = true
	assert !chromium_text_scroll_layer_supported(commands, plan, 1)
}

fn test_promoted_text_isolation_keeps_complete_contiguous_ownership() {
	commands := [layout.PaintCommand{kind:'fill_rect'},
		layout.PaintCommand{kind:'draw_text', text:'Tags'},
		layout.PaintCommand{kind:'draw_text', text:'Users'},
		layout.PaintCommand{kind:'fill_rect'}]
	for indices in [[1,3], [2,1], [-1,1], [1,4], []int{}] {
		mut plan := text_scroll_test_plan(false)
		plan.layers[1].composited_contents = true
		plan.layers[1].command_indices = indices
		assert !chromium_text_scroll_layer_supported(commands, plan, 1)
	}
	for owners in [[0,1,0,0], [1,1,1,0], [0,1,1,1], [0,1]] {
		mut plan := text_scroll_test_plan(false)
		plan.layers[1].composited_contents = true
		plan.command_layers = owners
		assert !chromium_text_scroll_layer_supported(commands, plan, 1)
	}
}

fn test_fixed_and_sticky_document_text_uses_its_promoted_raster() {
	for position in ['fixed','sticky','absolute'] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;min-height:2000px;font:13px/17px -apple-system,system-ui,sans-serif}
			section{position:${position};left:0;top:0;width:164px;height:600px}
			div{position:absolute;left:34px}#tags{top:186px}#users{top:396px}
		</style><section><div id="tags">Tags</div><div id="users">Users</div></section>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		commands := layout.display_list_commands(document.record_display_list() or {
			panic('missing text recording')
		})
		plan := layout.chromium_raster_layer_plan(document, commands, 1)
		mut seen := 0
		for index, command in commands {
			if command.kind != 'draw_text' || command.text !in ['Tags','Users'] { continue }
			seen++
			owner := plan.command_layers[index]
			if position == 'absolute' {
				assert owner == 0
			} else {
				assert owner > 0
				assert plan.layers[owner].composited_contents
				assert chromium_text_scroll_layer_supported(commands, plan, owner)
			}
		}
		assert seen == 2
	}
}
