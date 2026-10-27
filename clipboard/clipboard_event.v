// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Clipboard/ClipboardEvent.{h,cpp,idl}.
module clipboard

import dom
import html

pub struct ClipboardEventInit {
	dom.EventInit
pub mut:
	clipboard_data ?&html.DataTransfer
}

@[heap]
pub struct ClipboardEvent {
	dom.Event
mut:
	clipboard_data_ ?&html.DataTransfer
}

pub fn ClipboardEvent.create(event_name string, init ClipboardEventInit) &ClipboardEvent {
	return &ClipboardEvent{
		Event: dom.Event{
			interface_: .clipboard_event
			type_: event_name
			bubbles_: init.bubbles
			cancelable_: init.cancelable
			composed_: init.composed
			initialized_: true
		}
		clipboard_data_: init.clipboard_data
	}
}

pub fn ClipboardEvent.construct_impl(event_name string, init ClipboardEventInit) !&ClipboardEvent {
	return ClipboardEvent.create(event_name, init)
}

pub fn (event &ClipboardEvent) clipboard_data() ?&html.DataTransfer {
	return event.clipboard_data_
}

pub fn ClipboardEvent.clipboard_data_offset() uint {
	return uint(__offsetof(ClipboardEvent, clipboard_data_))
}
