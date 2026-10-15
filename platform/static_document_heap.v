module platform

import os

pub const static_document_heap_element_threshold = 1024
const static_document_heap_capacity = usize(160) * 1024 * 1024

$if gcboehm ? {
	fn C.GC_expand_hp(bytes usize) int
}

// Large static documents create their style and paint records in one bulk pass.
// A bounded capacity hint avoids repeatedly growing and tracing the same live
// graph. Existing larger heaps, explicit collector settings and small documents
// retain their normal policy; collection and idle page unmapping stay enabled.
pub fn prepare_static_document_heap(element_count int) bool {
	$if gcboehm ? {
		if element_count < static_document_heap_element_threshold
			|| os.getenv('GC_INITIAL_HEAP_SIZE') != ''
			|| os.getenv('GC_MAXIMUM_HEAP_SIZE') != ''
			|| os.getenv('GC_FREE_SPACE_DIVISOR') != '' {
			return false
		}
		usage := gc_heap_usage()
		// Boehm excludes unmapped pages from heap_size, but retains them as
		// reusable capacity. Expanding on mapped bytes alone would acquire new
		// OS memory again after every idle collection unmaps the free pages.
		current := usage.heap_size + usage.unmapped_bytes
		if current < static_document_heap_capacity {
			return C.GC_expand_hp(static_document_heap_capacity - current) != 0
		}
	}
	return false
}
