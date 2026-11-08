module main

import html
import layout

fn test_compositor_pictures_retain_curved_stroke_bounds_and_rounded_caps() {
	for geometry in ['M7 30Q15 2 38 20', 'M7 30C15 2 24 38 38 20',
		'M7 30L15 2L38 20Z', 'M7 30A18 12 0 0 1 38 20'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}div{width:50px;height:40px;background:#29374a;will-change:opacity}</style><div><svg width="50" height="40"><path d="${geometry}" stroke="white" fill="none" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		commands := layout.display_list_commands(document.record_display_list() or { panic('missing stroke paint') })
		plan := layout.chromium_raster_layer_plan(document, commands, 1)
		mut seen := false
		for index, command in commands {
			if command.kind != 'draw_svg_path' { continue }
			seen = true
			assert chromium_svg_compositor_path_supported(&command)
			assert !chromium_svg_solid_path_supported(&command)
			owner := plan.command_layers[index]
			assert owner > 0 && plan.layers[owner].composited_contents
			assert chromium_svg_compositor_layer_supported(commands, plan, owner)
		}
		assert seen
	}
}

fn test_curved_compositor_strokes_keep_dash_and_non_scaling_fallbacks() {
	for extra in ['stroke-dasharray="2 3"', 'vector-effect="non-scaling-stroke"'] {
		mut document := html.parse_document('<!doctype html><svg width="50" height="40"><path d="M7 30Q15 2 38 20" stroke="white" fill="none" stroke-width="1.2" stroke-linecap="round" ${extra}/></svg>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		commands := layout.display_list_commands(document.record_display_list() or { panic('missing fallback paint') })
		mut seen := false
		for command in commands {
			if command.kind != 'draw_svg_path' { continue }
			seen = true
			assert !chromium_svg_compositor_path_supported(&command)
		}
		assert seen
	}
}
