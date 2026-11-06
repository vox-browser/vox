module main

import dom
import html
import page

fn data_url_test_encode_png(_ &dom.Bitmap_) ![]u8 {
	return [u8(0), 255, 1, 0]
}

fn data_url_test_encode_jpeg(_ &dom.Bitmap_, _ ?int) ![]u8 {
	return [u8(0), 255, 1, 0]
}

fn test_canvas_binary_data_url_in_the_browser_module() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'canvas')!
	canvas := unsafe { &dom.HTMLCanvasElement(element) }
	_ = html.html_canvas_element_get_context(canvas, '2d', none)!
	data_url := html.html_canvas_element_to_data_url(canvas, 'image/png', none,
		data_url_test_encode_png, data_url_test_encode_jpeg)!
	assert data_url == 'data:image/png;base64,AP8BAA=='
}

fn test_image_clipboard_binary_data_url_in_the_browser_module() {
	mut handler := &page.EventHandler{}
	assert handler.focus_next_element([page.InputTarget{
		id: 'editor'
		is_editable: true
		is_focusable: true
	}])
	mut store := page.ClipboardDataStore{
		items: [page.ClipboardDataItem{kind: .file, mime_type: 'image/png', data: [u8(1), 2, 3]}]
	}
	assert handler.perform_paste_action_with_data_store(mut store) == .handled
	_, markup := handler.pasted_content()
	assert markup? == '<img src="data:image/png;base64,AQID" />'
}

fn test_process_tab_icon_bytes_round_trip_without_refetching() {
	assert process_tab_icon_data_url([u8(0), 255, 1, 0]) == 'data:image/png;base64,AP8BAA=='
	mut all_bytes := []u8{}
	for value in 0 .. 256 { all_bytes << u8(value) }
	for bytes in [all_bytes, []u8{}, [u8(1)], [u8(1), 2]] {
		address := process_tab_icon_data_url(bytes)
		assert browser_image_resource_bytes_for_document(dom.URL{value: address}, 'about:blank')! == bytes
	}
}
