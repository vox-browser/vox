module painting

fn test_all_mix_blend_modes_map_without_fallback() {
	modes := [BlendMode.normal, .multiply, .screen, .overlay, .darken, .lighten, .color_dodge,
		.color_burn, .hard_light, .soft_light, .difference, .exclusion, .hue, .saturation, .color,
		.luminosity, .plus_darker, .plus_lighter]
	for index, mode in modes {
		expected := if index == 0 { 0 } else { index + 1 }
		assert int(mix_blend_mode_to_compositing_and_blending_operator(mode)) == expected
	}
}

fn test_resolved_css_filter_scales_and_composes_in_upstream_order() {
	filter := ResolvedCSSFilter{
		operations: [
			ResolvedFilterOperation(BlurFilter{
				radius: 3
			}),
			DropShadowFilter{
				offset_x: 2
				offset_y: -1
				radius: 4
				color: Color{
					r: 9
				}
			},
			ColorFilter{
				operation: .contrast
				amount: 1.5
			},
			HueRotateFilter{
				angle_degrees: 90
			},
		]
	}
	gfx := filter.to_gfx_filter(2) or { panic('expected filter') }
	assert gfx.operations.len == 4
	assert gfx.operations[0].kind == 'hue-rotate'
	assert gfx.operations[1].kind == 'color'
	assert gfx.operations[2].kind == 'drop-shadow'
	assert gfx.operations[2].first == 4
	assert gfx.operations[2].second == -2
	assert gfx.operations[2].third == 8
	assert gfx.operations[3].kind == 'blur'
	assert gfx.operations[3].first == 6
	assert filter.has_filters()
	assert !filter.has_svg_filters()
	assert filter.dump().contains('blur(3')
	assert ResolvedCSSFilter{}.to_gfx_filter(1) == none
}

fn test_svg_filter_graph_wraps_the_css_filter_chain_without_flattening() {
	svg := GfxFilter{
		nodes:   [
			GfxFilterNode{
				id:         0
				kind:       'blur'
				input_ids:  [-1]
				parameters: {
					'radius_x': 2.0
					'radius_y': 3.0
				}
			},
		]
		root_id: 0
	}
	filter := ResolvedCSSFilter.with_svg_filter([
		ResolvedFilterOperation(ColorFilter{
			operation: .contrast
			amount:    1.5
		}),
	], svg, Rect{10, 20, 30, 40})
	gfx := filter.to_gfx_filter(2) or { panic('expected composed filter') }
	assert gfx.operations.len == 1
	assert gfx.operations[0].kind == 'color'
	assert gfx.nodes.len == 1
	assert gfx.nodes[0].input_ids == [-1]
	assert gfx.nodes[0].parameters['radius_x'] == 2
	assert gfx.root_id or { -1 } == 0
	assert gfx.bounds or { panic('expected SVG filter bounds') } == Rect{10, 20, 30, 40}
}

fn test_source_color_matrix_classifies_positive_alpha_bias() {
	mut values := [1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0]
	for bias in [0.0, -.25, .25] {
		values[19] = bias
		filter := GfxFilter{
			nodes: [GfxFilterNode{kind: 'color-matrix', input_ids: [-1], matrix: values}]
			root_id: 0
		}
		effect := filter.source_color_filter() or { panic('expected a source color matrix') }
		assert !effect.preserves_alpha()
		assert effect.fills_clear_pixels() == (bias > 0)
		if effect is SVGSourceColorMatrix {
			assert effect.stages.len == 1
			assert effect.stages[0][19] == f32(bias)
		} else {
			assert false
		}
	}
}

fn test_source_color_table_retains_missing_channels_and_alpha_coverage() {
	mut values := []u8{len: 256, init: u8(index)}
	values[0] = 153
	filter := GfxFilter{
		nodes: [
			GfxFilterNode{
				kind: 'color-table'
				input_ids: [-1]
				color_tables: [GfxFilterColorTable{channel: 'alpha', values: values}]
			},
		]
		root_id: 0
	}
	effect := filter.source_color_filter() or { panic('expected a source color table') }
	assert effect.fills_clear_pixels()
	assert !effect.preserves_alpha()
	if effect is SVGSourceColorTable {
		assert effect.stages.len == 1
		assert effect.stages[0][0].len == 0
		assert effect.stages[0][3][0] == 153
	} else {
		assert false
	}
}

