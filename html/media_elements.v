// Copyright (c) 2020-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLVideoElement.{h,cpp}, HTMLAudioElement.{h,cpp},
// HTMLTrackElement.{h,cpp}, and MediaControls.{h,cpp}. Bitmap/frame delivery,
// VTT fetching, and fullscreen remain explicit host-facing inputs.
module html

import dom
import css
import fetch as webfetch
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

// The Source request record reaches hosts that implement the Fetch boundary.
// The URL-only hook remains a compatibility adapter for existing decoders.
pub type PosterFrameRequestFetchHook = fn (&webfetch.Request) !&dom.Bitmap_

// Encoded bytes and the platform decoder remain explicit host inputs.
pub type PosterFrameDecodeHook = fn ([]u8) !DecodedImageData

@[heap]
pub struct PosterFrameFetchTransport {
pub:
	host   &webfetch.FetchHost @[required]
	decode PosterFrameDecodeHook @[required]
}

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
	poster_request_fetch_hook   ?PosterFrameRequestFetchHook
	poster_fetch_transport_     ?&PosterFrameFetchTransport
	poster_fetch_controller_    ?&webfetch.FetchController
	poster_fetch_finished_generation_ u64
	paint_facts_update_hook     ?VideoPaintFactsUpdateHook
	poster_fetch_generation_    u64
	poster_load_event_delayer_  ?dom.DocumentLoadEventDelayer
}

