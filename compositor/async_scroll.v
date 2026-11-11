// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Compositor/{AsyncScrollingState,AsyncScrollTree}.{h,cpp}.
module compositor

import math
import painting

pub enum WheelDeltaPrecision {
	discrete
	precise
}

pub enum ScrollGesturePhase {
	none
	started
	changed
	ended
	momentum
}

pub enum AsyncScrollNodeKind {
	viewport
	element
	pseudo_element
}

pub enum CompositorScrollNodeKind {
	viewport
	element
	pseudo_element
}

pub fn async_scroll_node_kind_for(kind CompositorScrollNodeKind) AsyncScrollNodeKind {
	return match kind {
		.viewport { .viewport }
		.element { .element }
		.pseudo_element { .pseudo_element }
	}
}

pub struct AsyncScrollNodeId {
pub:
	document_id       u64
	scroll_node_index int
}

pub struct AsyncScrollNodeStableId {
pub:
	node_id             u64
	kind                AsyncScrollNodeKind = .element
	pseudo_element_type u8
}

pub struct AsyncScrollOffset {
pub:
	stable_node_id           AsyncScrollNodeStableId
	compositor_scroll_offset painting.Point
	unadopted_scroll_delta   painting.Point
}

pub struct AsyncScrollNode {
pub:
	node_id                            AsyncScrollNodeId
	stable_node_id                     AsyncScrollNodeStableId
	scrollport_rect                    painting.IntRect
	min_scroll_offset                  painting.Point
	max_scroll_offset                  painting.Point
	is_viewport                        bool
	can_be_wheel_scrolled_horizontally bool
	can_be_wheel_scrolled_vertically   bool
	snaps_scroll_position_horizontally bool
	snaps_scroll_position_vertically   bool
pub mut:
	parent_node_id ?AsyncScrollNodeId
}

pub struct ContextRef {
pub:
	spatial int
}

pub struct BlockingWheelEventRegion {
pub:
	context ContextRef
	rect    painting.Rect
}

pub struct WheelHitTestTarget {
pub:
	context      ContextRef
	rect         painting.Rect
	corner_radii painting.CornerRadii
pub mut:
	target_node_id ?AsyncScrollNodeId
}

pub struct MainThreadWheelEventRegion {
pub:
	context ContextRef
	rect    painting.Rect
}

pub struct ViewportScrollbar {
pub:
	scroll_node_id       AsyncScrollNodeId
	scroll_node_index    int
	gutter_rect          painting.IntRect
	thumb_rect           painting.IntRect
	expanded_gutter_rect painting.IntRect
	expanded_thumb_rect  painting.IntRect
	scroll_size          f64
	expanded_scroll_size f64
	min_scroll_offset    f32
	max_scroll_offset    f32
	thumb_color          painting.Color
	track_color          painting.Color
	vertical             bool
}

pub struct AsyncScrollingState {
pub:
	scroll_nodes                                      []AsyncScrollNode
	wheel_hit_test_targets                            []WheelHitTestTarget
	main_thread_wheel_event_regions                   []MainThreadWheelEventRegion
	viewport_scrollbars                               []ViewportScrollbar
	blocking_wheel_event_regions                      []BlockingWheelEventRegion
	viewport_rect                                     painting.IntRect
	wheel_event_listener_state_generation             u64
	has_blocking_wheel_event_listeners                bool
	has_blocking_wheel_event_region_covering_viewport bool
}

pub enum WheelRoutingAdmission {
	accepted
	no_async_scrolling_state
	blocking_wheel_event_listeners
	no_scroll_node
	stale_wheel_event_listeners
}

pub enum SnapContainerHandling {
	scroll_on_compositor
	defer_to_main_thread
}

pub enum WheelScrollAdmission {
	accepted
	no_scrollable_target
	blocked_by_main_thread_region
	stale_blocking_wheel_event_regions
	blocked_by_wheel_event_region
}

pub fn snap_container_handling_for(precision WheelDeltaPrecision, phase ScrollGesturePhase) SnapContainerHandling {
	if precision == .discrete || phase == .momentum {
		return .defer_to_main_thread
	}
	return .scroll_on_compositor
}

