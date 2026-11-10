// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module clipboard

import html

struct ClipboardPasteObservation {
mut:
	text []&ClipboardTextPromise
	items []&ClipboardReadPromise
}

fn clipboard_paste_test_items(text string) []SystemClipboardItem {
	return [SystemClipboardItem{
		system_clipboard_representations: [SystemClipboardRepresentation{
			data: text.bytes()
			mime_type: 'text/plain'
		}]
	}]
}

fn drain_clipboard_paste_tasks(mut event_loop html.EventLoop) {
	mut count := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		count++
		assert count < 100
	}
}

fn test_transient_activation_does_not_authorize_reading_another_applications_clipboard() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := SystemClipboardBackend.create()
	backend.replace_items(clipboard_paste_test_items('other application'), ['unspecified'])
	mut board := Clipboard.create(backend, event_loop, none)
	for has_activation in [false, true] {
		board.set_has_transient_activation(has_activation)
		text := board.read_text()
		items := board.read(ClipboardUnsanitizedFormats{})
		drain_clipboard_paste_tasks(mut event_loop)
		assert text.state() == .rejected && text.reason().starts_with('NotAllowedError:')
		assert items.state() == .rejected && items.reason().starts_with('NotAllowedError:')
	}
}

fn test_browser_paste_reads_capture_the_pasted_snapshot_and_do_not_authorize_later_tasks() {
	mut event_loop := html.EventLoop.create(.window)
	mut backend := SystemClipboardBackend.create()
	backend.replace_items(clipboard_paste_test_items('pasted'), ['unspecified'])
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	mut observed := &ClipboardPasteObservation{}
	board.during_system_clipboard_paste(backend.items(), fn [board, mut observed] () {
		observed.text << board.read_text()
		observed.items << board.read(ClipboardUnsanitizedFormats{})
	})
	assert observed.text[0].state() == .pending
	backend.replace_items(clipboard_paste_test_items('replacement secret'), ['unspecified'])
	later := board.read_text()
	drain_clipboard_paste_tasks(mut event_loop)
	assert observed.text[0].state() == .fulfilled && observed.text[0].text() == 'pasted'
	assert observed.items[0].state() == .fulfilled
	item := observed.items[0].items()[0]
	blob := item.get_type('text/plain')!.blob()?
	assert blob.raw_bytes().bytestr() == 'pasted'
	assert later.state() == .rejected && later.reason().starts_with('NotAllowedError:')
}

fn test_nested_browser_pastes_restore_the_outer_snapshot_and_empty_pastes_remain_authorized() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	mut observed := &ClipboardPasteObservation{}
	board.during_system_clipboard_paste(clipboard_paste_test_items('outer'), fn [mut board, mut observed] () {
		observed.text << board.read_text()
		board.during_system_clipboard_paste(clipboard_paste_test_items('inner'), fn [board, mut observed] () {
			observed.text << board.read_text()
		})
		observed.text << board.read_text()
	})
	board.during_system_clipboard_paste([], fn [board, mut observed] () {
		observed.items << board.read(ClipboardUnsanitizedFormats{})
	})
	drain_clipboard_paste_tasks(mut event_loop)
	assert observed.text[0].text() == 'outer'
	assert observed.text[1].text() == 'inner'
	assert observed.text[2].text() == 'outer'
	assert observed.items[0].state() == .fulfilled && observed.items[0].items().len == 0
}

fn test_browser_paste_does_not_bypass_lost_activation_before_the_permission_task() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	mut observed := &ClipboardPasteObservation{}
	board.during_system_clipboard_paste(clipboard_paste_test_items('pasted'), fn [board, mut observed] () {
		observed.text << board.read_text()
	})
	board.set_has_transient_activation(false)
	drain_clipboard_paste_tasks(mut event_loop)
	assert observed.text[0].state() == .rejected
	assert observed.text[0].reason().starts_with('NotAllowedError:')
}
