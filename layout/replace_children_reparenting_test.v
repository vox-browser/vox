module layout

import css
import dom

fn test_replacing_children_preserves_links_already_owned_by_new_anonymous_wrappers() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	style := css.ComputedProperties.new()
	mut parent := unsafe { &Node(BlockContainer.new(document, none, style)) }
	mut wrapper := unsafe { &Node(BlockContainer.new(document, none, style)) }
	mut first := unsafe { &Node(TextNode.new_generated(document, 'first')) }
	second := unsafe { &Node(TextNode.new_generated(document, 'moved into wrapper')) }
	dropped := unsafe { &Node(TextNode.new_generated(document, 'removed')) }
	parent.append_child(first)
	parent.append_child(second)
	parent.append_child(dropped)
	wrapper.append_child(second)
	parent.replace_children([first, wrapper])
	assert voidptr(second.parent()?) == voidptr(wrapper)
	assert second.index_in_parent_ == 0
	assert voidptr(wrapper.parent()?) == voidptr(parent)
	assert wrapper.index_in_parent_ == 1
	assert voidptr(second.computed_values()) == voidptr(wrapper.computed_values())
	assert dropped.parent() == none && dropped.index_in_parent_ == -1
	parent.replace_children([wrapper])
	assert first.parent() == none && first.index_in_parent_ == -1
	assert voidptr(second.parent()?) == voidptr(wrapper)
	assert wrapper.index_in_parent_ == 0
}