pub struct AsyncScrollingMetadata {
pub:
	viewport_rect                                     painting.IntRect
	wheel_event_listener_state_generation             u64
	has_blocking_wheel_event_listeners                bool
	has_blocking_wheel_event_region_covering_viewport bool
}

pub struct CompositorScrollNodeCommand {
pub:
	context                            ContextRef
	document_id                        u64
	scroll_node_index                  int
	scrollable_node_id                 u64
	scroll_node_kind                   CompositorScrollNodeKind
	pseudo_element_type                u8
	parent_scroll_node_index           int
	scrollport_rect                    painting.IntRect
	min_scroll_offset                  painting.Point
	max_scroll_offset                  painting.Point
	is_viewport                        bool
	can_be_wheel_scrolled_horizontally bool
	can_be_wheel_scrolled_vertically   bool
	snaps_scroll_position_horizontally bool
	snaps_scroll_position_vertically   bool
}

pub struct CompositorWheelHitTestTargetCommand {
pub:
	context                  ContextRef
	document_id              u64
	target_scroll_node_index int
	rect                     painting.Rect
	corner_radii             painting.CornerRadii
}

pub struct CompositorMainThreadWheelEventRegionCommand {
pub:
	context ContextRef
	rect    painting.Rect
}

pub struct CompositorBlockingWheelEventRegionCommand {
pub:
	context ContextRef
	rect    painting.Rect
}

pub struct CompositorViewportScrollbarCommand {
pub:
	document_id          u64
	scroll_node_index    int
	gutter_rect          painting.IntRect
	thumb_rect           painting.IntRect
	expanded_gutter_rect painting.IntRect
	expanded_thumb_rect  painting.IntRect
	scroll_size          f64
	expanded_scroll_size f64
	min_scroll_offset    f32
	max_scroll_offset    f32
	thumb_color          painting.Color
	track_color          painting.Color
	vertical             bool
}

pub type CompositorDisplayListCommand = CompositorBlockingWheelEventRegionCommand
	| CompositorMainThreadWheelEventRegionCommand
	| CompositorScrollNodeCommand
	| CompositorViewportScrollbarCommand
	| CompositorWheelHitTestTargetCommand

@[heap]
pub struct CompositorDisplayList {
pub:
	metadata         ?AsyncScrollingMetadata
	commands         []CompositorDisplayListCommand
	structural_epoch u64
}

fn scroll_node_id_for(document_id u64, scroll_node_index int) AsyncScrollNodeId {
	return AsyncScrollNodeId{document_id, scroll_node_index}
}

fn stable_scroll_node_id_for(node_id u64, kind CompositorScrollNodeKind, pseudo_element_type u8) AsyncScrollNodeStableId {
	return AsyncScrollNodeStableId{
		node_id: node_id
		kind: async_scroll_node_kind_for(kind)
		pseudo_element_type: pseudo_element_type
	}
}

