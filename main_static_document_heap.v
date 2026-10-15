module main

import dom
import platform

fn static_document_heap_element_count(document &dom.Document) int {
	if document.as_node().is_scripting_enabled() { return 0 }
	root := document.as_node()
	mut count := 0
	mut current := root.first_child()
	for {
		node := current or { break }
		if node.is_element() {
			count++
			if count == platform.static_document_heap_element_threshold { break }
		}
		current = node.next_in_pre_order(root)
	}
	return count
}

fn prepare_static_document_render_heap(document &dom.Document) bool {
	return platform.prepare_static_document_heap(static_document_heap_element_count(document))
}
