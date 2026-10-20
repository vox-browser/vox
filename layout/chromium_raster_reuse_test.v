module layout

import html
import platform

fn test_reused_raster_plan_restores_layers_after_root_fallback_without_allocating() {
	chunks := [
		ChromiumRasterChunk{ bounds: LayoutRect{ width: 300, height: 200 }, command_index: 0 },
		ChromiumRasterChunk{
			state:         ChromiumRasterPropertyState{ scroll_frame: 1 }
			bounds:        LayoutRect{ width: 100, height: 30 }
			command_index: 1
			command_end:   3
		},
	]
	mut plan := ChromiumRasterLayerPlan{}
	mut states := []ChromiumRasterPropertyState{}
	chromium_layerize_chunks_into(chunks, 3, 1, mut plan, mut states)
	layers := plan.layers.data
	commands := plan.command_layers.data
	indices := plan.layers[1].command_indices.data
	chromium_root_raster_plan_into(3, mut plan)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100 {
		chromium_layerize_chunks_into(chunks, 3, 1, mut plan, mut states)
		assert plan.layers.data == layers
		assert plan.command_layers.data == commands
		assert plan.layers.len == 2
		assert plan.layers[1].command_indices.data == indices
		assert plan.layers[1].command_indices.len == 2
		assert plan.layers[1].command_indices[0] == 1
		assert plan.layers[1].command_indices[1] == 2
		assert plan.command_layers[0] == 0
		assert plan.command_layers[2] == 1
		chromium_root_raster_plan_into(3, mut plan)
		assert plan.layers.len == 1
		assert plan.layers[0].command_indices.len == 3
		assert plan.command_layers[2] == 0
		assert plan.layers[0].bounds == LayoutRect{}
	}
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
}

fn test_document_raster_plan_reuses_output_and_working_storage() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroll{overflow:auto;width:100px;height:30px}#wide{width:400px;height:30px;background:red}#fixed{position:fixed;top:40px;width:20px;height:20px;background:blue}</style><div id="scroll"><div id="wide"></div></div><div id="fixed"></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	expected := chromium_raster_layer_plan(document, commands, 1)
	mut plan := ChromiumRasterLayerPlan{}
	for _ in 0 .. 3 { update_chromium_raster_layer_plan(document, commands, 1, mut plan) }
	assert plan.layers == expected.layers
	assert plan.command_layers == expected.command_layers
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100 { update_chromium_raster_layer_plan(document, commands, 1, mut plan) }
	$if prealloc {
		assert platform.thread_arena_usage().used == before
	}
	assert plan.layers == expected.layers
	assert plan.command_layers == expected.command_layers
}