pub fn async_scrolling_state_from_display_list(display_list CompositorDisplayList) AsyncScrollingState {
	metadata := display_list.metadata or { AsyncScrollingMetadata{} }
	mut scroll_nodes := []AsyncScrollNode{}
	mut hit_targets := []WheelHitTestTarget{}
	mut main_thread_regions := []MainThreadWheelEventRegion{}
	mut blocking_regions := []BlockingWheelEventRegion{}
	mut scrollbars := []ViewportScrollbar{}
	mut has_blockers := metadata.has_blocking_wheel_event_listeners
	for entry in display_list.commands {
		match entry {
			CompositorScrollNodeCommand {
				parent_node_id := if entry.parent_scroll_node_index != 0 {
					?AsyncScrollNodeId(scroll_node_id_for(entry.document_id, entry.parent_scroll_node_index))
				} else { ?AsyncScrollNodeId(none) }
				scroll_nodes << AsyncScrollNode{
					node_id: scroll_node_id_for(entry.document_id, entry.scroll_node_index)
					parent_node_id: parent_node_id
					stable_node_id: stable_scroll_node_id_for(entry.scrollable_node_id, entry.scroll_node_kind, entry.pseudo_element_type)
					scrollport_rect: entry.scrollport_rect
					min_scroll_offset: entry.min_scroll_offset
					max_scroll_offset: entry.max_scroll_offset
					is_viewport: entry.is_viewport
					can_be_wheel_scrolled_horizontally: entry.can_be_wheel_scrolled_horizontally
					can_be_wheel_scrolled_vertically: entry.can_be_wheel_scrolled_vertically
					snaps_scroll_position_horizontally: entry.snaps_scroll_position_horizontally
					snaps_scroll_position_vertically: entry.snaps_scroll_position_vertically
				}
			}
			CompositorWheelHitTestTargetCommand {
				target_node_id := if entry.target_scroll_node_index != 0 {
					?AsyncScrollNodeId(scroll_node_id_for(entry.document_id, entry.target_scroll_node_index))
				} else { ?AsyncScrollNodeId(none) }
				hit_targets << WheelHitTestTarget{
					target_node_id: target_node_id
					context: entry.context
					rect: entry.rect
					corner_radii: entry.corner_radii
				}
			}
			CompositorMainThreadWheelEventRegionCommand {
				main_thread_regions << MainThreadWheelEventRegion{entry.context, entry.rect}
			}
			CompositorBlockingWheelEventRegionCommand {
				has_blockers = true
				blocking_regions << BlockingWheelEventRegion{entry.context, entry.rect}
			}
			CompositorViewportScrollbarCommand {
				scrollbars << ViewportScrollbar{
					scroll_node_id: scroll_node_id_for(entry.document_id, entry.scroll_node_index)
					scroll_node_index: entry.scroll_node_index
					gutter_rect: entry.gutter_rect
					thumb_rect: entry.thumb_rect
					expanded_gutter_rect: entry.expanded_gutter_rect
					expanded_thumb_rect: entry.expanded_thumb_rect
					scroll_size: entry.scroll_size
					expanded_scroll_size: entry.expanded_scroll_size
					min_scroll_offset: entry.min_scroll_offset
					max_scroll_offset: entry.max_scroll_offset
					thumb_color: entry.thumb_color
					track_color: entry.track_color
					vertical: entry.vertical
				}
			}
		}
	}
	return AsyncScrollingState{
		scroll_nodes: scroll_nodes
		wheel_hit_test_targets: hit_targets
		main_thread_wheel_event_regions: main_thread_regions
		viewport_scrollbars: scrollbars
		blocking_wheel_event_regions: blocking_regions
		viewport_rect: metadata.viewport_rect
		wheel_event_listener_state_generation: metadata.wheel_event_listener_state_generation
		has_blocking_wheel_event_listeners: has_blockers
		has_blocking_wheel_event_region_covering_viewport: metadata.has_blocking_wheel_event_region_covering_viewport
	}
}

pub fn wheel_routing_admission_for(state AsyncScrollingState) WheelRoutingAdmission {
	if state.has_blocking_wheel_event_region_covering_viewport {
		return .blocking_wheel_event_listeners
	}
	if state.scroll_nodes.len == 0 {
		return .no_scroll_node
	}
	return .accepted
}

pub fn wheel_routing_admission_to_utf16_view(admission WheelRoutingAdmission) string {
	return match admission {
		.accepted { 'accepted' }
		.no_async_scrolling_state { 'no async scrolling state' }
		.blocking_wheel_event_listeners { 'blocking wheel event listeners' }
		.no_scroll_node { 'no scroll node' }
		.stale_wheel_event_listeners { 'stale wheel event listeners' }
	}
}

pub struct CompositorScrollStateSnapshot {
pub mut:
	device_offsets []painting.Point
}

pub fn (snapshot CompositorScrollStateSnapshot) device_offset_for_index(index int) painting.Point {
	if index < 0 || index >= snapshot.device_offsets.len {
		return painting.Point{}
	}
	return snapshot.device_offsets[index]
}

pub fn (mut snapshot CompositorScrollStateSnapshot) set_device_offset_for_index(index int, offset painting.Point) {
	if index < 0 {
		return
	}
	for snapshot.device_offsets.len <= index {
		snapshot.device_offsets << painting.Point{}
	}
	snapshot.device_offsets[index] = offset
}

