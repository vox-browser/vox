// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// PageClient synchronization of session-history entry state with the browser
// process, including the testing snapshot/session-store surface.
module page

pub struct SessionHistoryEntryState {
pub mut:
	navigation_api_state   string
	scroll_restoration_mode string = 'auto'
	navigable_target_name  string
	reload_pending         bool
}

pub struct HistoryOperationRequest {
pub:
	operation_id u64
	parameters   string
}

fn session_history_entry_key(navigable_id u64, entry_identity string) string {
	return '${navigable_id}:${entry_identity}'
}

pub fn (mut client PageClient) page_did_update_session_history_entry_navigation_api_state(navigable_id u64, entry_identity string, navigation_api_state string) {
	key := session_history_entry_key(navigable_id, entry_identity)
	mut state := client.session_history_entries_[key]
	state.navigation_api_state = navigation_api_state
	client.session_history_entries_[key] = state
	client.record('update-session-history-navigation-api-state', '${key}:${navigation_api_state}')
}

pub fn (mut client PageClient) page_did_update_session_history_entry_scroll_restoration_mode(navigable_id u64, entry_identity string, scroll_restoration_mode string) {
	key := session_history_entry_key(navigable_id, entry_identity)
	mut state := client.session_history_entries_[key]
	state.scroll_restoration_mode = scroll_restoration_mode
	client.session_history_entries_[key] = state
	client.record('update-session-history-scroll-restoration', '${key}:${scroll_restoration_mode}')
}

pub fn (mut client PageClient) page_did_update_session_history_entry_document_state_navigable_target_name(navigable_id u64, entry_identity string, target_name string) {
	key := session_history_entry_key(navigable_id, entry_identity)
	mut state := client.session_history_entries_[key]
	state.navigable_target_name = target_name
	client.session_history_entries_[key] = state
	client.record('update-session-history-target-name', '${key}:${target_name}')
}

pub fn (mut client PageClient) page_did_set_session_history_entry_document_state_reload_pending(navigable_id u64, navigation_api_key string, reload_pending bool) {
	key := session_history_entry_key(navigable_id, navigation_api_key)
	mut state := client.session_history_entries_[key]
	state.reload_pending = reload_pending
	client.session_history_entries_[key] = state
	client.record('set-session-history-reload-pending', '${key}:${reload_pending}')
}

pub fn (client &PageClient) session_history_entry_state(navigable_id u64, entry_identity string) ?SessionHistoryEntryState {
	state := client.session_history_entries_[session_history_entry_key(navigable_id,
		entry_identity)] or { return none }
	return state
}

pub fn (mut client PageClient) page_did_request_set_system_visibility_state(visibility_state string) {
	client.system_visibility_state_ = visibility_state
	client.record('set-system-visibility-state', visibility_state)
}

pub fn (client &PageClient) system_visibility_state() string {
	return client.system_visibility_state_
}

pub fn (mut client PageClient) set_ui_process_session_history_for_testing(value string) {
	client.ui_process_session_history_ = value
}

pub fn (client &PageClient) page_did_request_ui_process_session_history_for_testing() string {
	return client.ui_process_session_history_
}

pub fn (mut client PageClient) page_did_request_capture_session_history_snapshot_for_testing() bool {
	client.captured_session_history_snapshot_ = client.ui_process_session_history_
	client.record('capture-session-history-snapshot', '')
	return true
}

pub fn (mut client PageClient) page_did_request_restore_session_history_snapshot_for_testing() bool {
	snapshot := client.captured_session_history_snapshot_ or { return false }
	client.ui_process_session_history_ = snapshot
	client.record('restore-session-history-snapshot', '')
	return true
}

pub fn (mut client PageClient) page_did_request_register_session_store_tab_for_testing() bool {
	if client.session_store_tab_registered_ {
		return false
	}
	client.session_store_tab_registered_ = true
	client.record('register-session-store-tab', '')
	return true
}

pub fn (mut client PageClient) set_session_store_tab_state_for_testing(value string) {
	client.session_store_tab_state_ = value
}

pub fn (client &PageClient) page_did_request_session_store_tab_state_for_testing() string {
	return client.session_store_tab_state_
}

pub fn (mut client PageClient) page_did_request_history_operation(operation_id u64, parameters string) {
	client.history_operation_requests_ << HistoryOperationRequest{
		operation_id: operation_id
		parameters: parameters
	}
	client.record('request-history-operation', '${operation_id}:${parameters}')
}

pub fn (client &PageClient) history_operation_requests() []HistoryOperationRequest {
	return client.history_operation_requests_.clone()
}

pub fn (mut client PageClient) page_did_request_child_navigable_unload(navigable_id u64) {
	client.child_navigable_unload_requests_ << navigable_id
	client.record('request-child-navigable-unload', navigable_id.str())
}

pub fn (client &PageClient) child_navigable_unload_requests() []u64 {
	return client.child_navigable_unload_requests_.clone()
}
