// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SourceBuffer.cpp, SourceBufferList.cpp, and
// ManagedSourceBuffer.cpp plus their headers and IDL.
module mediasourceextensions

import dom
import html
import math
import mimesniff

fn media_track_kind_to_text_track_kind(kind MediaSourceTrackKind) html.TextTrackKind {
	return match kind {
		.captions { .captions }
		.descriptions { .descriptions }
		.subtitles { .subtitles }
		else { .metadata }
	}
}

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
	content_type_ string
	audio_tracks_ &html.AudioTrackList = unsafe { nil }
	video_tracks_ &html.VideoTrackList = unsafe { nil }
	text_tracks_  &html.TextTrackList = unsafe { nil }
	range_removal_running_ bool
	append_generation_     u64
}

// SourceBuffer has no exposed constructor, but MediaSource implementations
// need an internal factory for the translated platform type.
pub fn SourceBuffer.create_internal() &SourceBuffer {
	return &SourceBuffer{
		EventTarget: dom.EventTarget{}
		processor_: SourceBufferProcessor.create()
		audio_tracks_: &html.AudioTrackList{}
		video_tracks_: &html.VideoTrackList{}
		text_tracks_: &html.TextTrackList{}
	}
}

pub fn SourceBuffer.create_internal_for_media_source(media_source &MediaSource) &SourceBuffer {
	return &SourceBuffer{
		EventTarget: dom.EventTarget{}
		media_source_: media_source
		processor_: SourceBufferProcessor.create()
		audio_tracks_: &html.AudioTrackList{}
		video_tracks_: &html.VideoTrackList{}
		text_tracks_: &html.TextTrackList{}
	}
}

pub fn (buffer &SourceBuffer) relevant_global_impl() ?&dom.EventTarget {
	media_source := buffer.media_source_ or { return none }
	return media_source.relevant_global_impl()
}

pub fn (mut buffer SourceBuffer) set_content_type(type_ string) ! {
	mime_type := mimesniff.MimeType.parse(type_) or { return error('Invalid media MIME type') }
	buffer.content_type_ = type_
	match mime_type.subtype() {
		'webm' { buffer.processor_.set_webm_parser() }
		'mp4' { buffer.processor_.set_isobmff_parser() }
		else { return error('Unsupported media byte-stream format') }
	}
}

pub fn (buffer &SourceBuffer) mode() AppendMode {
	return buffer.processor_.mode()
}

pub fn (buffer &SourceBuffer) timestamp_offset() f64 {
	return buffer.processor_.timestamp_offset()
}

pub fn (mut buffer SourceBuffer) set_timestamp_offset(value f64) ! {
	mut media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	if buffer.updating() {
		return error('InvalidStateError: SourceBuffer is updating')
	}
	if media_source.ready_state() == .ended {
		media_source.set_ready_state_to_open_and_fire_sourceopen_event()
	}
	if buffer.processor_.is_parsing_media_segment() {
		return error('InvalidStateError: Cannot set timestampOffset while parsing a media segment')
	}
	if buffer.processor_.mode() == .sequence {
		buffer.processor_.set_group_start_timestamp(value)
	}
	buffer.processor_.set_timestamp_offset(value)
}

pub fn (mut buffer SourceBuffer) set_mode(mode AppendMode) ! {
	mut media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	if buffer.updating() {
		return error('InvalidStateError: SourceBuffer is updating')
	}
	if buffer.processor_.generate_timestamps_flag() && mode == .segments {
		return error("TypeError: Cannot set mode to 'segments' when generate timestamps flag is true")
	}
	if media_source.ready_state() == .ended {
		media_source.set_ready_state_to_open_and_fire_sourceopen_event()
	}
	if buffer.processor_.is_parsing_media_segment() {
		return error('InvalidStateError: Cannot change mode while parsing a media segment')
	}
	if mode == .sequence {
		buffer.processor_.set_group_start_timestamp(buffer.processor_.group_end_timestamp())
	}
	buffer.processor_.set_mode(mode)
}

