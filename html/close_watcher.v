// Copyright (c) 2024, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Libraries/LibWeb/HTML/CloseWatcher.cpp and CloseWatcherManager.cpp.
module html

import dom

pub type CloseWatcherEnabledState = fn () bool

pub type CloseWatcherCancelAction = fn (bool) bool

pub type CloseWatcherCloseAction = fn ()

pub type CloseWatcherDocumentIsFullyActive = fn () bool

pub type CloseWatcherHasHistoryActionActivation = fn () bool

pub type CloseWatcherConsumeHistoryActionActivation = fn ()

pub struct CloseWatcherOptions {
pub:
	signal ?&dom.AbortSignal
}

@[heap]
pub struct CloseWatcher {
	dom.EventTarget
mut:
	manager                           &CloseWatcherManager @[required]
	is_running_cancel_action          bool
	is_active                         bool = true
	get_enabled_state_callback        CloseWatcherEnabledState                   @[required]
	cancel_action                     CloseWatcherCancelAction                   @[required]
	close_action                      CloseWatcherCloseAction                    @[required]
	document_is_fully_active          CloseWatcherDocumentIsFullyActive          @[required]
	has_history_action_activation     CloseWatcherHasHistoryActionActivation     @[required]
	consume_history_action_activation CloseWatcherConsumeHistoryActionActivation @[required]
	dispatches_dom_events             bool
}

fn close_watcher_always_enabled() bool {
	return true
}

fn close_watcher_continue_cancel_action(_ bool) bool {
	return true
}

fn close_watcher_empty_action() {}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-closewatcher
pub fn CloseWatcher.construct_impl(window &WindowModel, options CloseWatcherOptions) !&CloseWatcher {
	// NOTE: This check also covers a detached iframe.
	if window.browsing_context().has_navigable_been_destroyed() {
		return error('InvalidStateError: The iframe has been detached')
	}

	// 1. If the relevant global object's associated Document is not fully active,
	// then throw an InvalidStateError DOMException.
	if !window.associated_document().is_fully_active() {
		return error('InvalidStateError: The document is not fully active.')
	}

	// 2. Establish a close watcher whose cancel and close actions dispatch events
	// at the newly-created CloseWatcher.
	close_watcher := &CloseWatcher{
		manager:                           window.close_watcher_manager()
		get_enabled_state_callback:        close_watcher_always_enabled
		cancel_action:                     close_watcher_continue_cancel_action
		close_action:                      close_watcher_empty_action
		document_is_fully_active:          fn [window] () bool {
			return window.associated_document().is_fully_active()
		}
		has_history_action_activation:     fn [window] () bool {
			return window.has_history_action_activation()
		}
		consume_history_action_activation: fn [window] () {
			mut mutable_window := unsafe { &WindowModel(window) }
			mutable_window.consume_history_action_user_activation()
		}
		dispatches_dom_events:             true
	}
	mut manager := unsafe { &CloseWatcherManager(close_watcher.manager) }
	manager.add(close_watcher)

	// 3. Destroy the watcher immediately for an already-aborted signal, and add
	// the destruction algorithm to a live signal.
	if signal := options.signal {
		if signal.aborted() {
			mut mutable_close_watcher := unsafe { &CloseWatcher(close_watcher) }
			mutable_close_watcher.destroy()
		}
		mut mutable_signal := unsafe { &dom.AbortSignal(signal) }
		_ = mutable_signal.add_abort_algorithm(fn [close_watcher] () {
			mut mutable_close_watcher := unsafe { &CloseWatcher(close_watcher) }
			mutable_close_watcher.destroy()
		})
	}

	return close_watcher
}

// https://html.spec.whatwg.org/multipage/interaction.html#establish-a-close-watcher
pub fn CloseWatcher.establish(manager &CloseWatcherManager, get_enabled_state CloseWatcherEnabledState, cancel_action CloseWatcherCancelAction, close_action CloseWatcherCloseAction, document_is_fully_active CloseWatcherDocumentIsFullyActive, has_history_action_activation CloseWatcherHasHistoryActionActivation, consume_history_action_activation CloseWatcherConsumeHistoryActionActivation) &CloseWatcher {
	watcher := &CloseWatcher{
		manager:                           manager
		get_enabled_state_callback:        get_enabled_state
		cancel_action:                     cancel_action
		close_action:                      close_action
		document_is_fully_active:          document_is_fully_active
		has_history_action_activation:     has_history_action_activation
		consume_history_action_activation: consume_history_action_activation
	}
	mut mutable_manager := unsafe { &CloseWatcherManager(manager) }
	mutable_manager.add(watcher)
	return watcher
}

pub fn (watcher &CloseWatcher) get_enabled_state() bool {
	return watcher.get_enabled_state_callback()
}

