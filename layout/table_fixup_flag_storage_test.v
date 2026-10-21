module layout

import css
import dom
import platform

fn test_table_fixup_retires_saved_flags_and_restores_preexisting_skip_state() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	style := css.ComputedProperties.new().clone_for_anonymous_with_display(css.Display.from_short(.block))
	mut root := unsafe { &Node(BlockContainer.new(document, none, style)) }
	for _ in 0 .. 128 {
		child := unsafe { &Node(BlockContainer.new(document, none, style)) }
		root.append_child(child)
	}
	root.children_[17].table_fixup_skip_ = true
	storage := root.children_.data
	fixup_table_tree(mut root, document)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 16 { fixup_table_tree(mut root, document) }
	$if prealloc { assert platform.thread_arena_usage().used - before < 4096 }
	assert root.children_.data == storage
	assert root.children_.len == 128 && !root.table_fixup_skip_
	for index, child in root.children_ {
		assert child.table_fixup_skip_ == (index == 17)
		assert child.parent()? == root
	}
}
