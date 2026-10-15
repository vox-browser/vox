// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLVideoElement.{h,cpp}, HTMLAudioElement.{h,cpp},
// HTMLTrackElement.{h,cpp}, and MediaControls.{h,cpp}. Bitmap/frame delivery,
// VTT fetching, and fullscreen remain explicit host-facing inputs.
module html

import dom
import math
import painting
import platform

pub enum VideoRepresentation {
	video_frame
	first_video_frame
	poster_frame
	transparent_black
}

pub type PosterFrameFetchHook = fn(dom.URL) !&dom.Bitmap_

// Painting installs this boundary when a video has a concrete renderer owner.
pub type VideoPaintFactsUpdateHook = fn (&dom.HTMLVideoElement)

pub struct VideoDimensions {
pub:
	width  u32
	height u32
}

@[heap]
pub struct HTMLVideoElementModel {
pub:
	media &HTMLMediaElement
mut:
	base_url_                   dom.URL
	poster_                     ?string
	poster_frame_               ?&dom.Bitmap_
	current_frame_              ?&painting.MediaVideoFrame
	intrinsic_video_dimensions_ ?VideoDimensions
	natural_dimensions_         ?VideoDimensions
	poster_fetch_hook           ?PosterFrameFetchHook
	paint_facts_update_hook     ?VideoPaintFactsUpdateHook
	poster_fetch_generation_    u64
}

pub fn HTMLVideoElementModel.create(media &HTMLMediaElement, base_url dom.URL) &HTMLVideoElementModel {
	mut model := &HTMLVideoElementModel{
		media: media
		base_url_: base_url
	}
	mut mutable_media := unsafe { &HTMLMediaElement(media) }
	mutable_media.video_element_model_ = model
	if track := media.selected_video_track_ {
		if track.base.pixel_width > 0 && track.base.pixel_height > 0 {
			model.intrinsic_video_dimensions_ = VideoDimensions{
				width: track.base.pixel_width
				height: track.base.pixel_height
			}
		}
	}
	model.update_natural_dimensions()
	return model
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
	mutable_element.video_poster_attribute_changed_hook_ = html_video_element_poster_attribute_changed
	return model
}

pub fn html_video_element_attribute_changed(element &dom.HTMLVideoElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ == none && name == 'poster' {
		html_video_element_poster_attribute_changed(element, value)
	}
}

fn html_video_element_poster_attribute_changed(element &dom.HTMLVideoElement, value ?string) {
	mut video := html_video_element_model_for_dom_element(element)
	video.set_poster(value)
}

pub fn (mut video HTMLVideoElementModel) set_poster_fetch_hook(hook ?PosterFrameFetchHook) {
	video.poster_fetch_hook = hook
}

pub fn (mut video HTMLVideoElementModel) set_paint_facts_update_hook(hook ?VideoPaintFactsUpdateHook) {
	video.paint_facts_update_hook = hook
}

fn (video &HTMLVideoElementModel) push_video_paint_facts() {
	hook := video.paint_facts_update_hook or { return }
	owner := video.media.associated_element_ or { return }
	element := unsafe { &dom.Element(owner) }
	if element.is_html_element() && element.local_name() == 'video' {
		hook(unsafe { &dom.HTMLVideoElement(element) })
	}
}

pub fn (mut video HTMLVideoElementModel) set_poster(value ?string) {
	video.poster_ = value
	video.determine_element_poster_frame()
}

fn (video &HTMLVideoElementModel) parse_poster_url(poster string) ?dom.URL {
	if element := video.media.associated_element_ {
		return unsafe { &dom.Element(element) }.document().encoding_parse_url(poster)
	}
	return dom.dom_url_parse(poster, video.base_url_, 'UTF-8')
}