fn test_source_color_filter_accepts_consecutive_matrices() {
	values := [1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
	first := GfxFilterNode{kind: 'color-matrix', input_ids: [-1], matrix: values}
	mut biased := values.clone()
	biased[19] = .4
	second := GfxFilterNode{id: 1, kind: 'color-matrix', input_ids: [0], matrix: biased}
	filter := GfxFilter{nodes: [first, second], root_id: 1}
	effect := filter.source_color_filter() or { panic('expected a color matrix chain') }
	assert effect.fills_clear_pixels()
	assert !effect.preserves_alpha()
	if effect is SVGSourceColorMatrix {
		assert effect.stages.len == 2
		assert effect.stages[0][19] == 0
		assert effect.stages[1][19] == f32(.4)
	} else {
		assert false
	}
}

fn test_source_color_filter_preserves_mixed_stage_order_and_alpha() {
	values := [1.0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0]
	matrix := GfxFilterNode{id: 1, kind: 'color-matrix', input_ids: [0], matrix: values}
	table := GfxFilterNode{
		id: 2
		kind: 'color-table'
		input_ids: [1]
		color_tables: [GfxFilterColorTable{channel: 'red', values: []u8{len: 256, init: u8(index)}}]
	}
	decode := GfxFilterNode{
		kind: 'color-space-conversion'
		input_ids: [-1]
		string_parameters: {'source': 'srgb', 'destination': 'linear-rgb'}
	}
	encode := GfxFilterNode{
		id: 3
		kind: 'color-space-conversion'
		input_ids: [2]
		string_parameters: {'source': 'linear-rgb', 'destination': 'srgb'}
	}
	filter := GfxFilter{nodes: [decode, matrix, table, encode], root_id: 3}
	effect := filter.source_color_filter() or { panic('expected a mixed filter chain') }
	assert effect.preserves_alpha()
	assert !effect.fills_clear_pixels()
	if effect is SVGSourceColorChain {
		assert effect.linear_rgb
		assert effect.stages.len == 2
		assert !effect.stages[0].is_table
		assert effect.stages[1].is_table
		assert effect.stages[1].channels[0].len == 0
	} else {
		assert false
	}

	revive := GfxFilterNode{
		...table
		color_tables: [GfxFilterColorTable{channel: 'alpha', values: []u8{len: 256, init: 153}}]
	}
	coverage := GfxFilter{nodes: [decode, matrix, revive, encode], root_id: 3}.source_color_filter() or {
		panic('expected a mixed filter chain that restores coverage')
	}
	assert coverage.fills_clear_pixels()
	assert !coverage.preserves_alpha()

	branch := GfxFilter{nodes: [decode, matrix, GfxFilterNode{...table, input_ids: [0]}, encode], root_id: 3}
	assert !branch.supports_source_color_filter()
}

fn test_source_color_filter_follows_only_adjacent_component_transfers() {
	source := GfxFilterNode{kind: 'color-table', input_ids: [-1]}
	second := GfxFilterNode{id: 1, kind: 'color-table', input_ids: [0]}
	chain := GfxFilter{nodes: [source, second], root_id: 1}
	effect := chain.source_color_filter() or { panic('expected a color table chain') }
	assert effect.preserves_alpha()
	assert !effect.fills_clear_pixels()
	if effect is SVGSourceColorTable {
		assert effect.stages.len == 2
	} else {
		assert false
	}

	branch := GfxFilter{nodes: [source, GfxFilterNode{...second, input_ids: [-1]}], root_id: 1}
	assert !branch.supports_source_color_filter()
	earlier_root := GfxFilter{nodes: chain.nodes, root_id: 0}
	assert !earlier_root.supports_source_color_filter()
}

fn test_transition_hints_expand_to_five_sampled_stops() {
	red := Color{
		r: 255
	}
	blue := Color{
		b: 255
	}
	stops := [ColorStop{ color: red, position: 0 }, ColorStop{
		color: blue
		position: 1
		transition_hint: 0.5
	}]
	expanded := replace_transition_hints_with_normal_color_stops(stops)
	assert expanded.len == 7
	assert expanded[0].color == red
	assert expanded[3].position == 0.5
	assert expanded[3].color.r in [127, 128]
	assert expanded[3].color.b in [127, 128]
	assert expanded[6].color == blue
}

fn test_transition_hint_uses_css_midpoint_exponent() {
	stops := [ColorStop{
		color: Color{ r: 255 }
		position: 0
	}, ColorStop{
		color: Color{ b: 255 }
		position: 1
		transition_hint: 0.25
	}]
	expanded := expand_color_stops_for_painting(stops, none)
	assert expanded.len == 7
	// A hint marks the point where the two colors contribute equally. Plain
	// linear interpolation would incorrectly leave this sample 75% red.
	assert expanded[3].position == 0.25
	assert expanded[3].color.r in [127, 128]
	assert expanded[3].color.b in [127, 128]
}

fn test_repeating_gradient_expands_and_clamps_ends() {
	stops := [ColorStop{
		color: Color{
			r: 255
		}
		position: 0.25
	}, ColorStop{
		color: Color{
			b: 255
		}
		position: 0.5
	}]
	expanded := expand_repeat_length(stops, 0.25)
	assert expanded.len >= 5
	assert expanded[0].position == 0
	assert expanded[expanded.len - 1].position <= 1
	for index := 1; index < expanded.len; index++ {
		assert expanded[index].position >= expanded[index - 1].position
	}
}

fn test_box_shadow_layers_are_painted_back_to_front() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	layers := [
		ShadowData{
			color: Color{
				r: 1
			}
			offset_x: 1
			blur_radius: 2
			spread_distance: 3
		},
		ShadowData{
			color: Color{
				b: 2
			}
			offset_y: 2
			blur_radius: 1
			placement: .inner
		},
	]
	resolved := resolve_box_shadows(Rect{10, 20, 30, 40}, BorderRadiiData{}, layers, converter)
	assert resolved.len == 2
	assert resolved[0].placement == .inner
	assert resolved[0].color.b == 2
	assert resolved[0].outer_shadow_rect == IntRect{9, 19, 32, 46}
	assert resolved[0].inner_shadow_rect == IntRect{10, 22, 30, 40}
	assert resolved[1].placement == .outer
	assert resolved[1].shadow_rect == IntRect{8, 17, 36, 46}
}

