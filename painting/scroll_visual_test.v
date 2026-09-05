module painting

fn append_scroll_frame_index(indices_pointer &[]int, index int) {
	unsafe {
		mut indices := *indices_pointer
		indices << index
		*indices_pointer = indices
	}
}

fn test_scroll_state_hierarchy_snapshot_and_clear() {
	mut state := ScrollState{}
	root := state.create_scroll_frame_for('root', 0)
	sticky := state.create_sticky_frame_for('sticky', root)
	child := state.create_scroll_frame_for('child', sticky)
	mut root_frame := state.frame_at(root)
	root_frame.set_own_offset(Point{-10, -20})
	mut sticky_frame := state.frame_at(sticky)
	sticky_frame.set_own_offset(Point{2, 3})
	mut child_frame := state.frame_at(child)
	child_frame.set_own_offset(Point{-5, 0})
	assert state.cumulative_offset(child) == Point{-13, -17}
	assert state.nearest_scrolling_ancestor(child) == root
	mut scrolling := []int{}
	scrolling_pointer := &scrolling
	state.for_each_scroll_frame(fn [scrolling_pointer] (index int, mut _ ScrollFrame) {
		append_scroll_frame_index(scrolling_pointer, index)
	})
	mut sticky_frames := []int{}
	sticky_frames_pointer := &sticky_frames
	state.for_each_sticky_frame(fn [sticky_frames_pointer] (index int, mut _ ScrollFrame) {
		append_scroll_frame_index(sticky_frames_pointer, index)
	})
	assert scrolling == [root, child]
	assert sticky_frames == [sticky]
	snapshot := state.snapshot(2)
	assert snapshot.device_offset_for_index(root) == Point{-20, -40}
	assert snapshot.device_offset_for_index(99) == Point{}
	state.for_each_scroll_frame(fn (_ int, mut frame ScrollFrame) {
		frame.set_own_offset(frame.own_offset().add(Point{1, 1}))
	})
	assert state.frame_at(root).own_offset() == Point{-9, -19}
	assert state.frame_at(child).own_offset() == Point{-4, 1}
	root_frame.set_own_offset(Point{0.1, -0.1})
	rounded_snapshot := state.snapshot(1.5)
	assert rounded_snapshot.device_offset_for_index(root) == Point{
		x: f64(f32(0.1) * f32(1.5))
		y: f64(f32(-0.1) * f32(1.5))
	}
	previous_capacity := state.frames.cap
	state.clear()
	assert state.frames.len == 1
	assert state.frames.cap == previous_capacity
}

fn test_scrollbar_thumb_geometry_and_source_pointer_state_machine() {
	metrics := new_chrome_metrics(1) or { panic(err) }
	input := ScrollbarGeometryInput{
		direction: .vertical
		padding_rect: Rect{0, 0, 100, 200}
		scrollable_overflow: Rect{0, 0, 100, 800}
		scroll_offset: Point{0, 300}
		metrics: metrics
		with_gutter: true
	}
	data := paintable_box_compute_scrollbar_data(input) or { panic('expected scrollbar') }
	assert paintable_box_available_scrollbar_length(input) == 200
	assert paintable_box_absolute_scrollbar_rect(input) == Rect{88, 0, 12, 200}
	assert data.gutter_rect == Rect{88, 0, 12, 200}
	assert data.thumb_rect.width == 8
	assert data.thumb_rect.height == 49
	assert data.thumb_rect.y > 70 && data.thumb_rect.y < 80

	mut scrollbar := Scrollbar.create(.vertical)
	assert scrollbar.direction() == .vertical
	assert !scrollbar.is_enlarged()
	assert scrollbar.contains(Point{96, 80}, input)
	interaction := ScrollbarInteractionInput{
		geometry: input
	}
	assert scrollbar.handle_pointer_event('pointermove', 0, Point{96, 80}, interaction) == .none
	assert scrollbar.handle_pointer_event('pointerdown', 1, Point{96, 80}, interaction) == .none

	scrollbar.mouse_enter()
	assert scrollbar.is_enlarged()
	assert scrollbar.take_repaint_request()
	assert !scrollbar.take_repaint_request()
	// Clicking below the thumb uses the source's constrained half-thumb grab
	// point and jumps directly to the bottom of this gutter.
	assert scrollbar.handle_pointer_event('pointerdown', 0, Point{94, 180}, interaction) == .capture_input
	assert scrollbar.take_requested_scroll_offset() or { panic('missing scrollbar offset') } == Point{0, 600}
	assert scrollbar.take_repaint_request()
	// The retained grab position keeps dragging even when no current hit target
	// is present. The legacy private mouse_move path swallows that event.
	assert scrollbar.mouse_move(Point{94, 100}, interaction) == .swallow_event
	dragged := scrollbar.take_requested_scroll_offset() or { panic('missing dragged offset') }
	assert dragged.y == 282.125
	assert scrollbar.mouse_up(Point{}, 0) == .none
	assert scrollbar.take_repaint_request()
	scrollbar.mouse_leave()
	assert !scrollbar.is_enlarged()
}

