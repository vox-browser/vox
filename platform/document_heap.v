module platform

import os

$if gcboehm ? {
	fn C.GC_get_heap_size() usize
	fn C.GC_expand_hp(bytes usize) int
}

// Large documents create substantial short-lived parser/style/layout input.
// Give the collector room before that burst instead of repeatedly growing and
// marking a small heap. This is a capacity hint: collection stays enabled and
// allocation failure leaves its ordinary growth policy intact.
pub fn reserve_gc_heap_for_document(source_bytes int) bool {
	if source_bytes < 256 * 1024 {
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
