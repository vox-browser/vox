// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLVideoElement.{h,cpp}, HTMLAudioElement.{h,cpp},
// HTMLTrackElement.{h,cpp}, and MediaControls.{h,cpp}. Bitmap/frame delivery,
// VTT fetching, and fullscreen remain explicit host-facing inputs.
module html

import dom
import math

pub enum VideoRepresentation {
	video_frame
	first_video_frame
	poster_frame
	transparent_black
}

pub type PosterFrameFetchHook = fn (dom.URL) !&dom.ImmutableBitmap_

@[heap]
pub struct HTMLVideoElementModel {
pub:
	media &HTMLMediaElement
mut:
	base_url_         dom.URL
	poster_           ?string
	poster_frame_     ?&dom.ImmutableBitmap_
	current_frame_    ?&dom.ImmutableBitmap_
	video_width_      u32
	video_height_     u32
	poster_fetch_hook ?PosterFrameFetchHook
}

pub fn HTMLVideoElementModel.create(media &HTMLMediaElement, base_url dom.URL) &HTMLVideoElementModel {
	return &HTMLVideoElementModel{
		media:     media
		base_url_: base_url
	}
}

pub fn (mut video HTMLVideoElementModel) set_poster_fetch_hook(hook ?PosterFrameFetchHook) {
	video.poster_fetch_hook = hook
}

pub fn (mut video HTMLVideoElementModel) set_poster(value ?string) {
	video.poster_ = value
	video.determine_element_poster_frame()
}

pub fn (mut video HTMLVideoElementModel) determine_element_poster_frame() {
	poster := video.poster_ or {
		video.poster_frame_ = none
		return
	}

	if poster == '' {
		video.poster_frame_ = none
		return
	}
	url := dom.dom_url_parse(poster, video.base_url_, 'UTF-8') or {
		video.poster_frame_ = none
		return
	}
	fetch := video.poster_fetch_hook or {
		video.poster_frame_ = none
		return
	}

	frame := fetch(url) or {
		video.poster_frame_ = none
		return
	}
	video.poster_frame_ = frame
}

pub fn (mut video HTMLVideoElementModel) set_video_dimensions(width u32, height u32) {
	video.video_width_ = width
	video.video_height_ = height
}

pub fn (video &HTMLVideoElementModel) video_width() u32 {
	return video.video_width_
}

pub fn (video &HTMLVideoElementModel) video_height() u32 {
	return video.video_height_
}

pub fn (mut video HTMLVideoElementModel) set_current_frame(frame ?&dom.ImmutableBitmap_) {
	video.current_frame_ = frame
}

pub fn (video &HTMLVideoElementModel) poster_frame() ?&dom.ImmutableBitmap_ {
	return video.poster_frame_
}

pub fn (video &HTMLVideoElementModel) current_representation() VideoRepresentation {
	if video.media.ready_state() == .have_nothing || video.media.video_tracks().length() == 0 {
		return if video.poster_frame_ != none { .poster_frame } else { .transparent_black }
	}
	if video.media.paused() && video.media.current_time() == 0 && video.media.show_poster() {
		return if video.poster_frame_ != none { .poster_frame } else { .first_video_frame }
	}
	return .video_frame
}

pub fn (video &HTMLVideoElementModel) bitmap() ?&dom.ImmutableBitmap_ {
	return match video.current_representation() {
		.poster_frame { video.poster_frame_ }
		.video_frame, .first_video_frame { video.current_frame_ }
		.transparent_black { ?&dom.ImmutableBitmap_(none) }
	}
}

@[heap]
pub struct HTMLAudioElementModel {
pub:
	media &HTMLMediaElement
}

pub fn HTMLAudioElementModel.create(media &HTMLMediaElement) &HTMLAudioElementModel {
	return &HTMLAudioElementModel{
		media: media
	}
}

pub enum TrackElementReadyState {
	none
	loading
	loaded
	error
}

pub struct TextTrackResourceResponse {
pub:
	status u16 = 200
	body   string
}

pub type TextTrackFetchHook = fn (dom.URL, CORSSettingAttribute) !TextTrackResourceResponse