fn test_box_shadow_uses_source_border_and_padding_geometry() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	radii := BorderRadiiData{
		top_left: BorderRadiusData{10, 8}
		top_right: BorderRadiusData{20, 12}
		bottom_right: BorderRadiusData{30, 16}
		bottom_left: BorderRadiusData{40, 20}
	}
	borders := BordersData{
		top: BorderData{Color{}, .solid, 2}
		right: BorderData{Color{}, .solid, 3}
		bottom: BorderData{Color{}, .solid, 4}
		left: BorderData{Color{}, .solid, 5}
	}
	layers := [
		ShadowData{
			color: Color{ r: 1 }
			offset_x: 1
			offset_y: 2
			blur_radius: 3
			spread_distance: 2
		},
		ShadowData{
			color: Color{ b: 2 }
			offset_x: 4
			offset_y: -2
			blur_radius: 6
			spread_distance: 1
			placement: .inner
		},
	]
	resolved := paint_box_shadow(Rect{10, 20, 100, 50}, Rect{15, 22, 92, 44}, borders, radii, layers, converter)
	assert resolved.len == 2
	inner := resolved[0]
	assert inner.placement == .inner
	assert inner.content_rect == IntRect{15, 22, 92, 44}
	assert inner.outer_shadow_rect == IntRect{9, 16, 112, 56}
	assert inner.inner_shadow_rect == IntRect{20, 21, 90, 42}
	assert inner.content_corner_radii.top_left == CornerRadius{5, 6}
	assert inner.clip_corner_radii.top_left == CornerRadius{5, 6}
	assert inner.clip_corner_radii.bottom_right == CornerRadius{27, 12}
	assert inner.inner_corner_radii.top_right == CornerRadius{16, 9}
	outer := resolved[1]
	assert outer.placement == .outer
	assert outer.content_rect == IntRect{10, 20, 100, 50}
	assert outer.shadow_rect == IntRect{9, 20, 104, 54}
	assert outer.shadow_corner_radii.bottom_left == CornerRadius{42, 22}
}
