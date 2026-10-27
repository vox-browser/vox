module platform

import os

$if gcboehm ? {
	fn C.GC_gcollect()

	struct BrowserHeapTestDivisor {
	mut:
		value uint
	}

	fn browser_heap_test_read_divisor(context voidptr) voidptr {
		mut divisor := unsafe { &BrowserHeapTestDivisor(context) }
		divisor.value = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}

	fn browser_heap_test_write_divisor(context voidptr) voidptr {
		divisor := unsafe { &BrowserHeapTestDivisor(context) }
		C.GC_set_free_space_divisor(divisor.value)
		return unsafe { nil }
	}

	fn browser_heap_test_divisor() uint {
		mut divisor := BrowserHeapTestDivisor{}
		C.GC_call_with_alloc_lock(browser_heap_test_read_divisor, &divisor)
		return divisor.value
	}

	fn browser_heap_test_set_divisor(value uint) {
		divisor := BrowserHeapTestDivisor{value: value}
		C.GC_call_with_alloc_lock(browser_heap_test_write_divisor, &divisor)
	}

	fn browser_heap_test_heap_size() uint {
		mut heap := uint(0)
		C.GC_get_heap_usage_safe(&heap, unsafe { nil }, unsafe { nil }, unsafe { nil }, unsafe { nil })
		return heap
	}
}

fn test_browser_heap_policy_preserves_overrides_and_managed_ownership() {
	$if gcboehm ? {
		old_initial := os.getenv('GC_INITIAL_HEAP_SIZE')
		old_maximum := os.getenv('GC_MAXIMUM_HEAP_SIZE')
		old_divisor := os.getenv('GC_FREE_SPACE_DIVISOR')
		original_divisor := browser_heap_test_divisor()
		if old_initial != '' || old_maximum != '' || old_divisor != '' {
			before := browser_heap_test_heap_size()
			assert !initialize_browser_heap_policy()
			assert browser_heap_test_heap_size() == before
			assert browser_heap_test_divisor() == original_divisor
			return
		}
		defer {
			os.setenv('GC_INITIAL_HEAP_SIZE', old_initial, true)
			os.setenv('GC_MAXIMUM_HEAP_SIZE', old_maximum, true)
			os.setenv('GC_FREE_SPACE_DIVISOR', old_divisor, true)
			browser_heap_test_set_divisor(original_divisor)
		}
		// Changing these after libgc startup exercises the application's own
		// precedence rule without relying on the collector rereading getenv.
		for setting in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			os.setenv(setting, '8', true)
			before := browser_heap_test_heap_size()
			assert !initialize_browser_heap_policy()
			assert browser_heap_test_heap_size() == before
			assert browser_heap_test_divisor() == original_divisor
			os.setenv(setting, '', true)
		}
		browser_heap_test_set_divisor(2)
		retained := 'managed across browser startup'.repeat(30)
		mut nested := {
			'children': [retained, 'Unicode λ and 🌍']
		}
		original := nested['children'] or { panic('missing retained children') }
		before := browser_heap_test_heap_size()
		_ = initialize_browser_heap_policy()
		assert browser_heap_test_heap_size() == before
		assert browser_heap_test_divisor() == 64
		assert !initialize_browser_heap_policy()
		browser_heap_test_set_divisor(128)
		assert !initialize_browser_heap_policy()
		assert browser_heap_test_divisor() == 128
		// Pointer-bearing aggregates remain managed after policy changes and
		// real collections, and support subsequent array/map mutations.
		C.GC_gcollect()
		assert retained.ends_with('browser startup')
		assert nested['children'] == original
		nested['children'] << 'appended after collection'
		C.GC_gcollect()
		assert nested['children'][0] == retained
		assert nested['children'][1] == 'Unicode λ and 🌍'
		assert nested['children'][2] == 'appended after collection'
	} $else {
		assert !initialize_browser_heap_policy()
	}
}
