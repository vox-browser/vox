module painting

fn test_fragment_index_and_selection_offsets_cover_all_selection_states() {
	fragment := PaintableFragment{
		paintable_id:            'text'
		offset:                  Point{10, 20}
		size:                    Size{40, 10}
		start_offset:            5
		length_in_code_units:    4
		glyphs:                  [GlyphMetric{1, 10}, GlyphMetric{1, 10},
			GlyphMetric{1, 10}, GlyphMetric{1, 10}]
		space_width:             5
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
		baseline:     8
		font_ascent:  12
		font_descent: 5
	}
	assert overflowing.range_rect(.start_and_end, 6, 8) == Rect{20, 16, 20, 17}
}

fn test_paintable_tree_hit_testing_uses_reverse_stacking_order() {
	tree := PaintableTree{
		nodes: [
			PaintableNode{
				id:       'root'
				rect:     Rect{0, 0, 100, 100}
				children: [1, 2]
			},
			PaintableNode{
				id:           'low'
				parent_index: 0
				rect:         Rect{10, 10, 30, 30}
				z_index:      -1
				tree_order:   1
			},
			PaintableNode{
				id:           'high'
				parent_index: 0
				rect:         Rect{10, 10, 30, 30}
				z_index:      2
				tree_order:   2
			},
		]
	}
	hit := tree.hit_test(0, Point{20, 20}, .exact) or { panic('expected hit') }
	assert hit.paintable_id == 'high'
	hidden_tree := PaintableTree{
		nodes: [
			PaintableNode{
				id:      'hidden'
				rect:    Rect{0, 0, 10, 10}
				visible: false
			},
		]
	}
	assert hidden_tree.hit_test(0, Point{1, 1}, .exact) == none
	hidden_fragment_tree := PaintableTree{
		nodes: [
			PaintableNode{
				id:        'hidden-text'
				visible:   false
				fragments: [
					PaintableFragment{
						paintable_id:         'hidden-text'
						size:                 Size{10, 10}
						length_in_code_units: 1
						glyphs:               [GlyphMetric{1, 10}]
					},
				]
			},
		]
	}
	assert hidden_fragment_tree.hit_test(0, Point{1, 1}, .exact) == none
}

fn test_paintable_box_geometry_scrolling_and_cache() {
	mut box := PaintableBox{
		id:                        'box'
		offset:                    Point{10, 20}
		content_size:              Size{100, 50}
		containing_block_position: Point{5, 5}
		box_model:                 BoxModelMetrics{
			padding: PixelBox{2, 3, 4, 5}
			border:  PixelBox{1, 1, 1, 1}
		}
		overflow:                  OverflowData{
			scrollable_overflow_rect: Rect{0, 0, 300, 200}
			has_scrollable_overflow:  true
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
		children:     [
			StackingContext{
				paintable_id: 'positive'
				z_index:      3
				tree_order:   3
			},
			StackingContext{
				paintable_id: 'negative'
				z_index:      -2
				tree_order:   2
			},
			StackingContext{
				paintable_id: 'zero'
				z_index:      0
				tree_order:   1
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

fn test_background_table_control_and_replaced_content_algorithms() {
	layer := ResolvedBackgroundLayer{
		image_id:                    'tile'
		background_positioning_area: Rect{0, 0, 100, 100}
		image_rect:                  Rect{0, 0, 20, 20}
		repeat_x:                    .repeat
		repeat_y:                    .repeat
	}
	tiles := background_tiles(layer, Point{}, Point{}, Rect{0, 0, 45, 45})
	assert tiles.len == 9
	assert tiles[0] == Rect{0, 0, 20, 20}
	strong := ConflictingBorder{
		border:       DeviceBorderData{
			width:      2
			line_style: .solid
		}
		element_kind: .table
	}
	weak := ConflictingBorder{
		border:       DeviceBorderData{
			width:      2
			line_style: .dashed
		}
		element_kind: .cell
	}
	assert resolve_table_border_conflict(strong, weak) == strong
	earlier := ConflictingBorder{
		border:       strong.border
		element_kind: .cell
		tree_order:   2
	}
	later := ConflictingBorder{
		...earlier
		tree_order: 3
	}
	assert resolve_table_border_conflict(later, earlier) == earlier
	assert fieldset_effective_border_top(2, 3, 4, true) == 7
	colors := InputColors{
		accent:     Color{
			r: 1
		}
		base:       Color{
			r: 255
			g: 255
			b: 255
		}
		gray:       Color{
			r: 2
		}
		mid_gray:   Color{
			r: 3
		}
		dark_gray:  Color{
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
	assert command_name(replaced_content_command(.video, 'video', IntRect{0, 0, 10, 10}, IntRect{0, 0, 10, 10},
		.bilinear)) == 'DrawExternalContent'
}