@[heap]
pub struct VisualContextTree {
pub:
	structural_epoch       u64
	valid_contexts         map[int]bool
	context_translations   map[int]painting.Point
	animated_spatial_nodes map[int]bool
pub mut:
	sticky_resolution_count int
}

pub fn (tree VisualContextTree) context_is_valid(context ContextRef) bool {
	return tree.valid_contexts.len == 0 || tree.valid_contexts[context.spatial]
}

pub fn (tree VisualContextTree) transform_point_for_hit_test(context ContextRef, position painting.Point, snapshot CompositorScrollStateSnapshot) ?painting.Point {
	_ = snapshot
	if !tree.context_is_valid(context) {
		return none
	}
	translation := tree.context_translations[context.spatial]
	return position.subtract(translation)
}

pub fn (tree VisualContextTree) transform_rect_to_viewport(context ContextRef, rect painting.Rect, snapshot CompositorScrollStateSnapshot) painting.Rect {
	_ = snapshot
	return rect.translated(tree.context_translations[context.spatial])
}

pub fn (mut tree VisualContextTree) resolve_sticky_offsets(snapshot CompositorScrollStateSnapshot) {
	_ = snapshot
	tree.sticky_resolution_count++
}

fn scroll_tree_for_hit_testing(state AsyncScrollingState, display_list ?&CompositorDisplayList, visual_context_tree ?&VisualContextTree, snapshot CompositorScrollStateSnapshot) AsyncScrollTree {
	mut tree := AsyncScrollTree{}
	tree.set_state(state)
	tree.rebuild_wheel_hit_test_targets(display_list, visual_context_tree, snapshot)
	return tree
}

pub fn blocks_wheel_event_at_position(state AsyncScrollingState, display_list ?&CompositorDisplayList, visual_context_tree ?&VisualContextTree, snapshot CompositorScrollStateSnapshot, position painting.Point) bool {
	if state.has_blocking_wheel_event_region_covering_viewport {
		return true
	}
	list := display_list or { return state.has_blocking_wheel_event_listeners }
	contexts := visual_context_tree or { return state.has_blocking_wheel_event_listeners }
	tree := scroll_tree_for_hit_testing(state, list, contexts, snapshot)
	return tree.blocks_wheel_event_at_position(*contexts, position)
}

pub struct WheelHitTestResult {
pub:
	node_id                       ?AsyncScrollNodeId
	blocked_by_main_thread_region bool
	blocked_by_wheel_event_region bool
}

struct CachedWheelHitTestTarget {
	target_node_id ?AsyncScrollNodeId
	context        ContextRef
	rect           painting.Rect
	corner_radii   painting.CornerRadii
	viewport_rect  ?painting.Rect
}

struct CachedMainThreadWheelEventTarget {
	context       ContextRef
	rect          painting.Rect
	viewport_rect ?painting.Rect
}

struct CachedBlockingWheelEventTarget {
	context       ContextRef
	rect          painting.Rect
	viewport_rect ?painting.Rect
}

pub struct AsyncScrollTree {
mut:
	scroll_nodes_                                      []AsyncScrollNode
	wheel_hit_test_regions_                            []WheelHitTestTarget
	main_thread_wheel_event_regions_                   []MainThreadWheelEventRegion
	blocking_wheel_event_regions_                      []BlockingWheelEventRegion
	cached_wheel_hit_test_targets_                     []CachedWheelHitTestTarget
	cached_main_thread_wheel_event_targets_            []CachedMainThreadWheelEventTarget
	cached_blocking_wheel_event_targets_               []CachedBlockingWheelEventTarget
	visual_context_tree_structural_epoch_              ?u64
	scroll_state_snapshot_                             CompositorScrollStateSnapshot
	has_blocking_wheel_event_region_covering_viewport_ bool
}

pub fn (mut tree AsyncScrollTree) set_state(state AsyncScrollingState) {
	tree.scroll_nodes_ = state.scroll_nodes.clone()
	tree.wheel_hit_test_regions_ = state.wheel_hit_test_targets.clone()
	tree.main_thread_wheel_event_regions_ = state.main_thread_wheel_event_regions.clone()
	tree.blocking_wheel_event_regions_ = state.blocking_wheel_event_regions.clone()
	tree.has_blocking_wheel_event_region_covering_viewport_ = state.has_blocking_wheel_event_region_covering_viewport
	tree.clear_wheel_hit_test_targets()
}

