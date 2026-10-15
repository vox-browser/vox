module platform

import os

// Keep the collector enabled while allowing bulk DOM/style construction to
// make progress between collections. Restore the idle policy on every exit.
pub struct BrowserActivityHeapScope {
mut:
	previous_divisor usize
	active           bool
}

$if gcboehm ? {
	fn begin_browser_activity_heap_locked(context voidptr) voidptr {
		mut scope := unsafe { &BrowserActivityHeapScope(context) }
		scope.previous_divisor = C.GC_get_free_space_divisor()
		if scope.previous_divisor > 4 {
			C.GC_set_free_space_divisor(4)
			scope.active = true
		}
		return unsafe { nil }
	}

	fn finish_browser_activity_heap_locked(context voidptr) voidptr {
		scope := unsafe { &BrowserActivityHeapScope(context) }
		// An inner scope leaves this value alone. Preserve a subsequent explicit
		// collector-policy change instead of overwriting it during unwinding.
		if C.GC_get_free_space_divisor() == 4 {
			C.GC_set_free_space_divisor(scope.previous_divisor)
		}
		return unsafe { nil }
	}
}

pub fn begin_browser_activity_heap_scope() BrowserActivityHeapScope {
	mut scope := BrowserActivityHeapScope{}
	$if gcboehm ? {
		if os.getenv('GC_INITIAL_HEAP_SIZE') == '' && os.getenv('GC_MAXIMUM_HEAP_SIZE') == ''
			&& os.getenv('GC_FREE_SPACE_DIVISOR') == '' {
			C.GC_call_with_alloc_lock(begin_browser_activity_heap_locked, &scope)
		}
	}
	return scope
}

pub fn (mut scope BrowserActivityHeapScope) finish() {
	$if gcboehm ? {
		if scope.active {
			C.GC_call_with_alloc_lock(finish_browser_activity_heap_locked, &scope)
			scope.active = false
		}
	}
}
