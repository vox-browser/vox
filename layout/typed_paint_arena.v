module layout

struct TypedPaintArenaEntry {
	node &Node
	parent int
mut:
	first_child int
	child_count int
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
	mut entries := [TypedPaintArenaEntry{node: root, parent: -1}]
	mut index := 0
	for index < entries.len {
		node := entries[index].node
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
	plan := typed_paint_arena_plan(root, state)
	mut boxes := []BlockBox{cap: plan.len}
	for entry in plan {
		transform := if entry.parent < 0 { ancestor_transform } else { boxes[entry.parent].paint_transform }
		boxes << block_box_from_typed_layout_shallow(entry.node, state, transform)
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
