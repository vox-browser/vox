module page

fn test_page_client_retains_editing_and_background_state() {
	mut client := PageClient.create()
	client.page_did_update_editing_history_state(true, false)
	can_undo, can_redo := client.editing_history_state()
	assert can_undo
	assert !can_redo
	client.page_did_change_background_color('#112233')
	client.page_did_change_background_color('#112233')
	assert client.background_color() == '#112233'
	assert client.events.filter(it.name == 'change-background-color').len == 1
}

fn test_page_client_coordinates_clipboard_items_and_primary_paste() {
	mut client := PageClient.create()
	client.page_did_insert_clipboard_item('plain text', 'unspecified')
	client.page_did_insert_clipboard_item('<b>rich</b>', 'inline')
	assert client.clipboard_items() == [
		ClipboardItem{ value: 'plain text', presentation_style: 'unspecified' },
		ClipboardItem{ value: '<b>rich</b>', presentation_style: 'inline' },
	]
	client.page_did_request_primary_paste()
	client.page_did_complete_paste_action()
	assert client.primary_paste_request_count() == 1
	assert client.paste_action_completion_count() == 1
	client.page_did_update_primary_selection('selected text')
	assert client.primary_selection() == 'selected text'
}
