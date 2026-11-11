// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module clipboard

import dom
import html

fn clipboard_origin_test_document(value string) &dom.Document {
	url := dom.URL{value: value}
	mut document := dom.Document.create(url)
	document.set_origin(url.origin())
	navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
		html_model_handle_: voidptr(document)
		is_focused_callback_: fn (_ voidptr) bool { return true }
	}
	document.set_cached_navigable(navigable)
	return document
}

fn clipboard_origin_test_text(text string) SystemClipboardRepresentation {
	return SystemClipboardRepresentation{data: text.bytes(), mime_type: 'text/plain'}
}

fn drain_clipboard_origin_tasks(mut event_loop html.EventLoop) {
	mut count := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		count++
		assert count < 100
	}
}

fn test_clipboard_write_text_allows_only_activated_same_origin_readback_in_the_writing_tab() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut writer := clipboard_origin_test_document('https://writer.test/one')
	mut board := Clipboard.create(backend, event_loop, writer)
	board.set_has_transient_activation(true)
	write := board.write_text('own text')
	drain_clipboard_origin_tasks(mut event_loop)
	assert write.state() == .fulfilled
	board.set_has_transient_activation(false)
	denied := board.read_text()
	drain_clipboard_origin_tasks(mut event_loop)
	assert denied.state() == .rejected
	board.set_has_transient_activation(true)
	read := board.read_text()
	drain_clipboard_origin_tasks(mut event_loop)
	assert read.state() == .fulfilled && read.text() == 'own text'

	mut same_origin := clipboard_origin_test_document('https://writer.test/two')
	mut tab := writer.navigable()?
	tab.active_document_ = same_origin
	same_origin.set_cached_navigable(tab)
	mut same_board := Clipboard.create(backend, event_loop, same_origin)
	same_board.set_has_transient_activation(true)
	same_read := same_board.read_text()
	drain_clipboard_origin_tasks(mut event_loop)
	assert same_read.state() == .fulfilled && same_read.text() == 'own text'

	mut other_origin := clipboard_origin_test_document('https://other.test/')
	tab.active_document_ = other_origin
	other_origin.set_cached_navigable(tab)
	mut other_board := Clipboard.create(backend, event_loop, other_origin)
	other_board.set_has_transient_activation(true)
	other_read := other_board.read_text()
	drain_clipboard_origin_tasks(mut event_loop)
	assert other_read.state() == .rejected && other_read.reason().starts_with('NotAllowedError:')

	mut other_tab := clipboard_origin_test_document('https://writer.test/three')
	mut other_tab_board := Clipboard.create(backend, event_loop, other_tab)
	other_tab_board.set_has_transient_activation(true)
	other_tab_read := other_tab_board.read_text()
	drain_clipboard_origin_tasks(mut event_loop)
	assert other_tab_read.state() == .rejected
	writer.finalize()
	same_origin.finalize()
	other_origin.finalize()
	other_tab.finalize()
}

fn test_clipboard_write_item_records_all_byte_representations_for_readback() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut document := clipboard_origin_test_document('https://writer.test/')
	defer { document.finalize() }
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)
	item := ClipboardItem.construct_impl([
		ClipboardItemInput{type_: 'text/plain', data: ClipboardItemDataPromise.resolved_string('own text')},
		ClipboardItemInput{type_: 'text/html', data: ClipboardItemDataPromise.resolved_string('<b>own text</b>')},
	], ClipboardItemOptions{})!
	write := board.write([item])
	drain_clipboard_origin_tasks(mut event_loop)
	assert write.state() == .fulfilled
	read := board.read(ClipboardUnsanitizedFormats{})
	drain_clipboard_origin_tasks(mut event_loop)
	assert read.state() == .fulfilled
	assert read.items()[0].types() == ['text/plain', 'text/html']
}

fn test_clipboard_readback_checks_all_native_representations_and_keeps_the_last_origin_write() {
	mut document := clipboard_origin_test_document('https://writer.test/')
	defer { document.finalize() }
	mut backend := SystemClipboardBackend.create()
	text := clipboard_origin_test_text('own text')
	html_representation := SystemClipboardRepresentation{data: '<b>own text</b>'.bytes(), mime_type: 'text/html'}
	original := [SystemClipboardItem{system_clipboard_representations: [text, html_representation]}]
	backend.replace_items_written_by(original, ['unspecified'], document)
	for representations in [
		[clipboard_origin_test_text('new secret')],
		[SystemClipboardRepresentation{data: 'own text'.bytes(), mime_type: 'text/html'}],
		[text, clipboard_origin_test_text('new secret')],
		[text, SystemClipboardRepresentation.from_file('text/plain', html.SelectedFile.from_contents('secret.txt', 'own text'.bytes()))],
		[]SystemClipboardRepresentation{},
	] {
		backend.replace_items([SystemClipboardItem{system_clipboard_representations: representations}], ['unspecified'])
		assert backend.items_written_by(document).len == 0
	}
	backend.replace_items([], [])
	assert backend.items_written_by(document).len == 0
	// Native roundtrips may remove or reorder formats, and an external writer
	// may restore exactly the bytes the origin already knows.
	backend.replace_items([SystemClipboardItem{system_clipboard_representations: [html_representation]}], ['unspecified'])
	assert backend.items_written_by(document).len == 1
	backend.replace_items([SystemClipboardItem{system_clipboard_representations: [html_representation, text]}], ['unspecified'])
	assert backend.items_written_by(document).len == 1
}

fn test_clipboard_readback_uses_opaque_origin_identity_instead_of_its_null_serialization() {
	mut first := clipboard_origin_test_document('about:blank')
	mut second := clipboard_origin_test_document('about:blank')
	defer { first.finalize(); second.finalize() }
	mut tab := first.navigable()?
	second.set_cached_navigable(tab)
	mut backend := SystemClipboardBackend.create()
	backend.replace_items_written_by([SystemClipboardItem{
		system_clipboard_representations: [clipboard_origin_test_text('opaque owner')]
	}], ['unspecified'], first)
	assert first.origin().serialize() == second.origin().serialize()
	assert backend.items_written_by(second).len == 0
	second.set_origin(first.origin())
	assert backend.items_written_by(second).len == 1
}
