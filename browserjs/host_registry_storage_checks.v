module browserjs

import platform

// Internal ownership probes are available only in test builds.
$if test {
	pub fn check_websocket_registry_storage() {
		initial_count := websocket_hosts_.len
		assert initial_count == 0
		mut hosts := []&WebSocketHost{}
		for _ in 0 .. 64 {
			hosts << &WebSocketHost{document: unsafe { nil }, settings: unsafe { nil }}
		}
		mut arena := platform.new_arena('websocket-registration-test')
		entry := arena.enter()
		for host in hosts { register_websocket_host(host) }
		arena.leave(entry)
		transient_backing := arena.contains(websocket_hosts_.data)
		if !transient_backing {
			arena.reset()
			poll_websocket_hosts()
			actual_count := websocket_hosts_.len
			expected_count := hosts.len
			assert actual_count == expected_count
			for index, host in hosts {
				actual := uint(voidptr(websocket_hosts_[index]))
				expected := uint(voidptr(host))
				assert actual == expected
			}
		}
		for host in hosts { unregister_websocket_host(host) }
		arena.release()
		final_count := websocket_hosts_.len
		assert final_count == 0
		assert !transient_backing, 'process-wide WebSocket registry used a registration arena'
	}

	pub fn check_timer_registry_storage() {
		initial_owners := timer_host_bindings_.len
		initial_scopes := timer_scope_bindings_.len
		assert initial_owners == 0 && initial_scopes == 0
		mut hosts := []&TimerHost{}
		for _ in 0 .. 64 { hosts << &TimerHost{settings: unsafe { nil }, scope: unsafe { nil }} }
		mut arena := platform.new_arena('timer-registration-test')
		before := arena.usage().used
		entry := arena.enter()
		for host in hosts { register_timer_host(voidptr(host), voidptr(host), host) }
		arena.leave(entry)
		// Maps have an opaque, persistent header. Observe allocations made by
		// registry growth rather than merely checking that header's address.
		registration_bytes := arena.usage().used - before
		if registration_bytes == 0 {
			arena.reset()
			for host in hosts {
				owner := timer_host_bindings_[voidptr(host)] or { panic('lost timer owner') }
				scope := timer_scope_bindings_[voidptr(host)] or { panic('lost timer scope') }
				expected := uint(voidptr(host))
				actual_owner := uint(voidptr(owner))
				actual_scope := uint(voidptr(scope))
				assert actual_owner == expected && actual_scope == expected
			}
		}
		for host in hosts { unregister_timer_host(voidptr(host), voidptr(host)) }
		arena.release()
		final_owners := timer_host_bindings_.len
		final_scopes := timer_scope_bindings_.len
		assert final_owners == 0 && final_scopes == 0
		assert registration_bytes == 0, 'process-wide timer registries allocated in a registration arena'
	}
}
