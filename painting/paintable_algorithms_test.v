module painting

import css

fn test_to_gfx_scaling_mode_matches_css_image_rendering() {
	assert to_gfx_scaling_mode(.auto_, IntSize{200, 100}, IntSize{100, 50}) == .bilinear_mipmap
	assert to_gfx_scaling_mode(.smooth, IntSize{200, 100}, IntSize{100, 100}) == .bilinear
	assert to_gfx_scaling_mode(.high_quality, IntSize{100, 100}, IntSize{200, 200}) == .bilinear
	assert to_gfx_scaling_mode(.crisp_edges, IntSize{200, 100}, IntSize{100, 50}) == .nearest_neighbor
	assert to_gfx_scaling_mode(.pixelated, IntSize{100, 100}, IntSize{200, 200}) == .nearest_neighbor
}

fn test_fragment_index_and_selection_offsets_cover_all_selection_states() {
	fragment := PaintableFragment{
		paintable_id: 'text'
		offset: Point{10, 20}
		size: Size{40, 10}
		start_offset: 5
		length_in_code_units: 4
		glyphs: [GlyphMetric{1, 10}, GlyphMetric{1, 10}, GlyphMetric{1, 10}, GlyphMetric{1, 10}]
		space_width: 5
		has_trailing_whitespace: true
	}
	assert fragment.index_in_node_for_point(Point{0, 20}) == 0
	assert fragment.index_in_node_for_point(Point{16, 20}) == 6
	assert fragment.index_in_node_for_point(Point{49, 20}) == 9
	assert fragment.compute_selection_offsets(.none, 0, 10) == none
	assert fragment.compute_selection_offsets(.full, 0, 10) or { panic('expected offsets') } == SelectionOffsets{0, 4, true}
	assert fragment.compute_selection_offsets(.start_and_end, 6, 8) or { panic('expected offsets') } == SelectionOffsets{1, 3, false}
	assert fragment.compute_selection_offsets(.start, 7, 99) or { panic('expected offsets') } == SelectionOffsets{2, 4, true}
	assert fragment.compute_selection_offsets(.end, 0, 7) or { panic('expected offsets') } == SelectionOffsets{0, 2, false}
	assert fragment.range_rect(.start_and_end, 6, 8) == Rect{20, 20, 20, 10}
	assert fragment.range_rect(.start_and_end, 6, 6) == Rect{20, 20, 1, 10}
	assert fragment.range_rect(.full, 0, 99) == Rect{10, 20, 45, 10}
	overflowing := PaintableFragment{
		...fragment
		baseline: 8
		font_ascent: 12
		font_descent: 5
	}
	assert overflowing.range_rect(.start_and_end, 6, 8) == Rect{20, 16, 20, 17}
}

fn test_paintable_tree_hit_testing_uses_reverse_stacking_order() {
	tree := PaintableTree{
		nodes: [
			PaintableNode{
				id: 'root'
				rect: Rect{0, 0, 100, 100}
				children: [1, 2]
			},
			PaintableNode{
				id: 'low'
				parent_index: 0
				rect: Rect{10, 10, 30, 30}
				z_index: -1
				tree_order: 1
			},
			PaintableNode{
				id: 'high'
				parent_index: 0
				rect: Rect{10, 10, 30, 30}
				z_index: 2
				tree_order: 2
			},
		]
	}
	hit := tree.hit_test(0, Point{20, 20}, .exact) or { panic('expected hit') }
	assert hit.paintable_id == 'high'
	hidden_tree := PaintableTree{
		nodes: [
			PaintableNode{
				id: 'hidden'
				rect: Rect{0, 0, 10, 10}
				visible: false
			},
		]
	}
	assert hidden_tree.hit_test(0, Point{1, 1}, .exact) == none
	hidden_fragment_tree := PaintableTree{
		nodes: [
			PaintableNode{
				id: 'hidden-text'
				visible: false
				fragments: [
					PaintableFragment{
						paintable_id: 'hidden-text'
						size: Size{10, 10}
						length_in_code_units: 1
						glyphs: [GlyphMetric{1, 10}]
					},
				]
			},
		]
	}
	assert hidden_fragment_tree.hit_test(0, Point{1, 1}, .exact) == none
}

