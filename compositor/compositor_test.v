@[has_globals]
module compositor

import math
import painting

__global screenshot_callback_count int

fn screenshot_finished() {
	screenshot_callback_count++
}

fn near(actual f64, expected f64) bool {
	return math.abs(actual - expected) < 0.0001
}

fn scroll_test_node(document_id u64, index int, parent ?AsyncScrollNodeId, viewport bool) AsyncScrollNode {
	return AsyncScrollNode{
		node_id: AsyncScrollNodeId{document_id, index}
		stable_node_id: AsyncScrollNodeStableId{ node_id: u64(index) }
		parent_node_id: parent
		scrollport_rect: painting.IntRect{0, 0, 200, 200}
		min_scroll_offset: painting.Point{}
		max_scroll_offset: painting.Point{100, 100}
		is_viewport: viewport
		can_be_wheel_scrolled_horizontally: true
		can_be_wheel_scrolled_vertically: true
	}
}

fn test_context_ids_and_smooth_scroll_sampling() {
	assert compositor_context_id_for_page(7)! == 7
	if _ := compositor_context_id_for_page(0) {
		assert false
	}
	smooth := new_smooth_scroll_animation(painting.Point{}, painting.Point{100, 0}, 1, .smooth_scroll)!
	assert near(smooth.duration(), 0.1)
	middle := smooth.sample(0.05)
	assert near(middle.offset.x, 50)
	assert !middle.complete
	assert smooth.sample(0.1) == SmoothScrollSample{painting.Point{100, 0}, true}
	momentum := new_smooth_scroll_animation(painting.Point{}, painting.Point{10000, 0}, 1, .momentum)!
	assert momentum.duration() <= 5
	assert momentum.sample(momentum.duration() / 2).offset.x > 5000
}

fn test_async_scroll_ipc_records_round_trip_and_reject_truncation() {
	updates := PendingAsyncScrollUpdates{
		sequence: 17
		scroll_offsets: [AsyncScrollOffset{
			stable_node_id: AsyncScrollNodeStableId{
				node_id: 42
				kind: .pseudo_element
				pseudo_element_type: 3
			}
			compositor_scroll_offset: painting.Point{1.25, -2.5}
			unadopted_scroll_delta: painting.Point{3, 4}
		}]
		completed_operation_ids: [AsyncScrollOperationId(8), 9]
		operation_ids_taken_over_by_user_input: [AsyncScrollOperationId(10)]
		user_scroll_gesture_in_progress: true
		user_scroll_gesture_ended: false
	}
	encoded := encode_pending_async_scroll_updates(updates)
	assert decode_pending_async_scroll_updates(encoded)! == updates
	result := AsyncScrollEnqueueResult{
		accepted: true
		operation_id: 99
	}
	assert decode_async_scroll_enqueue_result(encode_async_scroll_enqueue_result(result))! == result
	if _ := decode_pending_async_scroll_updates(encoded[..encoded.len - 1]) {
		assert false
	} else {
		assert err.msg().starts_with('IPC:')
	}
}

fn test_display_list_metadata_builds_stable_scroll_state() {
	list := CompositorDisplayList{
		metadata: AsyncScrollingMetadata{
			viewport_rect: painting.IntRect{0, 0, 800, 600}
			wheel_event_listener_state_generation: 12
		}
		commands: [CompositorDisplayListCommand(CompositorScrollNodeCommand{
			document_id: 10
			scroll_node_index: 1
			scrollable_node_id: 20
			is_viewport: true
		}), CompositorDisplayListCommand(CompositorScrollNodeCommand{
			document_id: 10
			scroll_node_index: 2
			scrollable_node_id: 21
			parent_scroll_node_index: 1
		}), CompositorDisplayListCommand(CompositorWheelHitTestTargetCommand{
			context: ContextRef{3}
			document_id: 10
			target_scroll_node_index: 2
			rect: painting.Rect{0, 0, 100, 100}
		}), CompositorDisplayListCommand(CompositorBlockingWheelEventRegionCommand{
			context: ContextRef{3}
			rect: painting.Rect{10, 10, 20, 20}
		})]
		structural_epoch: 4
	}
	state := async_scrolling_state_from_display_list(list)
	assert state.scroll_nodes.len == 2
	assert state.scroll_nodes[1].parent_node_id or { panic('missing parent') } == AsyncScrollNodeId{10, 1}
	assert state.wheel_hit_test_targets[0].target_node_id or { panic('missing target') } == AsyncScrollNodeId{10, 2}
	assert state.scroll_nodes[1].stable_node_id.node_id == 21
	assert state.has_blocking_wheel_event_listeners
	assert state.wheel_event_listener_state_generation == 12
	assert wheel_routing_admission_for(state) == .accepted
	assert wheel_routing_admission_to_utf16_view(.stale_wheel_event_listeners) == 'stale wheel event listeners'
}

