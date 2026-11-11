// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

module clipboard

import dom
import html

struct ClipboardFocusOwner {
mut:
	focused bool = true
	paste_read &ClipboardTextPromise = unsafe { nil }
}

fn clipboard_focus_test_document(owner &ClipboardFocusOwner) &dom.Document {
	url := dom.URL{value: 'https://clipboard-focus.test/'}
	mut document := dom.Document.create(url)
	document.set_origin(url.origin())
	navigable := &dom.Navigable{
		active_document_: document
		is_top_level_traversable_: true
		html_model_handle_: voidptr(owner)
		is_focused_callback_: fn (target voidptr) bool {
			return unsafe { &ClipboardFocusOwner(target) }.focused
		}
	}
	document.set_cached_navigable(navigable)
	return document
}

fn drain_clipboard_focus_tasks(mut event_loop html.EventLoop) {
	mut count := 0
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
		count++
		assert count < 100
	}
}

fn test_background_document_cannot_read_its_own_data_or_a_paste_snapshot() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut owner := &ClipboardFocusOwner{}
	mut document := clipboard_focus_test_document(owner)
	defer { document.finalize() }
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)
	write := board.write_text('own text')
	drain_clipboard_focus_tasks(mut event_loop)
	assert write.state() == .fulfilled
	owner.focused = false
	read := board.read_text()
	board.during_system_clipboard_paste(backend.items(), fn [board, mut owner] () {
		owner.paste_read = board.read_text()
	})
	drain_clipboard_focus_tasks(mut event_loop)
	assert read.state() == .rejected && read.reason().starts_with('NotAllowedError:')
	assert owner.paste_read.state() == .rejected
	owner.focused = true
	restored := board.read_text()
	drain_clipboard_focus_tasks(mut event_loop)
	assert restored.state() == .fulfilled && restored.text() == 'own text'
}

fn test_clipboard_read_permission_checks_focus_when_the_deferred_task_runs() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut owner := &ClipboardFocusOwner{}
	mut document := clipboard_focus_test_document(owner)
	defer { document.finalize() }
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)
	board.during_system_clipboard_paste([], fn [board, mut owner] () {
		owner.paste_read = board.read_text()
	})
	assert owner.paste_read.state() == .pending
	owner.focused = false
	drain_clipboard_focus_tasks(mut event_loop)
	assert owner.paste_read.state() == .rejected
	assert owner.paste_read.reason().starts_with('NotAllowedError:')
}

fn test_clipboard_without_a_document_cannot_gain_focus_from_a_paste_scope() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut board := Clipboard.create(backend, event_loop, none)
	board.set_has_transient_activation(true)
	mut owner := &ClipboardFocusOwner{}
	board.during_system_clipboard_paste([], fn [board, mut owner] () {
		owner.paste_read = board.read_text()
	})
	drain_clipboard_focus_tasks(mut event_loop)
	assert owner.paste_read.state() == .rejected
	assert owner.paste_read.reason().starts_with('NotAllowedError:')
}

fn test_clipboard_reads_the_actual_document_windows_activation() {
	mut event_loop := html.EventLoop.create(.window)
	backend := SystemClipboardBackend.create()
	mut owner := &ClipboardFocusOwner{}
	mut document := clipboard_focus_test_document(owner)
	defer { document.finalize() }
	mut window := &dom.Window{}
	window.set_associated_document(document)
	document.set_window(window)
	mut board := Clipboard.create(backend, event_loop, document)
	board.set_has_transient_activation(true)
	assert !window.has_transient_activation()
	board.during_system_clipboard_paste([], fn [board, mut owner] () {
		owner.paste_read = board.read_text()
	})
	drain_clipboard_focus_tasks(mut event_loop)
	assert owner.paste_read.state() == .rejected
}
