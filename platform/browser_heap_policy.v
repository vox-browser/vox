module platform

import os

$if gcboehm ? {
	fn C.GC_get_heap_usage_safe(heap_size &usize, free_bytes &usize, unmapped_bytes &usize,
		bytes_since_gc &usize, total_bytes &usize)
	fn C.GC_expand_hp(bytes usize) int
	fn C.GC_get_free_space_divisor() usize
	fn C.GC_set_free_space_divisor(divisor usize)
	fn C.GC_call_with_alloc_lock(callback fn (voidptr) voidptr, context voidptr) voidptr

	fn configure_browser_heap_collections(_ voidptr) voidptr {
		// libgc requires its allocation lock around divisor access after
		// threads start. This callback does not allocate while holding it.
		if C.GC_get_free_space_divisor() < 16 {
			C.GC_set_free_space_divisor(16)
		}
		return unsafe { nil }
	}
}

// Apply before browser startup work, once the language runtime has initialized
// libgc. Reserving early avoids repeated growth and tracing during startup;
// the collection policy limits temporary layout retention later. This is an
// initial reservation, not a maximum: larger live pages can grow normally.
pub fn initialize_browser_heap_policy() bool {
	$if gcboehm ? {
		// An explicit collector configuration owns both sizing and collection
		// behavior, so leave all of it unchanged when any override is present.
		if os.getenv('GC_INITIAL_HEAP_SIZE') != '' || os.getenv('GC_MAXIMUM_HEAP_SIZE') != ''
			|| os.getenv('GC_FREE_SPACE_DIVISOR') != '' {
			return false
		}
		C.GC_call_with_alloc_lock(configure_browser_heap_collections, unsafe { nil })
		target := usize(224) * 1024 * 1024
		mut current := usize(0)
		C.GC_get_heap_usage_safe(&current, unsafe { nil }, unsafe { nil }, unsafe { nil }, unsafe { nil })
		if current < target {
			return C.GC_expand_hp(target - current) != 0
		}
	}
	return false
}