fn test_paintable_box_geometry_scrolling_and_cache() {
	mut box := PaintableBox{
		id: 'box'
		offset: Point{10, 20}
		content_size: Size{100, 50}
		containing_block_position: Point{5, 5}
		box_model: BoxModelMetrics{
			padding: PixelBox{2, 3, 4, 5}
			border: PixelBox{1, 1, 1, 1}
		}
		overflow: OverflowData{
			scrollable_overflow_rect: Rect{0, 0, 300, 200}
			has_scrollable_overflow: true
		}
	}
	assert box.absolute_rect() == Rect{15, 25, 100, 50}
	assert box.absolute_padding_box_rect() == Rect{10, 23, 108, 56}
	assert box.absolute_border_box_rect() == Rect{9, 22, 110, 58}
	assert box.set_scroll_offset(Point{999, 999})
	assert box.scroll_offset == Point{192, 144}
	assert !box.set_scroll_offset(Point{999, 999})
	box.cache_commands(.foreground, [
		DisplayListCommand(FillRect{IntRect{0, 0, 1, 1}, Color{
			r: 1
		}}),
	])
	assert box.cached_commands[.foreground].len == 1
	box.invalidate_paint_cache()
	assert box.cached_commands.len == 0
}

fn test_stacking_context_sort_generation_and_paint_order() {
	mut context := StackingContext{
		paintable_id: 'root'
		children: [
			StackingContext{
				paintable_id: 'positive'
				z_index: 3
				tree_order: 3
			},
			StackingContext{
				paintable_id: 'negative'
				z_index: -2
				tree_order: 2
			},
			StackingContext{
				paintable_id: 'zero'
				z_index: 0
				tree_order: 1
			},
		]
	}
	context.sort()
	assert stacking_paint_order(context) == ['root', 'negative', 'zero', 'positive']
	assert context.set_last_paint_generation_id(4)
	assert !context.set_last_paint_generation_id(4)
	assert !context.set_last_paint_generation_id(3)
	assert context.set_last_paint_generation_id(5)
}

fn test_stacking_context_paint_recurses_and_skips_unpaintable_contexts() {
	context := StackingContext{
		paintable_id: 'root'
		children: [
			StackingContext{
				paintable_id: 'positive'
				z_index: 2
				children: [StackingContext{
					paintable_id: 'nested-negative'
					z_index: -1
				}]
			},
			StackingContext{
				paintable_id: 'negative'
				z_index: -2
			},
			StackingContext{
				paintable_id: 'transparent'
				opacity: 0
			},
			StackingContext{
				paintable_id: 'noninvertible'
				z_index: 1
				non_invertible_transform: true
			},
		]
	}
	assert context.paint() == ['root', 'negative', 'positive', 'nested-negative']
	assert context.paint_child(2).len == 0
}

fn test_background_table_control_and_replaced_content_algorithms() {
	layer := ResolvedBackgroundLayer{
		image_id: 'tile'
		background_positioning_area: Rect{0, 0, 100, 100}
		image_rect: Rect{0, 0, 20, 20}
		repeat_x: .repeat
		repeat_y: .repeat
	}
	tiles := background_tiles(layer, Point{}, Point{}, Rect{0, 0, 45, 45})
	assert tiles.len == 9
	assert tiles[0] == Rect{0, 0, 20, 20}
	strong := ConflictingBorder{
		border: DeviceBorderData{
			width: 2
			line_style: .solid
		}
		element_kind: .table
	}
	weak := ConflictingBorder{
		border: DeviceBorderData{
			width: 2
			line_style: .dashed
		}
		element_kind: .cell
	}
	assert resolve_table_border_conflict(strong, weak) == strong
	earlier := ConflictingBorder{
		border: strong.border
		element_kind: .cell
		tree_order: 2
	}
	later := ConflictingBorder{
		...earlier
		tree_order: 3
	}
	assert resolve_table_border_conflict(later, earlier) == earlier
	assert fieldset_effective_border_top(2, 3, 4, true) == 7
	colors := InputColors{
		accent: Color{
			r: 1
		}
		base: Color{
			r: 255
			g: 255
			b: 255
		}
		gray: Color{
			r: 2
		}
		mid_gray: Color{
			r: 3
		}
		dark_gray: Color{
			r: 4
		}
		background: Color{
			r: 5
		}
	}
	assert checkbox_commands(IntRect{0, 0, 20, 20}, true, false, true, colors).len == 2
	indeterminate := checkbox_commands(IntRect{0, 0, 20, 20}, false, true, true, colors)
	assert indeterminate.len == 3
	assert indeterminate[2] is FillRoundedRect
	dash := indeterminate[2] as FillRoundedRect
	assert dash.rect == IntRect{4, 8, 12, 4}
	assert radio_button_commands(IntRect{0, 0, 13, 13}, true, true, colors).len == 3
	assert command_name(marker_command(.disc, IntRect{0, 0, 5, 5}, Color{})) == 'FillEllipse'
	assert command_name(replaced_content_command(.video, 'video', IntRect{0, 0, 10, 10}, IntRect{0, 0, 10, 10}, .bilinear)) == 'DrawExternalContent'
}