pub fn (mut buffer SourceBuffer) change_type(type_ string) ! {
	if type_.len == 0 {
		return error('TypeError: Type cannot be empty')
	}
	mut media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	if buffer.updating() {
		return error('InvalidStateError: SourceBuffer is updating')
	}
	if !MediaSource.is_type_supported(type_) {
		return error('NotSupportedError: Type is not supported')
	}
	if media_source.ready_state() == .ended {
		media_source.set_ready_state_to_open_and_fire_sourceopen_event()
	}
	buffer.processor_.reset_parser_state()
	buffer.set_content_type(type_)!
	buffer.processor_.set_generate_timestamps_flag(false)
	if buffer.processor_.generate_timestamps_flag() {
		buffer.set_mode(.sequence)!
	}
	buffer.processor_.set_pending_initialization_segment_for_change_type_flag(true)
}

pub fn (buffer &SourceBuffer) audio_tracks() &html.AudioTrackList {
	return buffer.audio_tracks_
}

pub fn (buffer &SourceBuffer) video_tracks() &html.VideoTrackList {
	return buffer.video_tracks_
}

pub fn (buffer &SourceBuffer) text_tracks() &html.TextTrackList {
	return buffer.text_tracks_
}

pub fn (buffer &SourceBuffer) updating() bool {
	return buffer.processor_.updating()
}

// https://w3c.github.io/media-source/#dom-sourcebuffer-buffered
pub fn (buffer &SourceBuffer) buffered() !&html.TimeRanges {
	media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	mut ranges := &html.TimeRanges{}
	for range_ in buffer.processor_.buffered_time_ranges() {
		ranges.add_range(range_.start, range_.end)
	}
	return ranges
}

pub fn (buffer &SourceBuffer) input_buffer_length() int {
	return buffer.processor_.input_buffer_length()
}

// https://w3c.github.io/media-source/#sourcebuffer-prepare-append
fn (mut buffer SourceBuffer) prepare_append(new_data_size int) ! {
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
	buffer.processor_.run_coded_frame_eviction(new_data_size, media_element.current_time())
	if buffer.processor_.is_buffer_full() {
		return error('QuotaExceededError: Buffer is full')
	}
}

// SourceBuffer.cpp captures this for every queued event. Capturing the
// mutable V receiver by value would dispatch from a different EventTarget.
fn (buffer &SourceBuffer) queue_buffer_event(media_source &MediaSource, name string) {
	buffer_handle := voidptr(buffer)
	media_source.queue_a_media_source_task(fn [buffer_handle, media_source, name] () {
		actual := unsafe { &SourceBuffer(buffer_handle) }
		actual.dispatch_event(media_source.create_associated_event(name))
	})
}

// https://w3c.github.io/media-source/#dom-sourcebuffer-appendbuffer
pub fn (mut buffer SourceBuffer) append_buffer(data []u8) ! {
	buffer.prepare_append(data.len)!
	buffer.processor_.append_to_input_buffer(data)
	buffer.processor_.set_updating(true)
	media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	buffer.queue_buffer_event(media_source, 'updatestart')
	append_generation := buffer.append_generation_
	media_source.queue_a_media_source_task(fn [mut buffer, append_generation] () {
		buffer.run_buffer_append_algorithm(append_generation)
	})
}

fn (mut buffer SourceBuffer) abort_buffer_append_algorithm() {
	buffer.append_generation_++
}

pub fn (mut buffer SourceBuffer) abort_if_updating() {
	if !buffer.updating() {
		return
	}
	buffer.abort_buffer_append_algorithm()
	buffer.processor_.set_updating(false)
	media_source := buffer.media_source_ or { return }
	buffer.queue_buffer_event(media_source, 'abort')
	buffer.queue_buffer_event(media_source, 'updateend')
}

// https://w3c.github.io/media-source/#dom-sourcebuffer-abort
pub fn (mut buffer SourceBuffer) abort() ! {
	media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	if media_source.ready_state() != .open {
		return error('InvalidStateError: MediaSource is not open')
	}
	if buffer.range_removal_running_ {
		return error('InvalidStateError: SourceBuffer is removing a range')
	}
	if buffer.updating() {
		buffer.abort_buffer_append_algorithm()
		buffer.processor_.set_updating(false)
		buffer.queue_buffer_event(media_source, 'abort')
		buffer.queue_buffer_event(media_source, 'updateend')
	}
	buffer.processor_.reset_parser_state()
}

