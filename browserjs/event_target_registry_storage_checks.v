module browserjs

import platform

$if test {
	pub fn check_event_target_registry_storage() {
		initial_count := event_target_bindings_.len
		mut bindings := []&EventTargetBinding{}
		for _ in 0 .. 64 { bindings << &EventTargetBinding{} }
		mut arena := platform.new_arena('event-target-registry-caller')
		before := arena.usage().used
		entry := arena.enter()
		for binding in bindings { register_runtime_binding(mut event_target_bindings_, voidptr(binding), binding) }
		arena.leave(entry)
		registration_bytes := arena.usage().used - before
		if registration_bytes == 0 {
			arena.reset()
			for binding in bindings {
				actual := event_target_bindings_[voidptr(binding)] or { panic('lost EventTarget binding') }
				assert voidptr(actual) == voidptr(binding)
			}
		}
		for binding in bindings { unregister_runtime_binding(mut event_target_bindings_, voidptr(binding)) }
		arena.release()
		assert event_target_bindings_.len == initial_count
		assert registration_bytes == 0, 'process-wide EventTarget registry allocated in a document arena'
	}

	pub fn check_event_target_registry_removal_storage() {
		initial_count := event_target_bindings_.len
		mut bindings := []&EventTargetBinding{}
		for _ in 0 .. 64 {
			binding := &EventTargetBinding{}
			bindings << binding
			register_runtime_binding(mut event_target_bindings_, voidptr(binding), binding)
		}
		mut arena := platform.new_arena('event-target-registry-removal')
		before := arena.usage().used
		entry := arena.enter()
		for binding in bindings[..16] {
			unregister_runtime_binding(mut event_target_bindings_, voidptr(binding))
		}
		arena.leave(entry)
		removal_bytes := arena.usage().used - before
		if removal_bytes == 0 {
			arena.reset()
			assert event_target_bindings_.len == initial_count + 48
			for binding in bindings[..16] { assert voidptr(binding) !in event_target_bindings_ }
			for binding in bindings[16..] {
				actual := event_target_bindings_[voidptr(binding)] or { panic('lost surviving EventTarget binding') }
				assert voidptr(actual) == voidptr(binding)
			}
		}
		for binding in bindings[16..] {
			unregister_runtime_binding(mut event_target_bindings_, voidptr(binding))
		}
		arena.release()
		assert event_target_bindings_.len == initial_count
		assert removal_bytes == 0, 'EventTarget removal allocated surviving registry metadata in a closing arena'
	}
}
