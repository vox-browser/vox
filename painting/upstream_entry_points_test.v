module painting

fn test_upstream_recording_context_preserves_conversion_and_flags() {
	mut context := DisplayListRecordingContext.create(2, Rect{1.25, 2.5, 10, 20}) or { panic(err) }
	assert context.device_pixels_per_css_pixel() == 2
	assert context.enclosing_device_rect(Rect{1.25, 2.5, 10, 20}) == IntRect{2, 5, 20, 40}
	assert context.scale_to_css_size(IntSize{8, 12}) == Size{4, 6}
	context.set_should_paint_overlay(true)
	context.set_should_show_line_box_borders(true)
	context.set_svg_transform(Affine{e: 4, f: 5})
	assert context.should_paint_overlay()
	assert context.should_show_line_box_borders()
	assert context.svg_transform().map_point(Point{}) == Point{4, 5}
}

fn test_upstream_display_player_dispatches_without_losing_context_order() {
	mut list := DisplayList.create(new_accumulated_visual_context_tree())
	assert list.append(FillRect{IntRect{0, 0, 5, 5}, Color{r: 10}}, 0)
	assert list.append(Save{}, 0)
	assert list.append(Restore{}, 0)
	mut player := DisplayListPlayer.create()
	actions := player.execute(list, ScrollStateSnapshot{}, IntRect{0, 0, 20, 20})
	assert actions.map(it.kind) == ['FillRect', 'Save', 'Restore']
	assert player.operations == ['FillRect', 'Save', 'Restore']
	bounds := FillRect{IntRect{1, 2, 3, 4}, Color{}}.bounding_rect() or { panic('missing bounds') }
	assert bounds == IntRect{1, 2, 3, 4}
	assert AddClipRect{IntRect{}}.is_clip()
}

fn test_upstream_paintable_state_keeps_geometry_cache_and_hit_test_in_one_model() {
	mut state := PaintableState.create('box', 'resizable', Rect{10, 20, 100, 50})
	state.metrics = BoxModelMetrics{
		padding: PixelBox{2, 3, 4, 5}
		border:  PixelBox{1, 1, 1, 1}
	}
	assert state.absolute_position() == Point{10, 20}
	assert state.border_box_width() == 110
	assert state.border_box_height() == 58
	assert state.hit_test(Point{10, 20})?.paintable_id == 'box'
	state.set_cached_commands(.foreground, [DisplayListCommand(FillRect{IntRect{0, 0, 1, 1}, Color{}})])
	assert state.has_cached_commands(.foreground)
	assert state.cached_commands(.foreground).len == 1
	state.reset_for_relayout()
	assert !state.has_cached_commands(.foreground)
}

fn test_upstream_gradient_and_scroll_value_entry_points_are_stateful() {
	mut gradient := SVGGradientPaintStyle.create()
	gradient.add_color_stop(ColorStop{color: Color{r: 255}, position: 0.75}, false)
	gradient.add_color_stop(ColorStop{color: Color{b: 255}, position: 0.25}, true)
	gradient.set_spread_method(.reflect)
	gradient.set_gradient_transform(Affine{e: 3})
	assert gradient.color_stops().map(it.position) == [0.25, 0.75]
	assert gradient.spread_method() == .reflect
	assert gradient.gradient_transform()?.map_point(Point{}).x == 3

	geometry := ScrollbarData{
		gutter_rect: Rect{0, 0, 100, 10}
		thumb_rect: Rect{0, 0, 20, 10}
		thumb_travel_to_scroll_ratio: 0.5
	}
	mut scrollbar := Scrollbar.create(.horizontal, geometry)
	scrollbar.mouse_enter()
	assert scrollbar.is_enlarged()
	assert scrollbar.scroll_to_mouse_position(Point{50, 5}) == 0.5
	scrollbar.mouse_leave()
	assert !scrollbar.is_enlarged()
}

fn test_upstream_free_algorithms_retain_color_gradient_and_table_rules() {
	color := Color{r: 90, g: 120, b: 150}
	assert light_color_for_inset_and_outset(color).r > color.r
	assert dark_color_for_inset_and_outset(color).r < color.r
	assert half_ceil(5) == 3
	assert half_floor(5) == 2
	assert row_index_for_element_kind(4, .row)? == 4
	assert row_index_for_element_kind(4, .column) == none
	stops := resolve_color_stop_positions([
		ColorStop{color: Color{r: 255}, position: 0.75},
		ColorStop{color: Color{b: 255}, position: 0.25},
	], false)
	assert stops.list[1].position == 0.75
	assert mix_blend_mode_to_compositing_and_blending_operator(.multiply) == .multiply
}
