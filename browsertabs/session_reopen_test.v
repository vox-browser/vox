module browsertabs

fn test_reopening_hidden_original_process_preserves_selected_document_and_frame() {
	mut original := create(Frame{ x: 12, y: 34, width: 900, height: 700 })!
	defer { original.leave() or {} }
	// Separate Session instances model the independent metadata readers in each
	// process. The OS process itself is deliberately shared by this unit fixture.
	mut state := original.load()!
	state.tabs << Tab{ id: 'selected', pid: state.tabs[0].pid, ready: true }
	state.selected = 'selected'
	original.save(state)!
	mut selected := join(original.folder, 'selected')!
	defer { selected.leave() or {} }
	original.request_reopen()!
	assert !original.take_reopen_request()
	selected.poll('Selected page', 'https://example.test/', '', true)!
	assert selected.take_reopen_request()
	assert !selected.take_reopen_request()
	assert selected.state.selected == 'selected'
	assert selected.state.tabs.len == 2
	assert selected.state.tabs[1].title == 'Selected page'
	assert selected.state.frame == Frame{ x: 12, y: 34, width: 900, height: 700 }
	// Every request works, including another request from the selected process.
	selected.request_reopen()!
	assert selected.take_reopen_request()
	original.poll('Original page', '', '', true)!
	assert !original.take_reopen_request()
	original.select(0, original.state.frame)!
	assert !original.take_reopen_request()
}

fn test_single_tab_reopen_and_older_session_records() {
	mut session := create(Frame{})!
	defer { session.leave() or {} }
	assert !session.take_reopen_request()
	session.request_reopen()!
	assert session.take_reopen_request()
	assert !session.take_reopen_request()
	old := decode_session_state('{"version":1,"tabs":[],"selected":"","frame":{}}')!
	assert old.reopen == 0
}
