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
