module dom

$if gcboehm ? {
	fn C.GC_get_total_bytes() uint
}

fn test_style_invalidator_pending_misses_do_not_allocate_error_records() {
	mut document := Document.create(url_about_blank())
	defer { document.finalize() }
	mut root := document.create_element('div')!
	mut document_node := unsafe { &Node(document) }
	document_node.append_child(root.as_node())!
	mut root_node := root.as_node()
	for _ in 0 .. 128 {
		child := document.create_element('span')!
		root_node.append_child(child.as_node())!
	}
	mut invalidator := StyleInvalidator{}
	invalidator.invalidate(mut document_node)
	mut before := uint(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	for _ in 0 .. 128 { invalidator.invalidate(mut document_node) }
	mut allocated := uint(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert allocated == 0
	assert invalidator.pending_invalidations.len == 0
	assert root_node.children.len == 128
}
