module main

import dom
import platform

fn document_heap_element_count(document &dom.Document) int {
	root := document.as_node()
	mut count := 0
	mut current := root.first_child()
	for {
		node := current or { break }
		if node.is_element() {
			count++
			if count == platform.document_heap_element_threshold { break }
		}
		current = node.next_in_pre_order(root)
	}
	return count
}

fn prepare_document_render_heap(document &dom.Document) bool {
	return platform.prepare_document_heap(document_heap_element_count(document))
}
