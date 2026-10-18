module layout

import css
import dom

fn table_subtree_box(document &dom.Document, display css.Display) &Node {
	style := css.ComputedProperties.new().clone_for_anonymous_with_display(display)
	return unsafe { &Node(BlockContainer.new(document, none, style)) }
}

fn table_subtree_fixture(document &dom.Document, variant int) &Node {
	mut root := table_subtree_box(document, css.Display.from_short(.block))
	for index in 0 .. 12 {
		mut child := table_subtree_box(document, css.Display.from_short(.block))
		if index == 5 {
			display := match variant {
				0 { css.Display.from_short(.block) }
				1 { css.Display.from_internal(.table_cell) }
				2 { css.Display.from_internal(.table_row) }
				3 { css.Display.from_internal(.table_caption) }
				4 { css.Display.from_internal(.table_column_group) }
				else { css.Display.from_short(.table) }
			}
			child = table_subtree_box(document, display)
			mut row := table_subtree_box(document, css.Display.from_internal(.table_row))
			row.append_child(table_subtree_box(document, css.Display.from_internal(.table_cell)))
			if variant != 0 { child.append_child(row) }
		}
		child.append_child(unsafe { &Node(TextNode.new_generated(document, 'ordinary text')) })
		child.append_child(unsafe { &Node(TextNode.new_generated(document, ' ')) })
		root.append_child(child)
	}
	return root
}

fn table_subtree_shape(node &Node) string {
	mut shape := '${node.display()} anonymous=${node.is_anonymous()} wrapper=${node.is_table_wrapper()} inline=${node.children_are_inline()}['
	if text := node.as_text_node() { shape += text.text_for_rendering() }
	for child in node.children_ { shape += table_subtree_shape(child) }
	return shape + ']'
}

fn test_table_fixup_subtree_proof_preserves_all_rules_beside_ordinary_flow() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for variant in 0 .. 6 {
		mut fast := table_subtree_fixture(document, variant)
		mut full := table_subtree_fixture(document, variant)
		fixup_table_tree(mut fast, document)
		fixup_table_tree_full(mut full, document)
		assert table_subtree_shape(fast) == table_subtree_shape(full)
		fast.for_each_in_inclusive_subtree(fn (node &Node) dom.TraversalDecision {
			assert !node.table_fixup_skip_
			return .@continue
		})
	}
}

fn test_table_fixup_rechecks_new_table_children_after_an_ordinary_pass() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut fast := table_subtree_fixture(document, 0)
	mut full := table_subtree_fixture(document, 0)
	storage := fast.children_.data
	fixup_table_tree(mut fast, document)
	assert fast.children_.data == storage
	fixup_table_tree_full(mut full, document)
	mut fast_child := fast.children_[4]
	mut full_child := full.children_[4]
	fast_child.append_child(table_subtree_box(document, css.Display.from_internal(.table_cell)))
	full_child.append_child(table_subtree_box(document, css.Display.from_internal(.table_cell)))
	fixup_table_tree(mut fast, document)
	fixup_table_tree_full(mut full, document)
	assert table_subtree_shape(fast) == table_subtree_shape(full)
}