// https://w3c.github.io/media-source/#dom-sourcebuffer-remove
pub fn (mut buffer SourceBuffer) remove(start f64, end f64) ! {
	mut media_source := buffer.media_source_ or {
		return error('InvalidStateError: SourceBuffer has no MediaSource')
	}
	if !media_source.source_buffers().contains(buffer) {
		return error('InvalidStateError: SourceBuffer has been removed')
	}
	if buffer.updating() {
		return error('InvalidStateError: SourceBuffer is updating')
	}
	duration := media_source.duration()
	if math.is_nan(duration) {
		return error('TypeError: MediaSource duration is NaN')
	}
	if start < 0 || start > duration {
		return error('TypeError: Removal range start is outside of the duration')
	}
	if end <= start || math.is_nan(end) {
		return error('TypeError: Removal range end does not follow its start')
	}
	if media_source.ready_state() == .ended {
		media_source.set_ready_state_to_open_and_fire_sourceopen_event()
	}
	buffer.run_range_removal(start, end)
}

// https://w3c.github.io/media-source/#sourcebuffer-range-removal
fn (mut buffer SourceBuffer) run_range_removal(start f64, end f64) {
	buffer.range_removal_running_ = true
	buffer.processor_.set_updating(true)
	media_source := buffer.media_source_ or {
		buffer.range_removal_running_ = false
		buffer.processor_.set_updating(false)
		return
	}
	buffer.queue_buffer_event(media_source, 'updatestart')
	media_source.queue_a_media_source_task(fn [mut buffer, start, end] () {
		media_source := buffer.media_source_ or {
			buffer.range_removal_running_ = false
			buffer.processor_.set_updating(false)
			return
		}
		if !media_source.source_buffers().contains(buffer) {
			buffer.range_removal_running_ = false
			return
		}
		buffer.processor_.run_coded_frame_removal(start, end)
		if mut media_element := media_source.media_element_assigned_to() {
			mut ranges := []html.MediaBufferedRange{}
			for range_ in buffer.processor_.buffered_time_ranges() {
				ranges << html.MediaBufferedRange{ start: range_.start, end: range_.end }
			}
			media_element.media_source_update_buffered_ranges_after_removal(ranges)
		}
		buffer.range_removal_running_ = false
		buffer.processor_.set_updating(false)
		buffer.queue_buffer_event(media_source, 'update')
		buffer.queue_buffer_event(media_source, 'updateend')
	})
}

fn (mut buffer SourceBuffer) run_buffer_append_algorithm(append_generation u64) {
	if append_generation != buffer.append_generation_ {
		return
	}
	result := buffer.processor_.run_segment_parser_loop()
	if !result.succeeded {
		buffer.run_append_error_algorithm()
		return
	}
	if result.first_initialization_segment {
		buffer.on_first_initialization_segment_processed(result.duration, result.tracks)
	}
	if result.processed_coded_frames {
		buffer.update_ready_state_and_duration_after_coded_frame_processing()
	}
	buffer.finish_buffer_append()
}

// https://w3c.github.io/media-source/#sourcebuffer-append-error
fn (mut buffer SourceBuffer) run_append_error_algorithm() {
	buffer.processor_.reset_parser_state()
	buffer.processor_.set_updating(false)
	media_source := buffer.media_source_ or { return }
	buffer.queue_buffer_event(media_source, 'error')
	buffer.queue_buffer_event(media_source, 'updateend')
	mut mutable_media_source := unsafe { media_source }
	mutable_media_source.run_end_of_stream_algorithm(.decode)
}

