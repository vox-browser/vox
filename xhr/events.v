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
	type_             string
	bubbles           bool
	cancelable        bool
	composed          bool
	length_computable bool
	loaded            f64
	total             f64
}

pub fn ProgressEvent.construct(type_ string, init ProgressEventInit) ProgressEvent {
	return ProgressEvent{
		type_:             type_
		bubbles:           init.bubbles
		cancelable:        init.cancelable
		composed:          init.composed
		length_computable: init.length_computable
		loaded:            init.loaded
		total:             init.total
	}
}

pub struct XMLHttpRequestEventTarget {
pub mut:
	events    []ProgressEvent
	listeners map[string]bool
}

pub fn (mut target XMLHttpRequestEventTarget) dispatch(type_ string, loaded u64, total u64) {
	target.events << ProgressEvent.construct(type_, ProgressEventInit{
		length_computable: total != 0
		loaded:            f64(loaded)
		total:             f64(total)
	})
}

pub fn (target &XMLHttpRequestEventTarget) has_relevant_listener() bool {
	return ['readystatechange', 'progress', 'abort', 'error', 'load', 'timeout', 'loadend'].any(target.listeners[it])
}

pub struct XMLHttpRequestUpload {
	XMLHttpRequestEventTarget
}
