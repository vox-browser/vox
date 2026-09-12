// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SourceBuffer.cpp, SourceBufferList.cpp, and
// ManagedSourceBuffer.cpp plus their headers and IDL.
module mediasourceextensions

import dom

pub enum AppendMode {
	segments
	sequence
}

pub fn (value AppendMode) webidl_name() string {
	return match value {
		.segments { 'segments' }
		.sequence { 'sequence' }
	}
}

pub fn append_mode_from_webidl(value string) !AppendMode {
	return match value {
		'segments' { .segments }
		'sequence' { .sequence }
		else { error('TypeError: ${value} is not an AppendMode') }
	}
}

@[heap]
pub struct SourceBuffer {
	dom.EventTarget
mut:
	media_source_ ?&MediaSource
	processor_    &SourceBufferProcessor = unsafe { nil }
}

// SourceBuffer has no exposed constructor, but MediaSource implementations
// need an internal factory for the translated platform type.
pub fn SourceBuffer.create_internal() &SourceBuffer {
	return &SourceBuffer{
		EventTarget: dom.EventTarget{}
		processor_: SourceBufferProcessor.create()
	}
}

pub fn SourceBuffer.create_internal_for_media_source(media_source &MediaSource) &SourceBuffer {
	return &SourceBuffer{
		EventTarget: dom.EventTarget{}
		media_source_: media_source
		processor_: SourceBufferProcessor.create()
	}
}

pub fn (buffer &SourceBuffer) updating() bool {
	return buffer.processor_.updating()
}

pub fn (buffer &SourceBuffer) input_buffer_length() int {
	return buffer.processor_.input_buffer_length()
}