fn (mut buffer SourceBuffer) on_first_initialization_segment_processed(duration ?f64, tracks []WebMTrackInfo) {
	mut media_source := buffer.media_source_ or { return }
	if math.is_nan(media_source.duration()) {
		media_source.run_duration_change_algorithm(duration or { math.inf(1) })
	}
	mut media_element := media_source.media_element_assigned_to() or { return }
	mut has_active_track := false
	for track in tracks {
		track_buffer := buffer.processor_.track_buffers()[track.number] or { continue }
		metadata := html.MediaTrackMetadata{
			identifier: media_source.next_track_id()
			name: track.label
			parsed_bcp47_language: if track.language == '' { none } else { track.language }
			playback_track_handle: voidptr(track_buffer.demuxer)
			kind: track.kind.name()
		}
		match track.type_ {
			.audio {
				audio_track := media_element.on_audio_track_added(metadata)
				mut list := buffer.audio_tracks_
				list.add_track(audio_track)
				has_active_track = true
			}
			.video {
				video_track := media_element.on_video_track_added(metadata)
				mut list := buffer.video_tracks_
				list.add_track(video_track)
				has_active_track = true
			}
			.text {
				mut text_track := html.TextTrack.create()
				text_track.set_id(metadata.identifier.str())
				text_track.set_language(track.language)
				text_track.set_label(track.label)
				text_track.set_kind(media_track_kind_to_text_track_kind(track.kind))
				mut source_list := buffer.text_tracks_
				source_list.add_track(text_track)
				mut element_list := media_element.text_tracks()
				element_list.add_track(text_track)
			}
		}
	}
	if has_active_track {
		mut active_buffers := media_source.active_source_buffers()
		active_buffers.append(buffer)
		// The pinned Source queues this notification in addition to append's task.
		source_handle := voidptr(media_source)
		list_handle := voidptr(active_buffers)
		media_source.queue_a_media_source_task(fn [source_handle, list_handle] () {
			source := unsafe { &MediaSource(source_handle) }
			list := unsafe { &SourceBufferList(list_handle) }
			list.dispatch_event(source.create_associated_event('addsourcebuffer'))
		})
	}
	media_element.media_source_initialization_segment_received(media_source.duration())
}

fn (mut buffer SourceBuffer) finish_buffer_append() {
	buffer.processor_.set_updating(false)
	media_source := buffer.media_source_ or { return }
	buffer.queue_buffer_event(media_source, 'update')
	buffer.queue_buffer_event(media_source, 'updateend')
}

fn (mut buffer SourceBuffer) update_ready_state_and_duration_after_coded_frame_processing() {
	media_source := buffer.media_source_ or { return }
	mut media_element := media_source.media_element_assigned_to() or { return }
	mut ranges := []html.MediaBufferedRange{}
	for range_ in buffer.processor_.buffered_time_ranges() {
		ranges << html.MediaBufferedRange{ start: range_.start, end: range_.end }
	}
	media_element.media_source_update_buffered_ranges(ranges)
}

pub fn (mut buffer SourceBuffer) set_reached_end_of_stream() {
	buffer.processor_.set_reached_end_of_stream()
}

pub fn (mut buffer SourceBuffer) clear_reached_end_of_stream() {
	buffer.processor_.clear_reached_end_of_stream()
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
	buffers_      []&SourceBuffer
	media_source_ ?&MediaSource
}

pub fn SourceBufferList.create_internal() &SourceBufferList {
	return &SourceBufferList{
		EventTarget: dom.EventTarget{}
	}
}

fn (mut list SourceBufferList) set_media_source(media_source &MediaSource) {
	list.media_source_ = media_source
}

pub fn (list &SourceBufferList) relevant_global_impl() ?&dom.EventTarget {
	media_source := list.media_source_ or { return none }
	return media_source.relevant_global_impl()
}

pub fn (mut list SourceBufferList) append(buffer &SourceBuffer) {
	list.buffers_ << buffer
	list_handle := voidptr(&list)
	// SourceBufferList.cpp explicitly uses an unspecified task with no Document.
	html.queue_a_task(.unspecified, html.main_thread_event_loop(), none, fn [list_handle] () {
		actual := unsafe { &SourceBufferList(list_handle) }
		if source := actual.media_source_ {
			actual.dispatch_event(source.create_associated_event('addsourcebuffer'))
			return
		}
		// Preserve the existing internal standalone-list adapter.
		actual.dispatch_event(dom.Event.create('addsourcebuffer', dom.EventInit{}))
	})
}

pub fn (mut list SourceBufferList) remove_all_buffers() {
	list.buffers_.clear()
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
