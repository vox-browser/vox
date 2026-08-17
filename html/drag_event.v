// Copyright (c) 2024, Maciej <sppmacd@pm.me>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of DragEvent.{h,cpp}.
module html

import dom

pub struct DragEventInit {
	dom.MouseEventInit
pub:
	data_transfer ?&DataTransfer
}

@[heap]
pub struct DragEvent {
	dom.MouseEvent
mut:
	data_transfer_ ?&DataTransfer
}

pub fn DragEvent.create(event_name string, event_init DragEventInit, page_x f64, page_y f64, offset_x f64, offset_y f64) &DragEvent {
	mut mouse_init := event_init.MouseEventInit
	mouse_init.page_x = page_x
	mouse_init.page_y = page_y
	mouse_init.offset_x = offset_x
	mouse_init.offset_y = offset_y
	mut mouse_event := dom.MouseEvent.create(event_name, mouse_init)
	mouse_event.interface_ = .drag_event
	return &DragEvent{
		MouseEvent:     *mouse_event
		data_transfer_: event_init.data_transfer
	}
}

pub fn DragEvent.construct_impl(event_name string, event_init DragEventInit) !&DragEvent {
	return DragEvent.create(event_name, event_init, event_init.client_x, event_init.client_y,
		event_init.client_x, event_init.client_y)
}

pub fn (event &DragEvent) data_transfer() ?&DataTransfer {
	return event.data_transfer_
}