fn (tree AsyncScrollTree) scroll_node_for_id(node_id AsyncScrollNodeId) ?AsyncScrollNode {
	for node in tree.scroll_nodes_ {
		if node.node_id == node_id {
			return node
		}
	}
	return none
}

fn (tree AsyncScrollTree) scroll_node_for_stable_id(stable_node_id AsyncScrollNodeStableId) ?AsyncScrollNode {
	for node in tree.scroll_nodes_ {
		if node.stable_node_id == stable_node_id {
			return node
		}
	}
	return none
}

fn (tree AsyncScrollTree) clamp_scroll_offset_to_node(node AsyncScrollNode, offset painting.Point) painting.Point {
	_ = tree
	return painting.Point{
		x: math.max(node.min_scroll_offset.x, math.min(offset.x, node.max_scroll_offset.x))
		y: math.max(node.min_scroll_offset.y, math.min(offset.y, node.max_scroll_offset.y))
	}
}

fn scroll_offset_for_record(node AsyncScrollNode, snapshot CompositorScrollStateSnapshot) painting.Point {
	device_offset := snapshot.device_offset_for_index(node.node_id.scroll_node_index)
	return painting.Point{-device_offset.x, -device_offset.y}
}

fn (tree AsyncScrollTree) can_scroll_node_by_delta(node AsyncScrollNode, snapshot CompositorScrollStateSnapshot, delta painting.Point) bool {
	offset := scroll_offset_for_record(node, snapshot)
	return (node.can_be_wheel_scrolled_horizontally && delta.x < 0
		&& offset.x > node.min_scroll_offset.x)
		|| (node.can_be_wheel_scrolled_horizontally && delta.x > 0
			&& offset.x < node.max_scroll_offset.x)
		|| (node.can_be_wheel_scrolled_vertically && delta.y < 0
			&& offset.y > node.min_scroll_offset.y)
		|| (node.can_be_wheel_scrolled_vertically && delta.y > 0
			&& offset.y < node.max_scroll_offset.y)
}

fn (tree AsyncScrollTree) has_non_zero_scroll_delta(delta painting.Point) bool {
	_ = tree
	return delta.x != 0 || delta.y != 0
}

fn (tree AsyncScrollTree) scrollable_ancestor_for_node(node_id AsyncScrollNodeId, snapshot CompositorScrollStateSnapshot, delta painting.Point) ?AsyncScrollNodeId {
	node := tree.scroll_node_for_id(node_id) or { return none }
	mut parent_id := node.parent_node_id
	for parent_id != none {
		id := parent_id or { break }
		parent := tree.scroll_node_for_id(id) or { return none }
		if tree.can_scroll_node_by_delta(parent, snapshot, delta) {
			return id
		}
		parent_id = parent.parent_node_id
	}
	return none
}

fn (tree AsyncScrollTree) hit_test_result_for_scroll_node(node_id AsyncScrollNodeId, delta painting.Point) WheelHitTestResult {
	node := tree.scroll_node_for_id(node_id) or { return WheelHitTestResult{} }
	if tree.can_scroll_node_by_delta(node, tree.scroll_state_snapshot_, delta) {
		return WheelHitTestResult{ node_id: node_id }
	}
	ancestor := tree.scrollable_ancestor_for_node(node_id, tree.scroll_state_snapshot_, delta) or {
		return WheelHitTestResult{}
	}
	return WheelHitTestResult{ node_id: ancestor }
}

fn (tree AsyncScrollTree) apply_scroll_delta_to_node(node AsyncScrollNode, delta painting.Point, mut snapshot CompositorScrollStateSnapshot) painting.Point {
	old_offset := scroll_offset_for_record(node, snapshot)
	wheel_delta := painting.Point{
		x: if node.can_be_wheel_scrolled_horizontally { delta.x } else { 0 }
		y: if node.can_be_wheel_scrolled_vertically { delta.y } else { 0 }
	}
	new_offset := tree.clamp_scroll_offset_to_node(node, old_offset.add(wheel_delta))
	if new_offset == old_offset {
		return delta
	}
	snapshot.set_device_offset_for_index(node.node_id.scroll_node_index, painting.Point{-new_offset.x, -new_offset.y})
	consumed := new_offset.subtract(old_offset)
	return delta.subtract(consumed)
}

