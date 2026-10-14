module platform

import os

$if gcboehm ? {
	fn C.GC_get_heap_size() usize
	fn C.GC_expand_hp(bytes usize) int
}

pub fn document_heap_reservation_element_threshold() int {
	return 2048
}

// Substantial DOMs create short-lived style/layout input. Give the collector
// room before that burst, while large comments and text blobs keep ordinary
// growth. Collection stays enabled; a refused hint leaves normal growth intact.
pub fn reserve_gc_heap_for_document(element_count int) bool {
	if element_count < document_heap_reservation_element_threshold() {
		return false
	}
	$if gcboehm ? {
		// Explicit collector settings take precedence over the browser's hint.
		if os.getenv('GC_INITIAL_HEAP_SIZE') != '' || os.getenv('GC_MAXIMUM_HEAP_SIZE') != '' {
			return false
		}
		target := usize(512 * 1024 * 1024)
		current := C.GC_get_heap_size()
		if current < target {
			return C.GC_expand_hp(target - current) != 0
		}
	}
	return false
}
