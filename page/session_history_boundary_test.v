module page

fn test_page_client_synchronizes_session_history_entry_fields() {
	mut client := PageClient.create()
	client.page_did_update_session_history_entry_navigation_api_state(7, 'entry-a', '{"page":2}')
	client.page_did_update_session_history_entry_scroll_restoration_mode(7, 'entry-a', 'manual')
	client.page_did_update_session_history_entry_document_state_navigable_target_name(7,
		'entry-a', 'results')
	client.page_did_set_session_history_entry_document_state_reload_pending(7, 'entry-a', true)
	state := client.session_history_entry_state(7, 'entry-a') or { panic('missing entry state') }
	assert state.navigation_api_state == '{"page":2}'
	assert state.scroll_restoration_mode == 'manual'
	assert state.navigable_target_name == 'results'
	assert state.reload_pending
	assert client.session_history_entry_state(8, 'entry-a') == none
}

fn test_page_client_session_history_snapshot_and_operation_requests() {
	mut client := PageClient.create()
	assert client.system_visibility_state() == 'hidden'
	client.page_did_request_set_system_visibility_state('visible')
	assert client.system_visibility_state() == 'visible'
	client.set_ui_process_session_history_for_testing('{"entries":[1]}')
	assert client.page_did_request_capture_session_history_snapshot_for_testing()
	client.set_ui_process_session_history_for_testing('{"entries":[2]}')
	assert client.page_did_request_restore_session_history_snapshot_for_testing()
	assert client.page_did_request_ui_process_session_history_for_testing() == '{"entries":[1]}'
	assert client.page_did_request_register_session_store_tab_for_testing()
	assert !client.page_did_request_register_session_store_tab_for_testing()
	client.set_session_store_tab_state_for_testing('{"selected":true}')
	assert client.page_did_request_session_store_tab_state_for_testing() == '{"selected":true}'

	client.page_did_request_history_operation(91, 'traverse:-1')
	client.page_did_request_child_navigable_unload(44)
	assert client.history_operation_requests() == [HistoryOperationRequest{
		operation_id: 91
		parameters: 'traverse:-1'
	}]
	assert client.child_navigable_unload_requests() == [u64(44)]
}
