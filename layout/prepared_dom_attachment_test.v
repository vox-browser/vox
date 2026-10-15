module layout

import dom
import html
import css

fn test_prepared_dom_attachment_commits_geometry_without_replacing_fresh_mirrors() {
	mut document := html.parse_document('<!doctype html><style>html,body,div{margin:0}div{font:16px/20px SerenityMono}</style><div id="host">a b</div>')
	defer { document.finalize() }
	root := build_layout_tree(document) or { panic('tree') }
	prepared := prepare_dom_layout_attachment(root)
	host := document.get_element_by_id('host') or { panic('host') }
	text := host.as_node().first_child() or { panic('text') }
	initial_host := host.as_node().layout_node() or { panic('mirror') }
	initial_text := text.layout_node() or { panic('mirror') }
	root_children_data := prepared.root.children_.data
	assert !initial_host.has_geometry_
	assert initial_text.rendered_text_chunks_.len == 0
	document.set_layout_viewport(&dom.LayoutViewport{ root_node: prepared.root })
	mut state := LayoutState.new()
	viewport := root.as_viewport() or { panic('viewport') }
	layout_viewport(mut state, viewport, 200, 100)
	committed := commit_dom_layout_attachment(root, state, prepared)
	assert voidptr(committed) == voidptr(prepared.root)
	assert committed.children_.data == root_children_data
	assert voidptr(host.as_node().layout_node() or { panic('host') }) == voidptr(initial_host)
	assert voidptr(text.layout_node() or { panic('text') }) == voidptr(initial_text)
	assert initial_host.has_geometry_
	assert initial_host.content_width_ == 200
	assert initial_text.rendered_text_chunks_.join('') == 'a b'
	assert initial_text.visual_lines_.len > 0
	assert initial_text.containing_block() != none
	assert voidptr(initial_text.parent() or { panic('parent') }) == voidptr(initial_host)
}

fn test_prepared_dom_attachment_keeps_previous_pass_snapshots_untouched() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}</style><div id="host">snapshot</div>')
	defer { document.finalize() }
	root := build_layout_tree(document) or { panic('tree') }
	initial := prepare_dom_layout_attachment(root)
	document.set_layout_viewport(&dom.LayoutViewport{ root_node: initial.root })
	mut first_state := LayoutState.new()
	viewport := root.as_viewport() or { panic('viewport') }
	layout_viewport(mut first_state, viewport, 200, 100)
	previous := commit_dom_layout_attachment(root, first_state, initial)
	host := document.get_element_by_id('host') or { panic('host') }
	previous_host := host.as_node().layout_node() or { panic('host') }
	old_rect := previous_host.border_box_
	old_children := previous.children_.clone()
	prepared := prepare_dom_layout_attachment(root)
	assert voidptr(prepared.root) != voidptr(previous)
	mut second_state := LayoutState.new()
	layout_viewport(mut second_state, viewport, 300, 100)
	_ = commit_dom_layout_attachment(root, second_state, prepared)
	current := host.as_node().layout_node() or { panic('host') }
	assert voidptr(current) != voidptr(previous_host)
	assert current.content_width_ == 300
	assert previous_host.border_box_ == old_rect
	assert previous_host.content_width_ == 200
	assert previous.children_.len == old_children.len
	for index, child in previous.children_ {
		assert voidptr(child) == voidptr(old_children[index])
	}
}

fn test_prepared_dom_attachment_allocates_mirrors_for_nodes_added_during_layout() {
	mut document := html.parse_document('<!doctype html><p>before</p>')
	defer { document.finalize() }
	mut root := build_layout_tree(document) or { panic('tree') }
	prepared := prepare_dom_layout_attachment(root)
	original_count := prepared.root.children_.len
	late := BlockContainer.new(document, none, css.ComputedProperties.new())
	root.append_child(unsafe { &Node(late) })
	state := LayoutState.new()
	committed := commit_dom_layout_attachment(root, state, prepared)
	assert voidptr(committed) == voidptr(prepared.root)
	assert committed.children_.len == original_count + 1
	mirror := committed.children_.last()
	assert mirror.layout_handle == voidptr(late)
	assert voidptr(mirror.parent() or { panic('parent') }) == voidptr(committed)
	assert !mirror.has_geometry_
	assert u64(voidptr(late)) !in prepared.placeholders
}
