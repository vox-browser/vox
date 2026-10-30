module layout

import css
import html
import os

fn test_partial_sticky_rasters_use_the_container_origin_and_refresh_after_resizing() {
	mut document := html.parse_document(os.read_file('${@VMODROOT}/../Tests/Browser/Brave/input/stackoverflow-sticky-raster-bounds.html') or { panic(err) })
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut sidebar := css.query_selector(document.as_node(), '.sidebar') or { panic('missing sidebar') }
	mut plan := ChromiumRasterLayerPlan{}
	for height in [f64(2560.65625), 700, 2560.65625] {
		sidebar.set_attribute_value('style', 'height:${height}px')
		_ = layout_document_typed_in_viewport(document, 1024, 768)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		for scale in [f64(1), 2] {
			update_chromium_raster_layer_plan(document, commands, scale, mut plan)
			mut borders := 0
			for index, command in commands {
				if command.kind != 'paint_uniform_border' { continue }
				borders++
				owner := plan.command_layers[index]
				assert owner > 0
				assert plan.layers[owner].composited_contents
				bounds := plan.layers[owner].bounds
				assert bounds.x == 700 && bounds.y == 336
				assert bounds.width == 300
				assert bounds.height == if height == 700 { 444.0 } else { 405.0 }
			}
			assert borders == 1
		}
	}
}

fn test_partial_recordings_snap_in_device_texels_and_keep_exact_edge_thresholds() {
	layer := LayoutRect{x:40, y:50, width:600, height:600}
	ink := LayoutRect{x:120, y:250, width:20, height:40}
	assert chromium_recorded_tiling_rect(layer, ink, 1) == LayoutRect{x:40, y:178, width:100, height:112}
	assert chromium_recorded_tiling_rect(layer, ink, 2) == LayoutRect{x:104, y:242, width:36, height:48}
	for gap in [f64(127), 128, 129] {
		bounds := chromium_recorded_tiling_rect(layer,
			LayoutRect{x:40, y:50, width:600-gap, height:600-gap}, 1)
		assert bounds.width == if gap < 128 { 600.0 } else { 600-gap }
		assert bounds.height == bounds.width
	}
}

fn test_sticky_raster_keeps_descendant_overflow_outside_the_container() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0;min-height:2000px}
		section{position:sticky;top:0;margin:40px;width:200px;height:100px}
		span{position:absolute;left:-10px;top:-15px;width:240px;height:140px;background:rgb(1 2 3)}
	</style><section><span></span></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut seen := false
	for index, command in commands {
		if command.color != 'rgb(1 2 3)' { continue }
		seen = true
		owner := plan.command_layers[index]
		assert owner > 0 && plan.layers[owner].composited_contents
		bounds := plan.layers[owner].bounds
		assert bounds.x == 30 && bounds.y == 25
		assert bounds.width == 240 && bounds.height == 140
	}
	assert seen
}

fn test_nested_compositor_and_scroll_surfaces_keep_their_own_sticky_descendant_bounds() {
	for contents in [
		'<aside style="will-change:transform;background:rgb(1 2 3)"></aside>',
		'<aside style="overflow:auto"><span style="display:block;width:200px;height:20px;background:rgb(1 2 3)"></span></aside>',
	] {
		mut document := html.parse_document('<!doctype html><style>
			body{margin:0;min-height:2000px}
			section{position:sticky;top:0;margin:40px;width:200px;height:100px}
			aside{position:absolute;left:50px;top:60px;width:40px;height:20px}
		</style><section>${contents}</section>')
		defer { document.finalize() }
		document.set_font_rendering_policy(.chromium)
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		plan := chromium_raster_layer_plan(document, commands, 1)
		mut seen := false
		for index, command in commands {
			if command.color != 'rgb(1 2 3)' { continue }
			seen = true
			owner := plan.command_layers[index]
			assert owner > 0 && plan.layers[owner].composited_contents
			bounds := plan.layers[owner].bounds
			assert bounds.x == 90 && bounds.y == 100
			assert bounds.height == 20
		}
		assert seen
	}
}

fn test_sticky_container_inside_a_composited_scroller_keeps_its_complete_extent() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}#scroller{overflow:auto;width:300px;height:300px}
		section{position:sticky;top:0;margin:40px;width:200px;height:100px}
		span{position:absolute;left:50px;top:60px;width:40px;height:20px;background:rgb(1 2 3)}
		#spacer{height:2000px}
	</style><div id="scroller"><section><span></span></section><div id="spacer"></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut seen := false
	for index, command in commands {
		if command.color != 'rgb(1 2 3)' { continue }
		seen = true
		owner := plan.command_layers[index]
		assert owner > 0 && plan.layers[owner].composited_contents
		bounds := plan.layers[owner].bounds
		assert bounds.x == 40 && bounds.y == 40
		assert bounds.width == 200 && bounds.height == 100
	}
	assert seen
}
