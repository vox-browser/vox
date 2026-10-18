module platform

import os

pub const document_heap_element_threshold = 1024
const document_heap_capacity = usize(320) * 1024 * 1024

$if gcboehm ? {
	fn C.GC_expand_hp(bytes usize) int
}

// Large scripted documents create style and paint records in bulk, and retain
// that graph while an interactive relayout builds its replacement. Leave room
// for both generations without repeatedly tracing the same live document.
// A bounded capacity hint avoids repeatedly growing and tracing the same live
// graph. Existing larger heaps, explicit collector settings and small documents
// retain their normal policy; collection and idle page unmapping stay enabled.
pub fn prepare_document_heap(element_count int) bool {
	$if gcboehm ? {
		if element_count < document_heap_element_threshold
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
		if current < document_heap_capacity {
			return C.GC_expand_hp(document_heap_capacity - current) != 0
		}
	}
	return false
}

// Scripting-disabled documents favor natural managed-heap growth over reserving
// capacity for the script/style allocation wave. Explicit settings remain owned
// by the collector and the script-enabled path keeps its existing policy.
pub fn prepare_document_heap_for_scripting(element_count int, scripting_enabled bool) bool {
	if !scripting_enabled { return false }
	return prepare_document_heap(element_count)
}