fn test_wheel_routing_fails_closed_and_respects_region_precedence() {
	context := ContextRef{1}
	node := scroll_test_node(1, 1, none, true)
	state := AsyncScrollingState{
		scroll_nodes: [node]
		wheel_hit_test_targets: [WheelHitTestTarget{
			context: context
			rect: painting.Rect{0, 0, 200, 200}
			target_node_id: node.node_id
		}]
		main_thread_wheel_event_regions: [MainThreadWheelEventRegion{
			context: context
			rect: painting.Rect{0, 0, 20, 20}
		}]
		blocking_wheel_event_regions: [BlockingWheelEventRegion{
			context: context
			rect: painting.Rect{30, 0, 20, 20}
		}]
		has_blocking_wheel_event_listeners: true
	}
	list := &CompositorDisplayList{ structural_epoch: 9 }
	tree := &VisualContextTree{
		structural_epoch: 9
		valid_contexts: {
			1: true
		}
	}
	snapshot := CompositorScrollStateSnapshot{ device_offsets: [painting.Point{}, painting.Point{}] }
	assert blocks_wheel_event_at_position(state, none, none, snapshot, painting.Point{35, 5})
	assert admit_wheel_scroll(state, list, tree, snapshot, painting.Point{5, 5}, painting.Point{0, 10}, .scroll_on_compositor, true) == .blocked_by_main_thread_region
	assert admit_wheel_scroll(state, list, tree, snapshot, painting.Point{35, 5}, painting.Point{0, 10}, .scroll_on_compositor, true) == .blocked_by_wheel_event_region
	assert admit_wheel_scroll(state, list, tree, snapshot, painting.Point{60, 5}, painting.Point{0, 10}, .scroll_on_compositor, false) == .stale_blocking_wheel_event_regions
	assert admit_wheel_scroll(state, list, tree, snapshot, painting.Point{60, 5}, painting.Point{0, 10}, .scroll_on_compositor, true) == .accepted
}

fn test_scroll_tree_hands_off_to_a_scrollable_ancestor_and_resolves_sticky_offsets() {
	parent := scroll_test_node(1, 1, none, true)
	child := scroll_test_node(1, 2, parent.node_id, false)
	mut scroll_tree := AsyncScrollTree{}
	scroll_tree.set_state(AsyncScrollingState{ scroll_nodes: [parent, child] })
	mut snapshot := CompositorScrollStateSnapshot{
		device_offsets: [painting.Point{}, painting.Point{}, painting.Point{-100, -100}]
	}
	mut visual_tree := VisualContextTree{}
	updates := scroll_tree.apply_scroll_delta(child.node_id, painting.Point{0, 25}, mut visual_tree, mut snapshot)
	assert updates.len == 1
	assert updates[0].stable_node_id == parent.stable_node_id
	assert updates[0].compositor_scroll_offset == painting.Point{0, 25}
	assert updates[0].unadopted_scroll_delta == painting.Point{0, 25}
	assert snapshot.device_offset_for_index(1) == painting.Point{0, -25}
	assert visual_tree.sticky_resolution_count == 1
	set_offset := scroll_tree.set_scroll_offset(parent.node_id, painting.Point{200, -10}, mut visual_tree, mut snapshot) or { panic('missing node') }
	assert set_offset == painting.Point{100, 0}
}

