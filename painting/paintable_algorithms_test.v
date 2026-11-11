module painting

import css
import math
import platform

fn test_to_gfx_scaling_mode_matches_css_image_rendering() {
	assert to_gfx_scaling_mode(.auto_, IntSize{200, 100}, IntSize{100, 50}) == .bilinear_mipmap
	assert to_gfx_scaling_mode(.smooth, IntSize{200, 100}, IntSize{100, 100}) == .bilinear
	assert to_gfx_scaling_mode(.high_quality, IntSize{100, 100}, IntSize{200, 200}) == .bilinear
	assert to_gfx_scaling_mode(.crisp_edges, IntSize{200, 100}, IntSize{100, 50}) == .nearest_neighbor
	assert to_gfx_scaling_mode(.pixelated, IntSize{100, 100}, IntSize{200, 200}) == .nearest_neighbor
}

fn test_image_paintable_translates_object_fit_position_rounding_and_clip() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	mut paintable := ImagePaintable{
		image_rect: Rect{10, 20, 100, 100}
		border_radii: BorderRadiiData{
			top_left: BorderRadiusData{20, 18}
			top_right: BorderRadiusData{16, 14}
			bottom_right: BorderRadiusData{12, 10}
			bottom_left: BorderRadiusData{8, 6}
		}
		border_widths: PixelBox{6, 5, 4, 3}
		object_fit: .contain
		object_position: css.Position{
			offset_x: css.LengthPercentage.from_percentage(css.Percentage.new(50))
			offset_y: css.LengthPercentage.from_percentage(css.Percentage.new(50))
		}
		resolution_context: css.LengthResolutionContext.default()
		image_rendering: .auto_
	}
	contain := paintable.paint('image', IntRect{0, 0, 200, 50}, converter) or {
		panic('expected contain image paint')
	}
	assert contain.bitmap.destination == IntRect{10, 58, 100, 25}
	assert contain.bitmap.clip_rect == IntRect{10, 20, 100, 100}
	// C++ chooses this from the 100x100 content box. Choosing from the fitted
	// 100x25 destination instead would incorrectly select bilinear-mipmap.
	assert contain.bitmap.scaling == .bilinear
	assert contain.clip_radii == CornerRadii{
		top_left: CornerRadius{17, 12}
		top_right: CornerRadius{11, 8}
		bottom_right: CornerRadius{7, 6}
		bottom_left: CornerRadius{5, 2}
	}

	paintable = ImagePaintable{
		...paintable
		object_fit: .cover
		object_position: css.Position{
			offset_x: css.LengthPercentage.from_percentage(css.Percentage.new(25))
			offset_y: css.LengthPercentage.from_percentage(css.Percentage.new(70))
		}
	}
	cover := paintable.paint('image', IntRect{0, 0, 200, 50}, converter) or {
		panic('expected cover image paint')
	}
	assert cover.bitmap.destination == IntRect{-65, 20, 400, 100}

	paintable = ImagePaintable{
		...paintable
		object_fit: .none_
		object_position: css.Position{
			offset_x: css.LengthPercentage.from_length(css.Length.make_px(9))
			offset_y: css.LengthPercentage.from_length(css.Length.make_px(5))
		}
	}
	none_fit := paintable.paint('image', IntRect{0, 0, 200, 50}, converter) or {
		panic('expected unscaled image paint')
	}
	assert none_fit.bitmap.destination == IntRect{19, 25, 200, 50}

	paintable = ImagePaintable{
		...paintable
		object_fit: .scale_down
		object_position: css.Position{}
	}
	large_scale_down := paintable.paint('image', IntRect{0, 0, 200, 50}, converter) or {
		panic('expected large scale-down image paint')
	}
	assert large_scale_down.bitmap.destination == IntRect{10, 58, 100, 25}
	small_scale_down := paintable.paint('image', IntRect{0, 0, 50, 50}, converter) or {
		panic('expected small scale-down image paint')
	}
	assert small_scale_down.bitmap.destination == IntRect{35, 45, 50, 50}

	paintable = ImagePaintable{
		...paintable
		object_fit: .fill
		is_svg_image: true
	}
	svg := paintable.paint('svg', IntRect{0, 0, 200, 50}, converter) or {
		panic('expected SVG image paint')
	}
	assert svg.bitmap.destination == IntRect{10, 20, 100, 100}

	paintable = ImagePaintable{
		...paintable
		object_fit: .none_
		is_svg_image: false
		object_position: css.Position{
			offset_x: css.LengthPercentage.from_percentage(css.Percentage.new(50))
			offset_y: css.LengthPercentage.from_percentage(css.Percentage.new(50))
		}
		intrinsic_size: css.SizeWithAspectRatio{
			aspect_ratio: css.CSSPixelFraction.new(css.CSSPixels.new(5), css.CSSPixels.new(3))
		}
	}
	ratio_only := paintable.paint('svg-ratio', IntRect{0, 0, 100, 100}, converter) or {
		panic('expected aspect-ratio-only image paint')
	}
	assert ratio_only.bitmap.destination == IntRect{10, 40, 100, 60}
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

	font := &platform.Font{ point_size: 16 }
	retained_run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ advance: 7, length_in_code_units: 1 },
		platform.Glyph{ advance: 13, length_in_code_units: 1 },
	])
	retained := PaintableFragment{
		offset: Point{3, 4}
		size: Size{20, 10}
		start_offset: 2
		length_in_code_units: 2
		glyph_run: retained_run
	}
	assert retained.glyphs.len == 0
	assert retained.range_rect(.start_and_end, 3, 4) == Rect{10, 4, 13, 10}
}

