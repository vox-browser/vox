// Copyright (c) 2020, the SerenityOS developers
// Copyright (c) 2023-2026, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLMediaElement.{h,cpp}. Decoder/network integration is
// supplied by MediaResourceFetchHook; the HTML state machine remains local.
module html

import dom
import math

pub enum MediaSeekMode {
	accurate
	approximate_for_speed
}

pub enum MediaNetworkState {
	empty
	idle
	loading
	no_source
}

pub enum MediaReadyState {
	have_nothing
	have_metadata
	have_current_data
	have_future_data
	have_enough_data
}

pub enum CanPlayTypeResult {
	empty
	maybe
	probably
}

pub enum MediaFetchingStatus {
	ongoing
	complete
	interrupted
}

pub struct MediaResourceResponse {
pub:
	status       u16 = 200
	mime_type    string
	duration     f64 = math.nan()
	total_length u64
	buffered_end f64
	audio_tracks []MediaTrackMetadata
	video_tracks []MediaTrackMetadata
}

pub type MediaResourceFetchHook = fn (dom.URL, u64) !MediaResourceResponse

fn media_element_noop_change_task() {}

fn media_element_noop_audio_enabled(track &AudioTrack, enabled bool) {
	_ = track
	_ = enabled
}

fn media_element_noop_video_selected(track ?&VideoTrack) {
	_ = track
}

@[heap]
pub struct HTMLMediaElement {
	dom.EventTarget
mut:
	event_target_               &dom.EventTarget = unsafe { nil }
	associated_element_         ?&dom.HTMLElement
	base_url_                   dom.URL = dom.url_about_blank()
	error_                      ?&MediaError
	crossorigin_                CORSSettingAttribute
	current_src_                string
	source_                     ?string
	source_candidates_          []string
	network_state_              MediaNetworkState
	ready_state_                MediaReadyState
	seeking_                    bool
	current_playback_position_  f64
	official_playback_position_ f64
	default_playback_start_     f64
	show_poster_                bool = true
	duration_                   f64  = math.nan()
	pending_play_promises_      []&dom.Promise
	paused_                     bool = true
	ended_                      bool
	default_playback_rate_      f64 = 1.0
	playback_rate_              f64 = 1.0
	volume_                     f64 = 1.0
	muted_                      bool
	page_muted_                 bool
	audio_tracks_               &AudioTrackList = unsafe { nil }
	video_tracks_               &VideoTrackList = unsafe { nil }
	text_tracks_                &TextTrackList  = unsafe { nil }
	can_autoplay_               bool            = true
	loop_                       bool
	autoplay_                   bool
	controls_                   bool
	fetch_hook_                 ?MediaResourceFetchHook
	fetch_generation_           u32
	buffered_                   &TimeRanges = unsafe { nil }
	played_                     &TimeRanges = unsafe { nil }
	seekable_                   &TimeRanges = unsafe { nil }
	play_range_start_           ?f64
	event_counts_               map[string]int
}

pub fn HTMLMediaElement.create(element ?&dom.HTMLElement, base_url dom.URL) &HTMLMediaElement {
	return &HTMLMediaElement{
		EventTarget:         dom.EventTarget{}
		event_target_:       dom.EventTarget.new()
		associated_element_: element
		base_url_:           base_url
		audio_tracks_:       &AudioTrackList{}
		video_tracks_:       &VideoTrackList{}
		text_tracks_:        &TextTrackList{}
		buffered_:           &TimeRanges{}
		played_:             &TimeRanges{}
		seekable_:           &TimeRanges{}
	}
}

pub fn (element &HTMLMediaElement) error() ?&MediaError {
	return element.error_
}

pub fn (element &HTMLMediaElement) current_src() string {
	return element.current_src_
}

pub fn (element &HTMLMediaElement) network_state() MediaNetworkState {
	return element.network_state_
}

pub fn (element &HTMLMediaElement) ready_state() MediaReadyState {
	return element.ready_state_
}

pub fn (element &HTMLMediaElement) seeking() bool {
	return element.seeking_
}

pub fn (element &HTMLMediaElement) paused() bool {
	return element.paused_
}

pub fn (element &HTMLMediaElement) show_poster() bool {
	return element.show_poster_
}

pub fn (element &HTMLMediaElement) duration() f64 {
	return element.duration_
}

pub fn (element &HTMLMediaElement) volume() f64 {
	return element.volume_
}

pub fn (element &HTMLMediaElement) muted() bool {
	return element.muted_
}

pub fn (element &HTMLMediaElement) default_playback_rate() f64 {
	return element.default_playback_rate_
}

pub fn (element &HTMLMediaElement) playback_rate() f64 {
	return element.playback_rate_
}

pub fn (element &HTMLMediaElement) crossorigin() CORSSettingAttribute {
	return element.crossorigin_
}

