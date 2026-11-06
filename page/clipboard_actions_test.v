module page

import dom

@[heap]
struct ClipboardInsertObservation {
mut:
	plain_text string
	html       ?string
}

fn observe_clipboard_insert(target voidptr, plain_text string, html ?string) EventResult {
	mut observation := unsafe { &ClipboardInsertObservation(target) }
	observation.plain_text = plain_text
	observation.html = html
	return .handled
}

fn clipboard_action_handler(client &PageClient) &EventHandler {
	mut handler := &EventHandler{}
	handler.set_page_client(client)
	handler.focused_target_ = 'editor'
	handler.focused_target_state = InputTarget{ id: 'editor', is_editable: true }
	return handler
}

fn test_delete_input_type_and_collapsed_grapheme_target_range() {
	assert input_type_for_delete_key(8)? == 'deleteContentBackward'
	assert input_type_for_delete_key(46)? == 'deleteContentForward'
	assert input_type_for_delete_key(13) == none
	assert collapsed_delete_target_range_for_input_event('A👩‍🚀B', 6,
		'deleteContentBackward')? == SelectionRange{ start: 1, end: 6 }
	assert collapsed_delete_target_range_for_input_event('A👩‍🚀B', 1,
		'deleteContentForward')? == SelectionRange{ start: 1, end: 6 }
}

fn test_clipboard_event_target_prefers_focus_then_document_element() {
	mut document := dom.Document.create_for_fragment_parsing()
	mut root := document.create_element_ns('http://www.w3.org/1999/xhtml', 'html')!
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(root.as_node())!
	assert voidptr(clipboard_event_target(document)?) == voidptr(root.as_node())
	input := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
	document.set_focused_area(input.as_node())
	assert voidptr(clipboard_event_target(document)?) == voidptr(input.as_node())
}

fn test_copy_and_cut_write_supported_representations_and_cut_editable_selection() {
	mut client := PageClient.create()
	mut handler := clipboard_action_handler(client)
	handler.set_selected_clipboard_content('plain', '<b>plain</b>')
	assert handler.perform_copy_action() == .handled
	assert client.clipboard_items().len == 1
	assert client.clipboard_items()[0].representations.map(it.mime_type) == ['text/html', 'text/plain']

	assert handler.perform_cut_action() == .handled
	text, html := handler.pasted_content()
	assert text == ''
	assert html == none
	assert handler.selected_text_ == ''
	assert handler.event_log.map(it.name).contains('beforeinput:deleteByCut')
}

fn test_cancelled_copy_uses_script_populated_data_store() {
	mut client := PageClient.create()
	mut handler := clipboard_action_handler(client)
	handler.set_selected_clipboard_content('selection', '')
	handler.set_clipboard_event_items('copy', [
		ClipboardDataItem{ kind: .text, mime_type: 'text/plain;charset=utf-8', data: 'script'.bytes() },
		ClipboardDataItem{ kind: .file, mime_type: 'image/png', data: [u8(1)] },
	])
	handler.set_clipboard_event_cancelled('copy', true)
	assert handler.perform_copy_action() == .handled
	assert client.clipboard_items()[0].representations.len == 1
	assert client.clipboard_items()[0].representations[0].data.bytestr() == 'script'
}

fn test_paste_normalizes_newlines_prefers_html_and_always_completes() {
	mut client := PageClient.create()
	mut handler := clipboard_action_handler(client)
	mut observation := &ClipboardInsertObservation{}
	handler.set_clipboard_insert_callback(voidptr(observation), observe_clipboard_insert)
	handler.set_system_clipboard_items([
		ClipboardDataItem{ kind: .text, mime_type: 'text/plain', data: 'a\r\nb\rc'.bytes() },
		ClipboardDataItem{ kind: .text, mime_type: 'text/html', data: '<b>a</b>'.bytes() },
	])
	assert handler.perform_paste_action() == .handled
	plain_text, html := handler.pasted_content()
	assert plain_text == 'a\nb\nc'
	assert html? == '<b>a</b>'
	assert observation.plain_text == 'a\nb\nc'
	assert observation.html? == '<b>a</b>'
	assert client.paste_action_completion_count() == 1

	handler.set_clipboard_event_cancelled('paste', true)
	assert handler.perform_paste_action() == .handled
	assert client.paste_action_completion_count() == 2
}

fn test_platform_clipboard_shortcuts_run_copy_cut_and_paste_actions() {
	mut client := PageClient.create()
	mut handler := clipboard_action_handler(client)
	handler.set_selected_clipboard_content('copy me', '<b>copy me</b>')
	assert handler.handle_keydown(int(`C`), 0, platform_control_modifier(), false, false) == .handled
	assert client.clipboard_items().len == 1
	assert client.clipboard_items()[0].representations.map(it.mime_type) == ['text/html', 'text/plain']

	handler.set_selected_clipboard_content('cut me', '')
	assert handler.handle_keydown(int(`X`), 0, platform_control_modifier(), false, false) == .handled
	assert handler.selected_text_ == ''
	assert client.clipboard_items().len == 2

	mut observation := &ClipboardInsertObservation{}
	handler.set_clipboard_insert_callback(voidptr(observation), observe_clipboard_insert)
	handler.set_system_clipboard_items([
		ClipboardDataItem{ kind: .text, mime_type: 'text/plain', data: 'paste\rtext'.bytes() },
	])
	assert handler.handle_keydown(int(`V`), 0, platform_control_modifier(), false, false) == .handled
	assert observation.plain_text == 'paste\ntext'
	assert client.paste_action_completion_count() == 1
}

fn test_image_paste_creates_data_url_and_text_input_is_cancelable() {
	mut client := PageClient.create()
	mut handler := clipboard_action_handler(client)
	mut store := ClipboardDataStore{
		items: [ClipboardDataItem{ kind: .file, mime_type: 'image/png', data: [u8(1), 2, 3] }]
	}
	assert handler.perform_paste_action_with_data_store(mut store) == .handled
	_, html := handler.pasted_content()
	assert html? == '<img src="data:image/png;base64,AQID" />'
	assert handler.fire_text_input_event('x') == .accepted
	handler.focused_target_state = InputTarget{ id: 'editor', is_editable: true, cancel_keyboard: true }
	assert handler.fire_text_input_event('x') == .cancelled
}

fn test_system_clipboard_converts_raw_png_and_user_files_to_file_items() {
	store := system_clipboard_data_store([
		ClipboardDataItem{
			kind: .text
			mime_type: 'image/png'
			data: [u8(1), 2, 3]
		},
		ClipboardDataItem{
			kind: .file
			mime_type: 'image/jpeg'
			data: [u8(4), 5, 6]
			file_name: 'photo.jpg'
		},
		ClipboardDataItem{
			kind: .text
			mime_type: 'application/octet-stream'
			data: [u8(7)]
		},
	])
	assert store.items.len == 2
	assert store.items[0].kind == .file
	assert store.items[0].mime_type == 'image/png'
	assert store.items[0].file_name == 'image.png'
	assert store.items[1].kind == .file
	assert store.items[1].mime_type == 'image/jpeg'
	assert store.items[1].file_name == 'photo.jpg'
}
