module dom

// NavigableContainer's local DOM projection. Rendering and host code need the
// actual child navigable, including during the gap with no active document.
// Script-visible contentDocument applies its origin check at the HTML boundary.
pub fn (node &Node) content_navigable() ?&Navigable {
	if !node.is_navigable_container() { return none }
	for navigable in dom_all_navigables {
		if navigable.has_been_destroyed_ { continue }
		container := navigable.container() or { continue }
		if voidptr(container) == voidptr(node) { return navigable }
	}
	return none
}