fn test_fragment_splits_ligatures_for_hit_testing_and_selection() {
	font := &platform.Font{ point_size: 16 }
	ligature_run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ advance: 10, length_in_code_units: 1 },
		platform.Glyph{ advance: 0, length_in_code_units: 1 },
		platform.Glyph{ advance: 30, length_in_code_units: 3 },
		platform.Glyph{ advance: 10, length_in_code_units: 1 },
		platform.Glyph{ advance: 10, length_in_code_units: 1 },
	])
	fragment := PaintableFragment{
		text_value: 'office'
		offset: Point{5, 8}
		size: Size{60, 12}
		length_in_code_units: 6
		glyph_run: ligature_run
	}
	assert fragment.index_in_node_for_point(Point{7.5, 8}) == 0
	assert fragment.index_in_node_for_point(Point{17.5, 8}) == 1
	assert fragment.index_in_node_for_point(Point{27.5, 8}) == 2
	assert fragment.index_in_node_for_point(Point{37.5, 8}) == 3
	assert fragment.index_in_node_for_point(Point{47.5, 8}) == 4
	assert fragment.index_in_node_for_point(Point{57.5, 8}) == 5
	assert fragment.range_rect(.start_and_end, 1, 2) == Rect{15, 8, 10, 12}
	assert fragment.range_rect(.start_and_end, 2, 3) == Rect{25, 8, 10, 12}
	assert fragment.range_rect(.start_and_end, 3, 4) == Rect{35, 8, 10, 12}
}

fn test_fragment_hit_testing_keeps_combining_graphemes_together() {
	font := &platform.Font{ point_size: 16 }
	run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ advance: 20, length_in_code_units: 2 },
		platform.Glyph{ advance: 10, length_in_code_units: 1 },
	])
	fragment := PaintableFragment{
		text_value: 'áb'
		size: Size{30, 10}
		length_in_code_units: 3
		glyph_run: run
	}
	assert fragment.index_in_node_for_point(Point{4, 0}) == 0
	assert fragment.index_in_node_for_point(Point{11, 0}) == 2
	assert fragment.index_in_node_for_point(Point{24, 0}) == 2
}

