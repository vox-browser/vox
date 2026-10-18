module layout

import dom

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
		mut index := DOMLayoutAttachmentIndex.new(root)
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