pub fn (mut video HTMLVideoElementModel) determine_element_poster_frame() {
	// A new invocation supersedes the previous algorithm, even for the same
	// URL or a clearing value. The synchronous host fetch can reenter it.
	video.poster_fetch_generation_++
	generation := video.poster_fetch_generation_
	poster := video.poster_ or {
		video.poster_frame_ = none
		video.update_natural_dimensions()
		return
	}

	if poster == '' {
		video.poster_frame_ = none
		video.update_natural_dimensions()
		return
	}
	url := video.parse_poster_url(poster) or {
		video.poster_frame_ = none
		video.update_natural_dimensions()
		return
	}
	fetch := video.poster_fetch_hook or {
		video.poster_frame_ = none
		video.update_natural_dimensions()
		return
	}

	frame := fetch(url) or {
		if generation != video.poster_fetch_generation_ {
			return
		}
		video.poster_frame_ = none
		video.update_natural_dimensions()
		return
	}
	if generation != video.poster_fetch_generation_ {
		return
	}
	video.poster_frame_ = frame
	video.update_natural_dimensions()
}

pub fn (mut video HTMLVideoElementModel) set_video_dimensions(width u32, height u32) {
	video.set_intrinsic_video_dimensions(VideoDimensions{width, height})
}

pub fn (mut video HTMLVideoElementModel) set_video_width(width u32) {
	height := if dimensions := video.intrinsic_video_dimensions_ { dimensions.height } else { 0 }
	video.set_intrinsic_video_dimensions(VideoDimensions{width, height})
}

pub fn (mut video HTMLVideoElementModel) set_video_height(height u32) {
	width := if dimensions := video.intrinsic_video_dimensions_ { dimensions.width } else { 0 }
	video.set_intrinsic_video_dimensions(VideoDimensions{width, height})
}

pub fn (video &HTMLVideoElementModel) supports_dimension_attributes() bool {
	_ = video
	return true
}

pub fn (video &HTMLVideoElementModel) video_width() u32 {
	if video.media.ready_state() == .have_nothing {
		return 0
	}
	return if dimensions := video.intrinsic_video_dimensions_ { dimensions.width } else { 0 }
}

pub fn (video &HTMLVideoElementModel) video_height() u32 {
	if video.media.ready_state() == .have_nothing {
		return 0
	}
	return if dimensions := video.intrinsic_video_dimensions_ { dimensions.height } else { 0 }
}

pub fn (mut video HTMLVideoElementModel) set_current_frame(frame ?&dom.Bitmap_) {
	video.set_current_video_frame(if bitmap := frame {
		?&painting.MediaVideoFrame(painting.MediaVideoFrame.from_bitmap(bitmap))
	} else {
		?&painting.MediaVideoFrame(none)
	})
}

pub fn (mut video HTMLVideoElementModel) set_current_video_frame(frame ?&painting.MediaVideoFrame) {
	video.current_frame_ = frame
	mut media := video.media
	mut source := media.ensure_video_frame_source()
	source.update(frame)
	if current_frame := frame {
		video.set_intrinsic_video_dimensions(VideoDimensions{
			width: current_frame.width
			height: current_frame.height
		})
	}
}

fn video_dimensions_equal(left ?VideoDimensions, right ?VideoDimensions) bool {
	if left == none || right == none {
		return left == none && right == none
	}
	left_value := left or { return false }
	right_value := right or { return false }
	return left_value == right_value
}

pub fn (mut video HTMLVideoElementModel) set_intrinsic_video_dimensions(dimensions ?VideoDimensions) {
	if video_dimensions_equal(video.intrinsic_video_dimensions_, dimensions) {
		return
	}
	video.intrinsic_video_dimensions_ = dimensions
	if dimensions != none {
		mut media := video.media
		media.queue_a_media_element_task(fn [mut media] () {
			media.fire_event('resize')
		})
	}
	video.update_natural_dimensions()
}

pub fn (mut video HTMLVideoElementModel) update_natural_dimensions() {
	mut dimensions := video.intrinsic_video_dimensions_
	if video.current_representation() == .poster_frame {
		if poster := video.poster_frame_ {
			dimensions = VideoDimensions{
				width: u32(poster.width)
				height: u32(poster.height)
			}
		}
	}
	if video_dimensions_equal(video.natural_dimensions_, dimensions) {
		video.push_video_paint_facts()
		return
	}
	video.natural_dimensions_ = dimensions
	if html_element := video.media.associated_element_ {
		mut node := unsafe { &dom.Element(html_element) }.as_node()
		node.set_needs_layout_update(.html_video_element_natural_dimensions_changed)
	}
	video.push_video_paint_facts()
}