pub fn (element &HTMLMediaElement) audio_tracks() &AudioTrackList {
	return element.audio_tracks_
}

pub fn (element &HTMLMediaElement) video_tracks() &VideoTrackList {
	return element.video_tracks_
}

pub fn (element &HTMLMediaElement) text_tracks() &TextTrackList {
	return element.text_tracks_
}

pub fn (element &HTMLMediaElement) buffered() &TimeRanges {
	return element.buffered_.clone()
}

pub fn (element &HTMLMediaElement) played() &TimeRanges {
	return element.played_.clone()
}

pub fn (element &HTMLMediaElement) seekable() &TimeRanges {
	return element.seekable_.clone()
}

pub fn (mut element HTMLMediaElement) set_fetch_hook(hook ?MediaResourceFetchHook) {
	element.fetch_hook_ = hook
}

pub fn (mut element HTMLMediaElement) set_source(source ?string) {
	element.source_ = source
}

pub fn (mut element HTMLMediaElement) set_source_candidates(candidates []string) {
	element.source_candidates_ = candidates.clone()
}

pub fn (mut element HTMLMediaElement) set_crossorigin(value ?string) {
	element.crossorigin_ = cors_setting_attribute_from_keyword(value)
}

pub fn (mut element HTMLMediaElement) set_loop(value bool) {
	element.loop_ = value
}

pub fn (mut element HTMLMediaElement) set_autoplay(value bool) {
	element.autoplay_ = value
}

fn (mut element HTMLMediaElement) fire_event(name string) {
	element.event_counts_[name]++
	event := dom.Event.create(name, dom.EventInit{})
	element.event_target_.dispatch_event(event)
}

pub fn (element &HTMLMediaElement) event_count(name string) int {
	return element.event_counts_[name]
}

pub fn (mut element HTMLMediaElement) cancel_the_fetching_process() {
	element.fetch_generation_++
	if element.network_state_ == .loading {
		element.network_state_ = .idle
	}
}

pub fn (mut element HTMLMediaElement) set_decoder_error(message string) {
	element.error_ = &MediaError{
		code:    .decode
		message: message
	}
	element.network_state_ = .idle
	element.set_ready_state(.have_nothing)
	element.reject_pending_play_promises(dom.js_string('NotSupportedError: ${message}'))
	element.fire_event('error')
}

fn mime_essence(type_ string) string {
	return type_.all_before(';').trim_space().to_lower()
}

pub fn (element &HTMLMediaElement) can_play_type(type_ string) CanPlayTypeResult {
	_ = element
	essence := mime_essence(type_)
	parts := essence.split('/')
	if parts.len != 2 {
		return .empty
	}
	supported := if parts[0] == 'video' {
		parts[1] in ['webm', 'mp4', 'mpeg', 'ogg']
	} else if parts[0] == 'audio' {
		parts[1] in ['flac', 'mp3', 'mpeg', 'ogg', 'wav', 'webm']
	} else {
		false
	}
	if !supported {
		return .empty
	}
	return if type_.to_lower().contains('codecs=') { .probably } else { .maybe }
}

pub fn (mut element HTMLMediaElement) load() ! {
	element.cancel_the_fetching_process()
	element.error_ = none
	element.current_src_ = ''
	element.network_state_ = .empty
	element.ready_state_ = .have_nothing
	element.current_playback_position_ = 0
	element.official_playback_position_ = 0
	element.duration_ = math.nan()
	element.ended_ = false
	element.show_poster_ = true
	element.buffered_.clear()
	element.played_.clear()
	element.seekable_.clear()
	element.audio_tracks_.remove_all_tracks()
	element.video_tracks_.remove_all_tracks()
	element.fire_event('emptied')
	element.select_resource()!
}

pub fn (mut element HTMLMediaElement) select_resource() ! {
	mut candidates := []string{}
	if source := element.source_ {
		if source.trim_space() != '' {
			candidates << source
		}
	}
	candidates << element.source_candidates_
	if candidates.len == 0 {
		element.network_state_ = .empty
		return
	}
	element.network_state_ = .loading
	element.fire_event('loadstart')
	hook := element.fetch_hook_ or {
		element.network_state_ = .no_source
		element.error_ = &MediaError{
			code:    .src_not_supported
			message: 'No media fetch hook'
		}
		element.fire_event('error')
		return error('NotSupportedError: no media fetch hook')
	}

	mut last_error := 'No supported media source'
	for candidate in candidates {
		url := dom.dom_url_parse(candidate, element.base_url_, 'UTF-8') or {
			last_error = 'Invalid media URL'
			continue
		}
		response := hook(url, 0) or {
			last_error = err.msg()
			continue
		}
		if response.status < 200 || response.status >= 300
			|| element.can_play_type(response.mime_type) == .empty {
			last_error = 'Unsupported media response'
			continue
		}
		element.current_src_ = url.serialize()
		element.process_media_response(response)
		return
	}
	element.network_state_ = .no_source
	element.error_ = &MediaError{
		code:    .src_not_supported
		message: last_error
	}
	element.reject_pending_play_promises(dom.js_string('NotSupportedError: ${last_error}'))
	element.fire_event('error')
	return error('NotSupportedError: ${last_error}')
}

