module layout

import html

fn test_fixed_hit_test_bounds_belong_to_the_layer_that_accepted_the_metadata() {
	for density in [f64(1), 2] {
		mut document := html.parse_document('<!doctype html><style>
			*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%}
			footer{position:fixed;left:260px;top:50%;width:764px;height:204px;transform:translateY(-102px)}
			.ink{position:absolute;left:12px;top:20px;width:740px;height:40px;background:rgb(3 2 1)}
			section{position:fixed;left:260px;right:0;top:61px;bottom:40.453125px;display:grid;align-items:end}
			.clip{overflow:auto}.dialog{padding-top:16px}
			.card{height:126px;margin:0 12px;border:1px solid #0000000d;border-radius:30px;
				box-shadow:0 4px 16px #0000000d;background:rgb(1 2 3)}
		</style><footer><div class="ink"></div></footer><section><div class="clip"><div class="dialog"><div class="card"></div></div></div></section>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		document.set_display_device_pixel_ratio(density)
		document.set_layout_coordinate_scale(density)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		for culled in [false, true] {
			mut plan := ChromiumRasterLayerPlan{}
			if culled {
				update_chromium_raster_layer_plan_for_viewport(document, commands, density,
					LayoutRect{0, 0, 1024, 768}, mut plan)
			} else {
				update_chromium_raster_layer_plan(document, commands, density, mut plan)
			}
			mut found := false
			for index, command in commands {
				if command.kind != 'paint_outer_box_shadow' { continue }
				found = true
				owner := plan.command_layers[index]
				assert owner > 0
				bounds := plan.layers[owner].bounds
				// The earlier footer accepted the empty fixed wrapper's hit-test
				// bounds. This later clipped paint owns only the visible panel.
				assert bounds.y >= 585 && bounds.y <= 587, 'density=${density}, culled=${culled}, y=${bounds.y}, height=${bounds.height}'
				assert bounds.x == 260 && bounds.width == 764
				assert bounds.height >= 142 && bounds.height <= 143
			}
			assert found
		}
	}
}
