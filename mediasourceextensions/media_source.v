// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaSource.{h,cpp,idl} and MediaSourceHandle.{h,cpp,idl}.
module mediasourceextensions

import dom
import fileapi
import html
import math
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
mut:
	ready_state_               ReadyState
	has_ever_been_attached_    bool
	media_element_assigned_to_ ?&html.HTMLMediaElement
	source_buffers_            &SourceBufferList = unsafe { nil }
	active_source_buffers_     &SourceBufferList = unsafe { nil }
	duration_                  f64 = math.nan()
	next_track_id_             i64 = 1
}

pub fn MediaSource.create() &MediaSource {
	return &MediaSource{
		EventTarget: dom.EventTarget{}
		source_buffers_: SourceBufferList.create_internal()
		active_source_buffers_: SourceBufferList.create_internal()
	}
}

pub fn MediaSource.construct_impl() !&MediaSource {
	return MediaSource.create()
}

pub fn (source &MediaSource) ready_state() ReadyState {
	return source.ready_state_
}

pub fn (source &MediaSource) ready_state_is_closed() bool {
	return source.ready_state_ == .closed
}

pub fn (source &MediaSource) has_ever_been_attached() bool {
	return source.has_ever_been_attached_
}

pub fn (source &MediaSource) media_element_assigned_to() ?&html.HTMLMediaElement {
	return source.media_element_assigned_to_
}

pub fn (source &MediaSource) source_buffers() &SourceBufferList {
	return source.source_buffers_
}

pub fn (source &MediaSource) active_source_buffers() &SourceBufferList {
	return source.active_source_buffers_
}

pub fn (mut source MediaSource) next_track_id() i64 {
	id := source.next_track_id_
	source.next_track_id_++
	return id
}

// https://w3c.github.io/media-source/#addsourcebuffer-method
pub fn (mut source MediaSource) add_source_buffer(type_ string) !&SourceBuffer {
	if type_.len == 0 {
		return error('TypeError: SourceBuffer type must not be empty')
	}
	if !MediaSource.is_type_supported(type_) {
		return error('NotSupportedError: Unsupported MIME type')
	}
	if source.ready_state_ != .open {
		return error('InvalidStateError: MediaSource is not open')
	}
	mut buffer := SourceBuffer.create_internal_for_media_source(source)
	buffer.set_content_type(type_)!
	mut buffers := source.source_buffers_
	buffers.append(buffer)
	return buffer
}

pub fn (source &MediaSource) duration() f64 {
	if source.ready_state_ == .closed {
		return math.nan()
	}
	return source.duration_
}

pub fn (mut source MediaSource) set_duration(duration f64) ! {
	if duration < 0 || math.is_nan(duration) {
		return error('TypeError: duration must not be negative or NaN')
	}
	if source.ready_state_ != .open {
		return error('InvalidStateError: MediaSource is not open')
	}
	for index in 0 .. source.source_buffers_.length() {
		buffer := source.source_buffers_.item(index) or { continue }
		if buffer.updating() {
			return error('InvalidStateError: A SourceBuffer is still updating')
		}
	}
	source.run_duration_change_algorithm(duration)
}

pub fn (mut source MediaSource) run_duration_change_algorithm(duration f64) {
	if source.duration_ == duration {
		return
	}
	source.duration_ = duration
	if mut media_element := source.media_element_assigned_to_ {
		media_element.media_source_set_duration(duration)
	}
}

// https://w3c.github.io/media-source/#dom-mediasource-endofstream
pub fn (mut source MediaSource) end_of_stream(error_ ?EndOfStreamError) ! {
	if source.ready_state_ != .open {
		return error('InvalidStateError: MediaSource is not open')
	}
	for index in 0 .. source.source_buffers_.length() {
		buffer := source.source_buffers_.item(index) or { continue }
		if buffer.updating() {
			return error('InvalidStateError: A SourceBuffer is still updating')
		}
	}
	source.run_end_of_stream_algorithm(error_)
}

