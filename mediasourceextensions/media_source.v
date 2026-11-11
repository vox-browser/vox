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
	relevant_global_object_    ?&dom.EventTarget
	duration_                  f64 = math.nan()
	next_track_id_             i64 = 1
}

pub fn MediaSource.create() &MediaSource {
	mut source := &MediaSource{
		EventTarget: dom.EventTarget{}
		source_buffers_: SourceBufferList.create_internal()
		active_source_buffers_: SourceBufferList.create_internal()
	}
	mut source_buffers := source.source_buffers_
	source_buffers.set_media_source(source)
	mut active_source_buffers := source.active_source_buffers_
	active_source_buffers.set_media_source(source)
	return source
}

pub fn MediaSource.construct_impl() !&MediaSource {
	return MediaSource.create()
}

pub fn MediaSource.create_for_constructor(relevant_global_object &dom.EventTarget) &MediaSource {
	mut source := MediaSource.create()
	source.relevant_global_object_ = relevant_global_object
	return source
}

pub fn (source &MediaSource) relevant_global_impl() &dom.EventTarget {
	return source.relevant_global_object_ or { &source.EventTarget }
}

pub fn (source &MediaSource) relevant_global_object() &dom.EventTarget {
	return source.relevant_global_impl()
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

pub fn (mut source MediaSource) set_has_ever_been_attached() {
	source.has_ever_been_attached_ = true
}

pub fn (mut source MediaSource) set_assigned_to_media_element(media_element &html.HTMLMediaElement) {
	source.media_element_assigned_to_ = media_element
}

pub fn (source &MediaSource) create_associated_event(event_name string) &dom.Event {
	_ = source
	return dom.Event.create(event_name, dom.EventInit{})
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
	source.run_duration_change_algorithm(duration)!
}

pub fn (mut source MediaSource) run_duration_change_algorithm(duration f64) ! {
	if source.duration_ == duration { return }
	mut highest_presentation_timestamp := f64(0)
	mut highest_end_time := f64(0)
	for index in 0 .. source.source_buffers_.length() {
		buffer := source.source_buffers_.item(index) or { continue }
		start := buffer.highest_presentation_timestamp()
		end := buffer.highest_end_time()
		if start > highest_presentation_timestamp { highest_presentation_timestamp = start }
		if end > highest_end_time { highest_end_time = end }
	}
	if duration < highest_presentation_timestamp {
		return error('InvalidStateError: Duration would truncate buffered coded frames')
	}
	source.assign_duration_change(math.max(duration, highest_end_time))
}

pub fn (mut source MediaSource) assign_duration_change(duration f64) {
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
	source_handle := voidptr(&source)
	source.queue_a_media_source_task(fn [source_handle] () {
		source := unsafe { &MediaSource(source_handle) }
		source.dispatch_event(source.create_associated_event('sourceended'))
	})
	for index in 0 .. source.source_buffers_.length() {
		if mut buffer := source.source_buffers_.item(index) {
			buffer.set_reached_end_of_stream()
		}
	}
	if error_ == none {
		mut highest_end_time := f64(0)
		for index in 0 .. source.source_buffers_.length() {
			buffer := source.source_buffers_.item(index) or { continue }
			end := buffer.highest_end_time()
			if end > highest_end_time { highest_end_time = end }
		}
		source.assign_duration_change(highest_end_time)
	}
	// FIXME: Signal completion and decode/network errors to the media element.
}

pub fn (source &MediaSource) queue_a_media_source_task(task fn ()) {
	// FIXME: The MSE spec does not say what task source to use for its tasks. Should this use the media element's
	//        task source? We may not have access to it if we're in a worker.
	mut document := ?&dom.Document(none)
	if media_element := source.media_element_assigned_to() {
		document = media_element.document()
	}
	html.queue_a_task(.unspecified, html.main_thread_event_loop(), document, task)
}

pub fn (mut source MediaSource) set_ready_state_to_open_and_fire_sourceopen_event() {
	source.ready_state_ = .open
	for index in 0 .. source.source_buffers_.length() {
		if mut buffer := source.source_buffers_.item(index) {
			buffer.clear_reached_end_of_stream()
		}
	}
	source_handle := voidptr(&source)
	source.queue_a_media_source_task(fn [source_handle] () {
		source := unsafe { &MediaSource(source_handle) }
		source.dispatch_event(source.create_associated_event('sourceopen'))
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
	source_handle := voidptr(&source)
	source.queue_a_media_source_task(fn [source_handle] () {
		source := unsafe { &MediaSource(source_handle) }
		source.dispatch_event(source.create_associated_event('sourceclose'))
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
	source.set_has_ever_been_attached()
	media_element.media_source_attachment_did_open(source_handle, detach_media_source_provider)
	source.set_assigned_to_media_element(media_element)
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

enum MediaSourceCodecID {
	vp8
	vp9
	h264
	h265
	mp3
	aac
	av1
	theora
	vorbis
	opus
	flac
}

fn media_source_string_is_decimal(value string, width int) bool {
	if value.len != width {
		return false
	}
	for byte in value.bytes() {
		if byte < `0` || byte > `9` {
			return false
		}
	}
	return true
}

fn media_source_string_is_hexadecimal(value string, width int) bool {
	if value.len != width {
		return false
	}
	for byte in value.bytes() {
		if !((byte >= `0` && byte <= `9`) || (byte >= `a` && byte <= `f`)
			|| (byte >= `A` && byte <= `F`)) {
			return false
		}
	}
	return true
}

fn media_source_cicp_is_valid(color_primaries int, transfer_characteristics int, matrix_coefficients int) bool {
	return color_primaries in [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 22]
		&& transfer_characteristics in [1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14,
		15, 16, 17, 18]
		&& matrix_coefficients in [0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]
}

fn media_source_profile_accepts_color_config(codec MediaSourceCodecID, profile int, bit_depth int, subsampling int) bool {
	if codec == .vp9 {
		return match profile {
			0 { bit_depth == 8 && subsampling == 420 }
			1 { bit_depth == 8 && subsampling in [422, 444] }
			2 { bit_depth in [10, 12] && subsampling == 420 }
			3 { bit_depth in [10, 12] && subsampling in [422, 444] }
			else { false }
		}
	}
	return match profile {
		0 { bit_depth in [8, 10] && subsampling == 420 }
		1 { bit_depth in [8, 10] && subsampling == 444 }
		2 {
			if bit_depth == 12 {
				subsampling in [420, 422, 444]
			} else {
				bit_depth in [8, 10] && subsampling == 422
			}
		}
		else { false }
	}
}

fn parse_media_source_vp9_codec(value string) ?MediaSourceCodecID {
	if value in ['vp9', 'vp9.0'] {
		return .vp9
	}
	parts := value.split('.')
	if parts.len !in [4, 9] || parts[0] != 'vp09' {
		return none
	}
	for part in parts[1..] {
		if !media_source_string_is_decimal(part, 2) {
			return none
		}
	}
	profile := parts[1].int()
	level := parts[2].int()
	bit_depth := parts[3].int()
	if profile > 3
		|| level !in [0, 10, 11, 20, 21, 30, 31, 40, 41, 50, 51, 52, 60, 61, 62]
		|| bit_depth !in [8, 10, 12] {
		return none
	}
	mut subsampling := 420
	if parts.len == 9 {
		subsampling = match parts[4].int() {
			0, 1 { 420 }
			2 { 422 }
			3 { 444 }
			else { return none }
		}
		color_primaries := parts[5].int()
		transfer_characteristics := parts[6].int()
		matrix_coefficients := parts[7].int()
		if !media_source_cicp_is_valid(color_primaries, transfer_characteristics,
			matrix_coefficients) || parts[8].int() > 1 {
			return none
		}
		if matrix_coefficients == 0 && subsampling != 444 {
			return none
		}
	}
	if !media_source_profile_accepts_color_config(.vp9, profile, bit_depth, subsampling) {
		return none
	}
	return .vp9
}

fn parse_media_source_av1_codec(value string) ?MediaSourceCodecID {
	parts := value.split('.')
	if parts.len !in [4, 10] || parts[0] != 'av01'
		|| !media_source_string_is_decimal(parts[1], 1)
		|| parts[2].len != 3 || !media_source_string_is_decimal(parts[2][..2], 2)
		|| parts[2][2] !in [`M`, `H`]
		|| !media_source_string_is_decimal(parts[3], 2) {
		return none
	}
	profile := parts[1].int()
	level := parts[2][..2].int()
	tier := parts[2][2]
	bit_depth := parts[3].int()
	if profile > 2 || (level > 23 && level != 31) || (tier == `H` && level < 8)
		|| bit_depth !in [8, 10, 12] {
		return none
	}
	mut monochrome := false
	mut subsampling := 420
	mut chroma_sample_position := 0
	mut matrix_coefficients := 1
	mut video_full_range := 0
	if parts.len == 10 {
		if !media_source_string_is_decimal(parts[4], 1) || parts[4].int() > 1
			|| !media_source_string_is_decimal(parts[5], 3)
			|| parts[5][0] !in [`0`, `1`] || parts[5][1] !in [`0`, `1`]
			|| parts[5][2] < `0` || parts[5][2] > `2`
			|| !media_source_string_is_decimal(parts[6], 2)
			|| !media_source_string_is_decimal(parts[7], 2)
			|| !media_source_string_is_decimal(parts[8], 2)
			|| !media_source_string_is_decimal(parts[9], 1) || parts[9].int() > 1 {
			return none
		}
		monochrome = parts[4].int() == 1
		subsampling = match parts[5][..2] {
			'11' { 420 }
			'10' { 422 }
			'00' { 444 }
			else { return none }
		}
		chroma_sample_position = int(parts[5][2] - `0`)
		color_primaries := parts[6].int()
		transfer_characteristics := parts[7].int()
		matrix_coefficients = parts[8].int()
		video_full_range = parts[9].int()
		if !media_source_cicp_is_valid(color_primaries, transfer_characteristics,
			matrix_coefficients) {
			return none
		}
	}
	if !media_source_profile_accepts_color_config(.av1, profile, bit_depth, subsampling)
		|| (chroma_sample_position != 0 && subsampling != 420)
		|| (monochrome && (profile == 1 || subsampling != 420 || chroma_sample_position != 0))
		|| (matrix_coefficients == 0 && (subsampling != 444 || video_full_range != 1)) {
		return none
	}
	return .av1
}

fn parse_media_source_h265_codec(value string) ?MediaSourceCodecID {
	parts := value.split('.')
	if parts.len < 4 || parts.len > 10 || parts[0] !in ['hev1', 'hvc1'] {
		return none
	}
	mut profile := parts[1]
	if profile.len > 0 && profile[0] in [`A`, `B`, `C`] {
		profile = profile[1..]
	}
	if profile.len == 0 || profile.len > 2 || !media_source_string_is_decimal(profile,
		profile.len) || profile.int() > 31 {
		return none
	}
	if parts[2].len == 0 || parts[2].len > 8
		|| !media_source_string_is_hexadecimal(parts[2], parts[2].len) {
		return none
	}
	tier_and_level := parts[3]
	if tier_and_level.len < 2 || tier_and_level[0] !in [`L`, `H`]
		|| tier_and_level.len > 4
		|| !media_source_string_is_decimal(tier_and_level[1..], tier_and_level.len - 1)
		|| tier_and_level[1..].int() > 255 {
		return none
	}
	for constraint in parts[4..] {
		if constraint.len == 0 || constraint.len > 2
			|| !media_source_string_is_hexadecimal(constraint, constraint.len) {
			return none
		}
	}
	return .h265
}

fn parse_media_source_codec(value string) ?MediaSourceCodecID {
	if value in ['vp8', 'vp8.0'] {
		return .vp8
	}
	if value.starts_with('vp9') || value.starts_with('vp09') {
		return parse_media_source_vp9_codec(value)
	}
	if value.starts_with('av01') {
		return parse_media_source_av1_codec(value)
	}
	if value.starts_with('avc1') || value.starts_with('avc3') {
		if value.len == 11 && media_source_string_is_hexadecimal(value[5..], 6) {
			return .h264
		}
		return none
	}
	if value.starts_with('hev1') || value.starts_with('hvc1') {
		return parse_media_source_h265_codec(value)
	}
	if value.starts_with('mp4a') {
		parts := value.split('.')
		if parts.len < 2 || parts.len > 3 || !media_source_string_is_hexadecimal(parts[1],
			2) {
			return none
		}
		object_type := parts[1].to_upper()
		if object_type == '40' {
			if parts.len != 3 || parts[2].len == 0
				|| !media_source_string_is_decimal(parts[2], parts[2].len)
				|| parts[2].int() !in [2, 5, 29] {
				return none
			}
			return .aac
		}
		if parts.len != 2 {
			return none
		}
		if object_type in ['66', '67', '68'] {
			return .aac
		}
		if object_type in ['69', '6B'] {
			return .mp3
		}
		return none
	}
	return match value {
		'theora' { MediaSourceCodecID.theora }
		'vorbis' { MediaSourceCodecID.vorbis }
		'opus', 'Opus' { MediaSourceCodecID.opus }
		'flac', 'fLaC' { MediaSourceCodecID.flac }
		else { none }
	}
}

fn media_source_container_supports_codec(subtype string, codec_string string, codec MediaSourceCodecID) bool {
	if subtype == 'webm' {
		return codec in [.vp8, .vp9, .av1, .vorbis, .opus]
	}
	if subtype != 'mp4' {
		return false
	}
	if codec == .vp8 {
		return false
	}
	if codec == .vp9 {
		return codec_string.starts_with('vp09')
	}
	if codec == .mp3 {
		return codec_string.starts_with('mp4a.')
	}
	return codec in [.h264, .h265, .aac, .av1, .opus, .flac]
}

fn media_source_codec_is_video(codec MediaSourceCodecID) bool {
	return codec in [.vp8, .vp9, .h264, .h265, .av1, .theora]
}

fn media_source_type_is_supported(value string) bool {
	if value.len == 0 {
		return false
	}
	mime_type := mimesniff.MimeType.parse(value) or { return false }
	if mime_type.type_() !in ['video', 'audio'] || mime_type.subtype() !in ['webm', 'mp4'] {
		return false
	}
	parameters := mime_type.parameters()
	codecs := parameters['codecs'] or { return false }
	for untrimmed_codec in codecs.split(',') {
		codec_string := untrimmed_codec.trim_space()
		codec := parse_media_source_codec(codec_string) or { return false }
		if mime_type.type_() == 'audio' && media_source_codec_is_video(codec) {
			return false
		}
		if !media_source_container_supports_codec(mime_type.subtype(), codec_string, codec) {
			return false
		}
	}
	return true
}

pub struct MediaSourceDecoderCapabilities {
pub:
	smooth          bool
	power_efficient bool
}

// decoder_capabilities_for_type is the shared support query used by
// MediaSource.isTypeSupported() and the Media Capabilities API.
pub fn MediaSource.decoder_capabilities_for_type(value string) ?MediaSourceDecoderCapabilities {
	if !media_source_type_is_supported(value) {
		return none
	}
	return MediaSourceDecoderCapabilities{
		smooth: true
		power_efficient: false
	}
}

pub fn MediaSource.is_type_supported(value string) bool {
	MediaSource.decoder_capabilities_for_type(value) or { return false }
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
