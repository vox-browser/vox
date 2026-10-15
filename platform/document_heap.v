module platform

import os

$if gcboehm ? {
	fn C.GC_get_heap_size() usize
	fn C.GC_get_heap_usage_safe(heap_size &usize, free_bytes &usize, unmapped_bytes &usize,
		bytes_since_gc &usize, total_bytes &usize)
	fn C.GC_expand_hp(bytes usize) int
	fn C.GC_get_free_space_divisor() usize
	fn C.GC_set_free_space_divisor(divisor usize)
	fn C.GC_call_with_alloc_lock(callback fn (voidptr) voidptr, context voidptr) voidptr
}

pub fn document_heap_reservation_element_threshold() int {
	// Medium-sized documents allocate enough temporary style/layout records to
	// benefit from the compact heap policy before their first layout.
	return 1024
}

$if gcboehm ? {
	fn configure_document_heap_collections(_ voidptr) voidptr {
		// libgc's divisor accessors require its allocation lock after threads
		// start. Keep this callback allocation-free while holding that lock.
		if C.GC_get_free_space_divisor() < 16 {
			C.GC_set_free_space_divisor(16)
		}
		return unsafe { nil }
	}
}

// Substantial DOMs use a modest initial reservation and collect temporary
// layout input more often instead of retaining a large unused heap. This is
// not a heap limit: larger live documents can still grow normally. Collection
// stays enabled, and a refused reservation leaves normal growth intact.
pub fn reserve_gc_heap_for_document(element_count int) bool {
	if element_count < document_heap_reservation_element_threshold() {
		return false
	}
	$if gcboehm ? {
		// Explicit collector settings take precedence over the browser's hint.
		if os.getenv('GC_INITIAL_HEAP_SIZE') != '' || os.getenv('GC_MAXIMUM_HEAP_SIZE') != ''
			|| os.getenv('GC_FREE_SPACE_DIVISOR') != '' {
			return false
		}
		C.GC_call_with_alloc_lock(configure_document_heap_collections, unsafe { nil })
		target := usize(64) * 1024 * 1024
		mut current := usize(0)
		C.GC_get_heap_usage_safe(&current, unsafe { nil }, unsafe { nil }, unsafe { nil }, unsafe { nil })
		if current < target {
			return C.GC_expand_hp(target - current) != 0
		}
	}
	return false
}
