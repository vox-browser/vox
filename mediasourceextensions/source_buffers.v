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
}

// SourceBuffer has no exposed constructor, but MediaSource implementations
// need an internal factory for the translated platform type.
pub fn SourceBuffer.create_internal() &SourceBuffer {
	return &SourceBuffer{
		EventTarget: dom.EventTarget{}
	}
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
}

pub fn SourceBufferList.create_internal() &SourceBufferList {
	return &SourceBufferList{
		EventTarget: dom.EventTarget{}
	}
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