fn test_resolve_background_layer_uses_cpp_sizing_round_and_position_order() {
	mut layer := css.BackgroundLayerData{
		size_type: .length_percentage
		size_x: css.LengthPercentageOrAuto.from_length(css.Length.make_px(30))
		size_y: css.LengthPercentageOrAuto.make_auto()
		position_x: css.LengthPercentage.from_percentage(css.Percentage.new(25))
		position_y: css.LengthPercentage.from_percentage(css.Percentage.new(50))
		repeat_x: .round
		repeat_y: .no_repeat
		blend_mode: .plus_lighter
	}
	resolved := resolve_background_layer(BackgroundLayerResolutionInput{
		layer: layer
		image_id: 'tile'
		natural_width: 60
		natural_height: 30
		background_positioning_area: Rect{10, 20, 100, 50}
		resolution_context: css.LengthResolutionContext.default()
	}) or { panic('expected a resolved background') }
	// 30x15 becomes 100/3 by 50/3: round fits three columns, then the auto Y
	// dimension restores the original 2:1 aspect ratio.
	assert resolved.image_rect.width > 33.33 && resolved.image_rect.width < 33.34
	assert resolved.image_rect.height > 16.66 && resolved.image_rect.height < 16.67
	assert resolved.position_x == 16.65625
	assert resolved.position_y == 16.65625
	assert resolved.repeat_x == .round
	assert resolved.repeat_y == .no_repeat
	assert resolved.blend_mode == .plus_lighter

	layer.size_type = .cover
	layer.repeat_x = .no_repeat
	cover := resolve_background_layer(BackgroundLayerResolutionInput{
		layer: layer
		image_id: 'cover'
		natural_width: 60
		natural_height: 30
		background_positioning_area: Rect{0, 0, 100, 100}
		resolution_context: css.LengthResolutionContext.default()
	}) or { panic('expected cover geometry') }
	assert cover.image_rect.width == 200
	assert cover.image_rect.height == 100
}

fn test_gradient_background_layer_keeps_absent_intrinsic_dimensions() {
	layer := css.BackgroundLayerData{
		size_type: .length_percentage
		size_x: css.LengthPercentageOrAuto.from_length_percentage(css.LengthPercentage.from_length(css.Length.make_px(40)))
		size_y: css.LengthPercentageOrAuto.make_auto()
		repeat_x: .no_repeat
		repeat_y: .no_repeat
	}
	resolved := resolve_background_layer_without_intrinsic(BackgroundLayerWithoutIntrinsicResolutionInput{
		layer: layer
		image_id: 'linear-gradient(red, blue)'
		background_positioning_area: Rect{0, 0, 100, 60}
		resolution_context: css.LengthResolutionContext.default()
	}) or { panic('gradient layer did not resolve') }
	// With no natural height or aspect ratio, default sizing takes the missing axis from the
	// default object size. Treating the positioning area as a fake intrinsic bitmap yields 24px.
	assert resolved.image_rect.width == 40
	assert resolved.image_rect.height == 60

	vertical := css.BackgroundLayerData{
		size_type: .length_percentage
		size_x: css.LengthPercentageOrAuto.make_auto()
		size_y: css.LengthPercentageOrAuto.from_length_percentage(css.LengthPercentage.from_length(css.Length.make_px(20)))
		repeat_x: .no_repeat
		repeat_y: .no_repeat
	}
	resolved_vertical := resolve_background_layer_without_intrinsic(BackgroundLayerWithoutIntrinsicResolutionInput{
		layer: vertical
		image_id: 'radial-gradient(red, blue)'
		background_positioning_area: Rect{0, 0, 100, 60}
		resolution_context: css.LengthResolutionContext.default()
	}) or { panic('vertical gradient layer did not resolve') }
	assert resolved_vertical.image_rect.width == 100
	assert resolved_vertical.image_rect.height == 20
}

fn test_background_tiles_matches_cpp_space_and_attachment_geometry() {
	space_layer := ResolvedBackgroundLayer{
		image_id: 'space'
		background_positioning_area: Rect{0, 0, 100, 20}
		image_rect: Rect{0, 0, 30, 20}
		repeat_x: .space
		repeat_y: .no_repeat
	}
	space_tiles := background_tiles(space_layer, Point{}, Point{}, Rect{0, 0, 100, 20})
	assert space_tiles == [Rect{0, 0, 30, 20}, Rect{35, 0, 30, 20}, Rect{70, 0, 30, 20}]

	local_layer := ResolvedBackgroundLayer{
		...space_layer
		attachment: .local
		repeat_x: .no_repeat
	}
	local_tiles := background_tiles(local_layer, Point{7, 3}, Point{}, Rect{-10, -10, 100, 100})
	assert local_tiles == [Rect{-7, -3, 30, 20}]
	fixed_layer := ResolvedBackgroundLayer{
		...space_layer
		attachment: .fixed
		repeat_x: .no_repeat
	}
	fixed_tiles := background_tiles(fixed_layer, Point{}, Point{40, 50}, Rect{0, 0, 100, 100})
	assert fixed_tiles == [Rect{40, 50, 30, 20}]
	limited := background_tiles_limited(space_layer, Point{}, Point{}, Rect{0, 0, 100, 20}, 2)
	assert limited == [Rect{0, 0, 30, 20}, Rect{35, 0, 30, 20}]
}

