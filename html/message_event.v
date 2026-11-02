// Copyright (c) 2021, Dex♪ <dexes.ttp@gmail.com>
// Copyright (c) 2022, Andreas Kling <andreas@ladybird.org>
// Copyright (c) 2026, Sam Atkins <sam@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MessageEvent.{h,cpp}.
module html

import dom

pub enum EmptyMessageOrigin {
	empty
}

pub type MessageEventOrigin = EmptyMessageOrigin | dom.Origin | string

pub struct WindowMessageEventSource {
pub:
	value &dom.WindowProxy = unsafe { nil }
}

pub struct PortMessageEventSource {
pub:
	value &MessagePort = unsafe { nil }
}

pub type MessageEventSource = PortMessageEventSource | WindowMessageEventSource

pub fn message_event_to_message_event_source_internal(source ?MessageEventSource) ?MessageEventSource {
	return source
}

pub struct MessageEventInit {
	dom.EventInit
pub:
	data          dom.JSValue = dom.JSValue{
		kind: .null_
	}
	origin        MessageEventOrigin = MessageEventOrigin(EmptyMessageOrigin.empty)
	last_event_id string
	source        ?MessageEventSource
	ports         []&MessagePort
}

@[heap]
pub struct MessageEvent {
	dom.Event
mut:
	data_          dom.JSValue
	origin_        MessageEventOrigin = MessageEventOrigin(EmptyMessageOrigin.empty)
	last_event_id_ string
	source_        ?MessageEventSource
	ports_         []&MessagePort
}

pub fn MessageEvent.create(event_name string, event_init MessageEventInit) &MessageEvent {
	return &MessageEvent{
		Event:          dom.Event{
			interface_:   .message_event
			type_:        event_name
			bubbles_:     event_init.bubbles
			cancelable_:  event_init.cancelable
			composed_:    event_init.composed
			initialized_: true
			time_stamp_:  dom.current_event_timestamp()
		}
		data_:          event_init.data
		origin_:        event_init.origin
		last_event_id_: event_init.last_event_id
		source_:        message_event_to_message_event_source_internal(event_init.source)
		ports_:         event_init.ports.clone()
	}
}

pub fn MessageEvent.construct_impl(event_name string, event_init MessageEventInit) !&MessageEvent {
	return MessageEvent.create(event_name, event_init)
}

pub fn (event &MessageEvent) data() dom.JSValue {
	return event.data_
}

pub fn (event &MessageEvent) origin() string {
	return match event.origin_ {
		EmptyMessageOrigin { '' }
		dom.Origin { (event.origin_ as dom.Origin).serialize() }
		string { event.origin_ as string }
	}
}

pub fn (event &MessageEvent) last_event_id() string {
	return event.last_event_id_
}

pub fn (event &MessageEvent) source() ?MessageEventSource {
	return event.source_
}

pub fn (event &MessageEvent) ports() []&MessagePort {
	return event.ports_.clone()
}

pub fn (event &MessageEvent) extract_an_origin() ?dom.Origin {
	if event.origin_ is dom.Origin {
		return event.origin_ as dom.Origin
	}
	return none
}

pub fn (mut event MessageEvent) init_message_event(type_ string, bubbles bool, cancelable bool, data dom.JSValue, origin string, last_event_id string, source ?MessageEventSource, ports []&MessagePort) {
	if event.dispatched() {
		return
	}
	event.initialize_event(type_, bubbles, cancelable)
	event.data_ = data
	event.origin_ = origin
	event.last_event_id_ = last_event_id
	event.source_ = message_event_to_message_event_source_internal(source)
	event.ports_ = ports.clone()
}