// https://w3c.github.io/media-source/#sourcebuffer-prepare-append
fn (mut buffer SourceBuffer) prepare_append() ! {
	mut media_source := buffer.media_source_ or {
		return error('InvalidStateError: Unsupported in workers')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	if buffer.updating() {
		return error('InvalidStateError: SourceBuffer is already updating')
	}
	media_element := media_source.media_element_assigned_to() or {
		return error('InvalidStateError: Unsupported in workers')
	}
	if media_element.error() != none {
		return error('InvalidStateError: Element has a recent error')
	}
	if media_source.ready_state() == .ended {
		media_source.set_ready_state_to_open_and_fire_sourceopen_event()
	}
	buffer.processor_.run_coded_frame_eviction()
	if buffer.processor_.is_buffer_full() {
		return error('QuotaExceededError: Buffer is full')
	}
}

// https://w3c.github.io/media-source/#dom-sourcebuffer-appendbuffer
pub fn (mut buffer SourceBuffer) append_buffer(data []u8) ! {
	buffer.prepare_append()!
	buffer.processor_.append_to_input_buffer(data)
	buffer.processor_.set_updating(true)
	media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	media_source.queue_a_media_source_task(fn [buffer] () {
		buffer.dispatch_event(dom.Event.create('updatestart', dom.EventInit{}))
	})
	media_source.queue_a_media_source_task(fn [mut buffer] () {
		buffer.run_buffer_append_algorithm()
	})
}

fn (mut buffer SourceBuffer) run_buffer_append_algorithm() {
	if !buffer.processor_.run_segment_parser_loop() {
		buffer.run_append_error_algorithm()
	}
}

// https://w3c.github.io/media-source/#sourcebuffer-append-error
fn (mut buffer SourceBuffer) run_append_error_algorithm() {
	buffer.processor_.reset_parser_state()
	buffer.processor_.set_updating(false)
	media_source := buffer.media_source_ or { return }
	media_source.queue_a_media_source_task(fn [buffer] () {
		buffer.dispatch_event(dom.Event.create('error', dom.EventInit{}))
	})
	media_source.queue_a_media_source_task(fn [buffer] () {
		buffer.dispatch_event(dom.Event.create('updateend', dom.EventInit{}))
	})
	mut mutable_media_source := media_source
	mutable_media_source.run_end_of_stream_algorithm(.decode)
}

pub fn (buffer &SourceBuffer) set_onupdatestart(handler ?&dom.CallbackType) {
	buffer.set_event_handler_attribute('updatestart', handler)
}

pub fn (buffer &SourceBuffer) onupdatestart() ?&dom.CallbackType {
	return buffer.event_handler_attribute('updatestart')
}

pub fn (buffer &SourceBuffer) set_onupdate(handler ?&dom.CallbackType) {
	buffer.set_event_handler_attribute('update', handler)
}

pub fn (buffer &SourceBuffer) onupdate() ?&dom.CallbackType {
	return buffer.event_handler_attribute('update')
}

pub fn (buffer &SourceBuffer) set_onupdateend(handler ?&dom.CallbackType) {
	buffer.set_event_handler_attribute('updateend', handler)
}

pub fn (buffer &SourceBuffer) onupdateend() ?&dom.CallbackType {
	return buffer.event_handler_attribute('updateend')
}

pub fn (buffer &SourceBuffer) set_onerror(handler ?&dom.CallbackType) {
	buffer.set_event_handler_attribute('error', handler)
}

pub fn (buffer &SourceBuffer) onerror() ?&dom.CallbackType {
	return buffer.event_handler_attribute('error')
}

pub fn (buffer &SourceBuffer) set_onabort(handler ?&dom.CallbackType) {
	buffer.set_event_handler_attribute('abort', handler)
}

pub fn (buffer &SourceBuffer) onabort() ?&dom.CallbackType {
	return buffer.event_handler_attribute('abort')
}

@[heap]
pub struct ManagedSourceBuffer {
	SourceBuffer
}

pub fn ManagedSourceBuffer.create_internal() &ManagedSourceBuffer {
	return &ManagedSourceBuffer{
		SourceBuffer: SourceBuffer{
			EventTarget: dom.EventTarget{}
		}
	}
}

pub fn (buffer &ManagedSourceBuffer) set_onbufferedchange(handler ?&dom.CallbackType) {
	buffer.set_event_handler_attribute('bufferedchange', handler)
}

pub fn (buffer &ManagedSourceBuffer) onbufferedchange() ?&dom.CallbackType {
	return buffer.event_handler_attribute('bufferedchange')
}

@[heap]
pub struct SourceBufferList {
	dom.EventTarget
mut:
	buffers_ []&SourceBuffer
}

pub fn SourceBufferList.create_internal() &SourceBufferList {
	return &SourceBufferList{
		EventTarget: dom.EventTarget{}
	}
}

pub fn (mut list SourceBufferList) append(buffer &SourceBuffer) {
	list.buffers_ << buffer
	list.dispatch_event(dom.Event.create('addsourcebuffer', dom.EventInit{}))
}

pub fn (list &SourceBufferList) length() u32 {
	return u32(list.buffers_.len)
}

pub fn (list &SourceBufferList) item(index u32) ?&SourceBuffer {
	if index >= u32(list.buffers_.len) {
		return none
	}
	return list.buffers_[index]
}

pub fn (list &SourceBufferList) contains(buffer &SourceBuffer) bool {
	for candidate in list.buffers_ {
		if candidate == buffer {
			return true
		}
	}
	return false
}

pub fn (list &SourceBufferList) set_onaddsourcebuffer(handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('addsourcebuffer', handler)
}

pub fn (list &SourceBufferList) onaddsourcebuffer() ?&dom.CallbackType {
	return list.event_handler_attribute('addsourcebuffer')
}

pub fn (list &SourceBufferList) set_onremovesourcebuffer(handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('removesourcebuffer', handler)
}

pub fn (list &SourceBufferList) onremovesourcebuffer() ?&dom.CallbackType {
	return list.event_handler_attribute('removesourcebuffer')
}