// https://w3c.github.io/media-source/#end-of-stream-algorithm
pub fn (mut source MediaSource) run_end_of_stream_algorithm(error_ ?EndOfStreamError) {
	source.ready_state_ = .ended
	source.queue_a_media_source_task(fn [source] () {
		source.dispatch_event(dom.Event.create('sourceended', dom.EventInit{}))
	})
	for index in 0 .. source.source_buffers_.length() {
		if mut buffer := source.source_buffers_.item(index) {
			buffer.set_reached_end_of_stream()
		}
	}
	// Duration adjustment and media-element error signaling depend on coded
	// track buffers and are translated with the demuxing path.
	_ = error_
}

pub fn (source &MediaSource) queue_a_media_source_task(task fn ()) {
	_ = source
	// The V event-loop boundary drains this task source synchronously.
	task()
}

pub fn (mut source MediaSource) set_ready_state_to_open_and_fire_sourceopen_event() {
	source.ready_state_ = .open
	for index in 0 .. source.source_buffers_.length() {
		if mut buffer := source.source_buffers_.item(index) {
			buffer.clear_reached_end_of_stream()
		}
	}
	source.queue_a_media_source_task(fn [source] () {
		source.dispatch_event(dom.Event.create('sourceopen', dom.EventInit{}))
	})
}

pub fn (mut source MediaSource) unassign_from_media_element() {
	source.media_element_assigned_to_ = none
}

// https://w3c.github.io/media-source/#mediasource-detach
pub fn (mut source MediaSource) detach_from_media_element() {
	source.ready_state_ = .closed
	source.duration_ = math.nan()
	for index in 0 .. source.source_buffers_.length() {
		if mut buffer := source.source_buffers_.item(index) {
			buffer.abort_if_updating()
		}
	}
	mut active_buffers := source.active_source_buffers_
	active_buffers.remove_all_buffers()
	source.queue_a_media_source_task(fn [active_buffers] () {
		active_buffers.dispatch_event(dom.Event.create('removesourcebuffer', dom.EventInit{}))
	})
	mut source_buffers := source.source_buffers_
	source_buffers.remove_all_buffers()
	source.queue_a_media_source_task(fn [source_buffers] () {
		source_buffers.dispatch_event(dom.Event.create('removesourcebuffer', dom.EventInit{}))
	})
	source.queue_a_media_source_task(fn [source] () {
		source.dispatch_event(dom.Event.create('sourceclose', dom.EventInit{}))
	})
	source.media_element_assigned_to_ = none
}

fn detach_media_source_provider(source_handle voidptr, media_element_handle voidptr) {
	mut source := unsafe { &MediaSource(source_handle) }
	assigned := source.media_element_assigned_to_ or { return }
	if voidptr(assigned) != media_element_handle {
		return
	}
	source.detach_from_media_element()
}

fn attach_media_source_provider(source_handle voidptr, media_element_handle voidptr) ! {
	mut source := unsafe { &MediaSource(source_handle) }
	if !source.ready_state_is_closed() {
		return error('MediaSource is not closed')
	}
	mut media_element := unsafe { &html.HTMLMediaElement(media_element_handle) }
	source.has_ever_been_attached_ = true
	media_element.media_source_attachment_did_open(source_handle, detach_media_source_provider)
	source.media_element_assigned_to_ = media_element
	source.set_ready_state_to_open_and_fire_sourceopen_event()
}

pub fn (source &MediaSource) as_media_provider() html.MediaProviderObject {
	return html.MediaProviderObject.from_media_source(voidptr(source), attach_media_source_provider)
}

pub fn (source &MediaSource) blob_url_object(id string) fileapi.BlobURLObject {
	return fileapi.BlobURLObject.from_media_source_object(id, voidptr(source), attach_media_source_provider)
}

pub fn MediaSource.can_construct_in_dedicated_worker() bool {
	return false
}

pub fn MediaSource.is_type_supported(value string) bool {
	if value.len == 0 {
		return false
	}
	mime_type := mimesniff.MimeType.parse(value) or { return false }
	if mime_type.type_() !in ['video', 'audio'] || mime_type.subtype() != 'webm' {
		return false
	}
	parameters := mime_type.parameters()
	codecs := parameters['codecs'] or { return false }
	for codec in codecs.split(',') {
		if !codec.starts_with('vp9') && !codec.starts_with('vp09') && !codec.starts_with('opus') {
			return false
		}
	}
	return true
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