fn test_snap_containers_defer_discrete_and_momentum_wheels() {
	mut node := scroll_test_node(1, 1, none, true)
	node = AsyncScrollNode{
		...node
		snaps_scroll_position_vertically: true
	}
	mut scroll_tree := AsyncScrollTree{}
	scroll_tree.set_state(AsyncScrollingState{ scroll_nodes: [node] })
	list := &CompositorDisplayList{ structural_epoch: 3 }
	contexts := &VisualContextTree{ structural_epoch: 3 }
	snapshot := CompositorScrollStateSnapshot{ device_offsets: [painting.Point{}, painting.Point{}] }
	scroll_tree.rebuild_wheel_hit_test_targets(list, contexts, snapshot)
	result := scroll_tree.hit_test_scroll_node_for_wheel(*contexts, painting.Point{10, 10}, painting.Point{0, 10}, .defer_to_main_thread)
	assert result.blocked_by_main_thread_region
	assert snap_container_handling_for(.discrete, .changed) == .defer_to_main_thread
	assert snap_container_handling_for(.precise, .momentum) == .defer_to_main_thread
	assert snap_container_handling_for(.precise, .changed) == .scroll_on_compositor
}

fn linear_opacity_animation(direction VisualAnimationPlaybackDirection) VisualAnimation {
	linear := VisualAnimationEasing{}
	return VisualAnimation{
		target_kind: .opacity
		visual_context_node_indices: [u32(2)]
		iteration_duration_ms: 1000
		iteration_count: 2
		playback_direction: direction
		easing: linear
		keyframes: [VisualAnimationKeyframe{
			offset: 0
			easing: linear
			value: OpacityAnimationValue{0}
		}, VisualAnimationKeyframe{
			offset: 1
			easing: linear
			value: OpacityAnimationValue{1}
		}]
	}
}

fn test_visual_animation_samples_direction_and_terminal_progress() {
	animation := linear_opacity_animation(.normal)
	assert animation.is_valid()
	middle := animation.sample(0.5) or { panic('missing sample') }
	assert near(middle.opacity, 0.5)
	terminal := animation.sample(2) or { panic('missing terminal sample') }
	assert terminal.opacity == 1
	alternate := linear_opacity_animation(.alternate)
	backward_sample := alternate.sample(1.25) or { panic('missing alternate sample') }
	assert near(backward_sample.opacity, 0.75)
	before := VisualAnimation{
		...animation
		start_delay_ms: 100
		fill_mode: .backwards
	}.sample(0) or { panic('backwards fill did not sample') }
	assert before.opacity == 0
}

fn test_visual_animation_validates_and_interpolates_filters_and_transforms() {
	invalid_easing := VisualAnimationEasing{
		kind: .cubic_bezier
		x1: -1
	}
	assert !invalid_easing.is_valid()
	transform := VisualAnimationTransformOperation{
		kind: .translate3d
		values: [f32(10), 20, 30]
	}
	assert transform.is_valid()
	matrix := transform.to_matrix()
	assert matrix.m14 == 10 && matrix.m24 == 20 && matrix.m34 == 30
	assert !VisualAnimationTransformOperation{
		kind: .scale3d
		values: [f32(1), 2]
	}.is_valid()
	shadow_from := VisualAnimationFilterOperation{
		kind: .drop_shadow
		amount: 2
		color: painting.Color{ r: 255, a: 255 }
	}
	shadow_to := VisualAnimationFilterOperation{
		kind: .drop_shadow
		amount: 6
		color: painting.Color{ b: 255, a: 255 }
	}
	middle := shadow_from.interpolated_with(shadow_to, 0.5)
	assert middle.amount == 4
	assert middle.color.r == 128 && middle.color.b == 128 && middle.color.a == 255
	assert VisualAnimationFilterOperation{
		kind: .color
		amount: 0.5
		color_operation: .opacity
	}.initial_value().amount == 1
}

