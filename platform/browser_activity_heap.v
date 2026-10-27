module platform

import os

const browser_activity_heap_divisor = uint(3)
const browser_compact_activity_heap_divisor = uint(64)

// This count and all collector-policy access are guarded by libgc's allocation
// lock. Nested generic timer/layout scopes retain a document's compact policy.
__global browser_compact_activity_heap_scopes_ uint

pub struct BrowserActivityHeapScope {
mut:
	previous_divisor uint
	applied_divisor  uint
	active           bool
	compact          bool
}

$if gcboehm ? {
	fn browser_activity_heap_minimum_divisor_locked() uint {
		return if browser_compact_activity_heap_scopes_ > 0 { browser_compact_activity_heap_divisor } else { uint(0) }
	}

	fn begin_browser_activity_heap_locked(context voidptr) voidptr {
		mut scope := unsafe { &BrowserActivityHeapScope(context) }
		if scope.compact { browser_compact_activity_heap_scopes_++ }
		scope.previous_divisor = C.GC_get_free_space_divisor()
		minimum := browser_activity_heap_minimum_divisor_locked()
		scope.applied_divisor = if minimum > 0 { minimum } else { browser_activity_heap_divisor }
		if (minimum > 0 && scope.previous_divisor < minimum)
			|| (minimum == 0 && scope.previous_divisor > scope.applied_divisor) {
			C.GC_set_free_space_divisor(scope.applied_divisor)
			scope.active = true
		}
		return unsafe { nil }
	}

	fn finish_browser_activity_heap_locked(context voidptr) voidptr {
		mut scope := unsafe { &BrowserActivityHeapScope(context) }
		// Respect later explicit policy changes when unwinding nested work.
		if scope.active && C.GC_get_free_space_divisor() == scope.applied_divisor {
			C.GC_set_free_space_divisor(scope.previous_divisor)
		}
		if scope.compact { browser_compact_activity_heap_scopes_-- }
		return unsafe { nil }
	}
}

pub fn begin_browser_activity_heap_scope() BrowserActivityHeapScope {
	return begin_browser_activity_heap_scope_for_scripting(true)
}

// HTML/CSS documents retain full managed DOM/layout ownership while collecting
// temporary construction records more often. No collection is forced here.
pub fn begin_browser_activity_heap_scope_for_scripting(scripting_enabled bool) BrowserActivityHeapScope {
	mut scope := BrowserActivityHeapScope{}
	$if gcboehm ? {
		if os.getenv('GC_INITIAL_HEAP_SIZE') == '' && os.getenv('GC_MAXIMUM_HEAP_SIZE') == ''
			&& os.getenv('GC_FREE_SPACE_DIVISOR') == '' {
			scope.compact = !scripting_enabled
			C.GC_call_with_alloc_lock(begin_browser_activity_heap_locked, &scope)
		}
	}
	return scope
}

pub fn (mut scope BrowserActivityHeapScope) finish() {
	$if gcboehm ? {
		if scope.active || scope.compact {
			C.GC_call_with_alloc_lock(finish_browser_activity_heap_locked, &scope)
			scope.active = false
			scope.compact = false
		}
	}
}
