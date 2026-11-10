module clipboard

import dom
import fileapi
import html

fn clipboard_test_focused_document() &dom.Document {
	mut document := dom.Document.create(dom.URL{value: 'https://clipboard.test/'})
	navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
		html_model_handle_: voidptr(document)
		is_focused_callback_: fn (_ voidptr) bool { return true }
	}
	document.set_cached_navigable(navigable)
	return document
}

struct ClipboardPasteReadResult {
mut:
	text &ClipboardTextPromise = unsafe { nil }
	items &ClipboardReadPromise = unsafe { nil }
}

fn clipboard_test_read_text_from_paste(mut board Clipboard) &ClipboardTextPromise {
	mut result := &ClipboardPasteReadResult{}
	board.during_system_clipboard_paste(board.backend().items(), fn [board, mut result] () {
		result.text = board.read_text()
	})
	return result.text
}

fn clipboard_test_read_from_paste(mut board Clipboard, formats ClipboardUnsanitizedFormats) &ClipboardReadPromise {
	mut result := &ClipboardPasteReadResult{}
	board.during_system_clipboard_paste(board.backend().items(), fn [board, mut result, formats] () {
		result.items = board.read(formats)
	})
	return result.items
}

fn drain_clipboard_test_event_loop(mut event_loop html.EventLoop) {
	mut iterations := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		iterations++
		assert iterations < 100
	}
}

fn test_well_known_clipboard_formats_use_mime_essence() {
	assert os_specific_well_known_format('TEXT/PLAIN; charset=utf-8') == 'text/plain'
	assert os_specific_well_known_format('text/html') == 'text/html'
	assert os_specific_well_known_format('image/png') == 'image/png'
	assert os_specific_well_known_format('application/json') == ''
	assert os_specific_well_known_format('invalid') == ''
}

fn test_write_blobs_and_option_to_clipboard_preserves_raw_bytes_and_native_formats() {
	text := fileapi.Blob.create([u8(0x66), 0x6f, 0x80], 'text/plain;charset=utf-8')
	image := fileapi.Blob.create([u8(0xc2), 0xa9], 'image/png')
	native_write := write_blobs_and_option_to_clipboard([text, image], 'attachment')
	assert native_write.presentation_style == 'attachment'
	assert native_write.item.system_clipboard_representations.len == 2
	assert native_write.item.system_clipboard_representations[0].mime_type == 'text/plain'
	assert native_write.item.system_clipboard_representations[0].byte_data()? == [u8(0x66), 0x6f, 0x80]
	assert native_write.item.system_clipboard_representations[1].mime_type == 'image/png'
	assert native_write.item.system_clipboard_representations[1].byte_data()? == [u8(0xc2), 0xa9]
}

fn test_clipboard_operations_require_transient_activation() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	board := Clipboard.create(backend, event_loop, none)
	read := board.read(ClipboardUnsanitizedFormats{})
	read_text := board.read_text()
	write := board.write([])
	write_text := board.write_text('blocked')
	drain_clipboard_test_event_loop(mut event_loop)
	assert read.state() == .rejected
	assert read.reason().starts_with('NotAllowedError:')
	assert read_text.state() == .rejected
	assert write.state() == .rejected
	assert write_text.state() == .rejected
	assert backend.items().len == 0
}

fn test_clipboard_write_text_and_read_text_cross_backend_boundary_asynchronously() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut document := clipboard_test_focused_document()
	defer { document.finalize() }
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)

	write := board.write_text('hello, clipboard')
	assert write.state() == .pending
	drain_clipboard_test_event_loop(mut event_loop)
	assert write.state() == .fulfilled
	assert backend.items().len == 1
	assert backend.items()[0].system_clipboard_representations[0].mime_type == 'text/plain'
	assert backend.items()[0].system_clipboard_representations[0].byte_data()?.bytestr() == 'hello, clipboard'
	assert backend.presentation_styles() == ['unspecified']

	read := clipboard_test_read_text_from_paste(mut board)
	assert read.state() == .pending
	drain_clipboard_test_event_loop(mut event_loop)
	assert read.state() == .fulfilled
	assert read.text() == 'hello, clipboard'
}

fn test_clipboard_read_text_skips_file_backed_native_entries() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := SystemClipboardBackend.create()
	backend.replace_items([
		SystemClipboardItem{
			system_clipboard_representations: [
				SystemClipboardRepresentation.from_file('text/plain',
					html.SelectedFile.from_contents('private.txt', 'private'.bytes())),
				SystemClipboardRepresentation{
					data: 'public'.bytes()
					mime_type: 'text/plain'
				},
			]
		},
	], ['unspecified'])
	mut document := clipboard_test_focused_document()
	defer { document.finalize() }
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)

	read := clipboard_test_read_text_from_paste(mut board)
	drain_clipboard_test_event_loop(mut event_loop)
	assert read.state() == .fulfilled
	assert read.text() == 'public'
}

