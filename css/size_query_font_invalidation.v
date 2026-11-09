module css

import dom

// Size query thresholds may use the container's font or the root's font even
// when the queried size and an intermediate descendant's inherited style stay
// unchanged. Compare the recorded query answers after publishing the new font.
fn invalidate_size_query_font_dependents(element &dom.Element) {
	if element.is_size_query_container() {
		invalidate_descendant_styles_depending_on_size_container_query(element)
	}
	root := element.document().document_element() or { return }
	if voidptr(root) != voidptr(element) { return }
	mut stack := []&dom.Node{}
	append_flat_tree_children(element.as_node(), mut stack)
	for stack.len > 0 {
		node := stack.pop()
		if mut descendant := node.as_element() {
			if descendant.style_depends_on_size_container_query() && !size_query_results_unchanged(descendant) {
				descendant.set_needs_style_update(true)
			}
		}
		append_flat_tree_children(node, mut stack)
	}
}