fn (mut element HTMLMediaElement) process_media_response(response MediaResourceResponse) {
	element.duration_ = response.duration
	element.set_ready_state(.have_metadata)
	element.fire_event('durationchange')
	element.fire_event('loadedmetadata')
	if response.buffered_end > 0 {
		element.buffered_.add_range(0, response.buffered_end)
		element.seekable_.add_range(0, if math.is_nan(response.duration) {
			response.buffered_end
		} else {
			response.duration
		})
		element.set_ready_state(.have_enough_data)
	}
	for metadata in response.audio_tracks {
		track := AudioTrack.create(metadata, media_element_noop_change_task,
			media_element_noop_audio_enabled)
		element.audio_tracks_.add_track(track)
	}
	for metadata in response.video_tracks {
		track := VideoTrack.create(metadata, media_element_noop_change_task,
			media_element_noop_video_selected)
		element.video_tracks_.add_track(track)
	}
	element.network_state_ = .idle
	element.fire_event('progress')
	element.fire_event('suspend')
	if element.autoplay_ && element.can_autoplay_ {
		_ = element.play()
	}
}

pub fn (mut element HTMLMediaElement) set_ready_state(state MediaReadyState) {
	old_state := element.ready_state_
	if old_state == state {
		return
	}
	element.ready_state_ = state
	if int(old_state) < int(MediaReadyState.have_current_data)
		&& int(state) >= int(MediaReadyState.have_current_data) {
		element.fire_event('loadeddata')
	}
	if int(old_state) < int(MediaReadyState.have_future_data)
		&& int(state) >= int(MediaReadyState.have_future_data) {
		element.fire_event('canplay')
		if !element.paused_ {
			element.notify_about_playing()
		}
	}
	if int(old_state) < int(MediaReadyState.have_enough_data)
		&& int(state) >= int(MediaReadyState.have_enough_data) {
		element.fire_event('canplaythrough')
	}
	if int(state) < int(MediaReadyState.have_future_data)
		&& int(old_state) >= int(MediaReadyState.have_future_data) && !element.paused_ {
		element.fire_event('waiting')
	}
}

pub fn (element &HTMLMediaElement) current_time() f64 {
	if element.ready_state_ == .have_nothing {
		return element.default_playback_start_
	}
	return element.official_playback_position_
}

pub fn (mut element HTMLMediaElement) set_current_time(value f64) {
	if element.ready_state_ == .have_nothing {
		element.default_playback_start_ = value
		return
	}
	element.seek_element(value, .accurate)
}

pub fn (mut element HTMLMediaElement) fast_seek(value f64) {
	if element.ready_state_ != .have_nothing {
		element.seek_element(value, .approximate_for_speed)
	}
}

fn (mut element HTMLMediaElement) seek_element(value f64, mode MediaSeekMode) {
	_ = mode
	element.seeking_ = true
	element.fire_event('seeking')
	mut target := if value < 0 { 0.0 } else { value }
	if !math.is_nan(element.duration_) && target > element.duration_ {
		target = element.duration_
	}
	element.current_playback_position_ = target
	element.official_playback_position_ = target
	element.ended_ = false
	element.seeking_ = false
	element.fire_event('timeupdate')
	element.fire_event('seeked')
}

pub fn (mut element HTMLMediaElement) set_current_playback_position(value f64) {
	element.current_playback_position_ = value
	element.official_playback_position_ = value
}

pub fn (element &HTMLMediaElement) ended() bool {
	return element.ended_ && element.playback_rate_ >= 0
}

pub fn (element &HTMLMediaElement) blocked() bool {
	return element.ready_state_ == .have_nothing || element.network_state_ == .loading
}

pub fn (element &HTMLMediaElement) stalled() bool {
	return int(element.ready_state_) <= int(MediaReadyState.have_current_data) && !element.paused_
}

pub fn (element &HTMLMediaElement) potentially_playing() bool {
	return !element.paused_ && !element.ended()
		&& int(element.ready_state_) >= int(MediaReadyState.have_future_data)
}

pub fn (mut element HTMLMediaElement) play() &dom.Promise {
	mut promise := dom.Promise.create()
	if media_error := element.error_ {
		if media_error.code == .src_not_supported {
			promise.reject(dom.js_string('NotSupportedError: media source is unsupported'))
			return promise
		}
	}
	element.pending_play_promises_ << promise
	if element.paused_ {
		element.paused_ = false
		element.ended_ = false
		element.show_poster_ = false
		element.play_range_start_ = element.current_time()
		element.fire_event('play')
	}
	if int(element.ready_state_) >= int(MediaReadyState.have_future_data) {
		element.notify_about_playing()
	} else {
		element.fire_event('waiting')
	}
	return promise
}

