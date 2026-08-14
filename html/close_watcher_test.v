module html

fn close_watcher_enabled() bool {
	return true
}

fn close_watcher_disabled() bool {
	return false
}

fn close_watcher_cancel_allows_close(_ bool) bool {
	return true
}

fn close_watcher_cancel_prevents_close(_ bool) bool {
	return false
}

fn close_watcher_noop() {}

fn close_watcher_fully_active() bool {
	return true
}

fn close_watcher_has_activation() bool {
	return true
}

fn make_close_watcher(manager &CloseWatcherManager, enabled CloseWatcherEnabledState, cancel CloseWatcherCancelAction) &CloseWatcher {
	return CloseWatcher.establish(manager, enabled, cancel, close_watcher_noop,
		close_watcher_fully_active, close_watcher_has_activation, close_watcher_noop)
}

fn test_close_watcher_manager_groups_and_processing() {
	manager := CloseWatcherManager.create()
	first := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_allows_close)
	second := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_allows_close)
	assert manager.groups.len == 1
	assert manager.groups[0].len == 2

	mut mutable_manager := unsafe { &CloseWatcherManager(manager) }
	assert mutable_manager.process_close_watchers()
	assert !first.is_active
	assert !second.is_active
	assert manager.groups.len == 0
}

fn test_close_watcher_user_activation_opens_a_new_group() {
	manager := CloseWatcherManager.create()
	first := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_allows_close)
	mut mutable_manager := unsafe { &CloseWatcherManager(manager) }
	mutable_manager.notify_about_user_activation()
	second := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_allows_close)
	assert manager.groups.len == 2

	assert mutable_manager.process_close_watchers()
	assert first.is_active
	assert !second.is_active
	assert manager.groups.len == 1
}

fn test_close_watcher_cancel_and_disabled_states() {
	manager := CloseWatcherManager.create()
	prevented := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_prevents_close)
	mut mutable_prevented := unsafe { &CloseWatcher(prevented) }
	assert !mutable_prevented.request_close(false)
	assert prevented.is_active

	disabled := make_close_watcher(manager, close_watcher_disabled, close_watcher_cancel_allows_close)
	mut mutable_disabled := unsafe { &CloseWatcher(disabled) }
	assert mutable_disabled.request_close(false)
	assert disabled.is_active
}