fn test_border_color_matches_inset_and_outset_hsv_adjustment() {
	dark := Color{51, 51, 51, 173}
	bright := Color{204, 204, 204, 173}
	inset_dark := DeviceBordersData{
		top: DeviceBorderData{dark, .inset, 4}
		bottom: DeviceBorderData{dark, .inset, 4}
	}
	assert border_color(.top, inset_dark) == dark
	assert border_color(.bottom, inset_dark) == Color{136, 136, 136, 173}
	outset_bright := DeviceBordersData{
		left: DeviceBorderData{bright, .outset, 4}
		right: DeviceBorderData{bright, .outset, 4}
	}
	assert border_color(.left, outset_bright) == bright
	assert border_color(.right, outset_bright) == Color{119, 119, 119, 173}
}

fn test_borders_data_for_outline_matches_cpp_visibility_checks() {
	transparent_color := Color{1, 2, 3, 0}
	assert borders_data_for_outline(transparent_color, .solid, 3) == none
	assert borders_data_for_outline(Color{1, 2, 3, 255}, .none, 3) == none
	assert borders_data_for_outline(Color{1, 2, 3, 255}, .solid, 0) == none
	borders := borders_data_for_outline(Color{1, 2, 3, 255}, .dashed, 7) or {
		panic('visible outline was suppressed')
	}
	assert borders.top == BorderData{Color{1, 2, 3, 255}, .dashed, 7}
	assert borders.right == borders.top
	assert borders.bottom == borders.top
	assert borders.left == borders.top
}

fn test_paint_all_borders_retains_cpp_joined_elliptical_paths() {
	red := Color{200, 10, 20, 255}
	solid := DeviceBorderData{red, .solid, 4}
	radii := CornerRadii{
		top_left: CornerRadius{20, 12}
		top_right: CornerRadius{16, 10}
		bottom_right: CornerRadius{14, 9}
		bottom_left: CornerRadius{18, 11}
	}
	commands := paint_all_borders(IntRect{0, 0, 100, 50}, radii, DeviceBordersData{
		top: solid
		right: solid
		bottom: solid
		left: solid
	})
	assert commands.len == 1
	assert commands[0] is FillPath
	joined := commands[0] as FillPath
	assert joined.color == red
	assert joined.winding_rule == .even_odd
	assert joined.path.fill_rule == .even_odd
	assert joined.path.segments.len == 32
	assert joined.path.segments.filter(it.kind == .move_to).len == 4
	assert joined.path.segments.filter(it.kind == .elliptical_arc_to).len == 16
	assert joined.path.segments.filter(it.kind == .elliptical_arc_to && it.sweep).len == 8

	dashed := DeviceBorderData{red, .dashed, 4}
	dashed_commands := paint_all_borders(IntRect{0, 0, 100, 50}, radii, DeviceBordersData{
		top: dashed
		right: dashed
		bottom: dashed
		left: dashed
	})
	assert dashed_commands.len == 4
	assert dashed_commands.all(it is DrawLine)
	top := dashed_commands[0] as DrawLine
	assert top.from == IntPoint{22, 2}
	assert top.to == IntPoint{81, 2}

	double := DeviceBorderData{red, .double, 6}
	double_commands := paint_all_borders(IntRect{0, 0, 100, 50}, radii, DeviceBordersData{
		top: double
		right: double
		bottom: double
		left: double
	})
	assert double_commands.len == 8
	assert double_commands.all(it is FillPath)

	dark_gray := Color{51, 51, 51, 173}
	groove := DeviceBorderData{dark_gray, .groove, 6}
	groove_commands := paint_all_borders(IntRect{0, 0, 100, 50}, radii, DeviceBordersData{
		top: groove
		right: groove
		bottom: groove
		left: groove
	})
	assert groove_commands.len == 8
	assert groove_commands.all(it is FillPath)
	assert groove_commands.filter((it as FillPath).color == dark_gray).len == 4
	assert groove_commands.filter((it as FillPath).color == Color{136, 136, 136, 173}).len == 4

	mixed_commands := paint_all_borders(IntRect{10, 20, 30, 40}, CornerRadii{}, DeviceBordersData{
		top: DeviceBorderData{red, .hidden, 5}
		right: DeviceBorderData{red, .none, 5}
		bottom: DeviceBorderData{red, .solid, 0}
		left: DeviceBorderData{red, .solid, 4}
	})
	assert mixed_commands.len == 1
	assert mixed_commands[0] is FillPath
	assert (mixed_commands[0] as FillPath).color == red
}
