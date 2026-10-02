// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XHR/EventNames, ProgressEvent, XMLHttpRequestEventTarget and
// XMLHttpRequestUpload.
module xhr

import dom

pub const event_names = ['readystatechange', 'loadstart', 'progress', 'abort', 'error', 'load',
	'timeout', 'loadend']

pub struct ProgressEventInit {
pub:
	bubbles           bool
	cancelable        bool
	composed          bool
	length_computable bool
	loaded            f64
	total             f64
}

@[heap]
pub struct ProgressEvent {
	dom.Event
pub:
	bubbles    bool
	cancelable bool
	composed   bool
mut:
	length_computable_ bool
	loaded_            f64
	total_             f64
}

pub fn ProgressEvent.construct(type_ string, init ProgressEventInit) ProgressEvent {
	base := dom.Event.create(type_, dom.EventInit{
		bubbles: init.bubbles
		cancelable: init.cancelable
		composed: init.composed
	})
	return ProgressEvent{
		Event:             dom.Event{ ...*base, interface_: .progress_event }
		bubbles:           init.bubbles
		cancelable:        init.cancelable
		composed:          init.composed
		length_computable_: init.length_computable
		loaded_:            init.loaded
		total_:             init.total
	}
}

pub fn ProgressEvent.create(type_ string, init ProgressEventInit) ProgressEvent {
	return ProgressEvent.construct(type_, init)
}

pub fn ProgressEvent.construct_impl(type_ string, init ProgressEventInit) ProgressEvent {
	return ProgressEvent.create(type_, init)
}

pub fn fire_progress_event(mut target XMLHttpRequestEventTarget, event_name string, transmitted u64, length u64) {
	event_value := ProgressEvent.create(event_name, ProgressEventInit{
		length_computable: length != 0
		loaded:            f64(transmitted)
		total:             f64(length)
	})
	mut event := &ProgressEvent{ ...event_value }
	event.time_stamp_ = target.event_timestamp()
	event.set_is_trusted(true)
	target.events << *event
	target.as_event_target().dispatch_event(unsafe { &dom.Event(event) })
}

pub fn (event &ProgressEvent) length_computable() bool {
	return event.length_computable_
}

pub fn (event &ProgressEvent) loaded() f64 {
	return event.loaded_
}

pub fn (event &ProgressEvent) total() f64 {
	return event.total_
}

@[heap]
pub struct XMLHttpRequestEventTarget {
	dom.EventTarget
pub mut:
	events    []ProgressEvent
	listeners map[string]bool
	event_timestamp fn () f64 = dom.current_event_timestamp
}

pub fn (target &XMLHttpRequestEventTarget) as_event_target() &dom.EventTarget {
	return unsafe { &dom.EventTarget(target) }
}

pub fn (target &XMLHttpRequestEventTarget) event_handler_callback(name string) ?&dom.CallbackType {
	return target.as_event_target().event_handler_attribute(name)
}

pub fn (target &XMLHttpRequestEventTarget) set_event_handler_callback(name string, callback ?&dom.CallbackType) {
	target.as_event_target().set_event_handler_attribute(name, callback)
}

pub fn (mut target XMLHttpRequestEventTarget) dispatch(type_ string, loaded u64, total u64) {
	fire_progress_event(mut target, type_, loaded, total)
}

pub fn (target &XMLHttpRequestEventTarget) has_relevant_listener() bool {
	for name in ['readystatechange', 'progress', 'abort', 'error', 'load', 'timeout', 'loadend'] {
		if target.listeners[name] || target.as_event_target().has_event_listener(name) { return true }
	}
	return false
}

pub fn (target &XMLHttpRequestEventTarget) onloadstart() bool { return target.listeners['loadstart'] }
pub fn (mut target XMLHttpRequestEventTarget) set_onloadstart(value bool) { target.listeners['loadstart'] = value }
pub fn (target &XMLHttpRequestEventTarget) onprogress() bool { return target.listeners['progress'] }
pub fn (mut target XMLHttpRequestEventTarget) set_onprogress(value bool) { target.listeners['progress'] = value }
pub fn (target &XMLHttpRequestEventTarget) onabort() bool { return target.listeners['abort'] }
pub fn (mut target XMLHttpRequestEventTarget) set_onabort(value bool) { target.listeners['abort'] = value }
pub fn (target &XMLHttpRequestEventTarget) onerror() bool { return target.listeners['error'] }
pub fn (mut target XMLHttpRequestEventTarget) set_onerror(value bool) { target.listeners['error'] = value }
pub fn (target &XMLHttpRequestEventTarget) onload() bool { return target.listeners['load'] }
pub fn (mut target XMLHttpRequestEventTarget) set_onload(value bool) { target.listeners['load'] = value }
pub fn (target &XMLHttpRequestEventTarget) ontimeout() bool { return target.listeners['timeout'] }
pub fn (mut target XMLHttpRequestEventTarget) set_ontimeout(value bool) { target.listeners['timeout'] = value }
pub fn (target &XMLHttpRequestEventTarget) onloadend() bool { return target.listeners['loadend'] }
pub fn (mut target XMLHttpRequestEventTarget) set_onloadend(value bool) { target.listeners['loadend'] = value }

@[heap]
pub struct XMLHttpRequestUpload {
	XMLHttpRequestEventTarget
}