fn test_repeated_fragment_hit_testing_releases_grapheme_workspace() {
	font := &platform.Font{point_size:16}
	run := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{advance:20,length_in_code_units:2},
		platform.Glyph{advance:10,length_in_code_units:1},
	])
	fragment := PaintableFragment{
		text_value: 'áb'
		size: Size{30,10}
		length_in_code_units: 3
		glyph_run: run
	}
	// Warm process-wide Unicode metadata before accounting for temporaries.
	assert fragment.index_in_node_for_point(Point{11,0}) == 2
	before := platform.thread_arena_usage().used
	for _ in 0 .. 500 {
		assert fragment.index_in_node_for_point(Point{4,0}) == 0
		assert fragment.index_in_node_for_point(Point{11,0}) == 2
	}
	$if prealloc { assert platform.thread_arena_usage().used == before }
	assert run.glyphs().len == 2
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
	tiles := background_tiles(layer, Point{}, Rect{0, 0, 45, 45})
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
	fieldset := FieldSetPaintable{
		border_rect: Rect{10, 10, 208, 88}
		css_border_top: 6
		legend_margin_box_height: 26
		legend_border_rect: Rect{24, 10, 80, 26}
	}
	assert fieldset.effective_border_top() == 26
	assert fieldset.visual_border_box_rect() == Rect{10, 20, 208, 78}
	converter := new_device_pixel_converter(1) or { panic(err) }
	background_clip := fieldset.background_clip_rect(converter) or { panic('missing background clip') }
	assert background_clip == IntRect{10, 20, 208, 78}
	fieldset_without_legend := FieldSetPaintable{
		border_rect: Rect{10, 10, 208, 88}
		css_border_top: 6
	}
	plain_background_clip := fieldset_without_legend.background_clip_rect(converter) or {
		panic('missing plain fieldset background clip')
	}
	assert plain_background_clip == IntRect{10, 10, 208, 88}
	red_border := BorderData{Color{220, 0, 0, 255}, .solid, 6}
	fieldset_border_commands := fieldset.paint(BordersData{
		top: red_border
		right: red_border
		bottom: red_border
		left: red_border
	}.to_device_pixels(converter), CornerRadii{}, converter)
	clipped_top_commands := fieldset_border_commands.filter(it.clip != none)
	assert clipped_top_commands.len == 0
	top_border_runs := fieldset_border_commands.filter(it.command is FillRect)
	assert top_border_runs.len == 2
	assert (top_border_runs[0].command as FillRect).rect == IntRect{10, 20, 14, 6}
	assert (top_border_runs[1].command as FillRect).rect == IntRect{104, 20, 114, 6}
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
		light_gray: Color{
			r: 5
		}
	}
	checked := checkbox_commands(IntRect{0, 0, 20, 20}, true, false, true, false, .light, colors)
	assert checked.len == 2
	assert checked[1] is FillPath
	checkmark := checked[1] as FillPath
	assert checkmark.color == Color{255, 255, 255, 255}
	assert checkmark.winding_rule == .even_odd
	assert math.abs(checkmark.path.polygon[0].x - 14.4) < 0.0001
	assert math.abs(checkmark.path.polygon[0].y - 2.8) < 0.0001
	assert math.abs(checkmark.path.polygon[5].x - 17) < 0.0001
	assert math.abs(checkmark.path.polygon[5].y - 4.8) < 0.0001
	indeterminate := checkbox_commands(IntRect{0, 0, 20, 20}, false, true, true, false, .light, colors)
	assert indeterminate.len == 3
	assert indeterminate[2] is FillRoundedRect
	dash := indeterminate[2] as FillRoundedRect
	assert dash.rect == IntRect{4, 8, 12, 4}
	assert radio_button_commands(IntRect{0, 0, 13, 13}, true, true, false, .light, colors).len == 3
	control_converter := new_device_pixel_converter(1) or { panic(err) }
	assert centered_form_control_rect(Rect{10, 20, 30, 20}, control_converter) == IntRect{15, 20, 20, 20}
	assert centered_form_control_rect(Rect{10, 20, 20, 30}, control_converter) == IntRect{10, 25, 20, 20}
	assert centered_form_control_rect(Rect{0.25, 0.25, 20.5, 10.5}, control_converter) == IntRect{5, 0, 11, 11}
	computed_colors := compute_input_colors(.light, css.Color{255, 0, 0, 255})
	assert computed_colors.accent == Color{255, 0, 0, 255}
	assert computed_colors.base == Color{255, 255, 255, 255}
	assert computed_colors.dark_gray == Color{76, 76, 76, 255}
	assert computed_colors.gray == Color{148, 148, 148, 255}
	assert computed_colors.mid_gray == Color{180, 180, 180, 255}
	assert computed_colors.light_gray == Color{202, 202, 202, 255}
	assert command_name(marker_command(.disc, IntRect{0, 0, 5, 5}, Color{})) == 'FillEllipse'
	closed_marker := marker_command(.disclosure_closed, IntRect{10, 20, 8, 6}, Color{})
	assert closed_marker is FillPath
	closed_path := closed_marker as FillPath
	assert closed_path.winding_rule == .even_odd
	assert closed_path.path.segments.len == 4
	assert closed_path.path.polygon[0] == Point{10, 20}
	assert math.abs(closed_path.path.polygon[1].x - 16.928203224) < 0.000001
	assert closed_path.path.polygon[1].y == 23
	assert closed_path.path.polygon[2] == Point{10, 26}
	marker := MarkerPaintable{
		marker_rect: Rect{0.4, 1.6, 4.4, 5.5}
		kind: .circle
		color: Color{1, 2, 3, 255}
	}
	marker_commands := marker.paint(new_device_pixel_converter(1) or { panic(err) })
	assert marker_commands.len == 1
	assert marker_commands[0] is DrawEllipse
	assert (marker_commands[0] as DrawEllipse).rect == IntRect{0, 2, 4, 6}
	open_kind := marker_kind_from_name('disclosure-open') or { panic('missing marker kind') }
	assert open_kind == .disclosure_open
	assert marker_kind_from_name('unknown') == none
}