fn test_clipboard_read_builds_items_and_ignores_unknown_native_formats() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := SystemClipboardBackend.create()
	backend.replace_items([
		SystemClipboardItem{
			system_clipboard_representations: [
				SystemClipboardRepresentation{
					data: '<b>hello</b>'.bytes()
					mime_type: 'text/html;charset=utf-8'
				},
				SystemClipboardRepresentation{
					data: '{"ignored":true}'.bytes()
					mime_type: 'application/json'
				},
			]
		},
		SystemClipboardItem{
			system_clipboard_representations: [
				SystemClipboardRepresentation{
					data: [u8(137), 80, 78, 71]
					mime_type: 'image/png'
				},
			]
		},
		SystemClipboardItem{
			system_clipboard_representations: [
				SystemClipboardRepresentation.from_file('image/png',
					html.SelectedFile.from_contents('private.png', [u8(1), 2, 3])),
			]
		},
	], ['inline', 'attachment', 'unspecified'])
	mut document := clipboard_test_focused_document()
	defer { document.finalize() }
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)

	read := clipboard_test_read_from_paste(mut board, ClipboardUnsanitizedFormats{
		unsanitized: ['text/html']
	})
	drain_clipboard_test_event_loop(mut event_loop)
	assert read.state() == .fulfilled
	items := read.items()
	assert items.len == 2
	assert items[0].types() == ['text/html']
	html_result := items[0].get_type('text/html') or { panic(err) }
	assert html_result.blob() or { panic('missing HTML Blob') }.raw_bytes().bytestr() == '<b>hello</b>'
	assert items[0].get_type('text/html') or { panic(err) } == html_result
	assert items[1].types() == ['image/png']
	png_result := items[1].get_type('image/png') or { panic(err) }
	assert png_result.blob() or { panic('missing PNG Blob') }.raw_bytes() == [u8(137), 80, 78, 71]
}

fn test_clipboard_write_serializes_supported_representations_and_styles() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'text/plain'
			data: ClipboardItemDataPromise.resolved_string('plain')
		},
		ClipboardItemInput{
			type_: 'text/html'
			data: ClipboardItemDataPromise.resolved_blob(fileapi.Blob.create('<i>html</i>'.bytes(), 'text/html'))
		},
	], ClipboardItemOptions{
		presentation_style: .attachment
	}) or { panic(err) }

	write := board.write([item])
	drain_clipboard_test_event_loop(mut event_loop)
	assert write.state() == .fulfilled
	assert backend.presentation_styles() == ['attachment']
	representations := backend.items()[0].system_clipboard_representations
	assert representations.len == 2
	assert representations[0].mime_type == 'text/plain'
	assert representations[0].byte_data()?.bytestr() == 'plain'
	assert representations[1].mime_type == 'text/html'
	assert representations[1].byte_data()?.bytestr() == '<i>html</i>'
}

fn test_clipboard_write_waits_for_pending_representation_data() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	mut data := ClipboardItemDataPromise.pending()
	item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'text/plain'
			data: data
		},
	], ClipboardItemOptions{}) or { panic(err) }
	write := board.write([item])
	drain_clipboard_test_event_loop(mut event_loop)
	assert write.state() == .pending
	assert backend.items().len == 0

	data.resolve(ClipboardItemData.from_string('settled later'))
	drain_clipboard_test_event_loop(mut event_loop)
	assert write.state() == .fulfilled
	assert backend.items()[0].system_clipboard_representations[0].byte_data()?.bytestr() == 'settled later'
}

fn test_clipboard_write_rejects_rejected_data_and_unsupported_types() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	rejected_item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'text/plain'
			data: ClipboardItemDataPromise.rejected('producer failed')
		},
	], ClipboardItemOptions{}) or { panic(err) }
	rejected_write := board.write([rejected_item])
	drain_clipboard_test_event_loop(mut event_loop)
	assert rejected_write.state() == .rejected
	assert rejected_write.reason().contains('producer failed')

	unsupported_item := ClipboardItem.construct_impl([
		ClipboardItemInput{
			type_: 'application/json'
			data: ClipboardItemDataPromise.resolved_string('{}')
		},
	], ClipboardItemOptions{}) or { panic(err) }
	unsupported_write := board.write([unsupported_item])
	drain_clipboard_test_event_loop(mut event_loop)
	assert unsupported_write.state() == .rejected
	assert unsupported_write.reason().contains('application/json')
}
