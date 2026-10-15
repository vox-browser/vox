module layout

import css
import dom

fn table_fixup_storage_box(document &dom.Document, display css.Display) &Node {
	style := css.ComputedProperties.new().clone_for_anonymous_with_display(display)
	return unsafe { &Node(Box.new(document, none, style)) }
}

fn test_table_cleanup_keeps_ordinary_child_storage_and_whitespace_unchanged() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := table_fixup_storage_box(document, css.Display.from_short(.block))
	mut child := table_fixup_storage_box(document, css.Display.from_short(.block))
	text := unsafe { &Node(TextNode.new_generated(document, 'ordinary content')) }
	space := unsafe { &Node(TextNode.new_generated(document, ' ')) }
	child.append_child(text)
	root.append_child(child)
	root.append_child(space)
	root_storage := root.children_.data
	child_storage := child.children_.data
	for _ in 0 .. 3 {
		remove_irrelevant_table_children(mut root)
		gc_collect()
		assert root.children_.data == root_storage
		assert child.children_.data == child_storage
		assert root.child_count() == 2
		assert voidptr(root.children_[0]) == voidptr(child)
		assert voidptr(root.children_[1]) == voidptr(space)
		assert voidptr(child.first_child()?) == voidptr(text)
		assert voidptr(space.parent()?) == voidptr(root)
		assert space.index_in_parent_ == 1
	}
}

fn test_table_cleanup_filters_columns_then_visits_surviving_children_only() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := table_fixup_storage_box(document, css.Display.from_short(.block))
	mut group := table_fixup_storage_box(document, css.Display.from_internal(.table_column_group))
	mut first := table_fixup_storage_box(document, css.Display.from_internal(.table_column))
	mut second := table_fixup_storage_box(document, css.Display.from_internal(.table_column))
	mut rejected := table_fixup_storage_box(document, css.Display.from_short(.block))
	retained := table_fixup_storage_box(document, css.Display.from_short(.block))
	first.append_child(table_fixup_storage_box(document, css.Display.from_short(.block)))
	rejected.append_child(retained)
	group.append_child(first)
	group.append_child(rejected)
	group.append_child(second)
	root.append_child(group)
	root_storage := root.children_.data
	remove_irrelevant_table_children(mut root)
	assert root.children_.data == root_storage
	assert group.child_count() == 2
	assert voidptr(group.children_[0]) == voidptr(first)
	assert voidptr(group.children_[1]) == voidptr(second)
	assert first.child_count() == 0
	assert rejected.parent() == none
	assert rejected.index_in_parent_ == -1
	assert voidptr(rejected.first_child()?) == voidptr(retained)
	assert first.index_in_parent_ == 0 && second.index_in_parent_ == 1
	group_storage := group.children_.data
	remove_irrelevant_table_children(mut root)
	gc_collect()
	assert group.children_.data == group_storage
	assert voidptr(second.parent()?) == voidptr(group)
}
