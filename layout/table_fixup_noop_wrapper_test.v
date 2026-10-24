module layout

import css
import dom

fn noop_table_wrapper_box(document &dom.Document, display css.Display) &Node {
	style := css.ComputedProperties.new().clone_for_anonymous_with_display(display)
	return unsafe { &Node(BlockContainer.new(document, none, style)) }
}

fn noop_table_wrapper_check_children(parent &Node, expected []&Node) {
	assert parent.children_.len == expected.len
	for index, child in expected {
		assert voidptr(parent.children_[index]) == voidptr(child)
		assert voidptr(child.parent() or { panic('missing child parent') }) == voidptr(parent)
		assert child.index_in_parent_ == index
	}
}

fn test_table_sequence_no_match_preserves_children_for_every_role_predicate() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	predicates := [table_not_proper_child, table_not_row, table_not_cell,
		table_is_cell, table_is_row, table_is_proper_child]
	for variant, predicate in predicates {
		mut parent := noop_table_wrapper_box(document, css.Display.from_short(.block))
		display := match variant {
			0, 1 { css.Display.from_internal(.table_row) }
			2 { css.Display.from_internal(.table_cell) }
			else { css.Display.from_short(.block) }
		}
		wrap_table_child_sequences(mut parent, document, predicate,
			css.Display.from_internal(.table_row), .box)
		assert parent.children_.len == 0
		mut expected := []&Node{}
		for _ in 0 .. 3 {
			child := noop_table_wrapper_box(document, display)
			parent.append_child(child)
			expected << child
		}
		for _ in 0 .. 3 {
			wrap_table_child_sequences(mut parent, document, predicate,
				css.Display.from_internal(.table_row), .box)
			gc_collect()
			noop_table_wrapper_check_children(parent, expected)
		}
	}
}

fn test_table_sequence_late_match_keeps_prefix_trailing_space_and_separate_runs() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := noop_table_wrapper_box(document, css.Display.from_short(.block))
	prefix := noop_table_wrapper_box(document, css.Display.from_short(.block))
	first := noop_table_wrapper_box(document, css.Display.from_internal(.table_cell))
	mut space_between := noop_table_wrapper_box(document, css.Display.from_short(.block))
	space_between.anonymous_ = true
	space_between.append_child(unsafe { &Node(TextNode.new_generated(document, ' ')) })
	second := noop_table_wrapper_box(document, css.Display.from_internal(.table_cell))
	trailing := unsafe { &Node(TextNode.new_generated(document, '\t')) }
	separator := noop_table_wrapper_box(document, css.Display.from_short(.block))
	last := noop_table_wrapper_box(document, css.Display.from_internal(.table_cell))
	for child in [prefix, first, space_between, second, trailing, separator, last] {
		parent.append_child(child)
	}
	wrap_table_child_sequences(mut parent, document, table_is_cell,
		css.Display.from_internal(.table_row), .box)
	assert parent.children_.len == 5
	row := parent.children_[1]
	last_row := parent.children_[4]
	assert row.is_anonymous() && row.display().is_table_row()
	assert last_row.is_anonymous() && last_row.display().is_table_row()
	noop_table_wrapper_check_children(parent, [prefix, row, trailing, separator, last_row])
	noop_table_wrapper_check_children(row, [first, space_between, second])
	noop_table_wrapper_check_children(last_row, [last])
	gc_collect()
	wrap_table_child_sequences(mut parent, document, table_is_cell,
		css.Display.from_internal(.table_row), .box)
	noop_table_wrapper_check_children(parent, [prefix, row, trailing, separator, last_row])
	noop_table_wrapper_check_children(row, [first, space_between, second])
}

fn test_table_sequence_rechecks_a_cell_inserted_after_no_match() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut parent := noop_table_wrapper_box(document, css.Display.from_short(.block))
	ordinary := noop_table_wrapper_box(document, css.Display.from_short(.block))
	parent.append_child(ordinary)
	wrap_table_child_sequences(mut parent, document, table_is_cell,
		css.Display.from_internal(.table_row), .box)
	noop_table_wrapper_check_children(parent, [ordinary])
	cell := noop_table_wrapper_box(document, css.Display.from_internal(.table_cell))
	parent.append_child(cell)
	gc_collect()
	wrap_table_child_sequences(mut parent, document, table_is_cell,
		css.Display.from_internal(.table_row), .box)
	assert parent.children_.len == 2
	row := parent.children_[1]
	assert row.is_anonymous() && row.display().is_table_row()
	noop_table_wrapper_check_children(parent, [ordinary, row])
	noop_table_wrapper_check_children(row, [cell])
}
