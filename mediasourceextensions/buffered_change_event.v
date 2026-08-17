// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of BufferedChangeEvent.{h,cpp,idl}.
module mediasourceextensions

import dom
import html

pub struct BufferedChangeEventInit {
	dom.EventInit
pub:
	added_ranges   ?&html.TimeRanges
	removed_ranges ?&html.TimeRanges
}

@[heap]
pub struct BufferedChangeEvent {
	dom.Event
}

pub fn BufferedChangeEvent.create(event_name string, init BufferedChangeEventInit) &BufferedChangeEvent {
	// The current upstream constructor passes only EventInit to DOM::Event. The
	// two TimeRanges accessors are still [FIXME] in its IDL, so no speculative
	// storage/accessors are added here.
	return &BufferedChangeEvent{
		Event: dom.Event{
			interface_:   .buffered_change_event
			type_:        event_name
			bubbles_:     init.bubbles
			cancelable_:  init.cancelable
			composed_:    init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
	}
}

pub fn BufferedChangeEvent.construct_impl(event_name string, init BufferedChangeEventInit) !&BufferedChangeEvent {
	return BufferedChangeEvent.create(event_name, init)
}
