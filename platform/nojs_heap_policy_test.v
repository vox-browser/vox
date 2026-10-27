module platform

import os

$if gcboehm ? {
	struct NoJSHeapPolicyValue { mut: value uint }
	fn nojs_heap_policy_read_locked(context voidptr) voidptr {
		mut state := unsafe { &NoJSHeapPolicyValue(context) }
		state.value = C.GC_get_free_space_divisor()
		return unsafe { nil }
	}
	fn nojs_heap_policy_write_locked(context voidptr) voidptr {
		state := unsafe { &NoJSHeapPolicyValue(context) }
		C.GC_set_free_space_divisor(state.value)
		return unsafe { nil }
	}
	fn nojs_heap_policy_divisor() uint {
		mut state := NoJSHeapPolicyValue{}
		C.GC_call_with_alloc_lock(nojs_heap_policy_read_locked, &state)
		return state.value
	}
	fn nojs_heap_policy_set_divisor(value uint) {
		state := NoJSHeapPolicyValue{value: value}
		C.GC_call_with_alloc_lock(nojs_heap_policy_write_locked, &state)
	}
	fn nojs_heap_policy_callback(context voidptr) { _ = context }
}

fn test_nojs_heap_scope_keeps_compact_policy_through_nested_generic_and_cooperative_work() {
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		old_settings := settings.map(os.getenv(it))
		old_divisor := nojs_heap_policy_divisor()
		defer {
			nojs_heap_policy_set_divisor(old_divisor)
			for i, setting in settings { os.setenv(setting, old_settings[i], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		nojs_heap_policy_set_divisor(64)
		mut outer := begin_browser_activity_heap_scope()
		assert nojs_heap_policy_divisor() == 3
		mut compact := begin_browser_activity_heap_scope_for_scripting(false)
		assert nojs_heap_policy_divisor() == 64
		assert gc_is_enabled()
		mut retained := {'nested': ['Unicode λ and 🌍', 'retained document']}
		mut generic := begin_browser_activity_heap_scope()
		assert nojs_heap_policy_divisor() == 64
		mut inner := begin_browser_activity_heap_scope_for_scripting(false)
		assert nojs_heap_policy_divisor() == 64
		mut cooperative := begin_cooperative_work(unsafe { nil }, nojs_heap_policy_callback)
		if cooperative_work_state_ != unsafe { nil } {
			cooperative_work_checkpoint_at(cooperative_work_state_.started_ns + 64_000_000)
		}
		assert nojs_heap_policy_divisor() == 64
		cooperative.finish()
		inner.finish()
		inner.finish()
		generic.finish()
		assert nojs_heap_policy_divisor() == 64
		gc_collect()
		assert retained['nested'][0] == 'Unicode λ and 🌍'
		retained['nested'] << 'after collection'
		assert retained['nested'].last() == 'after collection'
		compact.finish()
		compact.finish()
		assert nojs_heap_policy_divisor() == 3
		outer.finish()
		assert nojs_heap_policy_divisor() == 64
		mut later := begin_browser_activity_heap_scope()
		assert nojs_heap_policy_divisor() == 3
		later.finish()
		assert nojs_heap_policy_divisor() == 64
	} $else {
		mut scope := begin_browser_activity_heap_scope_for_scripting(false)
		scope.finish()
		assert !scope.active
		assert !scope.compact
	}
}

fn test_nojs_heap_scope_preserves_later_policy_changes_and_existing_tighter_policy() {
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		old_settings := settings.map(os.getenv(it))
		old_divisor := nojs_heap_policy_divisor()
		defer {
			nojs_heap_policy_set_divisor(old_divisor)
			for i, setting in settings { os.setenv(setting, old_settings[i], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		nojs_heap_policy_set_divisor(3)
		mut compact := begin_browser_activity_heap_scope_for_scripting(false)
		assert nojs_heap_policy_divisor() == 64
		nojs_heap_policy_set_divisor(16)
		compact.finish()
		assert nojs_heap_policy_divisor() == 16
		nojs_heap_policy_set_divisor(128)
		mut tighter := begin_browser_activity_heap_scope_for_scripting(false)
		mut nested := begin_browser_activity_heap_scope()
		assert nojs_heap_policy_divisor() == 128
		nested.finish()
		tighter.finish()
		assert nojs_heap_policy_divisor() == 128
		mut script_enabled := begin_browser_activity_heap_scope_for_scripting(true)
		assert nojs_heap_policy_divisor() == 3
		script_enabled.finish()
		assert nojs_heap_policy_divisor() == 128
	} $else {
		assert !prepare_document_heap_for_scripting(document_heap_element_threshold, false)
	}
}

fn test_nojs_heap_policy_preserves_all_explicit_collector_settings_and_avoids_reservation() {
	$if gcboehm ? {
		settings := ['GC_INITIAL_HEAP_SIZE', 'GC_MAXIMUM_HEAP_SIZE', 'GC_FREE_SPACE_DIVISOR']
		old_settings := settings.map(os.getenv(it))
		old_divisor := nojs_heap_policy_divisor()
		defer {
			nojs_heap_policy_set_divisor(old_divisor)
			for i, setting in settings { os.setenv(setting, old_settings[i], true) }
		}
		for setting in settings { os.setenv(setting, '', true) }
		for setting in settings {
			nojs_heap_policy_set_divisor(3)
			os.setenv(setting, '8', true)
			mut compact := begin_browser_activity_heap_scope_for_scripting(false)
			assert nojs_heap_policy_divisor() == 3
			compact.finish()
			assert nojs_heap_policy_divisor() == 3
			assert !prepare_document_heap_for_scripting(document_heap_element_threshold, true)
			os.setenv(setting, '', true)
		}
		before := gc_heap_usage()
		assert !prepare_document_heap_for_scripting(document_heap_element_threshold, false)
		after := gc_heap_usage()
		assert after.heap_size + after.unmapped_bytes == before.heap_size + before.unmapped_bytes
		assert gc_is_enabled()
	} $else {
		mut scope := begin_browser_activity_heap_scope_for_scripting(false)
		scope.finish()
		assert !prepare_document_heap_for_scripting(document_heap_element_threshold, false)
	}
}
