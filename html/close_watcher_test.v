module html

import dom

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

fn test_dom_window_activation_notifies_the_translated_close_watcher_manager() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	window := WindowModel.create_top_level(document, none, '')!
	manager := window.close_watcher_manager()
	first := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_allows_close)
	assert !manager.can_prevent_close()

	mut dom_window := document.get_window() or {
		assert false, 'translated WindowModel was not exposed through DOM'
		return
	}
	dom_window.close_watcher_manager().notify_about_user_activation()
	assert manager.can_prevent_close()

	second := make_close_watcher(manager, close_watcher_enabled, close_watcher_cancel_allows_close)
	assert manager.groups.len == 2
	assert first.is_active
	assert second.is_active
}

fn test_close_watcher_cancel_and_disabled_states() {
	manager := CloseWatcherManager.create()
	prevented := make_close_watcher(manager, close_watcher_enabled,
		close_watcher_cancel_prevents_close)
	mut mutable_prevented := unsafe { &CloseWatcher(prevented) }
	assert !mutable_prevented.request_close(false)
	assert prevented.is_active

	disabled := make_close_watcher(manager, close_watcher_disabled,
		close_watcher_cancel_allows_close)
	mut mutable_disabled := unsafe { &CloseWatcher(disabled) }
	assert mutable_disabled.request_close(false)
	assert disabled.is_active
}

struct CloseWatcherEventCounts {
mut:
	cancel int
	close  int
}

fn close_watcher_event_callback(mut counts CloseWatcherEventCounts) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [mut counts] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			if event.type_name() == 'cancel' {
				counts.cancel++
			} else if event.type_name() == 'close' {
				counts.close++
			}
			return dom.js_undefined()
		}
	}
}

fn test_close_watcher_construct_impl_handlers_request_close_and_abort() {
	document := dom.Document.create(dom.url_about_blank())
	mut navigable := &dom.Navigable{
		active_document_:          document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_cached_navigable(navigable)
	mut window := WindowModel.create_top_level(document, none, 'close-watcher') or { panic(err) }
	mut watcher := CloseWatcher.construct_impl(window, CloseWatcherOptions{}) or { panic(err) }
	mut counts := CloseWatcherEventCounts{}
	callback := close_watcher_event_callback(mut counts)
	watcher.set_oncancel(callback)
	watcher.set_onclose(callback)
	assert watcher.oncancel()? == callback
	assert watcher.onclose()? == callback
	watcher.request_close_for_bindings()
	assert counts.cancel == 1
	assert counts.close == 1
	assert !watcher.is_active

	signal := dom.AbortSignal.new()
	mut aborted_watcher := CloseWatcher.construct_impl(window, CloseWatcherOptions{
		signal: signal
	}) or { panic(err) }
	assert aborted_watcher.is_active
	mut mutable_signal := unsafe { &dom.AbortSignal(signal) }
	mutable_signal.signal_abort(dom.js_undefined())
	assert !aborted_watcher.is_active

	window.set_last_activation_timestamp(42)
	assert window.has_history_action_activation()
	window.consume_history_action_user_activation()
	assert !window.has_history_action_activation()
}

fn test_close_watcher_construct_impl_rejects_detached_context() {
	document := dom.Document.create(dom.url_about_blank())
	window := WindowModel.create_top_level(document, none, 'detached') or { panic(err) }
	mut context := unsafe { &BrowsingContextModel(window.browsing_context()) }
	context.remove()
	CloseWatcher.construct_impl(window, CloseWatcherOptions{}) or {
		assert err.msg().starts_with('InvalidStateError:')
		return
	}
	assert false
}