// https://html.spec.whatwg.org/multipage/interaction.html#close-watcher-request-close
pub fn (mut watcher CloseWatcher) request_close(require_history_action_activation bool) bool {
	if !watcher.is_active {
		return true
	}
	if !watcher.get_enabled_state() {
		return true
	}
	if watcher.is_running_cancel_action {
		return true
	}
	if !watcher.document_is_fully_active() {
		return true
	}

	can_prevent_close := !require_history_action_activation
		|| (watcher.manager.can_prevent_close() && watcher.has_history_action_activation())
	watcher.is_running_cancel_action = true
	should_continue := if watcher.dispatches_dom_events {
		event := dom.Event.create('cancel', dom.EventInit{
			cancelable: can_prevent_close
		})
		unsafe { &dom.EventTarget(&watcher) }.dispatch_event(event)
	} else {
		watcher.cancel_action(can_prevent_close)
	}
	watcher.is_running_cancel_action = false
	if !should_continue {
		assert can_prevent_close
		watcher.consume_history_action_activation()
		return false
	}

	watcher.close()
	return true
}

// https://html.spec.whatwg.org/multipage/interaction.html#dom-closewatcher-requestclose
pub fn (mut watcher CloseWatcher) request_close_for_bindings() {
	watcher.request_close(false)
}

// https://html.spec.whatwg.org/multipage/interaction.html#close-watcher-close
pub fn (mut watcher CloseWatcher) close() {
	if !watcher.is_active || !watcher.get_enabled_state() || !watcher.document_is_fully_active() {
		return
	}
	watcher.destroy()
	if watcher.dispatches_dom_events {
		unsafe { &dom.EventTarget(&watcher) }.dispatch_event(dom.Event.create('close', dom.EventInit{}))
	} else {
		watcher.close_action()
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#close-watcher-destroy
pub fn (mut watcher CloseWatcher) destroy() {
	mut mutable_manager := unsafe { &CloseWatcherManager(watcher.manager) }
	mutable_manager.remove(&watcher)
	watcher.is_active = false
}

pub fn (watcher &CloseWatcher) set_oncancel(event_handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(watcher) }.set_event_handler_attribute('cancel', event_handler)
}

pub fn (watcher &CloseWatcher) oncancel() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(watcher) }.event_handler_attribute('cancel')
}

pub fn (watcher &CloseWatcher) set_onclose(event_handler ?&dom.CallbackType) {
	unsafe { &dom.EventTarget(watcher) }.set_event_handler_attribute('close', event_handler)
}

pub fn (watcher &CloseWatcher) onclose() ?&dom.CallbackType {
	return unsafe { &dom.EventTarget(watcher) }.event_handler_attribute('close')
}

@[heap]
pub struct CloseWatcherManager {
	dom.CloseWatcherManager
mut:
	groups                             [][]&CloseWatcher
	allowed_number_of_groups           u32  = 1
	next_user_interaction_allows_group bool = true
}

fn close_watcher_manager_notify_user_activation(target voidptr) {
	mut manager := unsafe { &CloseWatcherManager(target) }
	manager.notify_about_user_activation()
}

pub fn CloseWatcherManager.create() &CloseWatcherManager {
	mut manager := &CloseWatcherManager{}
	manager.CloseWatcherManager = dom.CloseWatcherManager{
		target: voidptr(manager)
		notify_user_activation_callback: close_watcher_manager_notify_user_activation
	}
	return manager
}

pub fn (mut manager CloseWatcherManager) add(close_watcher &CloseWatcher) {
	if manager.groups.len < int(manager.allowed_number_of_groups) {
		manager.groups << [&CloseWatcher(close_watcher)]
	} else {
		assert manager.groups.len > 0
		manager.groups[manager.groups.len - 1] << close_watcher
	}
	manager.next_user_interaction_allows_group = true
}

pub fn (mut manager CloseWatcherManager) remove(close_watcher &CloseWatcher) {
	mut group_index := 0
	for group_index < manager.groups.len {
		mut watcher_index := 0
		for watcher_index < manager.groups[group_index].len {
			if voidptr(manager.groups[group_index][watcher_index]) == voidptr(close_watcher) {
				manager.groups[group_index].delete(watcher_index)
				break
			}
			watcher_index++
		}
		if manager.groups[group_index].len == 0 {
			manager.groups.delete(group_index)
		} else {
			group_index++
		}
	}
}

// https://html.spec.whatwg.org/multipage/interaction.html#process-close-watchers
pub fn (mut manager CloseWatcherManager) process_close_watchers() bool {
	mut processed_a_close_watcher := false
	if manager.groups.len > 0 {
		group_copy := manager.groups[manager.groups.len - 1].clone()
		for index := group_copy.len - 1; index >= 0; index-- {
			watcher := group_copy[index]
			if watcher.get_enabled_state() {
				processed_a_close_watcher = true
			}
			mut mutable_watcher := unsafe { &CloseWatcher(watcher) }
			if !mutable_watcher.request_close(true) {
				break
			}
		}
	}
	if manager.allowed_number_of_groups > 1 {
		manager.allowed_number_of_groups--
	}
	return processed_a_close_watcher
}

// https://html.spec.whatwg.org/multipage/interaction.html#notify-the-close-watcher-manager-about-user-activation
pub fn (mut manager CloseWatcherManager) notify_about_user_activation() {
	if manager.next_user_interaction_allows_group {
		manager.allowed_number_of_groups++
	}
	manager.next_user_interaction_allows_group = false
}

pub fn (manager &CloseWatcherManager) can_prevent_close() bool {
	return manager.groups.len < int(manager.allowed_number_of_groups)
}
