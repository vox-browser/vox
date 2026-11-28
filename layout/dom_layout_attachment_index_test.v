module layout

import dom
import html

fn test_attachment_index_preserves_visit_order_identity_and_reindexed_associations() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut root := &Node{document_:document}
	first := &Node{document_:document}
	second := &Node{document_:document}
	root.append_child(first)
	root.append_child(second)
	for indexed in [false, true] {
		if indexed { assign_layout_indexes(root) }
		mut index := DOMLayoutAttachmentWorkspace.new(root)
		defer { index.finish() }
		assert index.slots.len == if indexed { 3 } else { 0 }
		assert index.get(first) == none
		mirror := &dom.LayoutNode{layout_handle:voidptr(first)}
		index.set(first, mirror)
		assert voidptr(index.get(first)?) == voidptr(mirror)
		assert index.get(second) == none
		copy := &Node{...first}
		assert index.get(copy) == none
		copy_mirror := &dom.LayoutNode{layout_handle:voidptr(copy)}
		index.set(copy, copy_mirror)
		assert voidptr(index.get(copy)?) == voidptr(copy_mirror)
		assert voidptr(index.get(first)?) == voidptr(mirror)
		assign_layout_indexes(root)
		assert voidptr(index.get(first)?) == voidptr(mirror)
		assert index.get(second) == none
		second_mirror := &dom.LayoutNode{layout_handle:voidptr(second)}
		index.set(second, second_mirror)
		assert voidptr(index.get(second)?) == voidptr(second_mirror)
	}
}

fn test_native_attachment_workspace_reclaims_tables_and_keeps_published_geometry() {
	$if !prealloc { return }
	mut document := dom.Document.create(dom.url_about_blank())
	document.enable_native_storage()
	document.set_scripting_enabled_by_embedder(false)
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><div><span id="target">target text</span> '
		+ '<span>other fragment</span> '.repeat(96) + '</div>')
	allocations.finish()
	enable_native_paint_tree_storage(document)
	defer {
		document.destroy_a_document_and_its_descendants()
		document.finalize()
		document.release_native_storage()
	}
	_ = layout_document_typed_in_viewport(document, 380, 480)
	result := document_layout_result(document) or { panic('missing layout') }
	target := document.get_element_by_id('target') or { panic('target') }
	target_mirror := target.as_node().layout_node() or { panic('target mirror') }
	text := target.as_node().first_child() or { panic('target text') }
	text_mirror := text.layout_node() or { panic('text mirror') }
	typed_target := unsafe { &Node(target_mirror.layout_handle) }
	viewport := document.layout_node() or { panic('viewport') }
	root_mirror := viewport.root_layout_node() or { panic('root mirror') }

	mut scoped_allocations := document.enter_native_storage()
	defer { scoped_allocations.finish() }
	owner := document.native_storage().arena
	foreign := &Node{document_: document}
	foreign_mirror := &dom.LayoutNode{layout_handle: voidptr(foreign)}
	before := owner.usage().used
	for _ in 0 .. 8 {
		mut workspace := DOMLayoutAttachmentWorkspace.new(result.root)
		arena := workspace.arena
		assert arena != unsafe { nil }
		assert arena.contains(workspace.slots.data)
		workspace.set(result.root, root_mirror)
		workspace.set(foreign, foreign_mirror)
		assert arena.contains(unsafe { &workspace.other[u64(voidptr(foreign))] })
		found := workspace.get(foreign) or { panic('fallback mirror') }
		assert voidptr(found) == voidptr(foreign_mirror)
		geometry := inline_box_absolute_geometry_cached(typed_target, result.state,
			mut workspace.inline_pieces, arena) or { panic('missing inline geometry') }
		assert geometry.border_rect.width.to_double() > 0
		assert workspace.inline_pieces.len == 1
		for _, pieces in workspace.inline_pieces {
			assert pieces.len > 80
			assert arena.contains(pieces.data)
		}
		workspace.finish()
		assert arena.usage().capacity == 0
	}
	growth := owner.usage().used - before
	assert growth < 12 * 1024, '${growth} B retained while rebuilding attachment tables'
	assert target_mirror.has_geometry_
	assert text_mirror.rendered_text_chunks().join('') == 'target text'
	assert text_mirror.visual_lines().len > 0
}
