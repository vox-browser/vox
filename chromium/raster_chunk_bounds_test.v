module main

import dom
import html
import layout
import os
import strings

fn test_raster_chunk_workers_preserve_layer_geometry_after_root_scroll() {
	mut source := strings.new_builder(4096)
	source.write_string('<!doctype html><style>
		body{margin:0;background:#eee}
		header{position:sticky;top:0;background:#444;color:white;height:30px}
		aside{position:fixed;top:40px;right:5px;width:80px;height:30px;background:green}
		main{overflow:hidden;width:500px}
		p{margin:0;height:11px;background:white;outline:1px solid #ddd;
			box-shadow:0 1px 2px #0008;transform:translateX(2px)}
		b{opacity:.8}
	</style><header>Sticky</header><aside>Fixed</aside><main>')
	for index in 0 .. 160 {
		source.write_string('<p>Row <b>${index}</b></p>')
	}
	source.write_string('</main>')
	mut document := html.parse_document(source.str())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout.layout_document_typed_in_viewport(document, 700, 600)
	document.set_viewport_rect(dom.Rect{y: 260, width: 700, height: 600})
	commands := layout.display_list_commands(document.record_display_list() or {
		panic('missing paint commands')
	})
	assert commands.len >= 256 && commands.len <= 4096
	viewport := layout.LayoutRect{0, 260, 700, 600}

	old_workers := os.getenv_opt('VOX_SERIAL_CPU_RASTER')
	defer {
		if value := old_workers {
			os.setenv('VOX_SERIAL_CPU_RASTER', value, true)
		} else {
			os.unsetenv('VOX_SERIAL_CPU_RASTER')
		}
	}
	os.setenv('VOX_SERIAL_CPU_RASTER', '1', true)
	mut serial_plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 2, viewport,
		mut serial_plan)
	assert serial_plan.layers.len > 1

	os.unsetenv('VOX_SERIAL_CPU_RASTER')
	mut worker_plan := layout.ChromiumRasterLayerPlan{}
	layout.update_chromium_raster_layer_plan_for_viewport(document, commands, 2, viewport,
		mut worker_plan)
	assert worker_plan.layers.len == serial_plan.layers.len
	assert worker_plan.command_layers == serial_plan.command_layers
	for index, layer in worker_plan.layers {
		expected := serial_plan.layers[index]
		assert layer.bounds == expected.bounds
		assert layer.compositor_origin == expected.compositor_origin
		assert layer.compositor_size == expected.compositor_size
		assert layer.command_indices == expected.command_indices
	}
}