fn set_or_append_scroll_offset(mut offsets []AsyncScrollOffset, node AsyncScrollNode, compositor_offset painting.Point, unadopted_delta painting.Point) {
	for index, existing in offsets {
		if existing.stable_node_id == node.stable_node_id {
			offsets[index] = AsyncScrollOffset{
				stable_node_id: existing.stable_node_id
				compositor_scroll_offset: compositor_offset
				unadopted_scroll_delta: existing.unadopted_scroll_delta.add(unadopted_delta)
			}
			return
		}
	}
	offsets << AsyncScrollOffset{node.stable_node_id, compositor_offset, unadopted_delta}
}

pub fn (tree AsyncScrollTree) scroll_offset_for_node(node_id AsyncScrollNodeId, snapshot CompositorScrollStateSnapshot) ?painting.Point {
	node := tree.scroll_node_for_id(node_id) or { return none }
	return scroll_offset_for_record(node, snapshot)
}

pub fn (tree AsyncScrollTree) viewport_scroll_node_id() ?AsyncScrollNodeId {
	for node in tree.scroll_nodes_ {
		if node.is_viewport {
			return node.node_id
		}
	}
	return none
}

pub fn (tree AsyncScrollTree) scroll_node_id_for_stable_id(stable_node_id AsyncScrollNodeStableId) ?AsyncScrollNodeId {
	node := tree.scroll_node_for_stable_id(stable_node_id) or { return none }
	return node.node_id
}

pub fn (tree AsyncScrollTree) scroll_node_is_viewport(node_id AsyncScrollNodeId) bool {
	node := tree.scroll_node_for_id(node_id) or { return false }
	return node.is_viewport
}

pub fn (mut tree AsyncScrollTree) apply_scroll_delta(node_id AsyncScrollNodeId, delta painting.Point, mut visual_context_tree VisualContextTree, mut snapshot CompositorScrollStateSnapshot) []AsyncScrollOffset {
	mut offsets := []AsyncScrollOffset{}
	mut remaining := delta
	mut current_id := node_id
	for _ in 0 .. tree.scroll_nodes_.len {
		if !tree.has_non_zero_scroll_delta(remaining) {
			break
		}
		node := tree.scroll_node_for_id(current_id) or { break }
		before := remaining
		remaining = tree.apply_scroll_delta_to_node(node, remaining, mut snapshot)
		if remaining != before {
			consumed := before.subtract(remaining)
			set_or_append_scroll_offset(mut offsets, node, scroll_offset_for_record(node, snapshot), consumed)
			break
		}
		current_id = tree.scrollable_ancestor_for_node(current_id, snapshot, remaining) or { break }
	}
	if offsets.len > 0 {
		visual_context_tree.resolve_sticky_offsets(snapshot)
	}
	return offsets
}

pub fn (mut tree AsyncScrollTree) set_scroll_offset(node_id AsyncScrollNodeId, offset painting.Point, mut visual_context_tree VisualContextTree, mut snapshot CompositorScrollStateSnapshot) ?painting.Point {
	node := tree.scroll_node_for_id(node_id) or { return none }
	new_offset := tree.clamp_scroll_offset_to_node(node, offset)
	snapshot.set_device_offset_for_index(node.node_id.scroll_node_index, painting.Point{-new_offset.x, -new_offset.y})
	visual_context_tree.resolve_sticky_offsets(snapshot)
	return new_offset
}

