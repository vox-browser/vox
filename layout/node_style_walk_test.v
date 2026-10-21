module layout

import css
import dom

fn style_walk_owner(document &dom.Document, values &css.ComputedProperties) &NodeWithStyle {
	return &NodeWithStyle{
		Node: Node{document_: document, has_style_: true}
		computed_values_: values
	}
}

fn test_style_walk_returns_the_nearest_owner_through_unstyled_nodes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	outer_values := css.ComputedProperties.new()
	inner_values := css.ComputedProperties.new()
	mut outer := style_walk_owner(document, outer_values)
	mut inner := style_walk_owner(document, inner_values)
	outer.append_child(unsafe { &Node(inner) })
	mut current := unsafe { &Node(inner) }
	assert voidptr(current.computed_values()) == voidptr(inner_values)
	for _ in 0 .. 256 {
		child := Node.new(document, none)
		current.append_child(child)
		current = child
		assert voidptr(current.computed_values()) == voidptr(inner_values)
	}
	assert voidptr(outer.computed_values()) == voidptr(outer_values)
}

fn test_style_walk_observes_reparenting_and_replaced_owner_values() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	first_values := css.ComputedProperties.new()
	second_values := css.ComputedProperties.new()
	replacement := css.ComputedProperties.new()
	mut first := style_walk_owner(document, first_values)
	mut second := style_walk_owner(document, second_values)
	mut branch := Node.new(document, none)
	leaf := Node.new(document, none)
	branch.append_child(leaf)
	first.append_child(branch)
	assert voidptr(leaf.computed_values()) == voidptr(first_values)
	// The actual parent is authoritative during a staged move, even while an
	// old child vector still retains the branch.
	second.append_child(branch)
	assert voidptr(leaf.computed_values()) == voidptr(second_values)
	second.computed_values_ = replacement
	assert voidptr(leaf.computed_values()) == voidptr(replacement)
	assert voidptr(first.computed_values()) == voidptr(first_values)
	gc_collect()
	assert voidptr(leaf.computed_values()) == voidptr(replacement)
}

fn test_style_walk_preserves_distinct_equal_valued_owner_identity() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut owners := []&NodeWithStyle{}
	mut leaves := []&Node{}
	for _ in 0 .. 32 {
		values := css.ComputedProperties.new()
		mut owner := style_walk_owner(document, values)
		leaf := Node.new(document, none)
		owner.append_child(leaf)
		owners << owner
		leaves << leaf
	}
	gc_collect()
	for index, leaf in leaves {
		assert voidptr(leaf.computed_values()) == voidptr(owners[index].computed_values_)
		for other in 0 .. index {
			assert voidptr(leaf.computed_values()) != voidptr(leaves[other].computed_values())
		}
	}
}
