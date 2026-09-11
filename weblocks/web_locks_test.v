module weblocks

import dom

fn hold_lock(_ ?&Lock) LockCallbackResult {
	return pending_callback_result()
}

fn finish_lock(granted_lock ?&Lock) LockCallbackResult {
	assert granted_lock != none
	return fulfilled_callback_result('done')
}

fn finish_without_lock(granted_lock ?&Lock) LockCallbackResult {
	assert granted_lock == none
	return fulfilled_callback_result('unavailable')
}

fn reject_lock(_ ?&Lock) LockCallbackResult {
	return rejected_callback_result('callback failed')
}

fn web_locks_test_manager() &LockManager {
	environment := &LockEnvironment{
		client_id: 'client-1'
	}
	return obtain_lock_manager(environment)
}

fn test_request_validates_names_and_incompatible_options() {
	mut manager := web_locks_test_manager()
	reserved := manager.request_with_defaults('-reserved', finish_lock)
	assert reserved.state() == .rejected
	assert reserved.reason().starts_with('NotSupportedError:')
	conflicting := manager.request('resource', LockOptions{
		if_available: true
		steal: true
	}, finish_lock)
	assert conflicting.state() == .rejected
	shared_steal := manager.request('resource', LockOptions{
		mode: .shared
		steal: true
	}, finish_lock)
	assert shared_steal.state() == .rejected
}

fn test_exclusive_requests_wait_until_the_held_lock_settles() {
	mut manager := web_locks_test_manager()
	first := manager.request_with_defaults('resource', hold_lock)
	second := manager.request_with_defaults('resource', finish_lock)
	manager.run_until_idle()
	assert first.callback_invocations() == 1
	assert first.state() == .pending
	assert second.callback_invocations() == 0
	assert manager.held_lock_set().len == 1
	assert manager.pending_lock_count('resource') == 1
	assert manager.settle_callback_result(first, fulfilled_callback_result('first'))
	manager.run_until_idle()
	assert first.state() == .fulfilled
	assert first.value() == 'first'
	assert second.state() == .fulfilled
	assert second.value() == 'done'
	assert manager.held_lock_set().len == 0
}

fn test_shared_requests_run_together_and_exclusive_waits() {
	mut manager := web_locks_test_manager()
	first := manager.request('resource', LockOptions{ mode: .shared }, hold_lock)
	second := manager.request('resource', LockOptions{ mode: .shared }, hold_lock)
	exclusive := manager.request_with_defaults('resource', finish_lock)
	manager.run_until_idle()
	assert first.callback_invocations() == 1
	assert second.callback_invocations() == 1
	assert exclusive.callback_invocations() == 0
	assert manager.held_lock_set().len == 2
	assert manager.settle_callback_result(first, fulfilled_callback_result('one'))
	manager.run_until_idle()
	assert exclusive.callback_invocations() == 0
	assert manager.settle_callback_result(second, fulfilled_callback_result('two'))
	manager.run_until_idle()
	assert exclusive.state() == .fulfilled
}

fn test_if_available_invokes_callback_with_null_without_enqueuing() {
	mut manager := web_locks_test_manager()
	held := manager.request_with_defaults('resource', hold_lock)
	manager.run_until_idle()
	probe := manager.request('resource', LockOptions{ if_available: true }, finish_without_lock)
	manager.run_until_idle()
	assert probe.state() == .fulfilled
	assert probe.value() == 'unavailable'
	assert probe.callback_invocations() == 1
	assert !probe.last_callback_had_lock()
	assert manager.pending_lock_count('resource') == 0
	assert manager.settle_callback_result(held, fulfilled_callback_result('released'))
	manager.run_until_idle()
}

fn test_steal_rejects_the_old_lock_and_grants_the_new_request() {
	mut manager := web_locks_test_manager()
	old := manager.request_with_defaults('resource', hold_lock)
	manager.run_until_idle()
	thief := manager.request('resource', LockOptions{ steal: true }, finish_lock)
	manager.run_until_idle()
	assert old.state() == .rejected
	assert old.reason() == 'AbortError: Lock was stolen'
	assert thief.state() == .fulfilled
	assert thief.callback_invocations() == 1
}

fn test_abort_signal_removes_a_pending_request() {
	mut manager := web_locks_test_manager()
	held := manager.request_with_defaults('resource', hold_lock)
	manager.run_until_idle()
	mut signal := dom.AbortSignal.new()
	pending := manager.request('resource', LockOptions{ signal: signal }, finish_lock)
	manager.run_until_idle()
	assert manager.pending_lock_count('resource') == 1
	signal.signal_abort(dom.js_string('cancelled'))
	manager.run_until_idle()
	assert pending.state() == .rejected
	assert pending.reason() == 'cancelled'
	assert manager.pending_lock_count('resource') == 0
	assert manager.settle_callback_result(held, fulfilled_callback_result('released'))
	manager.run_until_idle()
}

fn test_query_snapshots_held_and_pending_locks() {
	mut manager := web_locks_test_manager()
	held := manager.request('alpha', LockOptions{ mode: .shared }, hold_lock)
	queued := manager.request_with_defaults('alpha', reject_lock)
	manager.run_until_idle()
	query := manager.query()
	manager.run_until_idle()
	assert query.state() == .fulfilled
	snapshot := query.snapshot()
	assert snapshot.held.len == 1
	assert snapshot.held[0] == LockInfo{
		name: 'alpha'
		mode: .shared
		client_id: 'client-1'
	}
	assert snapshot.pending.len == 1
	assert snapshot.pending[0].mode == .exclusive
	assert queued.state() == .pending
	assert manager.settle_callback_result(held, fulfilled_callback_result('released'))
	manager.run_until_idle()
	assert queued.state() == .rejected
	assert queued.reason() == 'callback failed'
}

fn test_navigator_returns_the_environment_lock_manager() {
	environment := &LockEnvironment{ client_id: 'navigator-client' }
	navigator := NavigatorLocks.create(environment)
	assert navigator.locks() == navigator.locks()
}
