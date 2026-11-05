module layout

import html
import painting

fn test_unused_perspective_keeps_independent_scroll_raster_layers() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#empty{perspective:1000px;width:10px;height:10px;background:rgb(4 5 6)}#scroll{width:100px;height:30px;overflow:auto}#wide{width:400px;height:30px;background:rgb(1 2 3)}</style><div id="empty"></div><div id="scroll"><div id="wide"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	result := document_layout_result(document) or { panic('missing layout') }
	assert result.visual_context_tree.nodes.any(it.data is painting.PerspectiveVisualData)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut wide := -1
	mut empty_background := -1
	for index, command in commands {
		if command.color == 'rgb(1 2 3)' { wide = index }
		if command.color == 'rgb(4 5 6)' { empty_background = index }
	}
	assert wide >= 0 && empty_background >= 0
	assert plan.layers.len > 1
	assert plan.command_layers[wide] > 0
}

fn test_depth_transformed_perspective_descendants_keep_root_raster_fallback() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#perspective{perspective:1000px}#child{transform:translateZ(1px);width:20px;height:20px;background:rgb(4 5 6)}#scroll{width:100px;height:30px;overflow:auto}#wide{width:400px;height:30px;background:rgb(1 2 3)}</style><div id="perspective"><div><div id="child"></div></div></div><div id="scroll"><div id="wide"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert commands.any(it.color == 'rgb(4 5 6)')
	plan := chromium_raster_layer_plan(document, commands, 1)
	assert plan.layers.len == 1
	assert plan.layers[0].command_indices.len == commands.len
}

fn test_scroll_compensation_fallback_depends_on_referenced_context_and_resets() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}#scroll{width:100px;height:30px;overflow:auto}#wide{width:400px;height:30px;background:rgb(1 2 3)}</style><div id="scroll"><div id="wide"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	mut result := document_layout_result(document) or { panic('missing layout') }
	mut commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	baseline := chromium_raster_layer_plan(document, commands, 1)
	assert baseline.layers.len > 1
	compensation := result.visual_context_tree.append(painting.ScrollCompensationVisualData{
		scroll_frame_index: 1
	}, 0)
	// A descendant must retain its ancestor's unsupported raster state.
	descendant := result.visual_context_tree.append(painting.TransformVisualData{}, compensation)
	unused := chromium_raster_layer_plan(document, commands, 1)
	assert unused.command_layers == baseline.command_layers
	mut painted := -1
	for index, command in commands {
		if command.color == 'rgb(1 2 3)' { painted = index }
	}
	assert painted >= 0
	previous := commands[painted].visual_context_index
	commands[painted].visual_context_index = descendant
	used := chromium_raster_layer_plan(document, commands, 1)
	assert used.layers.len == 1
	assert used.layers[0].command_indices.len == commands.len
	commands[painted].visual_context_index = previous
	restored := chromium_raster_layer_plan(document, commands, 1)
	assert restored.command_layers == baseline.command_layers
}