@[heap]
pub struct HTMLTrackElementModel {
pub:
	track &TextTrack
mut:
	base_url_           dom.URL
	src_                string
	track_url_          string
	loading_            bool
	awaiting_url_change bool
	parent_media_       ?&HTMLMediaElement
	fetch_hook_         ?TextTrackFetchHook
	event_target_       &dom.EventTarget = unsafe { nil }
	event_counts_       map[string]int
}

pub fn HTMLTrackElementModel.create(base_url dom.URL) &HTMLTrackElementModel {
	return &HTMLTrackElementModel{
		track:         TextTrack.create()
		base_url_:     base_url
		event_target_: dom.EventTarget.new()
	}
}

fn (mut element HTMLTrackElementModel) fire_event(name string) {
	element.event_counts_[name]++
	element.event_target_.dispatch_event(dom.Event.create(name, dom.EventInit{}))
}

pub fn (element &HTMLTrackElementModel) event_count(name string) int {
	return element.event_counts_[name]
}

pub fn (element &HTMLTrackElementModel) event_target() &dom.EventTarget {
	return element.event_target_
}

pub fn (mut element HTMLTrackElementModel) set_fetch_hook(hook ?TextTrackFetchHook) {
	element.fetch_hook_ = hook
}

pub fn (mut element HTMLTrackElementModel) set_parent_media(media ?&HTMLMediaElement) {
	element.parent_media_ = media
}

pub fn (mut element HTMLTrackElementModel) set_src(value string) {
	element.src_ = value
	parsed := dom.dom_url_parse(value, element.base_url_, 'UTF-8') or {
		element.track_url_ = ''
		return
	}
	new_url := parsed.serialize()
	if new_url == element.track_url_ {
		return
	}
	element.track_url_ = new_url
	if element.awaiting_url_change && element.track.mode() in [.hidden, .showing] {
		element.awaiting_url_change = false
		element.start_the_track_processing_model()
	}
}

pub fn (mut element HTMLTrackElementModel) set_kind(value string) {
	mut track := element.track
	track.set_kind(text_track_kind_from_string(value))
}

pub fn (mut element HTMLTrackElementModel) set_label(value string) {
	mut track := element.track
	track.set_label(value)
}

pub fn (mut element HTMLTrackElementModel) set_srclang(value string) {
	mut track := element.track
	track.set_language(value)
}

pub fn (mut element HTMLTrackElementModel) set_mode(mode TextTrackMode) {
	mut track := element.track
	track.set_mode(mode)
}

pub fn (element &HTMLTrackElementModel) ready_state() TrackElementReadyState {
	return match element.track.readiness_state() {
		.not_loaded { .none }
		.loading { .loading }
		.loaded { .loaded }
		.failed_to_load { .error }
	}
}

fn parse_vtt_timestamp(value string) ?f64 {
	parts := value.trim_space().split(':')
	if parts.len !in [2, 3] {
		return none
	}
	mut seconds := 0.0
	if parts.len == 3 {
		seconds += parts[0].f64() * 3600.0
		seconds += parts[1].f64() * 60.0
		seconds += parts[2].f64()
	} else {
		seconds += parts[0].f64() * 60.0
		seconds += parts[1].f64()
	}
	return if seconds < 0 || math.is_nan(seconds) { none } else { seconds }
}

fn parse_web_vtt(body string) ![]&TextTrackCue {
	normalized := body.replace('\r\n', '\n').replace('\r', '\n')
	if !normalized.starts_with('WEBVTT') {
		return error('invalid WebVTT signature')
	}
	mut cues := []&TextTrackCue{}
	for block in normalized.split('\n\n')[1..] {
		mut lines := block.split_into_lines().filter(it.trim_space() != '')
		if lines.len == 0 || lines[0].starts_with('NOTE') {
			continue
		}
		mut identifier := ''
		mut timing_index := 0
		if !lines[0].contains('-->') {
			identifier = lines[0]
			timing_index = 1
		}
		if timing_index >= lines.len || !lines[timing_index].contains('-->') {
			continue
		}
		timing := lines[timing_index].split('-->')
		start := parse_vtt_timestamp(timing[0]) or { continue }
		end_token := timing[1].trim_space().fields()[0]
		end := parse_vtt_timestamp(end_token) or { continue }
		mut cue := TextTrackCue.create(start, end, lines[timing_index + 1..].join('\n')) or {
			continue
		}
		cue.set_id(identifier)
		cues << cue
	}
	return cues
}