pub fn HTMLVideoElementModel.create(media &HTMLMediaElement, base_url dom.URL) &HTMLVideoElementModel {
	mut model := &HTMLVideoElementModel{
		media: media
		base_url_: base_url
	}
	mut mutable_media := unsafe { &HTMLMediaElement(media) }
	mutable_media.video_element_model_ = model
	if track := media.selected_video_track_ {
		model.intrinsic_video_dimensions_ = VideoDimensions{
			width: track.base.pixel_width
			height: track.base.pixel_height
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
	mut model := HTMLVideoElementModel.create(media, dom_element.document().base_url())
	// Attribute changes before lazy model creation have no HTML hook to notify.
	model.poster_ = dom_element.get_attribute_ns(none, 'poster')
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

pub fn (mut video HTMLVideoElementModel) set_poster_request_fetch_hook(hook ?PosterFrameRequestFetchHook) {
	video.poster_request_fetch_hook = hook
}

pub fn (mut video HTMLVideoElementModel) set_poster_fetch_transport(transport ?&PosterFrameFetchTransport) {
	video.poster_fetch_transport_ = transport
}

fn (mut video HTMLVideoElementModel) finish_poster_fetch(generation u64, frame ?&dom.Bitmap_) {
	if generation != video.poster_fetch_generation_ { return }
	video.poster_fetch_finished_generation_ = generation
	video.poster_fetch_controller_ = none
	video.poster_frame_ = frame
	video.finish_delaying_poster_load_event()
	video.update_natural_dimensions()
}

fn (mut video HTMLVideoElementModel) start_poster_fetch(request &webfetch.Request, generation u64,
	transport &PosterFrameFetchTransport) {
	algorithms := webfetch.FetchAlgorithms.create(webfetch.FetchAlgorithmsInput{
		process_response_consume_body: fn [mut video, generation, transport] (response &webfetch.Response, body webfetch.BodyBytes) {
			if generation != video.poster_fetch_generation_ { return }
			if response.is_network_error() || body.kind == .failure {
				video.finish_poster_fetch(generation, none)
				return
			}
			// Source VERIFY(response->body()) remains active for malformed hosts.
			if body.kind == .empty { panic('Video poster response requires a body') }
			decoded := transport.decode(body.bytes) or {
				video.finish_poster_fetch(generation, none)
				return
			}
			frame := if first := decoded.frame(0) { ?&dom.Bitmap_(first.bitmap()) } else { ?&dom.Bitmap_(none) }
			video.finish_poster_fetch(generation, frame)
		}
	})
	mut controller := webfetch.fetch(request, algorithms, transport.host, .no)
	// A host can reenter during fetch, or a client-less fetch can finish inline.
	if generation != video.poster_fetch_generation_ || generation == video.poster_fetch_finished_generation_ {
		controller.stop_fetch()
		return
	}
	video.poster_fetch_controller_ = controller
}

fn (video &HTMLVideoElementModel) fetch_poster_frame(request &webfetch.Request) !&dom.Bitmap_ {
	if hook := video.poster_request_fetch_hook {
		return hook(request)!
	}
	if hook := video.poster_fetch_hook {
		return hook(request.current_url())!
	}
	return error('No poster fetch hook')
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

fn (mut video HTMLVideoElementModel) finish_delaying_poster_load_event() {
	if mut delayer := video.poster_load_event_delayer_ {
		delayer.finish()
		video.poster_load_event_delayer_ = none
	}
}

fn (mut video HTMLVideoElementModel) retarget_poster_load_event_delay() {
	if video.poster_load_event_delayer_ == none {
		return
	}
	video.finish_delaying_poster_load_event()
	mut document := video.media.document() or { return }
	video.poster_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut document)
}

pub fn (mut video HTMLVideoElementModel) determine_element_poster_frame() {
	// A new invocation supersedes the previous algorithm, even for the same
	// URL or a clearing value. Hosts and decoder callbacks can reenter it.
	video.poster_fetch_generation_++
	generation := video.poster_fetch_generation_
	if mut controller := video.poster_fetch_controller_ {
		video.poster_fetch_controller_ = none
		controller.stop_fetch()
	}
	if generation != video.poster_fetch_generation_ { return }
	video.finish_delaying_poster_load_event()
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
	if video.poster_fetch_transport_ == none && video.poster_request_fetch_hook == none && video.poster_fetch_hook == none {
		video.poster_frame_ = none
		video.update_natural_dimensions()
		return
	}
	mut request := webfetch.Request.create()
	request.set_url(url)
	if document := video.media.document() {
		settings := document.relevant_settings_object()
		if settings != unsafe { nil } {
			request.set_client(unsafe { &EnvironmentSettingsObject(settings) })
		}
	}
	request.set_destination(.image)
	request.set_initiator_type(.video)
	request.set_credentials_mode(.include)
	request.set_use_url_credentials(true)
	if mut document := video.media.document() {
		video.poster_load_event_delayer_ = dom.DocumentLoadEventDelayer.new(mut document)
	}

	if transport := video.poster_fetch_transport_ {
		video.start_poster_fetch(request, generation, transport)
		return
	}

	frame := video.fetch_poster_frame(request) or {
		if generation != video.poster_fetch_generation_ {
			return
		}
		video.poster_frame_ = none
		video.finish_delaying_poster_load_event()
		video.update_natural_dimensions()
		return
	}
	if generation != video.poster_fetch_generation_ {
		return
	}
	video.poster_frame_ = frame
	video.finish_delaying_poster_load_event()
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
	if video.media.paused() && video.media.current_playback_position() == 0 && video.media.show_poster() {
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

fn (element &HTMLTrackElementModel) parse_source_url(value string) ?dom.URL {
	if owner := element.dom_element_ {
		return unsafe { &dom.Element(owner) }.document().encoding_parse_url(value)
	}
	return dom.dom_url_parse(value, element.base_url_, 'UTF-8')
}

pub fn (mut element HTMLTrackElementModel) set_src(value string) {
	element.clear_source_cues()
	element.src_ = value
	if value == '' {
		element.set_track_url('')
		return
	}
	parsed := element.parse_source_url(value) or {
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
	control_bar        ?&dom.Element
	play_pause_icon    ?&dom.Element
	timeline_track     ?&dom.Element
	timeline_fill      ?&dom.Element
	timestamp_element  ?&dom.Element
	volume_area        ?&dom.Element
	volume_fill        ?&dom.Element
	mute_button        ?&dom.Element
	fullscreen_icon    ?&dom.Element
	placeholder_circle ?&dom.Element
}

struct MediaControlsBufferedRange {
	element &dom.Element @[required]
mut:
	left f64
	width f64
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
	buffered_ranges_            []MediaControlsBufferedRange
	pending_scrub_seek_time_     ?f64
	scrub_seek_preemption_timer_ ?&platform.Timer
	last_timestamp_time_        i64 = -1
	last_timestamp_duration_    ?i64
	last_timeline_progress_     f64
}

pub fn MediaControls.create(media &HTMLMediaElement) &MediaControls {
	mut controls := &MediaControls{
		media: media
	}
	controls.create_shadow_tree()
	controls.set_up_event_listeners()
	return controls
}

fn media_timestamp(seconds i64) string {
	hours := seconds / 3600
	minutes := (seconds / 60) % 60
	secs := seconds % 60
	return if hours > 0 { '${hours:02d}:${minutes:02d}:${secs:02d}' } else { '${minutes:02d}:${secs:02d}' }
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
			is_video := media_element.is_html_element() && media_element.local_name() == 'video'
			shadow := media_element.attach_a_user_agent_shadow_root(.named)
			document := media_element.document()
			mut container := dom.create_element(document, 'div', ns_html, none, none, false) or {
				controls.update()
				controls.show_controls()
				return
			}
			container.set_attribute_value('class', if is_video { 'media-controls video' } else { 'media-controls audio' })
			mut bar := dom.create_element(document, 'div', ns_html, none, none, false) or { panic(err) }
			bar.set_attribute_value('class', 'controls')
			mut container_node := container.as_node()
			container_node.append_child(bar.as_node()) or { panic(err) }
			controls.dom_.control_bar = bar
			mut created := []&dom.Element{}
			for class_name in ['play-pause-icon', 'timeline-fill', 'timestamp', 'volume-area',
				'volume-fill', 'mute-button', 'fullscreen-icon', 'placeholder-circle'] {
				if class_name in ['fullscreen-icon', 'placeholder-circle'] && !is_video { continue }
				tag_name := if class_name == 'fullscreen-icon' { 'button' } else { 'div' }
				mut child := dom.create_element(document, tag_name, ns_html, none, none, false) or { continue }
				child.set_attribute_value('class', class_name)
				mut parent_node := if class_name == 'placeholder-circle' { container.as_node() } else { bar.as_node() }
				if class_name == 'timeline-fill' {
					mut track := dom.create_element(document, 'div', ns_html, none, none, false) or { panic(err) }
					track.set_attribute_value('class', 'timeline-track')
					mut track_node := track.as_node()
					track_node.append_child(child.as_node()) or { panic(err) }
					parent_node.append_child(track_node) or { panic(err) }
					controls.dom_.timeline_track = track
				} else {
					parent_node.append_child(child.as_node()) or { continue }
				}
				created << child
			}
			mut shadow_node := unsafe { &dom.Node(shadow) }
			shadow_node.append_child(container.as_node()) or {}
			controls.dom_.container = container
			expected_children := if is_video { 8 } else { 6 }
			if created.len == expected_children {
				controls.dom_.play_pause_icon = created[0]
				controls.dom_.timeline_fill = created[1]
				controls.dom_.timestamp_element = created[2]
				controls.dom_.volume_area = created[3]
				controls.dom_.volume_fill = created[4]
				controls.dom_.mute_button = created[5]
				if is_video {
					controls.dom_.fullscreen_icon = created[6]
					controls.dom_.placeholder_circle = created[7]
				}
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
		'progress' { mutable_controls.update_timeline() }
		'volumechange', 'addtrack', 'removetrack' { mutable_controls.update_volume_and_mute_indicator() }
		'loadedmetadata' {
			mutable_controls.update_timestamp()
			mutable_controls.update_volume_and_mute_indicator()
		}
		'emptied' {
			mutable_controls.update_placeholder_visibility()
			mutable_controls.update_timeline()
			mutable_controls.update_timestamp()
			mutable_controls.update_volume_and_mute_indicator()
		}
		else {}
	}
	return true
}

pub fn (mut controls MediaControls) set_up_event_listeners() {
	controls_pointer := voidptr(&controls)
	for event_name in ['play', 'pause', 'playing', 'seeked', 'timeupdate', 'durationchange', 'progress',
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
	if controls.dom_.fullscreen_icon != none {
		if html_element := controls.media.associated_element_ {
			element := unsafe { &dom.Element(html_element) }
			controls.add_event_listener(unsafe { &dom.EventTarget(element.document()) }, 'fullscreenchange', .no,
				fn [controls_pointer] (_ &dom.Event) bool {
					mut controls := unsafe { &MediaControls(controls_pointer) }
					controls.update_fullscreen_icon()
					return true
				})
		}
	}
	controls.set_up_hover_event_listeners()
	controls.add_event_listener(controls.media.event_target(), 'keydown', .no,
		fn [controls_pointer] (event &dom.Event) bool {
			if event.interface_ != .keyboard_event { return false }
			keyboard_event := unsafe { &dom.KeyboardEvent(event) }
			mut controls := unsafe { &MediaControls(controls_pointer) }
			match keyboard_event.key_code() {
				u32(dom.KeyCode.space) { controls.toggle_playback() }
				u32(dom.KeyCode.home) { controls.set_current_time(0) }
				u32(dom.KeyCode.end) {
					range_ := controls.timeline_range() or { return false }
					controls.set_current_time(range_.end)
				}
				u32(dom.KeyCode.right) { controls.set_current_time(controls.media.current_time() + 5) }
				u32(dom.KeyCode.left) { controls.set_current_time(controls.media.current_time() - 5) }
				u32(dom.KeyCode.up) { controls.set_volume(controls.media.volume() + 0.1) or { panic(err) } }
				u32(dom.KeyCode.down) { controls.set_volume(controls.media.volume() - 0.1) or { panic(err) } }
				u32(dom.KeyCode.m) { controls.toggle_mute() }
				u32(dom.KeyCode.f) { controls.toggle_fullscreen() }
				else { return false }
			}
			return true
		})
}

fn (mut controls MediaControls) set_up_hover_event_listeners() {
	html_element := controls.media.associated_element_ or { return }
	element := unsafe { &dom.Element(html_element) }
	if !element.is_html_element() || element.local_name() != 'video' { return }
	bar := controls.dom_.control_bar or { return }
	controls_pointer := voidptr(&controls)
	for event_name in ['mouseenter', 'mousemove', 'mouseleave'] {
		controls.add_event_listener(controls.media.event_target(), event_name, .no,
			fn [controls_pointer] (event &dom.Event) bool {
				mut controls := unsafe { &MediaControls(controls_pointer) }
				if event.type_ == 'mouseleave' { controls.hide_controls() } else { controls.show_controls() }
				return true
			})
	}
	for event_name in ['mouseenter', 'mouseleave'] {
		controls.add_event_listener(unsafe { &dom.EventTarget(bar.as_node()) }, event_name, .no,
			fn [controls_pointer] (event &dom.Event) bool {
				mut controls := unsafe { &MediaControls(controls_pointer) }
				controls.hovering_controls = event.type_ == 'mouseenter'
				controls.show_controls()
				return true
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

pub fn (mut controls MediaControls) begin_timeline_scrubbing(time f64) {
	mut media := controls.media
	controls.scrubbing_timeline = .while_paused
	if !media.paused() {
		media.pause()
		controls.scrubbing_timeline = .while_playing
	}
	controls.pending_scrub_seek_time_ = time
	controls.submit_pending_scrub_seek()
	if range_ := controls.timeline_range() {
		controls.set_timeline_progress(math.max(0.0, math.min(1.0, range_.progress_at(time))))
	}
	controls.set_timestamp(time, controls.media.duration())
}

pub fn (mut controls MediaControls) seek_while_scrubbing(time f64) {
	controls.pending_scrub_seek_time_ = time
	if !controls.media.seeking() {
		controls.submit_pending_scrub_seek()
	}
	if range_ := controls.timeline_range() {
		controls.set_timeline_progress(math.max(0.0, math.min(1.0, range_.progress_at(time))))
	}
	controls.set_timestamp(time, controls.media.duration())
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
		mut classes := icon.class_list()
		classes.toggle('playing', !paused) or { panic(err) }
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
	if controls.scrubbing_timeline == .no {
		progress := if value := range_ {
			math.max(0.0, math.min(1.0, value.progress_at(controls.media.current_time())))
		} else {
			0.0
		}
		controls.set_timeline_progress(progress)
	}
	buffered := controls.media.buffered()
	range_count := if range_ != none { int(buffered.length()) } else { 0 }
	track := controls.dom_.timeline_track or { return }
	for controls.buffered_ranges_.len > range_count {
		last := controls.buffered_ranges_.pop()
		mut node := last.element.as_node()
		node.remove(false)
	}
	for controls.buffered_ranges_.len < range_count {
		mut element := dom.create_element(controls.media.document() or { panic('Missing buffered timeline document') },
			'div', ns_html, none, none, false) or { panic(err) }
		element.set_attribute_value('class', 'timeline-buffered')
		mut style := css.element_style(element)
		style.set_property('display', 'block', '') or { panic(err) }
		mut track_node := track.as_node()
		track_node.append_child(element.as_node()) or { panic(err) }
		controls.buffered_ranges_ << MediaControlsBufferedRange{element: element}
	}
	value := range_ or { return }
	for i in 0 .. range_count {
		start := buffered.start(u32(i)) or { panic(err) }
		end := buffered.end(u32(i)) or { panic(err) }
		left := value.progress_at(start)
		width := (end - start) / value.span()
		mut cached := &controls.buffered_ranges_[i]
		if cached.left == left && cached.width == width { continue }
		cached.left = left
		cached.width = width
		mut style := css.element_style(cached.element)
		style.set_property('left', '${left * 100}%', '') or { panic(err) }
		style.set_property('width', '${width * 100}%', '') or { panic(err) }
	}
}

fn (mut controls MediaControls) set_timeline_progress(progress f64) {
	if controls.last_timeline_progress_ == progress { return }
	if fill := controls.dom_.timeline_fill {
		mut style := css.element_style(fill)
		style.set_property('width', '${progress * 100}%', '') or { panic(err) }
	}
	controls.last_timeline_progress_ = progress
	controls.timeline_percentage = progress * 100
}

pub fn (mut controls MediaControls) update_timestamp() {
	time := if controls.scrubbing_timeline == .no { controls.media.current_time() } else { f64(controls.last_timestamp_time_) }
	controls.set_timestamp(time, controls.media.duration())
}

fn (mut controls MediaControls) set_timestamp(time f64, duration f64) {
	rounded_time := i64(math.round_to_even(time))
	mut rounded_duration := ?i64(none)
	if !math.is_inf(duration, 0) {
		rounded_duration = if math.is_nan(duration) { i64(0) } else { i64(math.round_to_even(duration)) }
	}
	if rounded_time == controls.last_timestamp_time_ && rounded_duration == controls.last_timestamp_duration_ { return }
	controls.last_timestamp_time_ = rounded_time
	controls.last_timestamp_duration_ = rounded_duration
	current := media_timestamp(rounded_time)
	controls.timestamp = if total := rounded_duration {
		'${current} / ${media_timestamp(total)}'
	} else {
		current
	}
	if element := controls.dom_.timestamp_element {
		mut node := element.as_node()
		node.set_text_content(controls.timestamp) or { panic(err) }
	}
}

fn media_controls_mute_icon_class(icon MediaControlsMuteIcon) string {
	return match icon {
		.empty { '' }
		.low { 'low' }
		.high { 'high' }
	}
}

pub fn (mut controls MediaControls) update_volume_and_mute_indicator() {
	volume := controls.media.volume()
	has_audio := controls.media.audio_tracks().length() > 0
	muted := !has_audio || controls.media.muted()
	controls.volume_percentage = if muted { 0.0 } else { volume * 100.0 }
	new_icon := if volume > 0.5 {
		MediaControlsMuteIcon.high
	} else if volume > 0 {
		.low
	} else {
		.empty
	}
	controls.had_audio = has_audio
	if fill := controls.dom_.volume_fill {
		mut style := css.element_style(fill)
		style.set_property('width', if muted { '0' } else { '${controls.volume_percentage}%' }, '') or { panic(err) }
	}
	if new_icon != controls.mute_icon {
		if mut button := controls.dom_.mute_button {
			mut classes := button.class_list()
			previous := media_controls_mute_icon_class(controls.mute_icon)
			next := media_controls_mute_icon_class(new_icon)
			if previous != '' { classes.remove([previous]) or { panic(err) } }
			if next != '' { classes.add([next]) or { panic(err) } }
		}
		controls.mute_icon = new_icon
	}
	if muted != controls.was_muted {
		if mut button := controls.dom_.mute_button {
			mut classes := button.class_list()
			classes.toggle('muted', muted) or { panic(err) }
		}
		controls.was_muted = muted
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
		mut classes := icon.class_list()
		classes.toggle('fullscreen', is_fullscreen) or { panic(err) }
	}
}

pub fn (mut controls MediaControls) update_placeholder_visibility() {
	controls.placeholder_visible = controls.should_show_placeholder()
	if placeholder := controls.dom_.placeholder_circle {
		mut style := css.element_style(placeholder)
		style.set_property('display', if controls.placeholder_visible { 'flex' } else { 'none' }, '') or { panic(err) }
	}
}

pub fn (controls &MediaControls) should_show_placeholder() bool {
	if html_element := controls.media.associated_element_ {
		element := unsafe { &dom.Element(html_element) }
		if !element.is_html_element() || element.local_name() != 'video' { return false }
		video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		return video.current_representation() != .video_frame
	}
	if video := controls.media.video_element_model_ {
		return video.current_representation() != .video_frame
	}
	// Ownerless media without a video model retains its compatibility state query.
	return controls.media.ready_state() == .have_nothing || controls.media.show_poster()
}

pub fn (mut controls MediaControls) show_controls() {
	if mut bar := controls.dom_.control_bar {
		mut classes := bar.class_list()
		classes.add(['visible']) or { panic(err) }
	}
	controls.visible = true
}

pub fn (mut controls MediaControls) hide_controls() {
	if controls.scrubbing_timeline == .no && !controls.scrubbing_volume && !controls.hovering_controls {
		if controls.dom_.placeholder_circle != none && controls.should_show_placeholder() { return }
		if mut bar := controls.dom_.control_bar {
			mut classes := bar.class_list()
			classes.remove(['visible']) or { panic(err) }
		}
		controls.visible = false
	}
}