pub fn (mut tree AsyncScrollTree) rebuild_wheel_hit_test_targets(display_list ?&CompositorDisplayList, visual_context_tree ?&VisualContextTree, snapshot CompositorScrollStateSnapshot) {
	tree.clear_wheel_hit_test_targets()
	tree.scroll_state_snapshot_ = CompositorScrollStateSnapshot{snapshot.device_offsets.clone()}
	list := display_list or { return }
	contexts := visual_context_tree or { return }
	assert list.structural_epoch == contexts.structural_epoch
	tree.visual_context_tree_structural_epoch_ = contexts.structural_epoch
	for target in tree.wheel_hit_test_regions_ {
		if !contexts.context_is_valid(target.context) {
			continue
		}
		viewport_rect := if contexts.animated_spatial_nodes[target.context.spatial] {
			?painting.Rect(none)
		} else {
			?painting.Rect(contexts.transform_rect_to_viewport(target.context, target.rect, snapshot))
		}
		tree.cached_wheel_hit_test_targets_ << CachedWheelHitTestTarget{
			target_node_id: target.target_node_id
			context: target.context
			rect: target.rect
			corner_radii: target.corner_radii
			viewport_rect: viewport_rect
		}
	}
	for region in tree.main_thread_wheel_event_regions_ {
		if !contexts.context_is_valid(region.context) {
			continue
		}
		viewport_rect := if contexts.animated_spatial_nodes[region.context.spatial] {
			?painting.Rect(none)
		} else {
			?painting.Rect(contexts.transform_rect_to_viewport(region.context, region.rect, snapshot))
		}
		tree.cached_main_thread_wheel_event_targets_ << CachedMainThreadWheelEventTarget{
			context: region.context
			rect: region.rect
			viewport_rect: viewport_rect
		}
	}
	for region in tree.blocking_wheel_event_regions_ {
		// Retain invalid blockers so production hit testing fails closed.
		viewport_rect := if !contexts.context_is_valid(region.context)
			|| contexts.animated_spatial_nodes[region.context.spatial] {
			?painting.Rect(none)
		} else {
			?painting.Rect(contexts.transform_rect_to_viewport(region.context, region.rect, snapshot))
		}
		tree.cached_blocking_wheel_event_targets_ << CachedBlockingWheelEventTarget{
			context: region.context
			rect: region.rect
			viewport_rect: viewport_rect
		}
	}
}

pub fn (mut tree AsyncScrollTree) clear_wheel_hit_test_targets() {
	tree.cached_wheel_hit_test_targets_.clear()
	tree.cached_main_thread_wheel_event_targets_.clear()
	tree.cached_blocking_wheel_event_targets_.clear()
	tree.visual_context_tree_structural_epoch_ = none
}

fn wheel_hit_test_target_contains_point(target CachedWheelHitTestTarget, point painting.Point) bool {
	if !target.rect.contains(point) {
		return false
	}
	if !target.corner_radii.has_any_radius() {
		return true
	}
	return target.corner_radii.contains(painting.IntPoint{int(point.x), int(point.y)}, painting.IntRect{int(target.rect.x), int(target.rect.y), int(target.rect.width), int(target.rect.height)})
}

pub fn (tree AsyncScrollTree) blocks_wheel_event_at_position(visual_context_tree VisualContextTree, position painting.Point) bool {
	if tree.has_blocking_wheel_event_region_covering_viewport_ { return true }
	epoch := tree.visual_context_tree_structural_epoch_ or { return true }
	if epoch != visual_context_tree.structural_epoch { return true }
	for target in tree.cached_blocking_wheel_event_targets_ {
		if !visual_context_tree.context_is_valid(target.context) { return true }
		if viewport := target.viewport_rect {
			if !viewport.contains(position) { continue }
		}
		position_in_context := visual_context_tree.transform_point_for_hit_test(target.context, position, tree.scroll_state_snapshot_) or { continue }
		if target.rect.contains(position_in_context) { return true }
	}
	return false
}

