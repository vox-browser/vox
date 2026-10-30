module layout

import html
import platform

fn sticky_promotion_text_owner(source string) (ChromiumRasterLayerPlan, int) {
	mut document := html.parse_document(source)
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 800, 600)
	commands := display_list_commands(document.record_display_list() or { panic('missing sticky paint') })
	plan := chromium_raster_layer_plan(document, commands, 1)
	for index, command in commands {
		if command.kind == 'draw_text' && command.text == 'Tags' {
			return plan, plan.command_layers[index]
		}
	}
	panic('missing sticky text')
}

fn test_sticky_raster_promotion_requires_scroll_range_in_the_nearest_scrollport() {
	for height in [600, 2000] {
		plan, owner := sticky_promotion_text_owner('<!doctype html><style>
			body{margin:0;min-height:${height}px}
			section{position:sticky;top:0;width:164px;height:600px}
			span{position:absolute;left:34px;top:186px}
		</style><section><span>Tags</span></section>')
		if height == 600 {
			assert owner == 0
			assert !plan.layers[owner].composited_contents
		} else {
			assert owner > 0
			assert plan.layers[owner].composited_contents
		}
	}
}

fn test_inert_inner_scrollport_does_not_borrow_the_viewports_scroll_range() {
	for overflow in ['auto', 'scroll', 'hidden'] {
		plan, owner := sticky_promotion_text_owner('<!doctype html><style>
			body{margin:0;min-height:2000px}#scroller{overflow:${overflow};height:400px;width:164px}
			section{position:sticky;top:0;height:200px}span{position:absolute;left:34px;top:40px}
		</style><div id="scroller"><section><span>Tags</span></section></div>')
		assert !plan.layers[owner].composited_contents
	}
}

fn test_sticky_content_in_an_overflowing_scroller_keeps_its_compositor_identity() {
	for overflow in ['auto', 'scroll', 'hidden'] {
		plan, owner := sticky_promotion_text_owner('<!doctype html><style>
			body{margin:0}#scroller{overflow:${overflow};height:200px;width:164px}
			section{position:sticky;top:0;height:200px}span{position:absolute;left:34px;top:40px}
			#spacer{height:1000px}
		</style><div id="scroller"><section><span>Tags</span></section><div id="spacer"></div></div>')
		assert owner > 0
		assert plan.layers[owner].composited_contents
	}
}

fn test_sticky_promotion_excludes_scrollport_padding_from_the_scroll_range() {
	for spacer_height in [0, 1000] {
		plan, owner := sticky_promotion_text_owner('<!doctype html><style>
			body{margin:0;min-height:2000px}
			#scroller{overflow:hidden;width:164px;height:200px;padding:12px}
			section{position:sticky;top:0;height:200px}span{position:absolute;left:34px;top:40px}
			#spacer{height:${spacer_height}px}
		</style><div id="scroller"><section><span>Tags</span></section><div id="spacer"></div></div>')
		assert plan.layers[owner].composited_contents == (spacer_height > 0)
	}
}

fn test_a_fixed_ancestor_blocks_sticky_promotion_from_outside_scrolling() {
	plan, owner := sticky_promotion_text_owner('<!doctype html><style>
		body{margin:0;min-height:2000px}#fixed{position:fixed;top:0;width:164px;height:400px;background:#eee}
		section{position:sticky;top:0}span{position:absolute;left:34px;top:40px}
	</style><div id="fixed"><section><span>Tags</span></section></div>')
	// The fixed container still supplies its own composited state; the sticky
	// descendant must not create another property state merely from the viewport.
	assert owner > 0
	assert plan.layers[owner].composited_contents
	assert chromium_raster_plan_scratch_.layer_states[owner].sticky_frame == 0
}

fn test_sticky_promotion_refreshes_after_the_scroll_range_disappears_and_returns() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}
		section{position:sticky;top:0;width:164px;height:600px}
		span{position:absolute;left:34px;top:186px}</style><section><span>Tags</span></section>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	mut plan := ChromiumRasterLayerPlan{}
	mut body := document.body() or { panic('missing body') }
	for height in [2000, 600, 2000] {
		body.set_attribute_value('style', 'min-height:${height}px')
		_ = layout_document_typed_in_viewport(document, 800, 600)
		commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
		update_chromium_raster_layer_plan(document, commands, 1, mut plan)
		mut seen := false
		for index, command in commands {
			if command.kind != 'draw_text' || command.text != 'Tags' { continue }
			seen = true
			owner := plan.command_layers[index]
			assert plan.layers[owner].composited_contents == (height == 2000)
		}
		assert seen
	}
}

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
	assert plan.layers[plan.command_layers[wide]].scroll_contents
	assert !plan.layers[plan.command_layers[overlay]].scroll_contents
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
	assert !plan.layers[0].scroll_contents
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
		if depth > 0 {
			assert plan.command_layers[index] == effect_layer
		}
		if command.visual_layer_data != none && command.kind.starts_with('end_') { depth-- }
	}
	assert scroll_layer > 0 && effect_layer > 0 && scroll_layer != effect_layer
	assert plan.layers[effect_layer].legacy_raster
	assert !plan.layers[scroll_layer].legacy_raster
	assert depth == 0
}

fn test_raster_layers_compositor_surfaces_own_their_raster_extent_and_commands() {
	for hint in ['transform:translateZ(0)', 'will-change:transform'] {
		for background in ['', 'background:rgb(10 20 30)'] {
			mut document := html.parse_document('<!doctype html><style>html,body{margin:0}section{position:absolute;top:32px;width:268.1875px;height:220px;${hint};${background}}#first{left:45.8125px}#second{left:345.8125px;opacity:.5}.button{position:absolute;left:25px;top:120px;width:218.1875px;height:40px;border-radius:8px;background:black}</style><section id="first"><div class="button"></div></section><section id="second"><div class="button"></div><svg width="32" height="32"><circle cx="16" cy="16" r="16" fill="green"/></svg></section>')
			defer { document.finalize() }
			document.set_font_rendering_policy(.chromium)
			_ = layout_document_typed_in_viewport(document, 1024, 768)
			commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
			for scale in [f64(1), 2] {
				plan := chromium_raster_layer_plan(document, commands, scale)
				mut groups := 0
				mut active := -1
				mut depth := 0
				for index, command in commands {
					if command.kind == 'begin_css_effect_layer' {
						depth++
						active = plan.command_layers[index]
						assert active > 0
						assert !plan.layers[active].legacy_raster
						assert plan.layers[active].bounds == LayoutRect{
							x:      45 + groups * 300
							y:      32
							width:  269
							height: 220
						}
						groups++
					}
					if depth > 0 {
						assert plan.command_layers[index] == active
					}
					if command.kind == 'end_css_effect_layer' { depth-- }
				}
				assert groups == 2 && depth == 0
			}
		}
	}
}

fn test_compositor_raster_bounds_enclose_positive_and_negative_fractional_edges() {
	for x in [f64(45.8125), -45.8125] {
		for y in [f64(31.8125), -31.8125] {
			bounds := chromium_enclosing_raster_rect(LayoutRect{
				x:      x
				y:      y
				width:  268.1875
				height: 220.1875
			})
			assert bounds.x <= x && bounds.y <= y
			assert bounds.x + bounds.width >= x + 268.1875
			assert bounds.y + bounds.height >= y + 220.1875
			assert bounds.x > x - 1 && bounds.y > y - 1
			assert bounds.x + bounds.width < x + 269.1875
			assert bounds.y + bounds.height < y + 221.1875
		}
	}
	assert chromium_enclosing_raster_rect(LayoutRect{ x: -46, y: 32, width: 268, height: 220 }) == LayoutRect{ x: -46, y: 32, width: 268, height: 220 }
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

fn test_raster_layers_promote_content_over_an_empty_opacity_hint_surface() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0;background:rgb(247 248 252)}header{transform:translateZ(0);height:264px;box-shadow:0 4px 20px #0002}.empty{will-change:opacity;height:200px}.main{position:relative;height:64px;background:rgb(1 2 3);box-shadow:0 4px 16px #292a2e22}</style><header><div class="empty"></div><div class="main"></div></header>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	_ = layout_document_typed_in_viewport(document, 1024, 852)
	commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
	assert commands.filter(it.kind == 'begin_css_effect_layer').len == 2
	for scale in [1.0, 2.0] {
		plan := chromium_raster_layer_plan(document, commands, scale)
		mut scopes := []int{}
		mut content_layer := -1
		for index, command in commands {
			layer := plan.command_layers[index]
			if command.kind == 'begin_css_effect_layer' { scopes << layer }
			if command.color == 'rgb(1 2 3)' { content_layer = layer }
			if command.visual_layer_data != none {
				assert layer > 0 && !plan.layers[layer].legacy_raster
			}
		}
		assert scopes.len == 2 && scopes[0] > 0 && scopes[1] > scopes[0]
		assert content_layer > scopes[1]
		// The main shadow extends into the empty child's area and therefore
		// cannot merge backwards through it into the header's first picture.
		assert plan.layers[content_layer].bounds.y < 200
		assert plan.layers[scopes[0]].bounds.y < 0
		assert plan.layers[scopes[0]].bounds.height > 264
	}
}

fn test_raster_layer_shadow_overlap_includes_transformed_blur_ink() {
	box := BlockBox{ x: 10, y: 20, width: 100, height: 40 }
	bounds := chromium_raster_chunk_bounds(&box, &PaintCommand{
		kind:   'paint_outer_box_shadow'
		x:      10
		y:      24
		width:  100
		height: 40
		blur:   20
	})
	assert bounds == LayoutRect{ x: -20, y: -6, width: 160, height: 100 }
}

fn test_raster_compositor_scope_scratch_outlives_recording_arenas() {
	mut scratch := ChromiumRasterPlanScratch{}
	mut frame := platform.new_arena('compositor scope scratch')
	defer { frame.release() }
	for count in [4, 4, 12, 12] {
		entry := frame.enter()
		scratch.prepare(count, count)
		assert scratch.compositor_scopes.len == 0
		assert scratch.compositor_scopes.cap >= count
		for scope in 0 .. count { scratch.compositor_scopes << u64(scope + 1) }
		frame.leave(entry)
		frame.reset()
		assert scratch.compositor_scopes.len == count
		for scope in 0 .. count {
			assert scratch.compositor_scopes[scope] == u64(scope + 1)
		}
	}
}

fn test_raster_chunk_bounds_intersect_page_space_clip_after_transform() {
	box := BlockBox{
		x:               10
		y:               20
		width:           220
		height:          40
		paint_transform: [f64(0), 1, -1, 0, 100, 50]!
	}
	command := PaintCommand{
		kind:        'draw_svg_path'
		has_clip:    true
		clip_x:      50
		clip_y:      70
		clip_width:  20
		clip_height: 48
	}
	assert chromium_raster_chunk_bounds(&box, &command) == LayoutRect{
		x:      50
		y:      70
		width:  20
		height: 48
	}
	outside := PaintCommand{ ...command, clip_x: 200 }
	assert chromium_raster_chunk_bounds(&box, &outside).width == 0
}
