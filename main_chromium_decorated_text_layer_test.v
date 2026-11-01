module main

import html
import layout
import math

fn test_promoted_text_keeps_solid_underlines_and_skip_ink_in_its_raster() {
	commands := [layout.PaintCommand{ kind: 'fill_rect' }, layout.PaintCommand{
		kind:             'fill_rect'
		antialiased_rect: true
		x:                12.25
		y:                28
		width:            80.5
		height:           1
		clip_outs:        [f64(24), 27, 29, 30]
	}, layout.PaintCommand{ kind: 'draw_text', text: 'gypq' }, layout.PaintCommand{ kind: 'fill_rect' }]
	mut plan := layout.ChromiumRasterLayerPlan{
		layers:         [layout.ChromiumRasterLayer{}, layout.ChromiumRasterLayer{
			command_indices:     [1, 2]
			composited_contents: true
		}]
		command_layers: [0, 1, 1, 0]
	}
	assert chromium_text_scroll_layer_supported(commands, plan, 1)
	for replacement in [layout.PaintCommand{ kind: 'fill_rect' },
		layout.PaintCommand{ kind: 'fill_rect', antialiased_rect: true, radius: 2 },
		layout.PaintCommand{ kind: 'fill_rect', antialiased_rect: true, blur: 1 },
		layout.PaintCommand{ kind: 'fill_rect', antialiased_rect: true, opacity: 0.5 },
		layout.PaintCommand{ kind: 'fill_rect', antialiased_rect: true, clip_outs: [f64(0)] },
		layout.PaintCommand{ kind: 'fill_rect', antialiased_rect: true, clip_outs: [
			f64(4),
			0,
			2,
			3,
		] },
		layout.PaintCommand{ kind: 'fill_rect', antialiased_rect: true, clip_outs: [
			math.inf(1),
			0,
			2,
			3,
		] }] {
		mut changed := commands.clone()
		changed[1] = replacement
		assert !chromium_text_scroll_layer_supported(changed, plan, 1)
	}
	mut no_text := commands.clone()
	no_text[2] = commands[1]
	assert !chromium_text_scroll_layer_supported(no_text, plan, 1)
}

fn test_fixed_decorated_text_is_eligible_without_a_synthetic_css_effect() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;font:12px/16px system-ui;color:#5d5d5d}
		p{position:fixed;left:20px;top:80.5px;width:250px;margin:0}
		a{text-decoration:underline;color:inherit}
	</style><p>Small text with <a>gypq and a link</a>.</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 400, 200)
	commands := layout.display_list_commands(document.record_display_list() or {
		panic('missing decorated text recording')
	})
	plan := layout.chromium_raster_layer_plan(document, commands, 1)
	mut decorations := 0
	mut glyphs := 0
	for index, command in commands {
		if command.kind != 'draw_text' && !command.antialiased_rect { continue }
		owner := plan.command_layers[index]
		assert owner > 0
		assert chromium_text_scroll_layer_supported(commands, plan, owner)
		assert !plan.layers[owner].command_indices.any(commands[it].kind == 'begin_css_effect_layer')
		if command.kind == 'draw_text' { glyphs++ } else { decorations++ }
	}
	assert glyphs >= 2
	assert decorations == 1
}
