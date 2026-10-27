module platform

import os

$if gcboehm ? {
	struct ActivityHeapTestPolicy {
	mut:
		value uint
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

	fn activity_heap_test_divisor() uint {
		mut policy := ActivityHeapTestPolicy{}
		C.GC_call_with_alloc_lock(activity_heap_test_read, &policy)
		return policy.value
	}

	fn activity_heap_test_set_divisor(value uint) {
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
		activity_heap_test_set_divisor(128)
		mut outer := begin_browser_activity_heap_scope()
		assert activity_heap_test_divisor() == 3
		assert gc_is_enabled()
		mut inner := begin_browser_activity_heap_scope()
		inner.finish()
		assert activity_heap_test_divisor() == 3
		outer.finish()
		assert activity_heap_test_divisor() == 128
		outer.finish()
		assert activity_heap_test_divisor() == 128
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
		activity_heap_test_set_divisor(128)
		for name in ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR'] {
			os.setenv(name, '8', true)
			mut scope := begin_browser_activity_heap_scope()
			assert activity_heap_test_divisor() == 128
			scope.finish()
			assert activity_heap_test_divisor() == 128
			os.setenv(name, '', true)
		}
	}
}

fn test_timer_callbacks_keep_nested_active_policy_and_restore_idle_after_cleanup() {
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		previous := settings.map(os.getenv(it))
		original := activity_heap_test_divisor()
		defer {
			activity_heap_test_set_divisor(original)
			for index, setting in settings { os.setenv(setting, previous[index], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		activity_heap_test_set_divisor(64)
		mut timer := Timer.create_single_shot(100000, fn () {
			assert activity_heap_test_divisor() == 3
			assert gc_is_enabled()
			mut nested := Timer.create_single_shot(100000, fn () {
				assert activity_heap_test_divisor() == 3
				assert gc_is_enabled()
			})
			nested.start()
			nested.fire()
			assert !nested.has_activity_root()
			assert activity_heap_test_divisor() == 3
		})
		timer.start()
		timer.fire()
		assert !timer.has_activity_root()
		assert activity_heap_test_divisor() == 64
		for setting in settings {
			os.setenv(setting, '64', true)
			mut overridden := Timer.create_single_shot(100000, fn () {
				assert activity_heap_test_divisor() == 64
			})
			overridden.start()
			overridden.fire()
			assert activity_heap_test_divisor() == 64
			os.setenv(setting, '', true)
		}
	} $else {
		mut timer := Timer.create_single_shot(100000, fn () { assert true })
		timer.start()
		timer.fire()
		assert !timer.has_activity_root()
	}
}
