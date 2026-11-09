module dom

// aria-owns changes the parent used by accessible-name traversal, without
// changing DOM ancestry or the rendering tree. Keep the resolved relationships
// local to one computation so attribute and ID changes are immediately visible.
struct AccessibleNameOwnership {
mut:
	parents map[UniqueNodeID]&Node
	children map[UniqueNodeID][]&Node
}

fn collect_accessible_ownership_candidates(node &Node, mut candidates []&Element) {
	if element := node.as_element() {
		if value := element.get_attribute('aria-owns') {
			if value.trim_space().len > 0 { candidates << element }
		}
	}
	for child in node.children { collect_accessible_ownership_candidates(child, mut candidates) }
}

fn collect_accessible_ownership_ids(node &Node, mut ids map[string]&Element) {
	if element := node.as_element() {
		if id := element.id() {
			if id !in ids { ids[id] = element }
		}
	}
	for child in node.children { collect_accessible_ownership_ids(child, mut ids) }
}

fn accessible_name_ownership(node &Node, document &Document) AccessibleNameOwnership {
	root := node.root()
	mut candidates := []&Element{}
	collect_accessible_ownership_candidates(root, mut candidates)
	mut ownership := AccessibleNameOwnership{}
	if candidates.len == 0 { return ownership }
	mut mutable_document := unsafe { &Document(document) }
	mutable_document.update_layout(.node_name_or_description)
	mut ids := map[string]&Element{}
	collect_accessible_ownership_ids(root, mut ids)
	// Resolve owners in DOM order. The first valid owner wins, and cycles are
	// rejected against the DOM/ownership parent chain constructed so far.
	for owner in candidates {
		if ownership.is_hidden(owner) { continue }
		for id in (owner.get_attribute('aria-owns') or { '' }).fields() {
			target := ids[id] or { continue }
			target_node := target.as_node()
			if target_node.unique_id() in ownership.parents || accessible_element_hidden_by_rendering(target) { continue }
			mut ancestor := ?&Node(owner.as_node())
			mut circular := false
			for ancestor != none {
				current := ancestor or { break }
				if voidptr(current) == voidptr(target_node) { circular = true; break }
				ancestor = ownership.parent(current)
			}
			if circular { continue }
			ownership.parents[target_node.unique_id()] = owner.as_node()
			mut children := ownership.children[owner.as_node().unique_id()] or { []&Node{} }
			children << target_node
			ownership.children[owner.as_node().unique_id()] = children
		}
	}
	return ownership
}

fn (ownership &AccessibleNameOwnership) parent(node &Node) ?&Node {
	if parent := ownership.parents[node.unique_id()] { return parent }
	return node.parent_or_shadow_host()
}

fn (ownership &AccessibleNameOwnership) child_nodes(node &Node, rendered_children []&Node) []&Node {
	if ownership.parents.len == 0 { return rendered_children }
	mut children := []&Node{cap: rendered_children.len}
	for child in rendered_children {
		// Explicitly listed DOM children also move to the IDREF position.
		if child.unique_id() !in ownership.parents { children << child }
	}
	if owned := ownership.children[node.unique_id()] { children << owned }
	return children
}

// Rendering remains governed by DOM ancestry even after aria-owns. A visible
// descendant may override visibility:hidden, but cannot override display:none
// or content-visibility:hidden on a DOM ancestor.
fn accessible_element_hidden_by_rendering(element &Element) bool {
	computed := element.el_computed_properties() or { return true }
	if element.as_node().unsafe_layout_node() == none && !computed.display().is_contents() { return true }
	if computed.visibility() in [.hidden, .collapse] { return true }
	mut ancestor := ?&Node(element.as_node())
	for ancestor != none {
		current := ancestor or { break }
		if current_element := current.as_element() {
			if style := current_element.el_computed_properties() {
				if style.display().is_none() || style.content_visibility() == .hidden { return true }
			}
		}
		ancestor = current.parent_or_shadow_host()
	}
	return false
}

fn (ownership &AccessibleNameOwnership) is_hidden(element &Element) bool {
	if ownership.parents.len == 0 { return element.is_hidden() }
	if accessible_element_hidden_by_rendering(element) { return true }
	mut ancestor := ?&Node(element.as_node())
	for ancestor != none {
		current := ancestor or { break }
		if current_element := current.as_element() {
			if (current_element.get_attribute('aria-hidden') or { '' }) == 'true' { return true }
		}
		ancestor = ownership.parent(current)
	}
	return false
}