fn animation_with_values(target VisualAnimationTargetKind, from VisualAnimationValue, to VisualAnimationValue) VisualAnimation {
	linear := VisualAnimationEasing{}
	return VisualAnimation{
		target_kind: target
		visual_context_node_indices: [u32(1)]
		iteration_duration_ms: 1000
		iteration_count: 1
		easing: linear
		keyframes: [VisualAnimationKeyframe{
			offset: 0
			easing: linear
			value: from
		}, VisualAnimationKeyframe{
			offset: 1
			easing: linear
			value: to
		}]
	}
}

fn test_visual_animation_samples_every_target_kind() {
	background := animation_with_values(.background_color, BackgroundColorAnimationValue{
		value: painting.Color{ r: 255, a: 0 }
	}, BackgroundColorAnimationValue{
		value: painting.Color{ r: 255, a: 255 }
	})
	assert background.is_valid()
	background_sample := background.sample(0.5) or { panic('missing background sample') }
	background_color := background_sample.background_color or { panic('missing background color') }
	assert background_color == painting.Color{ r: 255, a: 128 }
	filter := animation_with_values(.filter, FilterListAnimationValue{}, FilterListAnimationValue{
		operations: [VisualAnimationFilterOperation{
			kind: .color
			amount: 0.5
			color_operation: .opacity
		}]
	})
	assert filter.is_valid()
	filter_sample := filter.sample(0.5) or { panic('missing filter sample') }
	assert filter_sample.samples_filter
	assert filter_sample.filter_operations.len == 1
	assert near(filter_sample.filter_operations[0].amount, 0.75)
	transform := animation_with_values(.transform, TransformListAnimationValue{
		operations: [VisualAnimationTransformOperation{
			kind: .translate_x
			values: [f32(0)]
		}]
	}, TransformListAnimationValue{
		operations: [VisualAnimationTransformOperation{
			kind: .translate_x
			values: [f32(20)]
		}]
	})
	assert transform.is_valid()
	transform_sample := transform.sample(0.5) or { panic('missing transform sample') }
	assert near(transform_sample.transform.m14, 10)
	mismatched := VisualAnimation{
		...transform
		keyframes: [transform.keyframes[0], VisualAnimationKeyframe{
			offset: 1
			easing: VisualAnimationEasing{}
			value: TransformListAnimationValue{
				operations: [VisualAnimationTransformOperation{
					kind: .scale_x
					values: [f32(2)]
				}]
			}
		}]
	}
	assert !mismatched.is_valid()
}

fn test_context_handle_flushes_canvas_before_sampling_operations() {
	screenshot_callback_count = 0
	mut host := new_compositor_host()
	mut handle := host.create_context(44)!
	host.append_canvas_2d_command('draw canvas')
	handle.update_display_list(CompositorDisplayList{}, VisualContextTree{}, DisplayListResourceTransaction{}, CompositorScrollStateSnapshot{})
	assert host.call_log()[1..3] == ['canvas_2d_stream', 'update_display_list:44']
	host.append_canvas_2d_command('present canvas')
	handle.present_frame(painting.IntRect{0, 0, 800, 600})
	host.append_canvas_2d_command('snapshot canvas')
	handle.request_screenshot(PaintingSurface{ id: 8 }, screenshot_finished)
	assert screenshot_callback_count == 1
	assert host.canvas_2d_batches() == [['draw canvas'], ['present canvas'], ['snapshot canvas']]
	host.set_next_async_scroll_result(AsyncScrollEnqueueResult{
		accepted: true
		operation_id: 9
	})
	operation_id := handle.async_scroll_by(1, painting.Point{}, painting.Point{0, 2}, painting.IntRect{}, .scroll_on_compositor, .yes).operation_id or { panic('missing ID') }
	assert operation_id == 9
	handle.destroy()
	handle.destroy()
	assert !host.has_context(44)
	assert host.call_log().count(it == 'destroy_context:44') == 1
}
