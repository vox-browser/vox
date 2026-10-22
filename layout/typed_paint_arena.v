module layout

import platform

struct PaintProjectionStatus {
mut:
	incomplete bool
}

struct TypedPaintArenaEntry {
	node &Node
	parent int
mut:
	first_child int
	child_count int
	omitted bool
}

// Match the shallow builder's empty-box exits before reserving storage. Its
// anonymous and generated boxes remain represented even without a DOM tag.
fn typed_paint_child_has_transport_box(node &Node, state &LayoutState) bool {
	if node.is_anonymous() || node.is_generated_for_pseudo_element() { return true }
	styled := node.as_node_with_style() or { return false }
	used := state.try_get(styled) or { return false }
	if used.svg_rendering_disabled() { return false }
	dom_node := node.dom_node() or { return false }
	element := dom_node.as_element() or { return false }
	return element.local_name() != ''
}

fn typed_paint_arena_plan(root &Node, state &LayoutState) []TypedPaintArenaEntry {
	return typed_paint_arena_plan_with_interest(root, state, none)
}

fn typed_paint_arena_plan_with_interest(root &Node, state &LayoutState, interest ?LayoutRect) []TypedPaintArenaEntry {
	mut entries := [TypedPaintArenaEntry{node: root, parent: -1}]
	mut index := 0
	for index < entries.len {
		node := entries[index].node
		if rect := interest {
			if paint_interest_can_omit(node, state, rect) {
				entries[index].omitted = true
				index++
				continue
			}
		}
		first_child := entries.len
		for child in typed_paint_child_nodes(node, state) {
			if !typed_paint_child_has_transport_box(child, state) { continue }
			entries << TypedPaintArenaEntry{node: child, parent: index}
		}
		entries[index].first_child = first_child
		entries[index].child_count = entries.len - first_child
		index++
	}
	return entries
}

fn build_typed_paint_tree_in_arena(root &Node, state &LayoutState, ancestor_transform [6]f64) BlockBox {
	mut omitted := PaintProjectionStatus{}
	return build_typed_paint_tree_with_interest(root, state, ancestor_transform, none, mut omitted)
}

fn build_typed_paint_tree_with_interest(root &Node, state &LayoutState, ancestor_transform [6]f64, interest ?LayoutRect, mut omitted PaintProjectionStatus) BlockBox {
	return build_typed_paint_tree_projection(root, state, ancestor_transform, interest, mut omitted)
}

fn build_typed_paint_tree_projection(root &Node, state &LayoutState, ancestor_transform [6]f64,
	interest ?LayoutRect, mut omitted PaintProjectionStatus) BlockBox {
	phase_mark := platform.arena_phase_begin()
	defer {
		platform.arena_phase_end('paint_tree', phase_mark)
	}
	prepare_retained_block_paint_owners(state, root.document())
	// The traversal borrows committed nodes and computes only a temporary plan.
	// Leave its workspace before publishing boxes and their retained payloads.
	scratch := platform.begin_thread_scratch('typed paint traversal')
	defer { scratch.finish() }
	plan := typed_paint_arena_plan_with_interest(root, state, interest)
	scratch.leave()
	mut boxes := []BlockBox{cap: plan.len}
	// Capacity is exact and the allocator zeroes reserved storage. Each slot is
	// fully written before a later child reads its parent's transform; no
	// interior slice is published until every record has been initialized.
	unsafe { boxes.grow_len(plan.len) }
	for index, entry in plan {
		if entry.omitted {
			omitted.incomplete = true
			fill_omitted_paint_box(entry.node, state, mut boxes[index])
			continue
		}
		transform := if entry.parent < 0 { ancestor_transform } else { boxes[entry.parent].paint_transform }
		fill_block_box_from_typed_layout_shallow(entry.node, state, transform, mut boxes[index])
	}
	// Every append is finished before publishing interior pointers or slices.
	// Slices are ordinary V array views, so later child-list growth detaches
	// rather than overwriting the adjacent parent's children.
	for index, entry in plan {
		if entry.child_count == 0 { continue }
		boxes[index].children = unsafe { boxes[entry.first_child..entry.first_child + entry.child_count] }
	}
	return boxes[0]
}