fn test_paintable_box_scrollbar_and_resizer_rects_preserve_source_edge_cases() {
	metrics := new_chrome_metrics(1) or { panic(err) }
	horizontal := ScrollbarGeometryInput{
		direction: .horizontal
		padding_rect: Rect{5, 7, 100, 50}
		scrollable_overflow: Rect{5, 7, 200, 50}
		metrics: metrics
		chrome_mirrored: true
		has_other_scrollbar: true
	}
	assert paintable_box_available_scrollbar_length(horizontal) == 88
	assert paintable_box_absolute_scrollbar_rect(horizontal) == Rect{17, 49, 88, 8}

	// PaintableBox does not clamp the resizer-adjusted length. Preserve that
	// signed geometry here; later device clipping decides whether it is visible.
	tiny_resizable := ScrollbarGeometryInput{
		direction: .vertical
		padding_rect: Rect{3, 4, 5, 6}
		scrollable_overflow: Rect{3, 4, 5, 20}
		metrics: metrics
		has_resizer: true
	}
	assert paintable_box_available_scrollbar_length(tiny_resizable) == -6
	assert paintable_box_absolute_scrollbar_rect(tiny_resizable) == Rect{0, 4, 8, -6}
	assert paintable_box_absolute_resizer_rect(tiny_resizable.padding_rect, true, false, metrics) or { panic('expected resizer') } == Rect{-4, -2, 12, 12}
	assert paintable_box_absolute_resizer_rect(tiny_resizable.padding_rect, true, true, metrics) or { panic('expected mirrored resizer') } == Rect{3, -2, 12, 12}
	assert paintable_box_absolute_resizer_rect(tiny_resizable.padding_rect, false, false, metrics) == none
}

fn test_resize_handle_and_backing_store_state_machines() {
	mut handle := ResizeHandle.create()
	assert handle.handle_pointer_event('pointerdown', 1, Point{1, 1}) == .none
	assert handle.handle_pointer_event('pointerdown', 0, Point{2, 3}) == .capture_input
	assert handle.is_resizing
	assert handle.origin == Point{2, 3}
	assert handle.last_point == Point{}
	assert handle.handle_pointer_event('pointermove', 9, Point{4, 6}) == .capture_input
	assert handle.last_point == Point{4, 6}
	assert handle.handle_pointer_event('pointerup', 0, Point{5, 7}) == .none
	assert !handle.is_resizing
	assert handle.last_point == Point{5, 7}
	assert handle.cursor(PhysicalResizeAxes{true, true}, false) == .se_resize
	assert handle.cursor(PhysicalResizeAxes{true, true}, true) == .sw_resize
	assert handle.cursor(PhysicalResizeAxes{}, false) == .ew_resize
	handle.mouse_enter()
	handle.mouse_leave()
	mut manager := BackingStoreManager{}
	assert manager.resize_if_needed(IntSize{800, 600}, true, true, false)
	assert manager.allocated_size == IntSize{1056, 856}
	assert !manager.resize_if_needed(IntSize{700, 500}, true, true, false)
	assert manager.resize_if_needed(IntSize{700, 500}, false, true, false)
	assert manager.allocated_size == IntSize{700, 500}
	assert manager.front_bitmap_id == 3
	assert manager.back_bitmap_id == 4
}