pub fn (tree AsyncScrollTree) hit_test_scroll_node_for_wheel(visual_context_tree VisualContextTree, position painting.Point, delta painting.Point, snap_handling SnapContainerHandling) WheelHitTestResult {
	epoch := tree.visual_context_tree_structural_epoch_ or { return WheelHitTestResult{} }
	if epoch != visual_context_tree.structural_epoch {
		return WheelHitTestResult{}
	}
	if tree.has_blocking_wheel_event_region_covering_viewport_ {
		return WheelHitTestResult{ blocked_by_wheel_event_region: true }
	}
	for target in tree.cached_main_thread_wheel_event_targets_ {
		if viewport := target.viewport_rect {
			if !viewport.contains(position) {
				continue
			}
		}
		position_in_context := visual_context_tree.transform_point_for_hit_test(target.context, position, tree.scroll_state_snapshot_) or { continue }
		if target.rect.contains(position_in_context) {
			return WheelHitTestResult{ blocked_by_main_thread_region: true }
		}
	}
	if tree.blocks_wheel_event_at_position(visual_context_tree, position) {
		return WheelHitTestResult{ blocked_by_wheel_event_region: true }
	}
	for index := tree.cached_wheel_hit_test_targets_.len - 1; index >= 0; index-- {
		target := tree.cached_wheel_hit_test_targets_[index]
		if viewport := target.viewport_rect {
			if !viewport.contains(position) {
				continue
			}
		}
		position_in_context := visual_context_tree.transform_point_for_hit_test(target.context, position, tree.scroll_state_snapshot_) or { continue }
		if !wheel_hit_test_target_contains_point(target, position_in_context) {
			continue
		}
		node_id := target.target_node_id or { return WheelHitTestResult{} }
		result := tree.hit_test_result_for_scroll_node(node_id, delta)
		if snap_handling == .defer_to_main_thread {
			if accepted_id := result.node_id {
				node := tree.scroll_node_for_id(accepted_id) or { return result }
				if (node.snaps_scroll_position_horizontally && delta.x != 0)
					|| (node.snaps_scroll_position_vertically && delta.y != 0) {
					return WheelHitTestResult{ blocked_by_main_thread_region: true }
				}
			}
		}
		return result
	}
	viewport_id := tree.viewport_scroll_node_id() or { return WheelHitTestResult{} }
	viewport_node := tree.scroll_node_for_id(viewport_id) or { return WheelHitTestResult{} }
	viewport := viewport_node.scrollport_rect
	if position.x < viewport.x || position.x >= viewport.x + viewport.width
		|| position.y < viewport.y || position.y >= viewport.y + viewport.height {
		return WheelHitTestResult{}
	}
	result := tree.hit_test_result_for_scroll_node(viewport_id, delta)
	if snap_handling == .defer_to_main_thread {
		if accepted_id := result.node_id {
			node := tree.scroll_node_for_id(accepted_id) or { return result }
			if (node.snaps_scroll_position_horizontally && delta.x != 0)
				|| (node.snaps_scroll_position_vertically && delta.y != 0) {
				return WheelHitTestResult{ blocked_by_main_thread_region: true }
			}
		}
	}
	return result
}

fn hit_test_scroll_node_at_position(state AsyncScrollingState, display_list ?&CompositorDisplayList, visual_context_tree ?&VisualContextTree, snapshot CompositorScrollStateSnapshot, position painting.Point, delta painting.Point, snap_handling SnapContainerHandling) WheelHitTestResult {
	list := display_list or { return WheelHitTestResult{blocked_by_wheel_event_region: state.has_blocking_wheel_event_listeners} }
	contexts := visual_context_tree or { return WheelHitTestResult{blocked_by_wheel_event_region: state.has_blocking_wheel_event_listeners} }
	tree := scroll_tree_for_hit_testing(state, list, contexts, snapshot)
	return tree.hit_test_scroll_node_for_wheel(*contexts, position, delta, snap_handling)
}

pub fn admit_wheel_scroll(state AsyncScrollingState, display_list ?&CompositorDisplayList, visual_context_tree ?&VisualContextTree, snapshot CompositorScrollStateSnapshot, position painting.Point, delta painting.Point, snap_handling SnapContainerHandling, blocker_regions_are_current bool) WheelScrollAdmission {
	result := hit_test_scroll_node_at_position(state, display_list, visual_context_tree, snapshot, position, delta, snap_handling)
	if result.blocked_by_main_thread_region {
		return .blocked_by_main_thread_region
	}
	if state.has_blocking_wheel_event_listeners {
		if !blocker_regions_are_current {
			return .stale_blocking_wheel_event_regions
		}
		if result.blocked_by_wheel_event_region {
			return .blocked_by_wheel_event_region
		}
	}
	if result.node_id == none {
		return .no_scrollable_target
	}
	return .accepted
}
