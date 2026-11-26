module layout

import dom
import os
import platform

// Same-binary control: rebuild the complete renderer snapshot for every paint
// style update the local refresh cannot apply.
const disable_paint_subtree_refresh = os.getenv('VOX_DISABLE_PAINT_SUBTREE_REFRESH') != ''
const paint_subtree_refresh_limit = 64

// One retained box whose subtree is projected again in place.
struct PaintSubtreeRefresh {
	slot      &BlockBox
	node      &Node
	transform [6]f64
}

// The nearest ancestor of `node` with a retained box: its parent in the
// renderer snapshot, whose accumulated transform the projection starts from.
fn retained_paint_parent(result &DocumentLayoutResult, node &Node) ?&Node {
	mut ancestor := node.parent()
	for ancestor != none {
		current := ancestor or { break }
		if u64(voidptr(current)) in result.box_index.last && voidptr(current) != voidptr(result.root) {
			return current
		}
		ancestor = current.parent()
	}
	return none
}

fn paint_subtree_refresh_node_is_eligible(result &DocumentLayoutResult, node &Node) bool {
	key := u64(voidptr(node))
	slot := result.box_index.last[key] or { return false }
	// Continuations and fragments have several boxes for one node.
	first := result.box_index.first[key] or { return false }
	if voidptr(first) != voidptr(slot) || voidptr(slot) == voidptr(&result.paint_tree) {
		return false
	}
	// The root box paints the canvas from the root element and body.
	return !node.is_root_element() && !node.is_body() && !node.is_viewport()
}

// Plan the subtrees to project again: for each changed node, the retained
// parent of its box (an inline node's containing box carries its lines, and a
// parent's lines place atomic inline children), keeping only outermost roots.
// Returns none when any update needs the complete projection.
fn plan_paint_subtree_refresh(mut result DocumentLayoutResult) ?[]PaintSubtreeRefresh {
	handles := result.paint_style_update_handles.items
	if handles.len == 0 || handles.len > paint_subtree_refresh_limit { return none }
	result.ensure_boxes_by_layout_cache()
	mut roots := []&Node{}
	for handle in handles {
		changed := unsafe { &Node(voidptr(handle)) }
		mut target := changed
		if u64(handle) !in result.box_index.last {
			target = retained_paint_parent(result, changed) or { return none }
		}
		root := retained_paint_parent(result, target) or { return none }
		if !paint_subtree_refresh_node_is_eligible(result, root) { return none }
		if roots.any(voidptr(it) == voidptr(root)) { continue }
		roots << root
	}
	mut plan := []PaintSubtreeRefresh{}
	for root in roots {
		mut covered := false
		mut ancestor := root.parent()
		for ancestor != none {
			current := ancestor or { break }
			if roots.any(voidptr(it) == voidptr(current)) {
				covered = true
				break
			}
			ancestor = current.parent()
		}
		if covered { continue }
		parent := retained_paint_parent(result, root) or { return none }
		parent_box := result.box_index.last[u64(voidptr(parent))] or { return none }
		slot := result.box_index.last[u64(voidptr(root))] or { return none }
		plan << PaintSubtreeRefresh{
			slot: slot
			node: root
			transform: parent_box.paint_transform
		}
	}
	return plan
}

// Project the changed subtrees again into the snapshot's own storage, as the
// local refresh rebuilds boxes in place, instead of the complete document.
fn refresh_changed_paint_subtrees(mut result DocumentLayoutResult) bool {
	if disable_paint_subtree_refresh || !result.has_renderer_snapshot { return false }
	plan := plan_paint_subtree_refresh(mut result) or { return false }
	root_layout_node := result.root.first_child() or { return false }
	if paint_refresh_diagnostics {
		eprintln('VOX_PAINT_REFRESH subtrees=${plan.len} handles=${result.paint_style_update_handles.len()}')
	}
	result.paint_tree_needs_style_update = false
	result.paint_style_update_requires_full_refresh = false
	result.paint_style_update_handles.clear()
	result.paint_style_update_compositor_handles.clear()
	result.paint_style_update_text_handles.clear()
	mut document := unsafe { &dom.Document(result.document) }
	document.invalidate_display_list()
	had_valid_hit_test_display_list := result.hit_test_display_list_is_valid
	project_paint_subtrees(mut result, root_layout_node, plan)
	finish_document_paint_tree_refresh(result.document, mut result, had_valid_hit_test_display_list)
	return true
}

fn project_paint_subtrees(mut result DocumentLayoutResult, root_layout_node &Node, plan []PaintSubtreeRefresh) {
	storage := result.paint_tree_storage
	mut entry := platform.ArenaEntry{}
	if storage != unsafe { nil } { entry = storage.arena.enter() }
	defer { if storage != unsafe { nil } { storage.arena.leave(entry) } }
	coordinates := begin_paint_coordinate_session(result.state)
	defer { coordinates.finish() }
	svg_sources := begin_paint_svg_source_session(root_layout_node)
	defer { svg_sources.finish() }
	mut incomplete := PaintProjectionStatus{}
	for item in plan {
		box := build_typed_paint_tree_projection(item.node, result.state, item.transform,
			result.paint_projection_interest, mut incomplete)
		unsafe {
			*item.slot = box
		}
	}
	if incomplete.incomplete { result.paint_projection_incomplete = true }
}
