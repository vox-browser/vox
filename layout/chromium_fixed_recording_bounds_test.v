module layout

import css
import html

fn test_fixed_recordings_snap_relative_to_unpainted_container_geometry() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}
		footer{position:fixed;left:200px;top:300px;width:600px;height:200px;transform:translateY(-100px)}
		.extent{position:fixed;left:100px;top:20px;width:800px;height:700px}
		.ink{position:absolute;left:40px;top:50px;width:80px;height:40px;background:rgb(1 2 3)}
	</style><footer><div class="ink"></div></footer><section class="extent"></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut extent := css.query_selector(document.as_node(), '.extent') or { panic('extent') }
	mut plan := ChromiumRasterLayerPlan{}
	for top in [-180, -40, -180] {
		extent.set_attribute_value('style', 'top:${top + 200}px')
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		for scale in [f64(1), 2] {
			update_chromium_raster_layer_plan(document, commands, scale, mut plan)
			mut seen := false
			for index, command in commands {
				if command.color != 'rgb(1 2 3)' { continue }
				layer := plan.layers[plan.command_layers[index]]
				assert layer.composited_contents
				assert layer.recorded_bounds == LayoutRect{240, 250, 80, 40}
				assert layer.bounds.x == 228
				assert layer.bounds.y == if top == -180 {
					if scale == 1 { 148.0 } else { 212.0 }
				} else {
					if scale == 1 { 160.0 } else { 224.0 }
				}
				assert layer.bounds.x + layer.bounds.width == 320
				assert layer.bounds.y + layer.bounds.height == 290
				seen = true
			}
			assert seen
		}
	}
}

fn test_fixed_recording_extents_exclude_siblings_and_nested_surfaces() {
	for contents in [
		'<section style="position:fixed;left:0;bottom:0;width:1000px;height:700px"></section>',
		'<aside style="will-change:transform;position:absolute;left:-100px;top:-180px;width:800px;height:700px"></aside>',
		'<aside style="overflow:auto;position:absolute;left:40px;top:50px;width:20px;height:20px"><div style="position:relative;left:-140px;top:-230px;width:800px;height:1000px"></div></aside>',
	] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0}footer{position:fixed;left:200px;top:200px;width:600px;height:200px}
			.ink{position:absolute;left:40px;top:50px;width:80px;height:40px;background:rgb(1 2 3)}
		</style><footer>${contents}<div class="ink"></div></footer>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('paint') })
		plan := chromium_raster_layer_plan(document, commands, 1)
		mut seen := false
		for index, command in commands {
			if command.color != 'rgb(1 2 3)' { continue }
			assert plan.layers[plan.command_layers[index]].bounds == LayoutRect{200, 200, 600, 200}
			seen = true
		}
		assert seen
	}
}

fn test_matching_fixed_anchors_share_hit_test_geometry_without_recording_it() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}
		footer{position:fixed;left:200px;top:200px;width:600px;height:200px}
		.ink{position:absolute;left:40px;top:50px;width:80px;height:40px;background:rgb(1 2 3)}
		section{position:fixed;left:100px;top:20px;width:800px;height:700px}
	</style><footer><div class="ink"></div></footer><section></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 768)
	commands := display_list_commands(document.record_display_list() or { panic('paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	assert !plan.has_paint_metadata
	mut seen := false
	for index, command in commands {
		if command.color != 'rgb(1 2 3)' { continue }
		layer := plan.layers[plan.command_layers[index]]
		assert layer.recorded_bounds == LayoutRect{240, 250, 80, 40}
		assert layer.bounds == LayoutRect{228, 148, 92, 142}
		seen = true
	}
	assert seen
}