fn test_canvas_paintable_presents_external_content_with_source_geometry() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	paintable := CanvasPaintable{
		canvas_rect: Rect{10.4, 20.6, 99.2, 49.1}
		border_radii: BorderRadiiData{
			top_left: BorderRadiusData{20, 18}
			top_right: BorderRadiusData{16, 14}
			bottom_right: BorderRadiusData{12, 10}
			bottom_left: BorderRadiusData{8, 6}
		}
		border_widths: PixelBox{6, 5, 4, 3}
		image_rendering: .auto_
	}
	result := paintable.paint('canvas', IntSize{100, 100}, converter) or {
		panic('expected canvas paint')
	}
	assert result.content.destination == IntRect{10, 21, 100, 49}
	assert result.content.source_id == 'canvas'
	// Only the height shrinks, so the source selects bilinear rather than the
	// bilinear-mipmap mode used when both dimensions shrink.
	assert result.content.scaling == .bilinear
	assert result.clip_rect == result.content.destination
	assert result.clip_radii == CornerRadii{
		top_left: CornerRadius{17, 12}
		top_right: CornerRadius{11, 8}
		bottom_right: CornerRadius{7, 6}
		bottom_left: CornerRadius{5, 2}
	}
	assert paintable.paint('empty', IntSize{}, converter) == none
}

