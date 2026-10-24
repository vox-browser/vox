module layout

import css
import dom

fn borrowed_table_child_box(document &dom.Document, display css.Display) &Node {
	style := css.ComputedProperties.new().clone_for_anonymous_with_display(display)
	return unsafe { &Node(BlockContainer.new(document, none, style)) }
}

fn borrowed_table_child_links(parent &Node, expected []&Node) {
	assert parent.children_.len == expected.len
	for index, child in expected {
		assert voidptr(parent.children_[index]) == voidptr(child)
		assert voidptr(child.parent() or { panic('missing parent') }) == voidptr(parent)
		assert child.index_in_parent_ == index
	}
}

fn test_table_wrapper_descendant_mutation_visits_every_later_sibling() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := borrowed_table_child_box(document, css.Display.from_short(.block))
	mut tables := []&Node{}
	mut contents := []&Node{}
	for _ in 0 .. 5 {
		mut table := borrowed_table_child_box(document, css.Display.from_short(.table))
		content := borrowed_table_child_box(document, css.Display.from_short(.block))
		table.append_child(content)
		root.append_child(table)
		tables << table
		contents << content
	}
	generate_table_child_wrappers(mut root, document)
	borrowed_table_child_links(root, tables)
	for index, table in tables {
		assert table.children_.len == 1
		row := table.children_[0]
		assert row.is_anonymous() && row.display().is_table_row()
		borrowed_table_child_links(table, [row])
		borrowed_table_child_links(row, [contents[index]])
	}
	gc_collect()
	generate_table_child_wrappers(mut root, document)
	for index, table in tables {
		row := table.children_[0]
		assert row.children_.len == 1
		cell := row.children_[0]
		assert cell.is_anonymous() && cell.display().is_table_cell()
		borrowed_table_child_links(row, [cell])
		borrowed_table_child_links(cell, [contents[index]])
	}
	borrowed_table_child_links(root, tables)
}

fn test_table_wrapper_nested_descendants_keep_authored_ancestor_links() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut table := borrowed_table_child_box(document, css.Display.from_short(.table))
	mut group := borrowed_table_child_box(document, css.Display.from_internal(.table_row_group))
	mut row := borrowed_table_child_box(document, css.Display.from_internal(.table_row))
	mut block := borrowed_table_child_box(document, css.Display.from_short(.block))
	mut inner := borrowed_table_child_box(document, css.Display.from_short(.table))
	leaf := borrowed_table_child_box(document, css.Display.from_short(.block))
	inner.append_child(leaf)
	block.append_child(inner)
	row.append_child(block)
	group.append_child(row)
	table.append_child(group)
	generate_table_child_wrappers(mut table, document)
	borrowed_table_child_links(table, [group])
	borrowed_table_child_links(group, [row])
	assert row.children_.len == 1
	cell := row.children_[0]
	assert cell.is_anonymous() && cell.display().is_table_cell()
	borrowed_table_child_links(row, [cell])
	borrowed_table_child_links(cell, [block])
	borrowed_table_child_links(block, [inner])
	assert inner.children_.len == 1
	inner_row := inner.children_[0]
	assert inner_row.is_anonymous() && inner_row.display().is_table_row()
	borrowed_table_child_links(inner, [inner_row])
	borrowed_table_child_links(inner_row, [leaf])
	gc_collect()
	generate_table_child_wrappers(mut table, document)
	borrowed_table_child_links(table, [group])
	borrowed_table_child_links(group, [row])
	borrowed_table_child_links(row, [cell])
	borrowed_table_child_links(block, [inner])
	assert inner_row.children_.len == 1
	inner_cell := inner_row.children_[0]
	assert inner_cell.is_anonymous() && inner_cell.display().is_table_cell()
	borrowed_table_child_links(inner_row, [inner_cell])
	borrowed_table_child_links(inner_cell, [leaf])
}

fn test_table_wrapper_skipped_subtree_can_be_revisited_after_later_sibling() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := borrowed_table_child_box(document, css.Display.from_short(.block))
	mut skipped := borrowed_table_child_box(document, css.Display.from_internal(.table_row))
	first := borrowed_table_child_box(document, css.Display.from_short(.block))
	skipped.append_child(first)
	skipped.table_fixup_skip_ = true
	mut later := borrowed_table_child_box(document, css.Display.from_internal(.table_row))
	second := borrowed_table_child_box(document, css.Display.from_short(.block))
	later.append_child(second)
	root.append_child(skipped)
	root.append_child(later)
	generate_table_child_wrappers(mut root, document)
	borrowed_table_child_links(root, [skipped, later])
	borrowed_table_child_links(skipped, [first])
	assert later.children_.len == 1
	later_cell := later.children_[0]
	assert later_cell.is_anonymous() && later_cell.display().is_table_cell()
	borrowed_table_child_links(later_cell, [second])
	gc_collect()
	skipped.table_fixup_skip_ = false
	generate_table_child_wrappers(mut root, document)
	assert skipped.children_.len == 1
	first_cell := skipped.children_[0]
	assert first_cell.is_anonymous() && first_cell.display().is_table_cell()
	borrowed_table_child_links(skipped, [first_cell])
	borrowed_table_child_links(first_cell, [first])
	borrowed_table_child_links(later, [later_cell])
	borrowed_table_child_links(later_cell, [second])
	borrowed_table_child_links(root, [skipped, later])
}