pub fn (mut element HTMLTrackElementModel) start_the_track_processing_model() {
	if element.loading_ || element.track.mode() !in [.hidden, .showing]
		|| element.parent_media_ == none {
		return
	}
	element.loading_ = true
	mut track := element.track
	track.set_readiness_state(.loading)
	url := dom.dom_url_parse(element.track_url_, element.base_url_, 'UTF-8') or {
		element.track_failed_to_load()
		return
	}
	fetch := element.fetch_hook_ or {
		element.track_failed_to_load()
		return
	}

	cors := if media := element.parent_media_ {
		media.crossorigin()
	} else {
		CORSSettingAttribute.no_cors
	}
	response := fetch(url, cors) or {
		element.track_failed_to_load()
		return
	}
	if response.status < 200 || response.status >= 300 {
		element.track_failed_to_load()
		return
	}
	mut cues := parse_web_vtt(response.body) or {
		element.track_failed_to_load()
		return
	}
	for mut cue in cues {
		track.add_cue(mut cue)
	}
	element.loading_ = false
	track.set_readiness_state(.loaded)
	element.awaiting_url_change = true
	element.fire_event('load')
}

fn (mut element HTMLTrackElementModel) track_failed_to_load() {
	element.loading_ = false
	mut track := element.track
	track.set_readiness_state(.failed_to_load)
	element.awaiting_url_change = true
	element.fire_event('error')
}

pub enum MediaControlsMuteIcon {
	empty
	low
	high
}

pub enum MediaControlsScrubbing {
	no
	while_paused
	while_playing
}

@[heap]
pub struct MediaControls {
pub:
	media &HTMLMediaElement
pub mut:
	visible             bool = true
	placeholder_visible bool
	play_icon_is_pause  bool
	timeline_percentage f64
	timestamp           string
	volume_percentage   f64
	mute_icon           MediaControlsMuteIcon
	fullscreen          bool
	scrubbing_timeline  MediaControlsScrubbing
	scrubbing_volume    bool
	hovering_controls   bool
}

pub fn MediaControls.create(media &HTMLMediaElement) &MediaControls {
	mut controls := &MediaControls{
		media: media
	}
	controls.update()
	return controls
}

fn media_timestamp(seconds f64) string {
	if math.is_nan(seconds) || math.is_inf(seconds, 0) || seconds < 0 {
		return '0:00'
	}
	total := int(seconds)
	hours := total / 3600
	minutes := (total / 60) % 60
	secs := total % 60
	return if hours > 0 { '${hours}:${minutes:02d}:${secs:02d}' } else { '${minutes}:${secs:02d}' }
}

pub fn (mut controls MediaControls) update() {
	controls.play_icon_is_pause = !controls.media.paused()
	duration := controls.media.duration()
	controls.timeline_percentage = if duration > 0 && !math.is_nan(duration) {
		controls.media.current_time() / duration
	} else {
		0
	}
	controls.timestamp = '${media_timestamp(controls.media.current_time())} / ${media_timestamp(duration)}'
	controls.volume_percentage = controls.media.effective_media_volume()
	controls.mute_icon = if controls.volume_percentage == 0 {
		.empty
	} else if controls.volume_percentage < 0.5 {
		.low
	} else {
		.high
	}
	controls.placeholder_visible = controls.should_show_placeholder()
}

pub fn (mut controls MediaControls) toggle_playback() {
	mut media := controls.media
	media.toggle_playback()
	controls.update()
}

pub fn (mut controls MediaControls) set_current_time(time f64) {
	mut media := controls.media
	media.set_current_time(time)
	controls.update()
}

pub fn (mut controls MediaControls) set_volume(volume f64) ! {
	mut media := controls.media
	media.set_volume(volume)!
	controls.update()
}

pub fn (mut controls MediaControls) toggle_mute() {
	mut media := controls.media
	media.set_muted(!media.muted())
	controls.update()
}

pub fn (mut controls MediaControls) toggle_fullscreen() {
	controls.fullscreen = !controls.fullscreen
}

pub fn (controls &MediaControls) should_show_placeholder() bool {
	return controls.media.ready_state() == .have_nothing || controls.media.show_poster()
}

pub fn (mut controls MediaControls) show_controls() {
	controls.visible = true
}

pub fn (mut controls MediaControls) hide_controls() {
	if !controls.hovering_controls { controls.visible = false }
}
