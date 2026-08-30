// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of XHR/EventNames, ProgressEvent, XMLHttpRequestEventTarget and
// XMLHttpRequestUpload.
module xhr

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

pub struct ProgressEvent {
pub:
	type_      string
	bubbles    bool
	cancelable bool
	composed   bool
mut:
	length_computable_ bool
	loaded_            f64
	total_             f64
}

pub fn ProgressEvent.construct(type_ string, init ProgressEventInit) ProgressEvent {
	return ProgressEvent{
		type_:             type_
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
	target.events << ProgressEvent.create(event_name, ProgressEventInit{
		length_computable: length != 0
		loaded:            f64(transmitted)
		total:             f64(length)
	})
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

pub struct XMLHttpRequestEventTarget {
pub mut:
	events    []ProgressEvent
	listeners map[string]bool
}

pub fn (mut target XMLHttpRequestEventTarget) dispatch(type_ string, loaded u64, total u64) {
	fire_progress_event(mut target, type_, loaded, total)
}

pub fn (target &XMLHttpRequestEventTarget) has_relevant_listener() bool {
	return ['readystatechange', 'progress', 'abort', 'error', 'load', 'timeout', 'loadend'].any(target.listeners[it])
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

pub struct XMLHttpRequestUpload {
	XMLHttpRequestEventTarget
}