fn test_visual_context_tree_ancestry_transform_clip_and_empty_propagation() {
	mut tree := new_accumulated_visual_context_tree()
	transform := tree.append(TransformVisualData{
		origin: Point{10, 10}
		matrix: Affine{
			a: 2
			d: 2
		}
	}, 0)
	clip := tree.append(ClipVisualData{ rect: IntRect{0, 0, 100, 100} }, transform)
	effect := tree.append(EffectsVisualData{ opacity: 0.5 }, clip)
	sibling := tree.append(ScrollVisualData{ scroll_frame_index: 1 }, transform)
	assert tree.find_common_ancestor(effect, sibling) == transform
	assert tree.is_effect(effect)
	point := tree.transform_point_for_hit_test(effect, Point{30, 30}, ScrollStateSnapshot{}) or {
		panic('expected hit')
	}
	assert point == Point{20, 20}
	assert tree.transform_point_for_hit_test(effect, Point{500, 500}, ScrollStateSnapshot{}) == none
	assert tree.inverse_transform_point(effect, Point{30, 30}) == Point{20, 20}
	assert tree.transform_rect_to_viewport(effect, Rect{10, 10, 5, 5}, ScrollStateSnapshot{}) == Rect{10, 10, 10, 10}
	empty := tree.append(ClipVisualData{ rect: IntRect{} }, 0)
	child := tree.append(EffectsVisualData{}, empty)
	assert tree.nodes[empty].has_empty_effective_clip
	assert tree.nodes[child].has_empty_effective_clip
	image_mask := tree.append(SVGMaskVisualData{
		bounding_rect: IntRect{0, 0, 100, 50}
		operations: [SVGMaskPaintOperation{
			kind: .image
			image_url: 'https://example.test/mask.png'
			image_rect: Rect{0, 0, 100, 50}
		}]
	}, 0)
	assert !tree.nodes[image_mask].has_empty_effective_clip
	double_wound_square := [Point{0, 0}, Point{10, 0}, Point{10, 10}, Point{0, 10}, Point{0, 0},
		Point{10, 0}, Point{10, 10}, Point{0, 10}]
	nonzero_clip := ClipPathVisualData{
		bounding_rect: IntRect{0, 0, 10, 10}
		polygon: double_wound_square
	}
	even_odd_clip := ClipPathVisualData{
		...nonzero_clip
		fill_rule: .even_odd
	}
	assert nonzero_clip.contains(Point{5, 5})
	assert !even_odd_clip.contains(Point{5, 5})
	hole_clip := ClipPathVisualData{
		bounding_rect: IntRect{0, 0, 10, 10}
		polygons: [
			[Point{0, 0}, Point{10, 0}, Point{10, 10}, Point{0, 10}],
			[Point{2, 2}, Point{8, 2}, Point{8, 8}, Point{2, 8}],
		]
		fill_rule: .even_odd
	}
	assert hole_clip.contains(Point{1, 1})
	assert !hole_clip.contains(Point{5, 5})
	assert !EffectsVisualData{}.needs_layer()
	assert EffectsVisualData{
		opacity: 0.5
	}.needs_layer()
}

fn test_visual_context_hit_test_ancestor_chain_inline_and_overflow_paths_match() {
	mut tree := new_accumulated_visual_context_tree()
	mut current := 0
	for _ in 0 .. inline_visual_context_ancestor_capacity {
		current = tree.append(TransformVisualData{
			matrix: Affine{
				a: 1
				d: 1
				e: 1
			}
		}, current)
	}
	// Eight ancestors use the source Vector<size_t, 8>-shaped stack path.
	inline_result := tree.transform_point_for_hit_test(current, Point{20, 10}, ScrollStateSnapshot{}) or {
		panic('missing inline-chain transform result')
	}
	assert inline_result == Point{12, 10}
	assert tree.inverse_transform_point(current, Point{20, 10}) == Point{12, 10}

	// The ninth ancestor exercises the dynamically sized fallback without
	// changing transform ordering or results.
	current = tree.append(TransformVisualData{
		matrix: Affine{
			a: 1
			d: 1
			e: 1
		}
	}, current)
	overflow_result := tree.transform_point_for_hit_test(current, Point{20, 10}, ScrollStateSnapshot{}) or {
		panic('missing overflow-chain transform result')
	}
	assert overflow_result == Point{11, 10}
	assert tree.inverse_transform_point(current, Point{20, 10}) == Point{11, 10}
}