fn test_video_paintable_switches_between_video_source_poster_and_transparent_content() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	mut source := VideoFrameSource.create()
	source.update(&MediaVideoFrame{
		width: 200
		height: 100
	})
	paintable := VideoPaintable{
		video_rect: Rect{5, 7, 100, 50}
		border_radii: BorderRadiiData{
			top_left: BorderRadiusData{12, 12}
			top_right: BorderRadiusData{12, 12}
			bottom_right: BorderRadiusData{12, 12}
			bottom_left: BorderRadiusData{12, 12}
		}
		border_widths: PixelBox{2, 2, 2, 2}
		image_rendering: .auto_
		natural_media_size: IntSize{200, 100}
	}
	video_frame := paintable.paint(.video_frame, 'video', none, source, converter) or {
		panic('expected video frame paint')
	}
	assert video_frame.content is DrawVideoFrameSource
	video_content := video_frame.content as DrawVideoFrameSource
	assert video_content.destination == IntRect{5, 7, 100, 50}
	assert video_content.scaling == .bilinear_mipmap
	assert video_content.source == source
	assert video_frame.clip_radii.top_left == CornerRadius{10, 10}
	contained := VideoPaintable{
		video_rect: Rect{0, 0, 100, 100}
		object_fit: .contain
		natural_media_size: IntSize{200, 100}
	}.paint(.video_frame, 'video', none, source, converter) or {
		panic('expected naturally sized video paint')
	}
	assert (contained.content as DrawVideoFrameSource).destination == IntRect{0, 25, 100, 50}
	assert VideoPaintable{
		video_rect: Rect{0, 0, 100, 100}
	}.paint(.video_frame, 'video', none, none, converter) == none

	poster := paintable.paint(.poster_frame, 'poster', IntSize{200, 100}, none, converter) or {
		panic('expected poster paint')
	}
	assert poster.content is DrawScaledDecodedImageFrame
	poster_content := poster.content as DrawScaledDecodedImageFrame
	assert poster_content.destination == IntRect{5, 7, 100, 50}
	assert poster_content.clip_rect == poster_content.destination
	assert poster_content.scaling == .bilinear_mipmap

	transparent_result := paintable.paint(.transparent_black, '', none, none, converter) or {
		panic('expected transparent video paint')
	}
	assert transparent_result.content is FillRect
	assert (transparent_result.content as FillRect).color == transparent
	assert paintable.paint(.poster_frame, '', none, none, converter) == none
}

fn test_navigable_container_viewport_paintable_clips_and_places_nested_display_list() {
	converter := new_device_pixel_converter(1) or { panic(err) }
	paintable := NavigableContainerViewportPaintable{
		viewport_rect: Rect{10.25, 20.75, 99.5, 49.5}
		border_radii: BorderRadiiData{
			top_left: BorderRadiusData{18, 16}
			top_right: BorderRadiusData{14, 12}
			bottom_right: BorderRadiusData{10, 8}
			bottom_left: BorderRadiusData{6, 4}
		}
		border_widths: PixelBox{5, 4, 3, 2}
	}
	result := paintable.paint(converter) or { panic('expected nested viewport paint') }
	assert result.clip_rect == IntRect{10, 21, 100, 49}
	assert result.nested_rect == IntRect{10, 20, 100, 50}
	assert result.clip_radii == CornerRadii{
		top_left: CornerRadius{16, 11}
		top_right: CornerRadius{10, 7}
		bottom_right: CornerRadius{6, 5}
		bottom_left: CornerRadius{4, 1}
	}
	assert NavigableContainerViewportPaintable{
		viewport_rect: Rect{0, 0, 0, 10}
	}.paint(converter) == none
}

