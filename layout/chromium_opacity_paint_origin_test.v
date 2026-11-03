module layout

import html

fn test_fixed_opacity_paint_origin_is_css_space_and_clears_on_plan_reuse() {
	mut plan := ChromiumRasterLayerPlan{}
	for density in [f64(1), 2] {
		for fixed in [true, false, true] {
			position := if fixed { 'fixed' } else { 'absolute' }
			mut document := html.parse_document('<!doctype html><style>body{margin:0}
				#owner{position:${position};left:10px;top:170px;width:360px;height:90px;background:white}
				#child{position:absolute;left:280px;top:20px;width:32px;height:32px;
					border:1px solid blue;border-radius:50%;background:blue;opacity:.5}
				</style><div id="owner"><div id="child"></div></div>')
			document.set_font_rendering_policy(.chromium)
			document.set_display_device_pixel_ratio(density)
			document.set_layout_coordinate_scale(density)
			_ = layout_document_typed_in_viewport(document, 400, 300)
			commands := display_list_commands(document.record_display_list() or { panic('paint') })
			update_chromium_raster_layer_plan(document, commands, density, mut plan)
			mut found := 0
			for layer in plan.layers {
				if !layer.has_fixed_opacity_paint_origin { continue }
				found++
				assert layer.legacy_raster
				assert layer.fixed_opacity_paint_origin_x == 10
				assert layer.fixed_opacity_paint_origin_y == 170
			}
			assert (found > 0) == fixed, 'density=${density}, fixed=${fixed}, origins=${found}'
			document.finalize()
		}
	}
}
