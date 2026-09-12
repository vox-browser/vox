// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaSource.{h,cpp,idl} and MediaSourceHandle.{h,cpp,idl}.
module mediasourceextensions

import dom
import mimesniff

pub enum ReadyState {
	closed
	open
	ended
}

pub fn (value ReadyState) webidl_name() string {
	return match value {
		.closed { 'closed' }
		.open { 'open' }
		.ended { 'ended' }
	}
}

pub fn ready_state_from_webidl(value string) !ReadyState {
	return match value {
		'closed' { .closed }
		'open' { .open }
		'ended' { .ended }
		else { error('TypeError: ${value} is not a ReadyState') }
	}
}

pub enum EndOfStreamError {
	network
	decode
}

pub fn (value EndOfStreamError) webidl_name() string {
	return match value {
		.network { 'network' }
		.decode { 'decode' }
	}
}

pub fn end_of_stream_error_from_webidl(value string) !EndOfStreamError {
	return match value {
		'network' { .network }
		'decode' { .decode }
		else { error('TypeError: ${value} is not an EndOfStreamError') }
	}
}

@[heap]
pub struct MediaSource {
	dom.EventTarget
}

pub fn MediaSource.create() &MediaSource {
	return &MediaSource{
		EventTarget: dom.EventTarget{}
	}
}

pub fn MediaSource.construct_impl() !&MediaSource {
	return MediaSource.create()
}

pub fn MediaSource.can_construct_in_dedicated_worker() bool {
	return true
}

pub fn MediaSource.is_type_supported(value string) bool {
	if value.len == 0 {
		return false
	}
	_ := mimesniff.MimeType.parse(value) or { return false }
	// Media subtype, codec, and combination support checks remain FIXME in the
	// current upstream implementation.
	return false
}

pub fn (source &MediaSource) set_onsourceopen(handler ?&dom.CallbackType) {
	source.set_event_handler_attribute('sourceopen', handler)
}

pub fn (source &MediaSource) onsourceopen() ?&dom.CallbackType {
	return source.event_handler_attribute('sourceopen')
}

pub fn (source &MediaSource) set_onsourceended(handler ?&dom.CallbackType) {
	source.set_event_handler_attribute('sourceended', handler)
}

pub fn (source &MediaSource) onsourceended() ?&dom.CallbackType {
	return source.event_handler_attribute('sourceended')
}

pub fn (source &MediaSource) set_onsourceclose(handler ?&dom.CallbackType) {
	source.set_event_handler_attribute('sourceclose', handler)
}

pub fn (source &MediaSource) onsourceclose() ?&dom.CallbackType {
	return source.event_handler_attribute('sourceclose')
}

// The platform object is created internally; MediaSourceHandle has no exposed
// WebIDL constructor.
@[heap]
pub struct MediaSourceHandle {}

fn MediaSourceHandle.create_internal() &MediaSourceHandle {
	return &MediaSourceHandle{}
}

pub fn (handle &MediaSourceHandle) is_transferable() bool {
	_ = handle
	return true
}
