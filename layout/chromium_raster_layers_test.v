module layout

import html

fn test_raster_layers_preserve_overlap_and_merge_disjoint_chunks() {
	root := ChromiumRasterPropertyState{}
	scroll := ChromiumRasterPropertyState{
		scroll_frame: 1
	}
	plan := chromium_layerize_chunks([
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				x:      0
				y:      0
				width:  300
				height: 200
			}
			command_index: 0
		},
		ChromiumRasterChunk{
			state:         scroll
			bounds:        LayoutRect{
				x:      20
				y:      30
				width:  200
				height: 30
			}
			command_index: 1
		},
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				x:      180
				y:      25
				width:  40
				height: 40
			}
			command_index: 2
		},
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				x:      240
				y:      100
				width:  10
				height: 10
			}
			command_index: 3
		},
		ChromiumRasterChunk{
			state:         scroll
			bounds:        LayoutRect{
				x:      20
				y:      30
				width:  40
				height: 20
			}
			command_index: 4
		},
	], 5, 1)
	assert plan.command_layers == [0, 1, 2, 2, 1]
	assert plan.layers.len == 3
	assert plan.layers[1].command_indices == [1, 4]
	assert plan.layers[2].bounds == LayoutRect{
		x:      180
		y:      25
		width:  70
		height: 85
	}
}

fn test_raster_layers_different_sticky_states_do_not_merge() {
	plan := chromium_layerize_chunks([
		ChromiumRasterChunk{
			state:         ChromiumRasterPropertyState{
				sticky_frame: 2
			}
			bounds:        LayoutRect{
				width:  100
				height: 40
			}
			command_index: 0
		},
		ChromiumRasterChunk{
			state:         ChromiumRasterPropertyState{
				sticky_frame: 3
			}
			bounds:        LayoutRect{
				width:  100
				height: 40
			}
			command_index: 1
		},
	], 2, 1)
	assert plan.command_layers == [1, 2]
	assert chromium_root_raster_plan(3).layers[0].command_indices == [0, 1, 2]
}

fn test_raster_layers_follow_retained_scrolling_and_escaped_absolute_ancestry() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#wrap{position:relative;margin:20px;width:200px}#scroll{overflow-x:auto;overflow-y:hidden;height:30px}#wide{width:400px;height:30px;background:rgb(1 2 3)}#overlay{position:absolute;right:0;top:-5px;width:40px;height:40px;background:rgb(4 5 6)}</style><div id="wrap"><div id="scroll"><div id="wide"></div><div id="overlay"></div></div></div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 300, 200)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut wide := -1
	mut overlay := -1
	for i, command in commands {
		if command.color == 'rgb(1 2 3)' { wide = i }
		if command.color == 'rgb(4 5 6)' { overlay = i }
	}
	assert wide >= 0 && overlay >= 0
	assert plan.command_layers.len == commands.len
	assert plan.command_layers[wide] > 0
	assert plan.command_layers[overlay] > plan.command_layers[wide]
	assert plan.layers[plan.command_layers[overlay]].bounds.y == 15
}

fn test_raster_layers_hidden_overflow_does_not_create_composited_scroll_layer() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#scroll{overflow:hidden;width:100px;height:30px}#wide{width:400px;height:30px;background:rgb(1 2 3)}</style><div id="scroll"><div id="wide"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	assert plan.layers.len == 1
	for layer in plan.command_layers {
		assert layer == 0
	}
}

fn test_raster_layers_effect_groups_remain_atomic_without_disabling_other_scroll_layers() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#scroll{width:100px;height:30px;overflow:auto}#wide{width:400px;height:30px;background:rgb(1 2 3)}#effect{opacity:.5;margin-top:50px;background:rgb(4 5 6);width:60px;height:40px}#inner{opacity:.6;background:rgb(7 8 9);width:20px;height:20px}</style><div id="scroll"><div id="wide"></div></div><div id="effect"><div id="inner"></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 300, 200)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	mut scroll_layer := -1
	mut effect_layer := -1
	mut depth := 0
	for index, command in commands {
		if command.color == 'rgb(1 2 3)' { scroll_layer = plan.command_layers[index] }
		if command.visual_layer_data != none && command.kind.starts_with('begin_') {
			depth++
			if depth == 1 { effect_layer = plan.command_layers[index] }
		}
		if depth > 0 { assert plan.command_layers[index] == effect_layer
		 }
		if command.visual_layer_data != none && command.kind.starts_with('end_') { depth-- }
	}
	assert scroll_layer > 0 && effect_layer > 0 && scroll_layer != effect_layer
	assert plan.layers[effect_layer].legacy_raster
	assert !plan.layers[scroll_layer].legacy_raster
	assert depth == 0
}

fn test_raster_layers_reject_sparse_merge_before_overlapping_scroll_content() {
	root := ChromiumRasterPropertyState{}
	plan := chromium_layerize_chunks([
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				width:  1024
				height: 7000
			}
			command_index: 0
		},
		ChromiumRasterChunk{
			state:         ChromiumRasterPropertyState{
				scroll_frame: 1
			}
			bounds:        LayoutRect{
				x:      32
				y:      72
				width:  1222
				height: 23
			}
			command_index: 1
		},
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				x:      936
				y:      67.5
				width:  68
				height: 33
			}
			command_index: 2
		},
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				x:      32
				y:      6000
				width:  200
				height: 50
			}
			command_index: 3
		},
	], 4, 1)
	assert plan.command_layers == [0, 1, 2, 0]
	assert plan.layers[2].bounds == LayoutRect{
		x:      936
		y:      67.5
		width:  68
		height: 33
	}
}

fn test_raster_layers_separate_viewport_fixed_chunks_from_scrolling_root() {
	root := ChromiumRasterPropertyState{}
	plan := chromium_layerize_chunks([
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				width:  1024
				height: 7000
			}
			command_index: 0
		},
		ChromiumRasterChunk{
			state:         ChromiumRasterPropertyState{
				scroll_frame: 1
			}
			bounds:        LayoutRect{
				x:      32
				y:      72
				width:  1222
				height: 23
			}
			command_index: 1
		},
		ChromiumRasterChunk{
			state:         root
			bounds:        LayoutRect{
				x:      936
				y:      67.5
				width:  68
				height: 33
			}
			command_index: 2
		},
		ChromiumRasterChunk{
			state:         ChromiumRasterPropertyState{
				fixed_to_viewport: true
			}
			bounds:        LayoutRect{
				width:  1024
				height: 276
			}
			command_index: 3
		},
	], 4, 1)
	assert plan.command_layers == [0, 1, 2, 3]
	assert plan.layers[2].bounds == LayoutRect{
		x:      936
		y:      67.5
		width:  68
		height: 33
	}
	box := BlockBox{
		x:      0
		y:      0
		width:  1024
		height: 276
	}
	assert chromium_raster_chunk_bounds(&box, &PaintCommand{
		has_clip:    true
		clip_width:  1024
		clip_height: 0
	}) == LayoutRect{}
}