pub fn (video &HTMLVideoElementModel) natural_media_size() ?VideoDimensions {
	return video.intrinsic_video_dimensions_
}

pub fn (video &HTMLVideoElementModel) natural_element_size() ?VideoDimensions {
	return video.natural_dimensions_
}

pub fn (video &HTMLVideoElementModel) poster_frame() ?&dom.Bitmap_ {
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

pub fn (video &HTMLVideoElementModel) current_decoded_image_frame() ?&dom.DecodedImageFrame_ {
	frame := if source := video.media.video_frame_source_ {
		source.current_frame()
	} else {
		video.current_frame_
	}
	current_frame := frame or { return none }
	bitmap := current_frame.to_bitmap() or { return none }
	return dom.DecodedImageFrame_.create_with_color_space(bitmap, current_frame.decoded_color_space)
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
	base_url_              dom.URL
	src_                   string
	track_url_             string
	loading_               bool
	processing_generation_ u64
	source_cue_generation_ u64
	awaiting_url_change    bool
	parent_media_          ?&HTMLMediaElement
	dom_element_           ?&dom.HTMLTrackElement
	fetch_hook_            ?TextTrackFetchHook
	event_target_          &dom.EventTarget = unsafe { nil }
	event_counts_          map[string]int
}

pub fn HTMLTrackElementModel.create(base_url dom.URL) &HTMLTrackElementModel {
	return create_track_element_model(base_url, dom.EventTarget.new())
}

fn create_track_element_model(base_url dom.URL, event_target &dom.EventTarget) &HTMLTrackElementModel {
	return &HTMLTrackElementModel{
		track: TextTrack.create()
		base_url_: base_url
		event_target_: event_target
	}
}

pub fn html_track_element_model_for_dom_element(element &dom.HTMLTrackElement) &HTMLTrackElementModel {
	if element.track_element_model_ != unsafe { nil } {
		return unsafe { &HTMLTrackElementModel(element.track_element_model_) }
	}
	dom_element := unsafe { &dom.Element(element) }
	mut model := create_track_element_model(dom_element.document().base_url(),
		unsafe { &dom.EventTarget(element) })
	model.dom_element_ = element
	model.set_kind(dom_element.get_attribute_ns(none, 'kind') or { '' })
	model.set_label(dom_element.get_attribute_ns(none, 'label') or { '' })
	model.set_srclang(dom_element.get_attribute_ns(none, 'srclang') or { '' })
	if source := dom_element.get_attribute_ns(none, 'src') {
		model.set_src(source)
	}
	mut track := model.track
	track.set_id(dom_element.get_attribute_ns(none, 'id') or { '' })
	mut mutable_element := unsafe { &dom.HTMLTrackElement(element) }
	mutable_element.track_element_model_ = model
	mutable_element.track_attribute_changed_hook_ = html_track_element_content_attribute_changed
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

fn (element &HTMLTrackElementModel) current_parent_media() ?&HTMLMediaElement {
	if owner := element.dom_element_ {
		dom_element := unsafe { &dom.Element(owner) }
		if parent := dom_element.as_node().parent_element() {
			return html_media_element_for_dom_element(parent)
		}
		return none
	}
	return element.parent_media_
}

fn (mut element HTMLTrackElementModel) clear_source_cues() {
	element.source_cue_generation_++
	mut track := element.track
	track.clear_cues()
}

pub fn (mut element HTMLTrackElementModel) set_src(value string) {
	element.clear_source_cues()
	element.src_ = value
	if value == '' {
		element.set_track_url('')
		return
	}
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
	if element.track.mode() in [.hidden, .showing] && (element.loading_ || element.awaiting_url_change) {
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
		end_fields := timing[1].trim_space().fields()
		if end_fields.len == 0 {
			continue
		}
		end := parse_vtt_timestamp(end_fields[0]) or { continue }
		mut cue := TextTrackCue.create(start, end, lines[timing_index + 1..].join('\n')) or {
			continue
		}
		cue.set_id(identifier)
		cues << cue
	}
	return cues
}

pub fn (mut element HTMLTrackElementModel) start_the_track_processing_model() {
	if element.loading_ || element.track.mode() !in [.hidden, .showing] || element.current_parent_media() == none {
		return
	}
	element.loading_ = true
	element.start_the_track_processing_model_parallel_steps()
}

pub fn (mut element HTMLTrackElementModel) start_the_track_processing_model_parallel_steps() {
	element.processing_generation_++
	generation := element.processing_generation_
	element.loading_ = true
	element.awaiting_url_change = false
	mut track := element.track
	track.set_readiness_state(.loading)
	if generation != element.processing_generation_ {
		return
	}
	if element.track_url_ == '' {
		element.track_failed_to_load()
		return
	}
	url := dom.dom_url_parse(element.track_url_, element.base_url_, 'UTF-8') or {
		element.track_failed_to_load()
		return
	}
	fetch := element.fetch_hook_ or {
		element.track_failed_to_load()
		return
	}

	cors := if media := element.current_parent_media() {
		media.crossorigin()
	} else {
		CORSSettingAttribute.no_cors
	}
	cue_generation := element.source_cue_generation_
	response := fetch(url, cors) or {
		if generation != element.processing_generation_ {
			return
		}
		element.track_failed_to_load()
		return
	}
	if generation != element.processing_generation_ {
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
	if cue_generation == element.source_cue_generation_ {
		for mut cue in cues {
			track.add_cue(mut cue)
		}
	}
	element.loading_ = false
	element.track_became_ready()
	track.set_readiness_state(.loaded)
	if generation != element.processing_generation_ {
		return
	}
	element.fire_event('load')
}

pub fn (mut element HTMLTrackElementModel) track_became_ready() {
	element.awaiting_url_change = true
}

fn (mut element HTMLTrackElementModel) track_failed_to_load() {
	generation := element.processing_generation_
	element.loading_ = false
	mut track := element.track
	element.track_became_ready()
	track.set_readiness_state(.failed_to_load)
	if generation != element.processing_generation_ {
		return
	}
	element.fire_event('error')
}

pub fn html_track_element_attribute_changed(element &dom.HTMLTrackElement, name string, old_value ?string, value ?string, namespace_ ?string) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.attribute_changed(name, old_value, value, namespace_)
	if namespace_ != none {
		return
	}
	html_track_element_content_attribute_changed(element, name, value)
}

fn html_track_element_content_attribute_changed(element &dom.HTMLTrackElement, name string, value ?string) {
	mut model := html_track_element_model_for_dom_element(element)
	model.content_attribute_changed(element, name, value)
}

fn (mut model HTMLTrackElementModel) content_attribute_changed(element &dom.HTMLTrackElement, name string, value ?string) {
	match name.to_lower() {
		'kind' { model.set_kind(value or { '' }) }
		'label' { model.set_label(value or { '' }) }
		'srclang' { model.set_srclang(value or { '' }) }
		'src' {
			if source := value {
				model.base_url_ = unsafe { &dom.Element(element) }.document().base_url()
				model.set_src(source)
			} else {
				model.clear_source_cues()
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

struct MediaControlsTimelineRange {
	start f64
	end   f64
}

fn (range MediaControlsTimelineRange) span() f64 {
	return range.end - range.start
}

fn (range MediaControlsTimelineRange) progress_at(time f64) f64 {
	return (time - range.start) / range.span()
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
	pending_scrub_seek_time_     ?f64
	scrub_seek_preemption_timer_ ?&platform.Timer
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
				tag_name := if class_name == 'fullscreen-icon' { 'button' } else { 'div' }
				mut child := dom.create_element(document, tag_name, ns_html, none, none, false) or { continue }
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
		'seeked' {
			mutable_controls.update_placeholder_visibility()
			if mutable_controls.scrubbing_timeline != .no {
				mutable_controls.submit_pending_scrub_seek()
			}
		}
		'timeupdate', 'durationchange' {
			mutable_controls.update_timeline()
			mutable_controls.update_timestamp()
		}
		'volumechange', 'addtrack', 'removetrack' { mutable_controls.update_volume_and_mute_indicator() }
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
	controls_pointer := voidptr(&controls)
	for event_name in ['play', 'pause', 'playing', 'seeked', 'timeupdate', 'durationchange',
		'volumechange', 'loadedmetadata', 'emptied'] {
		controls.add_event_listener(controls.media.event_target(), event_name, .no,
			fn [controls_pointer] (event &dom.Event) bool {
				controls := unsafe { &MediaControls(controls_pointer) }
				return media_controls_state_handler(controls, event)
			})
	}
	for event_name in ['addtrack', 'removetrack'] {
		controls.add_event_listener(controls.media.audio_tracks().event_target(), event_name, .no,
			fn [controls_pointer] (event &dom.Event) bool {
				controls := unsafe { &MediaControls(controls_pointer) }
				return media_controls_state_handler(controls, event)
			})
	}
	controls.add_event_listener(controls.media.event_target(), 'keydown', .no,
		fn [controls_pointer] (event &dom.Event) bool {
			keyboard_event := unsafe { &dom.KeyboardEvent(event) }
			if keyboard_event.key_code() != u32(dom.KeyCode.f) {
				return false
			}
			mut controls := unsafe { &MediaControls(controls_pointer) }
			controls.toggle_fullscreen()
			return true
		})
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

pub fn (mut controls MediaControls) begin_timeline_scrubbing(time f64) {
	mut media := controls.media
	controls.scrubbing_timeline = .while_paused
	if !media.paused() {
		media.pause()
		controls.scrubbing_timeline = .while_playing
	}
	controls.pending_scrub_seek_time_ = time
	controls.submit_pending_scrub_seek()
}

pub fn (mut controls MediaControls) seek_while_scrubbing(time f64) {
	controls.pending_scrub_seek_time_ = time
	if controls.media.seeking() {
		return
	}
	controls.submit_pending_scrub_seek()
}

fn (mut controls MediaControls) submit_pending_scrub_seek() {
	time := controls.pending_scrub_seek_time_ or { return }
	controls.pending_scrub_seek_time_ = none
	if mut timer := controls.scrub_seek_preemption_timer_ {
		timer.restart()
	} else {
		controls_pointer := voidptr(&controls)
		mut timer := platform.Timer.create_single_shot(500, fn [controls_pointer] () {
			mut controls := unsafe { &MediaControls(controls_pointer) }
			controls.submit_pending_scrub_seek()
		})
		timer.start()
		controls.scrub_seek_preemption_timer_ = timer
	}
	controls.set_current_time(time)
}

pub fn (mut controls MediaControls) end_timeline_scrubbing(time f64) {
	was_playing := controls.scrubbing_timeline == .while_playing
	controls.scrubbing_timeline = .no
	controls.pending_scrub_seek_time_ = none
	if mut timer := controls.scrub_seek_preemption_timer_ {
		timer.stop()
	}
	controls.scrub_seek_preemption_timer_ = none
	controls.set_current_time(time)
	if was_playing {
		mut media := controls.media
		if !media.ended() {
			_ = media.play()
		}
	}
	controls.update_play_pause_icon()
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

fn (controls &MediaControls) timeline_range() ?MediaControlsTimelineRange {
	seekable := controls.media.seekable()
	if seekable.length() == 0 {
		return none
	}
	index := seekable.length() - 1
	range_ := MediaControlsTimelineRange{
		start: seekable.start(index) or { return none }
		end: seekable.end(index) or { return none }
	}
	if math.is_nan(range_.start) || math.is_nan(range_.end)
		|| math.is_inf(range_.start, 0) || math.is_inf(range_.end, 0) || range_.span() <= 0 {
		return none
	}
	return range_
}

pub fn (mut controls MediaControls) update_timeline() {
	range_ := controls.timeline_range()
	percentage := if value := range_ {
		math.max(0.0, math.min(1.0, value.progress_at(controls.media.current_time()))) * 100.0
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
	controls.timestamp = if math.is_inf(duration, 0) {
		current
	} else {
		total := media_timestamp(if math.is_nan(duration) { 0.0 } else { math.round(duration) })
		'${current} / ${total}'
	}
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
