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

pub type PosterFrameFetchHook = fn(dom.URL) !&dom.ImmutableBitmap_

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
		media: media
		base_url_: base_url
	}
}

pub fn html_video_element_model_for_dom_element(element &dom.HTMLVideoElement) &HTMLVideoElementModel {
	if element.video_element_model_ != unsafe { nil } {
		return unsafe { &HTMLVideoElementModel(element.video_element_model_) }
	}
	dom_element := unsafe { &dom.Element(element) }
	media := html_media_element_for_dom_element(dom_element) or {
		HTMLMediaElement.create(unsafe { &dom.HTMLElement(dom_element) },
			dom_element.document().base_url())
	}
	model := HTMLVideoElementModel.create(media, dom_element.document().base_url())
	mut mutable_element := unsafe { &dom.HTMLVideoElement(element) }
	mutable_element.video_element_model_ = model
	return model
}

pub fn html_video_element_attribute_changed(element &dom.HTMLVideoElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ == none && name == 'poster' {
		mut video := html_video_element_model_for_dom_element(element)
		video.set_poster(value)
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

pub fn (mut video HTMLVideoElementModel) set_video_width(width u32) {
	video.video_width_ = width
}

pub fn (mut video HTMLVideoElementModel) set_video_height(height u32) {
	video.video_height_ = height
}

pub fn (video &HTMLVideoElementModel) supports_dimension_attributes() bool {
	_ = video
	return true
}

pub fn (video &HTMLVideoElementModel) video_width() u32 {
	if video.media.ready_state() == .have_nothing {
		return 0
	}
	return video.video_width_
}

pub fn (video &HTMLVideoElementModel) video_height() u32 {
	if video.media.ready_state() == .have_nothing {
		return 0
	}
	return video.video_height_
}

pub fn (mut video HTMLVideoElementModel) set_current_frame(frame ?&dom.ImmutableBitmap_) {
	video.current_frame_ = frame
	mut media := video.media
	mut source := media.ensure_external_content_source()
	source.update(frame)
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
		.video_frame, .first_video_frame {
			if source := video.media.external_content_source_ {
				source.frame()
			} else {
				video.current_frame_
			}
		}
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

pub fn (audio &HTMLAudioElementModel) should_paint(scripting_disabled bool) bool {
	return audio.media.has_controls() || scripting_disabled
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

pub type TextTrackFetchHook = fn(dom.URL, CORSSettingAttribute) !TextTrackResourceResponse

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
		track: TextTrack.create()
		base_url_: base_url
		event_target_: dom.EventTarget.new()
	}
}

pub fn html_track_element_model_for_dom_element(element &dom.HTMLTrackElement) &HTMLTrackElementModel {
	if element.track_element_model_ != unsafe { nil } {
		return unsafe { &HTMLTrackElementModel(element.track_element_model_) }
	}
	dom_element := unsafe { &dom.Element(element) }
	mut model := HTMLTrackElementModel.create(dom_element.document().base_url())
	model.set_kind(dom_element.get_attribute_value('kind'))
	model.set_label(dom_element.get_attribute_value('label'))
	model.set_srclang(dom_element.get_attribute_value('srclang'))
	model.set_src(dom_element.get_attribute_value('src'))
	mut track := model.track
	track.set_id(dom_element.get_attribute_value('id'))
	mut mutable_element := unsafe { &dom.HTMLTrackElement(element) }
	mutable_element.track_element_model_ = model
	return model
}

pub fn html_track_element_track(element &dom.HTMLTrackElement) &TextTrack {
	return html_track_element_model_for_dom_element(element).track
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
		element.set_track_url('')
		return
	}
	element.set_track_url(parsed.serialize())
}

pub fn (mut element HTMLTrackElementModel) set_track_url(track_url string) {
	if track_url == element.track_url_ {
		return
	}
	element.track_url_ = track_url
	if element.loading_ && element.track.mode() in [.hidden, .showing] {
		element.loading_ = false
	}
	if element.awaiting_url_change && element.track.mode() in [.hidden, .showing] {
		element.awaiting_url_change = false
		element.start_the_track_processing_model_parallel_steps()
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
	if element.loading_ || element.track.mode() !in [.hidden, .showing] || element.parent_media_ == none {
		return
	}
	element.loading_ = true
	element.start_the_track_processing_model_parallel_steps()
}

pub fn (mut element HTMLTrackElementModel) start_the_track_processing_model_parallel_steps() {
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
	element.fire_event('load')
	element.track_became_ready()
}

pub fn (mut element HTMLTrackElementModel) track_became_ready() {
	element.awaiting_url_change = true
}

fn (mut element HTMLTrackElementModel) track_failed_to_load() {
	element.loading_ = false
	mut track := element.track
	track.set_readiness_state(.failed_to_load)
	element.fire_event('error')
	element.track_became_ready()
}

pub fn html_track_element_attribute_changed(element &dom.HTMLTrackElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	mut model := html_track_element_model_for_dom_element(element)
	match name.to_lower() {
		'kind' { model.set_kind(value or { '' }) }
		'label' { model.set_label(value or { '' }) }
		'srclang' { model.set_srclang(value or { '' }) }
		'src' {
			if source := value {
				model.set_src(source)
			}
		}
		'id' {
			mut track := model.track
			track.set_id(value or { '' })
		}
		else {}
	}
}

pub fn html_track_element_inserted(element &dom.HTMLTrackElement) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.inserted()
	mut model := html_track_element_model_for_dom_element(element)
	model.set_mode(.hidden)
	if parent := dom_element.as_node().parent_element() {
		model.set_parent_media(html_media_element_for_dom_element(parent))
	}
	model.start_the_track_processing_model()
}

pub fn html_track_element_set_track_url(element &dom.HTMLTrackElement, track_url string) {
	mut model := html_track_element_model_for_dom_element(element)
	model.set_track_url(track_url)
}

pub fn html_track_element_start_the_track_processing_model_parallel_steps(element &dom.HTMLTrackElement) {
	mut model := html_track_element_model_for_dom_element(element)
	model.start_the_track_processing_model_parallel_steps()
}

pub fn html_track_element_track_became_ready(element &dom.HTMLTrackElement) {
	mut model := html_track_element_model_for_dom_element(element)
	model.track_became_ready()
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

pub enum MediaControlsListenOnce {
	no
	yes
}

pub type MediaControlsEventHandler = fn (&dom.Event) bool

struct MediaControlsRegisteredEventListener {
	target     &dom.EventTarget
	event_name string
	listener   &dom.IDLEventListener
}

struct MediaControlsDOM {
mut:
	container          ?&dom.Element
	play_pause_icon    ?&dom.Element
	timeline_fill      ?&dom.Element
	timestamp_element  ?&dom.Element
	volume_area        ?&dom.Element
	volume_fill        ?&dom.Element
	mute_button        ?&dom.Element
	fullscreen_icon    ?&dom.Element
	placeholder_circle ?&dom.Element
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
	shadow_tree_created bool
	had_audio           bool = true
	was_muted           bool
mut:
	dom_                        MediaControlsDOM
	registered_event_listeners_ []MediaControlsRegisteredEventListener
}

pub fn MediaControls.create(media &HTMLMediaElement) &MediaControls {
	mut controls := &MediaControls{
		media: media
	}
	controls.create_shadow_tree()
	controls.set_up_event_listeners()
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
	controls.update_play_pause_icon()
	controls.update_timeline()
	controls.update_timestamp()
	controls.update_volume_and_mute_indicator()
	controls.update_fullscreen_icon()
	controls.update_placeholder_visibility()
}

pub fn (mut controls MediaControls) create_shadow_tree() {
	if html_element := controls.media.associated_element_ {
		mut media_element := unsafe { &dom.Element(html_element) }
		if media_element.shadow_root() == none {
			shadow := media_element.attach_a_user_agent_shadow_root(.named)
			document := media_element.document()
			mut container := dom.create_element(document, 'div', ns_html, none, none, false) or {
				controls.update()
				controls.show_controls()
				return
			}
			container.set_attribute_value('class', if media_element.local_name() == 'video' { 'media-controls video' } else { 'media-controls audio' })
			mut created := []&dom.Element{}
			for class_name in ['play-pause-icon', 'timeline-fill', 'timestamp', 'volume-area',
				'volume-fill', 'mute-button', 'fullscreen-icon', 'placeholder-circle'] {
				mut child := dom.create_element(document, 'div', ns_html, none, none, false) or { continue }
				child.set_attribute_value('class', class_name)
				mut container_node := container.as_node()
				container_node.append_child(child.as_node()) or { continue }
				created << child
			}
			mut shadow_node := unsafe { &dom.Node(shadow) }
			shadow_node.append_child(container.as_node()) or {}
			controls.dom_.container = container
			if created.len == 8 {
				controls.dom_.play_pause_icon = created[0]
				controls.dom_.timeline_fill = created[1]
				controls.dom_.timestamp_element = created[2]
				controls.dom_.volume_area = created[3]
				controls.dom_.volume_fill = created[4]
				controls.dom_.mute_button = created[5]
				controls.dom_.fullscreen_icon = created[6]
				controls.dom_.placeholder_circle = created[7]
			}
		}
	}
	controls.shadow_tree_created = true
	controls.update()
	controls.show_controls()
}

pub fn (mut controls MediaControls) add_event_listener(target &dom.EventTarget, event_name string, listen_once MediaControlsListenOnce, handler MediaControlsEventHandler) &dom.IDLEventListener {
	callback := &dom.CallbackType{
		handle_event: fn [handler] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			if handler(event) {
				mut mutable_event := unsafe { &dom.Event(event) }
				mutable_event.prevent_default()
			}
			return dom.js_undefined()
		}
	}
	listener := dom.IDLEventListener.create(callback)
	target.add_event_listener(event_name, listener, dom.AddEventListenerOptions{
		once: listen_once == .yes
	})
	controls.registered_event_listeners_ << MediaControlsRegisteredEventListener{
		target: target
		event_name: event_name
		listener: listener
	}
	return listener
}

pub fn (mut controls MediaControls) remove_event_listeners() {
	for registration in controls.registered_event_listeners_ {
		registration.target.remove_event_listener_without_options(registration.event_name,
			registration.listener)
	}
	controls.registered_event_listeners_.clear()
}

fn media_controls_state_handler(controls &MediaControls, event &dom.Event) bool {
	mut mutable_controls := unsafe { &MediaControls(controls) }
	match event.type_ {
		'play', 'pause', 'playing' {
			mutable_controls.update_play_pause_icon()
			mutable_controls.update_placeholder_visibility()
		}
		'seeked' { mutable_controls.update_placeholder_visibility() }
		'timeupdate', 'durationchange' {
			mutable_controls.update_timeline()
			mutable_controls.update_timestamp()
		}
		'volumechange', 'addtrack' { mutable_controls.update_volume_and_mute_indicator() }
		'loadedmetadata' {
			mutable_controls.update_timestamp()
			mutable_controls.update_volume_and_mute_indicator()
		}
		'emptied' {
			mutable_controls.update_placeholder_visibility()
			mutable_controls.update_timeline()
			mutable_controls.update_timestamp()
		}
		else {}
	}
	return true
}

pub fn (mut controls MediaControls) set_up_event_listeners() {
	for event_name in ['play', 'pause', 'playing', 'seeked', 'timeupdate', 'durationchange',
		'volumechange', 'loadedmetadata', 'addtrack', 'emptied'] {
		controls.add_event_listener(controls.media.event_target(), event_name, .no,
			fn [controls] (event &dom.Event) bool {
				return media_controls_state_handler(controls, event)
			})
	}
}

pub fn (mut controls MediaControls) toggle_playback() {
	if controls.scrubbing_timeline != .no {
		return
	}
	mut media := controls.media
	media.toggle_playback()
	controls.update_play_pause_icon()
	controls.show_controls()
}

pub fn (mut controls MediaControls) set_current_time(time f64) {
	mut media := controls.media
	media.set_current_time(time)
	controls.update_timeline()
	controls.update_timestamp()
	controls.show_controls()
}

pub fn (mut controls MediaControls) set_volume(volume f64) ! {
	mut media := controls.media
	media.set_volume(math.max(0.0, math.min(1.0, volume)))!
	media.set_muted(false)
	controls.update_volume_and_mute_indicator()
	controls.show_controls()
}

pub fn (mut controls MediaControls) toggle_mute() {
	mut media := controls.media
	media.set_muted(!media.muted())
	controls.update_volume_and_mute_indicator()
	controls.show_controls()
}

pub fn (mut controls MediaControls) toggle_fullscreen() {
	mut media := controls.media
	media.toggle_fullscreen()
	controls.fullscreen = !controls.fullscreen
	controls.update_fullscreen_icon()
}

pub fn (mut controls MediaControls) update_play_pause_icon() {
	paused := if controls.scrubbing_timeline != .no {
		controls.scrubbing_timeline == .while_paused
	} else {
		controls.media.paused()
	}
	controls.play_icon_is_pause = !paused
	if mut icon := controls.dom_.play_pause_icon {
		icon.set_attribute_value('class', if paused { 'play-pause-icon' } else { 'play-pause-icon playing' })
	}
}

pub fn (mut controls MediaControls) update_timeline() {
	duration := controls.media.duration()
	percentage := if duration > 0 && !math.is_nan(duration) {
		(controls.media.current_time() / duration) * 100.0
	} else {
		0.0
	}
	if controls.timeline_percentage == percentage {
		return
	}
	controls.timeline_percentage = percentage
	if mut fill := controls.dom_.timeline_fill {
		fill.set_attribute_value('style', 'width:${percentage}%;')
	}
}

pub fn (mut controls MediaControls) update_timestamp() {
	current := media_timestamp(math.round(controls.media.current_time()))
	duration := controls.media.duration()
	total := media_timestamp(if math.is_nan(duration) { 0.0 } else { math.round(duration) })
	controls.timestamp = '${current} / ${total}'
	if element := controls.dom_.timestamp_element {
		mut node := element.as_node()
		node.set_text_content(controls.timestamp) or {}
	}
}

pub fn (mut controls MediaControls) update_volume_and_mute_indicator() {
	volume := controls.media.volume()
	has_audio := controls.media.audio_tracks().length() > 0
	muted := !has_audio || controls.media.muted()
	controls.volume_percentage = if muted { 0.0 } else { volume * 100.0 }
	controls.mute_icon = if volume > 0.5 {
		.high
	} else if volume > 0 {
		.low
	} else {
		.empty
	}
	controls.was_muted = muted
	controls.had_audio = has_audio
	if mut fill := controls.dom_.volume_fill {
		fill.set_attribute_value('style', 'width:${controls.volume_percentage}%;')
	}
	if mut button := controls.dom_.mute_button {
		icon_class := match controls.mute_icon {
			.empty { '' }
			.low { ' low' }
			.high { ' high' }
		}
		button.set_attribute_value('class', 'mute-button${icon_class}${if muted { ' muted' } else { '' }}')
	}
	if mut area := controls.dom_.volume_area {
		area.set_attribute_value('style', if has_audio { '' } else { 'display:none;' })
	}
}

pub fn (mut controls MediaControls) update_fullscreen_icon() {
	mut is_fullscreen := controls.fullscreen
	if html_element := controls.media.associated_element_ {
		element := unsafe { &dom.Element(html_element) }
		if fullscreen_element := element.document().fullscreen_element() {
			is_fullscreen = fullscreen_element == element
		} else {
			is_fullscreen = false
		}
	}
	controls.fullscreen = is_fullscreen
	if mut icon := controls.dom_.fullscreen_icon {
		icon.set_attribute_value('class', if is_fullscreen { 'fullscreen-icon fullscreen' } else { 'fullscreen-icon' })
	}
}

pub fn (mut controls MediaControls) update_placeholder_visibility() {
	controls.placeholder_visible = controls.should_show_placeholder()
	if mut placeholder := controls.dom_.placeholder_circle {
		placeholder.set_attribute_value('style', if controls.placeholder_visible { 'display:flex;' } else { 'display:none;' })
	}
}

pub fn (controls &MediaControls) should_show_placeholder() bool {
	return controls.media.ready_state() == .have_nothing || controls.media.show_poster()
}

pub fn (mut controls MediaControls) show_controls() {
	controls.visible = true
}

pub fn (mut controls MediaControls) hide_controls() {
	if controls.scrubbing_timeline == .no && !controls.scrubbing_volume && !controls.hovering_controls {
		controls.visible = false
	}
}
