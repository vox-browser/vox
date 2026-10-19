module platform

import os

$if gcboehm ? {
	#include "@DIR/boehm_gc.h"

	fn C.GC_get_heap_usage_safe(heap_size &usize, free_bytes &usize, unmapped_bytes &usize,
		bytes_since_gc &usize, total_bytes &usize)
	fn C.GC_get_free_space_divisor() usize
	fn C.GC_set_free_space_divisor(divisor usize)
	fn C.GC_call_with_alloc_lock(callback fn (voidptr) voidptr, context voidptr) voidptr

	struct BrowserHeapPolicyResult {
	mut:
		changed bool
	}

	fn configure_browser_heap_collections(context voidptr) voidptr {
		// libgc requires its allocation lock around divisor access after
		// threads start. This callback does not allocate while holding it.
		if C.GC_get_free_space_divisor() < 64 {
			C.GC_set_free_space_divisor(64)
			mut result := unsafe { &BrowserHeapPolicyResult(context) }
			result.changed = true
		}
		return unsafe { nil }
	}
}

// Collect temporary browser data before it inflates the resident heap. Apply
// before startup work; heap capacity grows naturally with actual live data.
pub fn initialize_browser_heap_policy() bool {
	$if gcboehm ? {
		// An explicit collector configuration owns both sizing and collection
		// behavior, so leave all of it unchanged when any override is present.
		if os.getenv('GC_INITIAL_HEAP_SIZE') != '' || os.getenv('GC_MAXIMUM_HEAP_SIZE') != ''
			|| os.getenv('GC_FREE_SPACE_DIVISOR') != '' {
			return false
		}
		mut result := BrowserHeapPolicyResult{}
		C.GC_call_with_alloc_lock(configure_browser_heap_collections, &result)
		return result.changed
	}
	return false
}
