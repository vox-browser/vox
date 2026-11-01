module css

import dom

// The children of a node in the flat tree: a host's are its shadow tree's, a
// slot's are the nodes assigned to it, and everything else's are its DOM
// children. This is the inverse of the walk that selects a query container.
fn append_flat_tree_children(node &dom.Node, mut children []&dom.Node) {
	if element := node.as_element() {
		if shadow_root := element.shadow_root() {
			mut child := unsafe { &dom.Node(shadow_root) }.first_child()
			for child != none {
				current := child or { break }
				children << current
				child = current.next_sibling()
			}
			return
		}
		if node.is_html_slot_element() {
			slot := unsafe { &dom.HTMLSlotElement(element) }
			if slot.assigned_nodes_internal().len > 0 {
				children << slot.assigned_nodes_internal()
				return
			}
		}
	}

	mut child := node.first_child()
	for child != none {
		current := child or { break }
		children << current
		child = current.next_sibling()
	}
}

// A query container's size moved, so every flat-tree descendant whose size
// query or container-relative unit resolved against it must be recomputed.
pub fn invalidate_descendant_styles_depending_on_size_container_query(query_container &dom.Element) {
	if !query_container.is_size_query_container() {
		return
	}

	mut document := unsafe { &dom.Document(query_container.document()) }
	mut stack := []&dom.Node{}
	append_flat_tree_children(query_container.as_node(), mut stack)
	for stack.len > 0 {
		node := stack.pop()
		if element := node.as_element() {
			document.record_size_query_container_scan_visit()
			if element.style_depends_on_size_container_query()
				&& (element.needs_style_update() || !size_query_results_unchanged(element)) {
				mut mutable_element := unsafe { &dom.Element(element) }
				mutable_element.set_needs_style_update(true)
			}
		}
		append_flat_tree_children(node, mut stack)
	}
}
