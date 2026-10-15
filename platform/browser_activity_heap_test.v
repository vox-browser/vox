module platform

import os

$if gcboehm ? {
	struct ActivityHeapTestPolicy {
	mut:
		value usize
	}

	fn activity_heap_test_read(context voidptr) voidptr {
		mut policy := unsafe { &ActivityHeapTestPolicy(context) }
		policy.value = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}

	fn activity_heap_test_write(context voidptr) voidptr {
		policy := unsafe { &ActivityHeapTestPolicy(context) }
		C.GC_set_free_space_divisor(policy.value)
		return unsafe { nil }
	}

	fn activity_heap_test_divisor() usize {
		mut policy := ActivityHeapTestPolicy{}
		C.GC_call_with_alloc_lock(activity_heap_test_read, &policy)
		return policy.value
	}

	fn activity_heap_test_set_divisor(value usize) {
		policy := ActivityHeapTestPolicy{ value: value }
		C.GC_call_with_alloc_lock(activity_heap_test_write, &policy)
	}
}

fn test_browser_activity_heap_scope_keeps_gc_enabled_and_restores_nested_policy() {
	$if gcboehm ? {
		mut saved := map[string]string{}
		for name in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			saved[name] = os.getenv(name)
			os.setenv(name, '', true)
		}
		original := activity_heap_test_divisor()
		defer {
			activity_heap_test_set_divisor(original)
			for name, value in saved { os.setenv(name, value, true) }
		}
		activity_heap_test_set_divisor(32)
		mut outer := begin_browser_activity_heap_scope()
		assert activity_heap_test_divisor() == 4
		assert gc_is_enabled()
		mut inner := begin_browser_activity_heap_scope()
		inner.finish()
		assert activity_heap_test_divisor() == 4
		outer.finish()
		assert activity_heap_test_divisor() == 32
		outer.finish()
		assert activity_heap_test_divisor() == 32
		mut changed := begin_browser_activity_heap_scope()
		activity_heap_test_set_divisor(8)
		changed.finish()
		assert activity_heap_test_divisor() == 8
	} $else {
		mut scope := begin_browser_activity_heap_scope()
		scope.finish()
	}
}

fn test_browser_activity_heap_scope_honors_all_explicit_collector_overrides() {
	$if gcboehm ? {
		mut saved := map[string]string{}
		for name in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			saved[name] = os.getenv(name)
			os.setenv(name, '', true)
		}
		original := activity_heap_test_divisor()
		defer {
			activity_heap_test_set_divisor(original)
			for name, value in saved { os.setenv(name, value, true) }
		}
		activity_heap_test_set_divisor(32)
		for name in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			os.setenv(name, '8', true)
			mut scope := begin_browser_activity_heap_scope()
			assert activity_heap_test_divisor() == 32
			scope.finish()
			assert activity_heap_test_divisor() == 32
			os.setenv(name, '', true)
		}
	}
}