fn (mut element HTMLMediaElement) notify_about_playing() {
	element.fire_event('playing')
	for promise in element.pending_play_promises_ {
		mut mutable_promise := unsafe { &dom.Promise(promise) }
		mutable_promise.resolve(dom.js_undefined())
	}
	element.pending_play_promises_.clear()
}

fn (mut element HTMLMediaElement) reject_pending_play_promises(reason dom.JSValue) {
	for promise in element.pending_play_promises_ {
		mut mutable_promise := unsafe { &dom.Promise(promise) }
		mutable_promise.reject(reason)
	}
	element.pending_play_promises_.clear()
}

pub fn (mut element HTMLMediaElement) pause() {
	if element.paused_ {
		return
	}
	if start := element.play_range_start_ {
		if element.current_time() >= start {
			element.played_.add_range(start, element.current_time())
		}
	}
	element.play_range_start_ = none
	element.paused_ = true
	element.fire_event('timeupdate')
	element.fire_event('pause')
	element.reject_pending_play_promises(dom.js_string('AbortError: playback was paused'))
}

pub fn (mut element HTMLMediaElement) toggle_playback() &dom.Promise {
	if element.paused_ {
		return element.play()
	}
	element.pause()
	return dom.Promise.resolved(dom.js_undefined())
}

pub fn (mut element HTMLMediaElement) set_volume(volume f64) ! {
	if math.is_nan(volume) || volume < 0 || volume > 1 {
		return error('IndexSizeError: volume must be in the range 0 to 1')
	}
	if element.volume_ != volume {
		element.volume_ = volume
		element.fire_event('volumechange')
	}
}

pub fn (mut element HTMLMediaElement) set_muted(muted bool) {
	if element.muted_ != muted {
		element.muted_ = muted
		element.fire_event('volumechange')
	}
}

pub fn (mut element HTMLMediaElement) set_page_muted(muted bool) {
	element.page_muted_ = muted
}

pub fn (element &HTMLMediaElement) effective_media_volume() f64 {
	return if element.muted_ || element.page_muted_ { 0 } else { element.volume_ }
}

pub fn (mut element HTMLMediaElement) set_default_playback_rate(rate f64) {
	if element.default_playback_rate_ != rate {
		element.default_playback_rate_ = rate
		element.fire_event('ratechange')
	}
}

pub fn (mut element HTMLMediaElement) set_playback_rate(rate f64) ! {
	if math.is_nan(rate) || math.is_inf(rate, 0) {
		return error('NotSupportedError: playbackRate must be finite')
	}
	if element.playback_rate_ != rate {
		element.playback_rate_ = rate
		element.fire_event('ratechange')
	}
}

pub fn (mut element HTMLMediaElement) advance_playback(elapsed_seconds f64) {
	if !element.potentially_playing() || elapsed_seconds <= 0 {
		return
	}
	new_position := element.current_playback_position_ + elapsed_seconds * element.playback_rate_
	if element.playback_rate_ >= 0 && !math.is_nan(element.duration_)
		&& new_position >= element.duration_ {
		if element.loop_ {
			element.current_playback_position_ = 0
			element.official_playback_position_ = 0
			element.fire_event('timeupdate')
			return
		}
		element.current_playback_position_ = element.duration_
		element.official_playback_position_ = element.duration_
		element.ended_ = true
		element.paused_ = true
		element.fire_event('timeupdate')
		element.fire_event('pause')
		element.fire_event('ended')
		return
	}
	element.current_playback_position_ = if new_position < 0 { 0 } else { new_position }
	element.official_playback_position_ = element.current_playback_position_
	element.fire_event('timeupdate')
}

pub fn (mut element HTMLMediaElement) add_text_track(kind TextTrackKind, label string, language string) &TextTrack {
	mut track := TextTrack.create()
	track.set_kind(kind)
	track.set_label(label)
	track.set_language(language)
	track.set_mode(.hidden)
	element.text_tracks_.add_track(track)
	element.fire_event('addtrack')
	return track
}

pub fn (mut element HTMLMediaElement) create_controls() {
	element.controls_ = true
}

pub fn (mut element HTMLMediaElement) destroy_controls() {
	element.controls_ = false
}

pub fn (element &HTMLMediaElement) has_controls() bool {
	return element.controls_
}

pub fn (element &HTMLMediaElement) set_on_event(name string, handler ?&dom.CallbackType) {
	element.event_target_.set_event_handler_attribute(name, handler)
}

pub fn (element &HTMLMediaElement) event_target() &dom.EventTarget {
	return element.event_target_
}