fn test_native_input_control_colors_follow_active_disabled_and_contrast_paths() {
	colors := compute_input_colors(.light, css.Color{255, 0, 0, 255})
	active_checkbox := checkbox_commands(IntRect{0, 0, 20, 20}, true, false, true, true, .light, colors)
	assert active_checkbox[0] is FillRoundedRect
	assert (active_checkbox[0] as FillRoundedRect).color == Color{255, 76, 76, 255}

	disabled_checkbox := checkbox_commands(IntRect{0, 0, 20, 20}, true, false, false, false, .light, colors)
	assert disabled_checkbox[0] is FillRoundedRect
	assert (disabled_checkbox[0] as FillRoundedRect).color == colors.mid_gray
	assert disabled_checkbox[1] is FillPath
	assert (disabled_checkbox[1] as FillPath).color == Color{255, 255, 255, 255}
	disabled_radio := radio_button_commands(IntRect{0, 0, 20, 20}, true, false, false, .light, colors)
	assert (disabled_radio[1] as FillRoundedRect).color == colors.light_gray
	// CheckBoxPaintable keeps the original when neither it nor its inverse
	// clears the minimum contrast ratio.
	middle_gray := Color{128, 128, 128, 255}
	assert increase_input_color_contrast(middle_gray, middle_gray) == middle_gray

	light_accent := compute_input_colors(.light, css.Color{255, 255, 255, 255})
	radio := radio_button_commands(IntRect{0, 0, 13, 13}, true, true, false, .light, light_accent)
	assert radio[0] is FillRoundedRect
	assert (radio[0] as FillRoundedRect).color == light_accent.accent
	assert radio[1] is FillRoundedRect
	assert (radio[1] as FillRoundedRect).color == light_accent.dark_gray
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
	// C++ converts 100/3 back to fixed-point CSSPixels by truncation, then
	// restores the auto Y dimension with CSSPixelFraction multiplication.
	assert resolved.image_rect.width == 33.328125
	assert resolved.image_rect.height == 16.65625
	assert resolved.position_x == 16.65625
	assert resolved.position_y == 16.671875
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
	space_tiles := background_tiles(space_layer, Point{}, Rect{0, 0, 100, 20})
	assert space_tiles == [Rect{0, 0, 30, 20}, Rect{35, 0, 30, 20}, Rect{70, 0, 30, 20}]

	local_layer := ResolvedBackgroundLayer{
		...space_layer
		attachment: .local
		repeat_x: .no_repeat
	}
	local_tiles := background_tiles(local_layer, Point{7, 3}, Rect{-10, -10, 100, 100})
	assert local_tiles == [Rect{-7, -3, 30, 20}]
	fixed_layer := ResolvedBackgroundLayer{
		...space_layer
		attachment: .fixed
		repeat_x: .no_repeat
	}
	fixed_tiles := background_tiles(fixed_layer, Point{}, Rect{0, 0, 100, 100})
	assert fixed_tiles == [Rect{0, 0, 30, 20}]
	limited := background_tiles_limited(space_layer, Point{}, Rect{0, 0, 100, 20}, 2)
	assert limited == [Rect{0, 0, 30, 20}, Rect{35, 0, 30, 20}]
	repeat_layer := ResolvedBackgroundLayer{
		...space_layer
		position_x: 83.328125
		image_rect: Rect{0, 0, 33.328125, 20}
		repeat_x: .repeat
	}
	plan := background_tile_plan(repeat_layer, Point{}, Rect{0, 0, 100, 20})
	assert plan.can_use_repeated_bitmap()
	assert plan.first_tile == Rect{-15.671875, 0, 33.328125, 20}
	assert plan.x_step == 33.328125
	assert !background_tile_plan(space_layer, Point{}, Rect{0, 0, 100, 20}).can_use_repeated_bitmap()

	// Ladybird f347d88af69b: both axes preserve the fractional remainder in
	// double precision. A float remainder would push the last tile too far.
	large_space_layer := ResolvedBackgroundLayer{
		...space_layer
		background_positioning_area: Rect{0, 0, 1_000_000.015625, 1_000_000.015625}
		image_rect: Rect{0, 0, 300_000.015625, 300_000.015625}
		repeat_y: .space
	}
	large_plan := background_tile_plan(large_space_layer, Point{}, large_space_layer.background_positioning_area)
	assert large_plan.x_step == 350_000
	assert large_plan.y_step == 350_000
	large_tiles := background_tiles(large_space_layer, Point{}, large_space_layer.background_positioning_area)
	assert large_tiles.len == 9
	assert large_tiles.last().right() == large_space_layer.background_positioning_area.right()
	assert large_tiles.last().bottom() == large_space_layer.background_positioning_area.bottom()
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
