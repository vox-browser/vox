// Copyright (c) 2020, the SerenityOS developers
// Copyright (c) 2023-2026, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLMediaElement.{h,cpp}. Decoder/network integration is
// supplied by MediaResourceFetchHook; the HTML state machine remains local.
module html

import dom
import fileapi
import url as liburl
import math
import page
import painting
import time
import webidl

pub enum MediaSeekMode {
	accurate
	approximate_for_speed
}

pub enum MediaPlaybackSeekMode {
	accurate
	fast_before
	fast_after
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

pub enum MediaPlaybackDirection {
	forwards
	backwards
}

pub enum TimeMarchesOnReason {
	normal_playback
	other
}

pub type MediaElementTask = fn()

pub type MediaPlaybackNoArgHook = fn()

pub type MediaPlaybackSetVolumeHook = fn(f64)

pub type MediaPlaybackSetRateHook = fn(f32)

pub type MediaPlaybackSetAudioTrackHook = fn(&AudioTrack, bool)

pub type MediaPlaybackSetVideoTrackHook = fn(?&VideoTrack)

pub type MediaPlaybackSeekHook = fn(f64, MediaPlaybackSeekMode)

pub type MediaPlaybackCurrentTimeHook = fn() f64

pub type MediaPlaybackCurrentFrameHook = fn () ?&painting.MediaVideoFrame

pub type MediaPlaybackStartTimeRealtimeHook = fn () ?i64

pub struct MediaBufferedRange {
pub:
	start f64
	end   f64
}

pub type MediaPlaybackBufferedRangesHook = fn () []MediaBufferedRange

// Host callbacks corresponding to LibMedia::PlaybackManager. Keeping this
// boundary explicit lets the HTML state machine remain a direct translation
// without importing a platform decoder into the html module.
pub struct MediaPlaybackManagerHooks {
pub:
	start               ?MediaPlaybackNoArgHook
	play                ?MediaPlaybackNoArgHook
	pause               ?MediaPlaybackNoArgHook
	set_volume          ?MediaPlaybackSetVolumeHook
	set_playback_rate   ?MediaPlaybackSetRateHook
	set_audio_track     ?MediaPlaybackSetAudioTrackHook
	set_video_track     ?MediaPlaybackSetVideoTrackHook
	seek                ?MediaPlaybackSeekHook
	current_time        ?MediaPlaybackCurrentTimeHook
	current_video_frame ?MediaPlaybackCurrentFrameHook
	buffered_ranges     ?MediaPlaybackBufferedRangesHook
	start_time_realtime ?MediaPlaybackStartTimeRealtimeHook
}

pub struct MediaResourceResponse {
pub:
	status              u16 = 200
	mime_type           string
	duration            f64 = math.nan()
	total_length        u64
	buffered_end        f64
	audio_tracks        []MediaTrackMetadata
	video_tracks        []MediaTrackMetadata
	accepts_byte_ranges bool
	// FFmpeg exposes AVFormatContext::start_time_realtime in microseconds.
	start_time_realtime_microseconds ?i64
}

// JS::Date-compatible value returned by HTMLMediaElement.getStartDate(). A
// fresh object is allocated for every call, including the invalid-date case.
@[heap]
pub struct MediaStartDate {
mut:
	time_value_ f64
}

pub fn (date &MediaStartDate) get_time() f64 {
	return date.time_value_
}

pub type MediaResourceFetchHook = fn(dom.URL, u64) !MediaResourceResponse

pub type MediaResourceFailureCallback = fn(string)

pub struct MediaByteRange {
pub:
	offset u64
}

pub enum MediaProviderKind {
	blob
	media_source
}

pub type MediaSourceDetachHook = fn (voidptr, voidptr)

// HTML and MediaSourceExtensions mutually depend on one another upstream. V
// packages cannot form import cycles, so the MediaSource attachment operation
// crosses this small typed callback boundary while Blob remains fully typed.
pub struct MediaProviderObject {
pub:
	kind                MediaProviderKind
	blob                ?&fileapi.Blob
	media_source_handle voidptr
	media_source_attach ?fileapi.BlobURLMediaSourceAttachHook
}

pub fn MediaProviderObject.from_blob(blob &fileapi.Blob) MediaProviderObject {
	return MediaProviderObject{
		kind: .blob
		blob: blob
	}
}

pub fn MediaProviderObject.from_media_source(handle voidptr, attach fileapi.BlobURLMediaSourceAttachHook) MediaProviderObject {
	return MediaProviderObject{
		kind: .media_source
		media_source_handle: handle
		media_source_attach: attach
	}
}

fn media_element_noop_change_task() {}

fn media_element_noop_audio_enabled(track &AudioTrack, enabled bool) {
	_ = track
	_ = enabled
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
	first_data_load_event_since_load_start_ bool
	seeking_                    bool
	current_playback_position_  f64
	official_playback_position_ f64
	official_playback_position_task_generation_ u64
	default_playback_start_     f64
	show_poster_                bool = true
	duration_                   f64 = math.nan()
	playback_start_time_realtime_microseconds_ ?i64
	timeline_offset_microseconds_               ?i64
	pending_play_promises_      []&dom.Promise
	paused_                     bool = true
	ended_                      bool
	default_playback_rate_      f64 = 1.0
	playback_rate_              f64 = 1.0
	volume_                     f64 = 1.0
	muted_                      bool
	page_muted_                 bool
	has_started_playback_       bool
	is_playing_audio_           bool
	audio_tracks_               &AudioTrackList = unsafe { nil }
	video_tracks_               &VideoTrackList = unsafe { nil }
	text_tracks_                &TextTrackList = unsafe { nil }
	can_autoplay_               bool = true
	loop_                       bool
	autoplay_                   bool
	preload_                    ?string
	controls_                   ?&MediaControls
	destroying_controls_        bool
	fetch_hook_                 ?MediaResourceFetchHook
	fetch_generation_           u32
	buffered_                   &TimeRanges = unsafe { nil }
	played_                     &TimeRanges = unsafe { nil }
	seekable_                   &TimeRanges = unsafe { nil }
	play_range_start_           ?f64
	event_counts_               map[string]int
	playback_hooks_             MediaPlaybackManagerHooks
	playback_manager_ready_     bool
	playback_has_future_data_   bool
	selected_video_track_       ?&VideoTrack
	video_element_model_        ?&HTMLVideoElementModel
	video_frame_source_         ?&painting.VideoFrameSource
	accepts_byte_ranges_        bool
	last_fetch_offset_          u64
	loop_was_specified_at_end_  bool
	running_time_update_event_  bool
	last_time_update_event_time_ ?i64
	last_known_current_playback_position_ ?f64
	queued_media_task_ids_       []u64
	last_progress_event_time_ms_ ?i64
	allow_autoplay_             bool = true
	document_observer_          ?&dom.DocumentObserver
	delaying_load_event_        ?dom.DocumentLoadEventDelayer
	resource_selection_pending_ bool
	resource_fetch_started_     bool
	waiting_for_an_implementation_defined_event_to_fetch_the_resource_ bool
	current_resource_selection_is_explicit_                            bool
	assigned_media_provider_    ?MediaProviderObject
	attached_media_source_      voidptr
	media_source_detach_        ?MediaSourceDetachHook
	video_sink_is_ticking_      bool = true
	screen_wake_lock_          ?&page.ScreenWakeLockHandle
}

pub fn HTMLMediaElement.create(element ?&dom.HTMLElement, base_url dom.URL) &HTMLMediaElement {
	event_target := if html_element := element {
		unsafe { &dom.EventTarget(html_element) }
	} else {
		dom.EventTarget.new()
	}
	mut media := &HTMLMediaElement{
		EventTarget: dom.EventTarget{}
		event_target_: event_target
		associated_element_: element
		base_url_: base_url
		audio_tracks_: &AudioTrackList{}
		text_tracks_: &TextTrackList{}
		buffered_: &TimeRanges{}
		played_: &TimeRanges{}
		seekable_: &TimeRanges{}
	}
	media.video_tracks_ = VideoTrackList.create(media)
	if html_element := element {
		dom_element := unsafe { &dom.Element(html_element) }
		mut document := dom_element.document()
		document.set_media_element_state_query(media_element_matches_pseudo_class)
		document.set_media_element_resource_attribute_changed_hook(html_media_element_resource_attribute_changed)
		document.set_media_element_source_attribute_changed_hook(html_media_element_source_attribute_changed)
		document.set_media_element_controls_attribute_changed_hook(html_media_element_controls_attribute_changed)
		mut observer := dom.DocumentObserver.create(mut document)
		observer.set_document_became_inactive(fn [media] () {
			mut mutable_media := unsafe { &HTMLMediaElement(media) }
			mutable_media.pause_element()
		})
		media.document_observer_ = observer
		mut node := dom_element.as_node()
		node.set_adopted_from_hook(dom.NodeAdoptedFromHook{
			target: voidptr(media)
			callback: html_media_element_adopted_from_callback
		})
		if document.has_page() {
			document.page().register_actual_media_element(document, node.unique_id(), dom.MediaElementPageCallbacks{
				target: voidptr(media)
				mute_state_changed: html_media_element_page_mute_state_changed_callback
				is_playing_audio: html_media_element_is_playing_audio_callback
			})
		}
	}
	return media
}

fn html_media_element_adopted_from_callback(target voidptr, old_document &dom.Document) {
	mut media := unsafe { &HTMLMediaElement(target) }
	media.adopted_from(old_document)
}

fn html_media_element_page_mute_state_changed_callback(target voidptr) {
	mut media := unsafe { &HTMLMediaElement(target) }
	media.page_mute_state_changed()
}

fn html_media_element_is_playing_audio_callback(target voidptr, document &dom.Document) bool {
	media := unsafe { &HTMLMediaElement(target) }
	current_document := media.document() or { return false }
	return current_document.unique_id() == document.unique_id() && media.is_playing_audio()
}

// DOM::Node::document() of the media element.
pub fn (media &HTMLMediaElement) document() ?&dom.Document {
	html_element := media.associated_element_ or { return none }
	return unsafe { &dom.Element(html_element) }.document()
}

// HTMLMediaElement::is_focusable(), which DOM's Element::is_focusable() dispatch translates.
pub fn (media &HTMLMediaElement) is_focusable() bool {
	html_element := media.associated_element_ or { return false }
	return unsafe { &dom.Element(html_element) }.is_focusable()
}

pub fn (media &HTMLMediaElement) selected_video_track_sink() ?&VideoTrack {
	return media.selected_video_track_
}

pub fn (media &HTMLMediaElement) is_html_media_element() bool {
	return true
}

pub fn (media &HTMLMediaElement) media_element_event_task_source() TaskSource {
	_ = media
	return .media_element
}

// Return the HTMLMediaElement state associated with a concrete <audio> or
// <video> DOM element, materializing the translated base-class state on first use.
pub fn html_media_element_for_dom_element(element &dom.Element) ?&HTMLMediaElement {
	if !element.is_html_element() { return none }
	if element.local_name() == 'audio' {
		mut audio := unsafe { &dom.HTMLAudioElement(element) }
		if audio.media_element_model_ == unsafe { nil } {
			mut model := HTMLMediaElement.create(unsafe { &dom.HTMLElement(element) },
				element.document().base_url())
			model.set_source(element.get_attribute('src'))
			model.crossorigin_ = cors_setting_attribute_from_keyword(element.get_attribute_ns(none, 'crossorigin'))
			model.preload_ = element.get_attribute_ns(none, 'preload')
			model.autoplay_ = element.has_attribute_ns(none, 'autoplay')
			audio.media_element_model_ = model
			if element.has_attribute_ns(none, 'controls') { model.create_controls() }
		}
		return unsafe { &HTMLMediaElement(audio.media_element_model_) }
	}
	if element.local_name() == 'video' {
		mut video := unsafe { &dom.HTMLVideoElement(element) }
		if video.media_element_model_ == unsafe { nil } {
			mut model := HTMLMediaElement.create(unsafe { &dom.HTMLElement(element) },
				element.document().base_url())
			model.set_source(element.get_attribute('src'))
			model.crossorigin_ = cors_setting_attribute_from_keyword(element.get_attribute_ns(none, 'crossorigin'))
			model.preload_ = element.get_attribute_ns(none, 'preload')
			model.autoplay_ = element.has_attribute_ns(none, 'autoplay')
			video.media_element_model_ = model
			if element.has_attribute_ns(none, 'controls') { model.create_controls() }
		}
		return unsafe { &HTMLMediaElement(video.media_element_model_) }
	}
	return none
}

fn media_element_matches_pseudo_class(element &dom.Element, pseudo_class dom.MediaElementPseudoClass) bool {
	media := html_media_element_for_dom_element(element) or { return false }
	return match pseudo_class {
		.paused { media.paused() }
		// Current Source's style-engine facts and isolated queries track paused
		// alone, including resource-less play; buffering is an independent fact.
		.playing { !media.paused() }
		.muted { media.muted() }
		.seeking { media.seeking() }
		.buffering { media.blocked() }
		.stalled { media.stalled() }
	}
}

fn html_media_element_source_attribute_changed(element &dom.Element, value ?string) {
	model_pointer := match element.local_name() {
		'audio' { unsafe { &dom.HTMLAudioElement(element) }.media_element_model_ }
		'video' { unsafe { &dom.HTMLVideoElement(element) }.media_element_model_ }
		else { return }
	}
	// Parsing and attribute scans do not create otherwise unused media owners.
	if model_pointer == unsafe { nil } { return }
	mut media := unsafe { &HTMLMediaElement(model_pointer) }
	media.set_source(element.get_attribute('src'))
	media.base_url_ = element.document().base_url()
	// Removing src updates the selection input without invoking load_element().
	if value != none { media.load_element() or {} }
}

fn html_media_element_resource_attribute_changed(element &dom.Element) {
	if !element.is_html_element() { return }
	model_pointer := match element.local_name() {
		'audio' { unsafe { &dom.HTMLAudioElement(element) }.media_element_model_ }
		'video' { unsafe { &dom.HTMLVideoElement(element) }.media_element_model_ }
		else { return }
	}
	// Attribute scans during parsing do not materialize media state. Only a
	// resource selection which already belongs to this actual owner can resume.
	if model_pointer == unsafe { nil } { return }
	mut media := unsafe { &HTMLMediaElement(model_pointer) }
	media.resource_attribute_changed()
}

fn html_media_element_controls_attribute_changed(element &dom.Element, value ?string) {
	if !element.is_html_element() { return }
	model_pointer := match element.local_name() {
		'audio' { unsafe { &dom.HTMLAudioElement(element) }.media_element_model_ }
		'video' { unsafe { &dom.HTMLVideoElement(element) }.media_element_model_ }
		else { return }
	}
	// Keep unused DOM owners lazy, as for src/preload/autoplay. Materialization
	// above projects the parsed null-namespace attribute after publishing the model.
	if model_pointer == unsafe { nil } { return }
	mut media := unsafe { &HTMLMediaElement(model_pointer) }
	if value != none || element.as_node().is_scripting_disabled() {
		media.create_controls()
	} else {
		media.destroy_controls()
	}
}

// CSS/Invalidation/ElementStateInvalidator.cpp records typed state changes.
// The translated style engine consumes those changes through property plans.
fn (element &HTMLMediaElement) invalidate_media_state_style(names []string) {
	html_element := element.associated_element_ or { return }
	mut node := unsafe { &dom.Element(html_element) }.as_node()
	if !node.is_connected() { return }
	if node.document().style_computer().invalidation_plan_callback == unsafe { nil } {
		node.invalidate_style(.other)
		return
	}
	mut properties := []dom.InvalidationProperty{cap: names.len}
	for name in names {
		properties << dom.InvalidationProperty{ type_: .pseudo_class, pseudo_class_name: name }
	}
	node.invalidate_style_with_properties(.other, properties, dom.StyleInvalidationOptions{ invalidate_self: true })
}

pub fn (mut element HTMLMediaElement) removed_from(old_parent ?&dom.Node, old_root &dom.Node) {
	if html_element := element.associated_element_ {
		mut dom_element := unsafe { &dom.Element(html_element) }
		dom_element.removed_from(old_parent, old_root)
		if dom_element.as_node().in_a_document_tree() {
			return
		}
	}
	element.pause_element()
}

pub fn (mut element HTMLMediaElement) adopted_from(old_document &dom.Document) {
	html_element := element.associated_element_ or { return }
	mut new_document := unsafe { &dom.Element(html_element) }.document()
	element.base_url_ = new_document.base_url()
	new_document.set_media_element_resource_attribute_changed_hook(html_media_element_resource_attribute_changed)
	new_document.set_media_element_source_attribute_changed_hook(html_media_element_source_attribute_changed)
	new_document.set_media_element_controls_attribute_changed_hook(html_media_element_controls_attribute_changed)
	if observer := element.document_observer_ {
		mut mutable_observer := unsafe { &dom.DocumentObserver(observer) }
		mutable_observer.retarget_for_adoption(mut new_document)
	}
	if element.is_playing_audio_ {
		media_id := unsafe { &dom.Element(html_element) }.as_node().unique_id()
		mut mutable_old_document := unsafe { &dom.Document(old_document) }
		mutable_old_document.media_element_audio_play_state_changed(media_id, false)
		new_document.media_element_audio_play_state_changed(media_id, true)
	}

	// The delaying flag belongs to the media element's current node document,
	// so transfer its load-event delay when the element is adopted.
	mut was_delaying := false
	if mut delayer := element.delaying_load_event_ {
		delayer.finish()
		was_delaying = true
	}
	if was_delaying {
		element.delaying_load_event_ = dom.DocumentLoadEventDelayer.new(mut new_document)
	}
	if mut video := element.video_element_model_ {
		video.retarget_poster_load_event_delay()
	}

	// Resource-selection tasks queued against an inactive document cannot run.
	// Drop their stale task-source entries and continue in the adopting document
	// unless a resource fetch had already begun.
	if !old_document.is_fully_active() && !element.resource_fetch_started_
		&& element.resource_selection_pending_ {
		element.remove_queued_media_element_tasks()
		element.select_resource_for_current_load() or {}
	}
	if element.screen_wake_lock_ != none {
		element.release_screen_wake_lock()
		element.update_screen_wake_lock()
	}
}

fn (mut element HTMLMediaElement) begin_delaying_load_event() {
	if element.delaying_load_event_ != none {
		return
	}
	html_element := element.associated_element_ or { return }
	mut document := unsafe { &dom.Element(html_element) }.document()
	element.delaying_load_event_ = dom.DocumentLoadEventDelayer.new(mut document)
}

fn (mut element HTMLMediaElement) finish_delaying_load_event() {
	if mut delayer := element.delaying_load_event_ {
		delayer.finish()
		element.delaying_load_event_ = none
	}
}

pub fn (mut element HTMLMediaElement) media_source_attachment_did_open(source_handle voidptr, detach MediaSourceDetachHook) {
	element.attached_media_source_ = source_handle
	element.media_source_detach_ = detach
	element.finish_delaying_load_event()
	element.set_up_playback_manager()
}

fn (mut element HTMLMediaElement) detach_attached_media_source() {
	if element.attached_media_source_ == unsafe { nil } {
		return
	}
	if detach := element.media_source_detach_ {
		detach(element.attached_media_source_, voidptr(element))
	}
	element.attached_media_source_ = unsafe { nil }
	element.media_source_detach_ = none
}

pub fn (mut element HTMLMediaElement) media_source_set_duration(duration f64) {
	element.set_duration(duration)
}

pub fn (mut element HTMLMediaElement) media_source_initialization_segment_received(duration f64) {
	element.on_metadata_parsed(duration)
}

pub fn (mut element HTMLMediaElement) media_source_update_buffered_ranges(ranges []MediaBufferedRange) {
	element.set_media_source_buffered_ranges(ranges)
	element.process_media_data(.ongoing)
	element.update_ready_state()
}

// Source's playback manager observes the updated demuxer before the removal
// completion's update_ready_state(). Refresh the V cached-range adapter at
// that same boundary without entering the append-only progress event path.
pub fn (mut element HTMLMediaElement) media_source_update_buffered_ranges_after_removal(ranges []MediaBufferedRange) {
	element.set_media_source_buffered_ranges(ranges)
	element.update_ready_state()
}

fn (mut element HTMLMediaElement) set_media_source_buffered_ranges(ranges []MediaBufferedRange) {
	element.buffered_.clear()
	for range_ in ranges {
		element.buffered_.add_range(range_.start, range_.end)
	}
	element.playback_has_future_data_ = ranges.any(it.end > element.current_playback_position_)
}

pub fn (mut element HTMLMediaElement) toggle_fullscreen() {
	html_element := element.associated_element_ or { return }
	mut dom_element := unsafe { &dom.Element(html_element) }
	mut document := dom_element.document()
	if fullscreen_element := document.fullscreen_element() {
		if voidptr(fullscreen_element) == voidptr(dom_element) {
			document.exit_fullscreen()
			return
		}
	}
	dom_element.request_fullscreen(.bindings)
}

fn media_source_candidates_from_dom(element &dom.Element) []string {
	mut candidates := []string{}
	for child in element.as_node().children_as_vector() {
		if source_element := child.as_element() {
			if source_element.is_html_element() && source_element.local_name() == 'source' {
				source := source_element.get_attribute_ns(none, 'src') or { '' }
				if source.trim_space() != '' {
					candidates << source
				}
			}
		}
	}
	return candidates
}

pub fn (mut element HTMLMediaElement) children_changed(metadata dom.ChildrenChangedMetadata) {
	if html_element := element.associated_element_ {
		mut dom_element := unsafe { &dom.Element(html_element) }
		dom_element.children_changed(metadata)
		element.source_candidates_ = media_source_candidates_from_dom(dom_element)
		if element.network_state_ == .no_source && element.source_ == none {
			element.select_resource() or {}
		}
	}
}

pub fn (element &HTMLMediaElement) error() ?&MediaError {
	return element.error_
}

pub fn (element &HTMLMediaElement) current_src() string {
	return element.current_src_
}

// https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject
pub fn (element &HTMLMediaElement) src_object() ?MediaProviderObject {
	return element.assigned_media_provider_
}

// https://html.spec.whatwg.org/multipage/media.html#dom-media-srcobject
pub fn (mut element HTMLMediaElement) set_src_object(provider ?MediaProviderObject) ! {
	element.assigned_media_provider_ = provider
	element.load_element()!
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

pub fn (element &HTMLMediaElement) is_fetching() bool {
	return element.network_state_ == .loading
}

pub fn (element &HTMLMediaElement) is_playing_audio() bool {
	return element.is_playing_audio_
}

fn (element &HTMLMediaElement) should_be_playing_audio() bool {
	return element.has_started_playback_ && element.audio_tracks_.has_enabled_track()
		&& element.effective_media_volume() > 0
}

fn (mut element HTMLMediaElement) update_audio_play_state() {
	is_playing_audio := element.should_be_playing_audio()
	if element.is_playing_audio_ == is_playing_audio {
		return
	}
	element.is_playing_audio_ = is_playing_audio
	html_element := element.associated_element_ or { return }
	mut document := unsafe { &dom.Element(html_element) }.document()
	if document.has_page() {
		document.page().client_page_did_change_audio_play_state(is_playing_audio)
	}
	document.media_element_audio_play_state_changed(html_element.as_node().unique_id(), is_playing_audio)
}

pub fn (element &HTMLMediaElement) should_hold_screen_wake_lock() bool {
	html_element := element.associated_element_ or { return false }
	dom_element := unsafe { &dom.Element(html_element) }
	if !dom_element.is_html_element() || dom_element.local_name() != 'video' {
		return false
	}
	if element.video_tracks_.selected_index() < 0 || !element.audio_tracks_.has_enabled_track() {
		return false
	}
	return element.potentially_playing()
}

pub fn (mut element HTMLMediaElement) update_screen_wake_lock() {
	if element.should_hold_screen_wake_lock() {
		if element.screen_wake_lock_ == none {
			document := element.document() or { return }
			if !document.has_page() { return }
			element.screen_wake_lock_ = page.ScreenWakeLockHandle.create_for_dom_page(document.page())
		}
		return
	}
	element.release_screen_wake_lock()
}

fn (mut element HTMLMediaElement) release_screen_wake_lock() {
	if mut handle := element.screen_wake_lock_ {
		handle.release()
		element.screen_wake_lock_ = none
	}
}

// Selected Source finalize responsibilities. Physical GC and the remaining
// manager/timer finalization are separate integration boundaries.
pub fn (mut element HTMLMediaElement) finalize() {
	element.release_screen_wake_lock()
	// Source clears controls eagerly: native timer closures must not survive
	// the media owner's finalization and touch its shadow nodes later.
	element.destroy_controls()
	if html_element := element.associated_element_ {
		dom_element := unsafe { &dom.Element(html_element) }
		document := dom_element.document()
		if document.has_page() {
			document.page().unregister_actual_media_element(dom_element.as_node().unique_id())
		}
	}
}

pub fn (element &HTMLMediaElement) video_sink_is_ticking() bool {
	return element.video_sink_is_ticking_
}

pub fn (element &HTMLMediaElement) show_poster() bool {
	return element.show_poster_
}

pub fn (element &HTMLMediaElement) duration() f64 {
	return element.duration_
}

// https://html.spec.whatwg.org/multipage/media.html#dom-media-getstartdate
pub fn (element &HTMLMediaElement) get_start_date() &MediaStartDate {
	date_value := if timeline_offset := element.timeline_offset_microseconds_ {
		// UnixDateTime::milliseconds_since_epoch() rounds away from zero.
		// Divide before rounding so even the i64 clock limits cannot overflow.
		milliseconds := timeline_offset / 1000
		remainder := timeline_offset % 1000
		f64(milliseconds + if remainder > 0 { i64(1) } else if remainder < 0 { i64(-1) } else { i64(0) })
	} else {
		math.nan()
	}
	return &MediaStartDate{
		time_value_: date_value
	}
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
	if html_element := element.associated_element_ {
		return cors_setting_attribute_from_keyword(unsafe { &dom.Element(html_element) }.get_attribute_ns(none, 'crossorigin'))
	}
	return element.crossorigin_
}

pub fn (element &HTMLMediaElement) cross_origin() ?string {
	return match element.crossorigin() {
		.no_cors { none }
		.anonymous { 'anonymous' }
		.use_credentials { 'use-credentials' }
	}
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
	if hook := element.playback_hooks_.buffered_ranges {
		mut result := &TimeRanges{}
		for range_ in hook() {
			result.add_range(range_.start, range_.end)
		}
		return result
	}
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

pub fn (mut element HTMLMediaElement) set_playback_manager_hooks(hooks MediaPlaybackManagerHooks) {
	element.playback_hooks_ = hooks
	element.playback_manager_ready_ = true
	element.update_playback_rate()
}

@[heap]
struct QueuedMediaElementTask {
mut:
	id u64
}

// HTMLMediaElement::queue_a_media_element_task(), including the active-document
// guard. Per-element task IDs retain upstream's unique task-source ownership.
pub fn (element &HTMLMediaElement) queue_a_media_element_task(steps MediaElementTask) {
	mut queued := &QueuedMediaElementTask{}
	element_pointer := voidptr(element)
	mut document := ?&dom.Document(none)
	if html_element := element.associated_element_ {
		document = unsafe { &dom.Element(html_element) }.document()
	}
	queued.id = queue_a_task(element.media_element_event_task_source(), none, document,
		fn [element_pointer, queued, steps] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			for index, id in media.queued_media_task_ids_ {
				if id == queued.id {
					media.queued_media_task_ids_.delete(index)
					break
				}
			}
			if html_element := media.associated_element_ {
				if !unsafe { &dom.Element(html_element) }.document().is_fully_active() {
					return
				}
			}
			steps()
		})
	mut media := unsafe { &HTMLMediaElement(element) }
	media.queued_media_task_ids_ << queued.id
}

fn (mut element HTMLMediaElement) remove_queued_media_element_tasks() {
	ids := element.queued_media_task_ids_.clone()
	mut queue := main_thread_event_loop().task_queue()
	queue.remove_tasks_matching(fn [ids] (task &Task) bool {
		return task.id() in ids
	})
	element.queued_media_task_ids_.clear()
}

pub fn (mut element HTMLMediaElement) set_source(source ?string) {
	element.source_ = source
}

pub fn (mut element HTMLMediaElement) set_source_candidates(candidates []string) {
	element.source_candidates_ = candidates.clone()
}

pub fn (mut element HTMLMediaElement) set_crossorigin(value ?string) {
	element.crossorigin_ = cors_setting_attribute_from_keyword(value)
	if html_element := element.associated_element_ {
		mut dom_element := unsafe { &dom.Element(html_element) }
		if raw := value {
			dom_element.set_attribute_value('crossorigin', raw)
		} else {
			dom_element.remove_attribute_ns(none, 'crossorigin')
		}
	}
}

pub fn (element &HTMLMediaElement) loop() bool {
	if html_element := element.associated_element_ {
		return unsafe { &dom.Element(html_element) }.has_attribute_ns(none, 'loop')
	}
	return element.loop_
}

pub fn (mut element HTMLMediaElement) set_loop(value bool) {
	element.loop_ = value
	if html_element := element.associated_element_ {
		mut dom_element := unsafe { &dom.Element(html_element) }
		if value {
			dom_element.set_attribute_value('loop', '')
		} else {
			dom_element.remove_attribute_ns(none, 'loop')
		}
	}
}

pub fn (element &HTMLMediaElement) autoplay() bool {
	if html_element := element.associated_element_ {
		return unsafe { &dom.Element(html_element) }.has_attribute_ns(none, 'autoplay')
	}
	return element.autoplay_
}

pub fn (mut element HTMLMediaElement) set_autoplay(value bool) {
	element.autoplay_ = value
	if html_element := element.associated_element_ {
		mut dom_element := unsafe { &dom.Element(html_element) }
		if value {
			dom_element.set_attribute_value('autoplay', '')
		} else {
			dom_element.remove_attribute_ns(none, 'autoplay')
		}
	}
	element.resource_attribute_changed()
}

fn (mut element HTMLMediaElement) resource_attribute_changed() {
	if element.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		&& !element.should_wait_for_an_implementation_defined_event_before_fetching_the_resource() {
		element.continue_fetching_the_resource_after_an_implementation_defined_event() or {}
	}
}

fn (element &HTMLMediaElement) raw_preload() ?string {
	if html_element := element.associated_element_ {
		return unsafe { &dom.Element(html_element) }.get_attribute_ns(none, 'preload')
	}
	return element.preload_
}

pub fn (element &HTMLMediaElement) preload() string {
	raw := element.raw_preload() or { return 'metadata' }
	return match ascii_lowercase_string(raw) {
		'auto' { 'auto' }
		'none' { 'none' }
		'metadata' { 'metadata' }
		else { 'metadata' }
	}
}

pub fn (mut element HTMLMediaElement) set_preload(value ?string) {
	element.preload_ = value
	if html_element := element.associated_element_ {
		mut dom_element := unsafe { &dom.Element(html_element) }
		if raw := value {
			dom_element.set_attribute_value('preload', raw)
		} else {
			dom_element.remove_attribute_ns(none, 'preload')
		}
	}
	element.resource_attribute_changed()
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
	element.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ = false
	element.resource_selection_pending_ = false
	element.resource_fetch_started_ = false
	if element.network_state_ == .loading {
		element.network_state_ = .idle
	}
}

pub fn (mut element HTMLMediaElement) set_decoder_error(message string) {
	if element.error_ != none {
		return
	}
	element.error_ = &MediaError{
		code: .decode
		message: message
	}
	element.cancel_the_fetching_process()
	element.network_state_ = .idle
	element.finish_delaying_load_event()
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
	// Upstream promotes the selection immediately after load_element(), before
	// its stable-state task runs. V performs that task synchronously, so record
	// the promotion first and retain it through the current selection.
	element.promote_current_resource_selection_to_explicit()
	element.load_element_for_current_load()!
}

pub fn (mut element HTMLMediaElement) load_element() ! {
	element.current_resource_selection_is_explicit_ = false
	element.load_element_for_current_load()!
}

fn (mut element HTMLMediaElement) load_element_for_current_load() ! {
	// HTMLMediaElement::load_element() rearms the first-data notification even
	// when this load later has no resource or fails playback-rate validation.
	element.first_data_load_event_since_load_start_ = true
	// Upstream load step 5 cancels only this element's outstanding media tasks.
	element.remove_queued_media_element_tasks()
	element_pointer := voidptr(&element)
	if element.network_state_ in [.loading, .idle] {
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('abort')
		})
	}
	if element.network_state_ != .empty {
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('emptied')
		})
		// A MediaSource can be attached through srcObject or a blob URL. Track
		// the actual attachment so either form is detached before media state
		// and playback-manager state are reset.
		element.detach_attached_media_source()
		if !element.paused_ {
			element.set_paused(true)
			promises := element.take_pending_play_promises()
			element.reject_pending_play_promises_with_abort_error(promises, 'Media playback was aborted')
		}
	}
	element.cancel_the_fetching_process()
	element.forget_media_resource_specific_tracks()
	element.error_ = none
	element.current_src_ = ''
	element.network_state_ = .empty
	element.set_ready_state(.have_nothing)
	element.set_seeking(false)
	element.current_playback_position_ = 0
	if element.official_playback_position_ != 0 {
		element.set_official_playback_position(0)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.dispatch_time_update_event()
		})
	}
	element.playback_start_time_realtime_microseconds_ = none
	element.timeline_offset_microseconds_ = none
	element.set_duration(math.nan())
	element.set_ended(false)
	element.set_show_poster(true)
	element.set_playback_rate(element.default_playback_rate_)!
	element.can_autoplay_ = true
	element.buffered_.clear()
	element.played_.clear()
	element.seekable_.clear()
	element.select_resource_for_current_load()!
}

pub fn (mut element HTMLMediaElement) select_resource() ! {
	element.current_resource_selection_is_explicit_ = false
	element.select_resource_for_current_load()!
}

fn (mut element HTMLMediaElement) select_resource_for_current_load() ! {
	if html_element := element.associated_element_ {
		document := unsafe { &dom.Element(html_element) }.document()
		if !document.is_fully_active() {
			element.begin_delaying_load_event()
			element.resource_selection_pending_ = true
			return
		}
	}
	element.resource_selection_pending_ = false
	element.begin_delaying_load_event()
	defer {
		element.finish_delaying_load_event()
	}
	if provider := element.assigned_media_provider_ {
		element.network_state_ = .loading
		element.fire_event('loadstart')
		element.current_src_ = ''
		element.load_local_resource(provider) or {
			promises := element.take_pending_play_promises()
			element.handle_media_source_failure(promises, err.msg())
		}
		return
	}
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
	mut last_error := 'No supported media source'
	for candidate in candidates {
		url := dom.dom_url_parse(candidate, element.base_url_, 'UTF-8') or {
			last_error = 'Invalid media URL'
			continue
		}
		element.current_src_ = url.serialize()
		loaded_media_source := element.load_media_source_from_blob_url(url) or {
			last_error = err.msg()
			continue
		}
		if loaded_media_source {
			return
		}
		if element.should_wait_for_an_implementation_defined_event_before_fetching_the_resource() {
			element.wait_for_an_implementation_defined_event_before_fetching_the_resource()
			return
		}
		hook := element.fetch_hook_ or {
			last_error = 'No media fetch hook'
			continue
		}
		element.resource_fetch_started_ = true
		response := hook(url, 0) or {
			last_error = err.msg()
			continue
		}
		if failure := element.verify_response_or_get_failure_reason(response, true) {
			last_error = failure
			continue
		}
		if response.status < 200 || response.status >= 300 || element.can_play_type(response.mime_type) == .empty {
			last_error = 'Unsupported media response'
			continue
		}
		element.accepts_byte_ranges_ = response.accepts_byte_ranges
		element.last_fetch_offset_ = 0
		element.process_media_response(response)
		return
	}
	element.network_state_ = .no_source
	element.error_ = &MediaError{
		code: .src_not_supported
		message: last_error
	}
	element.reject_pending_play_promises(dom.js_webidl_value(webidl.dom_exception_value_for_record(
		webidl.DOMException.create_record('NotSupportedError', last_error))))
	element.fire_event('error')
	return error('NotSupportedError: ${last_error}')
}

// https://html.spec.whatwg.org/multipage/media.html#attr-media-preload
fn (element &HTMLMediaElement) preload_attribute_is_in_none_state() bool {
	preload := element.raw_preload() or { return false }
	return ascii_lowercase_string(preload) == 'none'
}

fn (element &HTMLMediaElement) should_wait_for_an_implementation_defined_event_before_fetching_the_resource() bool {
	// An explicit load() requests that this selection fetch even when
	// preload=none, matching Chromium, Firefox, and current Ladybird.
	if element.current_resource_selection_is_explicit_ {
		return false
	}
	if !element.preload_attribute_is_in_none_state() || !element.paused_ {
		return false
	}
	if element.is_eligible_for_autoplay() && element.is_allowed_to_play() {
		return false
	}
	return true
}

fn (mut element HTMLMediaElement) promote_current_resource_selection_to_explicit() {
	element.current_resource_selection_is_explicit_ = true
}

fn (mut element HTMLMediaElement) wait_for_an_implementation_defined_event_before_fetching_the_resource() {
	element.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ = true
	element.network_state_ = .idle
	element.fire_event('suspend')
	element.finish_delaying_load_event()
}

fn (mut element HTMLMediaElement) continue_fetching_the_resource_after_an_implementation_defined_event() ! {
	if !element.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ {
		return
	}
	element.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ = false
	element.begin_delaying_load_event()
	element.network_state_ = .loading
	defer {
		element.finish_delaying_load_event()
	}
	url := dom.dom_url_parse(element.current_src_, element.base_url_, 'UTF-8') or {
		return error('Invalid media URL')
	}
	element.load_url_resource(url, none)!
}

fn (mut element HTMLMediaElement) load_local_resource(provider MediaProviderObject) ! {
	if provider.kind != .media_source {
		return error('File objects are not supported')
	}
	attach := provider.media_source_attach or {
		return error('MediaSource cannot be attached')
	}
	attach(provider.media_source_handle, voidptr(element))!
}

fn (mut element HTMLMediaElement) load_media_source_from_blob_url(url dom.URL) !bool {
	if url.scheme() != 'blob' {
		return false
	}
	// HTMLMediaElement.cpp:1257–1297 authorizes the copied URL entry first.
	// Only a MediaSource tag resolves the live store object for attachment.
	if record := url.parsed() {
		if snapshot := record.blob_url_entry() {
			html_element := element.associated_element_ or { return false }
			document := unsafe { &dom.Element(html_element) }.document()
			native_settings := document.relevant_settings_object()
			if native_settings == unsafe { nil } {
				panic('Source Blob media requires actual node-document settings')
			}
			settings := unsafe { &EnvironmentSettingsObject(native_settings) }
			mut access := fileapi.BlobURLObtainEnvironment(fileapi.BlobURLRequestEnvironment{
				environment: settings
			})
			if settings.fetch_request_client_is_window()
				&& settings.fetch_request_client_is_top_level_window()
				&& settings.environment().creation_url == url {
				access = fileapi.BlobURLObtainEnvironment(fileapi.TopLevelSelfFetch{})
			}
			object := fileapi.obtain_a_blob_object(snapshot, access) or { return false }
			if object !is liburl.BlobURLMediaSource { return false }
			live_entry := fileapi.resolve_a_blob_url(record) or {
				panic('Source MediaSource URL snapshot requires a live store entry')
			}
			live_object := live_entry.object
			if live_object.kind != .media_source {
				panic('Source MediaSource URL store object changed kind')
			}
			attach := live_object.media_source_attach or {
				panic('Source MediaSource store entry requires a live attachment')
			}
			element.load_local_resource(MediaProviderObject.from_media_source(live_object.media_source_handle, attach))!
			return true
		}
	}
	// Standalone string consumers retain their separate Legacy store adapter.
	entry := fileapi.resolve_a_legacy_blob_url(url.serialize()) or { return false }
	if entry.object.kind != .media_source {
		return false
	}

	mut access := fileapi.LegacyBlobURLObtainEnvironment(fileapi.LegacyBlobURLEnvironment{})
	if html_element := element.associated_element_ {
		document := unsafe { &dom.Element(html_element) }.document()
		document_url := dom.URL{value: document.url_string()}
		is_top_level_self_fetch := if navigable := document.navigable() {
			navigable.parent() == none && document_url == url
		} else {
			false
		}
		if is_top_level_self_fetch {
			access = fileapi.LegacyBlobURLObtainEnvironment(fileapi.TopLevelSelfFetch{})
		} else {
			origin := document.origin()
			access = fileapi.LegacyBlobURLObtainEnvironment(fileapi.LegacyBlobURLEnvironment{
				id: document_url.serialize()
				origin: origin.serialize()
				storage_key: origin.serialize_for_ipc()
			})
		}
	} else {
		origin := element.base_url_.origin()
		access = fileapi.LegacyBlobURLObtainEnvironment(fileapi.LegacyBlobURLEnvironment{
			id: element.base_url_.serialize()
			origin: origin.serialize()
			storage_key: origin.serialize_for_ipc()
		})
	}
	object := fileapi.obtain_a_legacy_blob_object(entry, access) or {
		return error('MediaSource blob URL is not authorized for this document')
	}
	attach := object.media_source_attach or { return error('MediaSource blob URL is detached') }
	element.load_local_resource(MediaProviderObject.from_media_source(object.media_source_handle, attach))!
	return true
}

// HTMLMediaElement::load_url_resource(URL, failure_callback). The host hook owns
// the transport; this method preserves the media state-machine transition and
// failure callback around it.
pub fn (mut element HTMLMediaElement) load_url_resource(url_record dom.URL, failure_callback ?MediaResourceFailureCallback) ! {
	element.current_src_ = url_record.serialize()
	if element.load_media_source_from_blob_url(url_record)! {
		return
	}
	element.network_state_ = .loading
	element.last_fetch_offset_ = 0
	hook := element.fetch_hook_ or {
		message := 'No media fetch hook'
		if callback := failure_callback {
			callback(message)
		}
		return error(message)
	}
	element.resource_fetch_started_ = true
	response := hook(url_record, 0) or {
		message := err.msg()
		if callback := failure_callback {
			callback(message)
		}
		return error(message)
	}
	if failure := element.verify_response_or_get_failure_reason(response, true) {
		if callback := failure_callback {
			callback(failure)
		}
		return error(failure)
	}
	element.accepts_byte_ranges_ = response.accepts_byte_ranges
	element.process_media_response(response)
}

pub fn (mut element HTMLMediaElement) fetch_resource(url_record dom.URL, failure_callback ?MediaResourceFailureCallback) ! {
	element.load_url_resource(url_record, failure_callback)!
}

// HTMLMediaElement::fetch_resource(ByteRange). V cannot overload method names,
// so the byte-range overload retains an explicit suffix.
pub fn (mut element HTMLMediaElement) fetch_resource_byte_range(byte_range MediaByteRange) ! {
	element.restart_fetch_at_offset(byte_range.offset)!
}

pub fn (element &HTMLMediaElement) verify_response_or_get_failure_reason(response MediaResourceResponse, entire_resource bool) ?string {
	if entire_resource || response.status == 200 {
		return none
	}
	if response.status != 206 {
		return 'Unexpected status code: ${response.status}'
	}
	return none
}

pub fn (mut element HTMLMediaElement) restart_fetch_at_offset(offset u64) ! {
	if element.error_ != none || !element.accepts_byte_ranges_ {
		return
	}
	hook := element.fetch_hook_ or { return }
	if element.current_src_ == '' {
		return
	}
	response := hook(dom.URL{ value: element.current_src_ }, offset)!
	if failure := element.verify_response_or_get_failure_reason(response, false) {
		return error(failure)
	}
	element.last_fetch_offset_ = offset
	element.process_media_data(.ongoing)
}

pub fn (element &HTMLMediaElement) last_fetch_offset() u64 {
	return element.last_fetch_offset_
}

fn (mut element HTMLMediaElement) process_media_response(response MediaResourceResponse) {
	element.set_up_playback_manager()
	element.playback_start_time_realtime_microseconds_ = response.start_time_realtime_microseconds
	for metadata in response.audio_tracks {
		element.on_audio_track_added(metadata)
	}
	for metadata in response.video_tracks {
		element.on_video_track_added(metadata)
	}
	element.on_metadata_parsed(response.duration)
	if response.buffered_end > 0 {
		element.buffered_.add_range(0, response.buffered_end)
		element.seekable_.add_range(0, if math.is_nan(response.duration) {
			response.buffered_end
		} else {
			response.duration
		})
		element.playback_has_future_data_ = true
		element.update_ready_state()
	}
	element.process_media_data(.complete)
}

pub fn (mut element HTMLMediaElement) set_ready_state(state MediaReadyState) {
	old_state := element.ready_state_
	if old_state == state {
		return
	}
	was_buffering := element.blocked()
	element.ready_state_ = state
	if was_buffering != element.blocked() {
		element.invalidate_media_state_style(['buffering'])
	}
	defer {
		element.upon_has_ended_playback_possibly_changed()
		element.update_screen_wake_lock()
	}
	if mut video := element.video_element_model_ {
		video.update_natural_dimensions()
	}
	if element.network_state_ == .empty {
		return
	}
	// Metadata notification belongs to the readiness transition, including
	// MediaSource initialization, rather than to the synchronous fetch adapter.
	if element.network_state_ != .empty && old_state == .have_nothing
		&& state == .have_metadata {
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('loadedmetadata')
		})
		return
	}
	// Source's first-data branch requires a nonempty network state and the
	// exact metadata-to-data transition. Consume the flag when queuing, so
	// buffering oscillations cannot queue another event during this load.
	if element.network_state_ != .empty && old_state == .have_metadata
		&& int(state) >= int(MediaReadyState.have_current_data) {
		if element.first_data_load_event_since_load_start_ {
			element.first_data_load_event_since_load_start_ = false
			element_pointer := voidptr(&element)
			element.queue_a_media_element_task(fn [element_pointer] () {
				mut media := unsafe { &HTMLMediaElement(element_pointer) }
				media.fire_event('loadeddata')
			})
		}
		// The pinned caller clears its DocumentLoadEventDelayer synchronously,
		// independently of whether this crossing queued the first-data event.
		element.finish_delaying_load_event()
	}
	// Both Source branches queue canplay before notifying about playing. Take
	// the pending promise batch now, before any queued listener can call play().
	if element.network_state_ != .empty
		&& int(old_state) <= int(MediaReadyState.have_current_data)
		&& state in [.have_future_data, .have_enough_data] {
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('canplay')
		})
		if !element.paused_ {
			element.notify_about_playing()
		}
	}
	// Source queues this enough-data notification after canplay and any
	// readiness-driven playing task, before entering its autoplay substeps.
	if element.network_state_ != .empty && state == .have_enough_data {
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('canplaythrough')
		})
		if !element.is_eligible_for_autoplay() {
			return
		}
		if element.is_allowed_to_play() {
			element.set_paused(false)
			if element.show_poster_ {
				element.set_show_poster(false)
				element.time_marches_on(.normal_playback)
			}
			element.queue_a_media_element_task(fn [element_pointer] () {
				mut media := unsafe { &HTMLMediaElement(element_pointer) }
				media.fire_event('play')
			})
			element.notify_about_playing()
		}
		return
	}
	if int(state) < int(MediaReadyState.have_future_data) && int(old_state) >= int(MediaReadyState.have_future_data) && !element.paused_ {
		element.fire_event('waiting')
	}
}

// https://w3c.github.io/media-source/#buffer-monitoring
pub fn (mut element HTMLMediaElement) update_ready_state() {
	if !element.playback_manager_ready_ || element.ready_state_ == .have_nothing {
		return
	}

	current_time := if hook := element.playback_hooks_.current_time {
		hook()
	} else {
		element.current_playback_position_
	}
	buffered_ranges := if hook := element.playback_hooks_.buffered_ranges {
		hook()
	} else {
		mut ranges := []MediaBufferedRange{cap: element.buffered_.ranges.len}
		for range_ in element.buffered_.ranges {
			ranges << MediaBufferedRange{range_.start, range_.end}
		}
		ranges
	}
	mut current_range_end := ?f64(none)
	for range_ in buffered_ranges {
		if range_.end >= current_time {
			current_range_end = range_.end
			break
		}
	}
	if !element.playback_has_future_data_ && current_range_end == none {
		element.set_ready_state(.have_metadata)
		return
	}

	range_end := current_range_end or { 0.0 }
	playable_duration := math.max(0.0, range_end - current_time)
	if element.playback_has_future_data_
		&& (playable_duration >= 5.0 || (!math.is_nan(element.duration_) && range_end >= element.duration_)) {
		element.set_ready_state(.have_enough_data)
		return
	}
	if element.playback_has_future_data_ && playable_duration > 0 {
		element.set_ready_state(.have_future_data)
		return
	}
	element.set_ready_state(.have_current_data)
}

pub fn (mut element HTMLMediaElement) set_seeking(seeking bool) {
	if element.seeking_ == seeking {
		return
	}
	element.seeking_ = seeking
	element.invalidate_media_state_style(['seeking'])
}

pub fn (mut element HTMLMediaElement) set_duration(duration f64) {
	if !math.is_nan(duration) {
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('durationchange')
		})
		if element.current_playback_position_ > duration {
			element.seek_element(duration, .accurate)
		}
	}
	element.duration_ = duration
	element.upon_has_ended_playback_possibly_changed()
	element.request_paint_command_rebuild()
}

fn (element &HTMLMediaElement) request_paint_command_rebuild() {
	if html_element := element.associated_element_ {
		mut node := unsafe { &dom.Element(html_element) }.as_node()
		node.set_needs_repaint(.paint_commands)
	}
}

pub fn (mut element HTMLMediaElement) set_show_poster(show_poster bool) {
	if element.show_poster_ == show_poster {
		return
	}
	element.show_poster_ = show_poster
	if mut video := element.video_element_model_ {
		video.update_natural_dimensions()
	}
	element.request_paint_command_rebuild()
}

pub fn (mut element HTMLMediaElement) set_paused(paused bool) {
	if element.paused_ == paused {
		return
	}
	element.paused_ = paused
	if paused {
		element.has_started_playback_ = false
		if hook := element.playback_hooks_.pause {
			hook()
		}
		element.update_audio_play_state()
	}
	element.update_screen_wake_lock()
	if mut video := element.video_element_model_ {
		video.update_natural_dimensions()
	}
	element.request_paint_command_rebuild()
	element.invalidate_media_state_style(['paused', 'playing'])
}

pub fn (mut element HTMLMediaElement) set_ended(ended bool) {
	if element.ended_ == ended { return }
	element.ended_ = ended
	element.update_screen_wake_lock()
}

pub fn (element &HTMLMediaElement) current_time() f64 {
	if element.default_playback_start_ != 0 {
		return element.default_playback_start_
	}
	generation := main_thread_event_loop().task_generation()
	if element.official_playback_position_task_generation_ != generation {
		// Source declares these cache fields mutable in its const getter.
		mut media := unsafe { &HTMLMediaElement(element) }
		media.official_playback_position_task_generation_ = generation
		media.official_playback_position_ = element.current_playback_position()
	}
	return element.official_playback_position_
}

pub fn (element &HTMLMediaElement) current_playback_position() f64 {
	if current_time := element.playback_hooks_.current_time {
		return current_time()
	}
	// Preserve the existing model clock when no platform hook is installed.
	// Source returns zero without a manager; this remains a compatibility path.
	return element.current_playback_position_
}

pub fn (mut element HTMLMediaElement) set_official_playback_position(position f64) {
	element.official_playback_position_ = position
	element.official_playback_position_task_generation_ = main_thread_event_loop().task_generation()
}

pub fn (mut element HTMLMediaElement) set_current_time(value f64) {
	if element.ready_state_ == .have_nothing {
		element.default_playback_start_ = value
		return
	}
	element.seek_element(value, .accurate)
}

pub fn (mut element HTMLMediaElement) fast_seek(value f64) {
	element.seek_element(value, .approximate_for_speed)
}

pub fn (mut element HTMLMediaElement) seek_element(value f64, mode MediaSeekMode) {
	element.set_show_poster(false)
	if element.ready_state_ == .have_nothing {
		return
	}
	element.set_seeking(true)
	mut target := if value < 0 { 0.0 } else { value }
	if !math.is_nan(element.duration_) && target > element.duration_ {
		target = element.duration_
	}
	if !element.seekable_.in_range(target) {
		if element.seekable_.length() == 0 {
			element.set_seeking(false)
			return
		}
		mut nearest := element.seekable_.start(0) or { 0.0 }
		mut nearest_distance := math.abs(target - nearest)
		for index := u32(0); index < element.seekable_.length(); index++ {
			for point in [element.seekable_.start(index) or { continue }, element.seekable_.end(index) or {
				continue
			}] {
				distance := math.abs(target - point)
				if distance < nearest_distance || (distance == nearest_distance && math.abs(element.current_playback_position_ - point) < math.abs(element.current_playback_position_ - nearest)) {
					nearest = point
					nearest_distance = distance
				}
			}
		}
		target = nearest
	}
	mut playback_seek_mode := MediaPlaybackSeekMode.accurate
	if mode == .approximate_for_speed {
		// Source samples the live clock at each comparison before queuing seeking.
		if target < element.current_playback_position() {
			playback_seek_mode = .fast_before
		} else if target > element.current_playback_position() {
			playback_seek_mode = .fast_after
		}
	}
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.fire_event('seeking')
	})
	if hook := element.playback_hooks_.seek {
		hook(target, playback_seek_mode)
	} else {
		element.current_playback_position_ = target
		element.upon_has_ended_playback_possibly_changed()
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.finish_seeking_element()
		})
	}
	// Source's ad-hoc seek commit samples the clock after requesting the seek.
	element.set_official_playback_position(element.current_playback_position())
}

pub fn (mut element HTMLMediaElement) finish_seeking_element() {
	element.set_seeking(false)
	element.update_video_frame_and_timeline()
	element.upon_current_playback_position_possibly_changed()
	element.time_marches_on(.other)
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.dispatch_time_update_event()
	})
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.fire_event('seeked')
	})
}

pub fn (mut element HTMLMediaElement) set_current_playback_position(value f64) {
	element.current_playback_position_ = value
	element.upon_has_ended_playback_possibly_changed()
	if mut video := element.video_element_model_ {
		video.update_natural_dimensions()
	}
	element.upon_current_playback_position_possibly_changed()
}

// HTMLMediaElement.cpp's playback-position observation algorithm keeps buffer
// monitoring on its own media task rather than tying it to timeupdate throttling.
pub fn (mut element HTMLMediaElement) upon_current_playback_position_possibly_changed() {
	if !element.playback_manager_ready_ || element.seeking_ {
		return
	}
	current_position := element.current_playback_position()
	if last := element.last_known_current_playback_position_ {
		if last == current_position {
			return
		}
	} else {
		element.last_known_current_playback_position_ = current_position
		return
	}
	element.last_known_current_playback_position_ = current_position
	element.time_marches_on(.normal_playback)
	element.upon_has_ended_playback_possibly_changed()
	if mut video := element.video_element_model_ {
		video.update_natural_dimensions()
	}
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.update_ready_state()
	})
}

pub fn (element &HTMLMediaElement) ended() bool {
	return element.ended_
}

pub fn (element &HTMLMediaElement) blocked() bool {
	return int(element.ready_state_) <= int(MediaReadyState.have_current_data)
}

pub fn (_ &HTMLMediaElement) stalled() bool {
	return false
}

pub fn (element &HTMLMediaElement) potentially_playing() bool {
	return !element.paused_ && !element.ended() && !element.blocked()
}

pub fn (mut element HTMLMediaElement) play() &dom.Promise {
	mut context := webidl.PromiseContext{}
	if document := element.document() {
		settings := document.relevant_settings_object()
		if settings != unsafe { nil } {
			context = unsafe { &EnvironmentSettingsObject(settings) }.stream_promise_context()
		}
	}
	mut promise := dom.Promise.from_webidl(webidl.create_promise_for(context))
	if !element.is_allowed_to_play() {
		promise.reject(dom.js_webidl_value(webidl.dom_exception_value_for_record(
			webidl.DOMException.create_record('NotAllowedError',
				'Media playback is not allowed without user interaction'))))
		return promise
	}
	if media_error := element.error_ {
		if media_error.code == .src_not_supported {
			promise.reject(dom.js_webidl_value(webidl.dom_exception_value_for_record(
				webidl.DOMException.create_record('NotSupportedError', media_error.message))))
			return promise
		}
	}
	element.pending_play_promises_ << promise
	element.play_element()
	return promise
}

pub fn (mut element HTMLMediaElement) play_from_user_interaction() {
	element.play_element()
}

pub fn (mut element HTMLMediaElement) play_element() {
	if element.network_state_ == .empty {
		element.select_resource() or {}
	}
	if element.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ {
		element.continue_fetching_the_resource_after_an_implementation_defined_event() or {}
	}
	if element.has_ended_playback() && element.direction_of_playback() == .forwards {
		element.seek_element(0, .accurate)
	}
	if element.paused_ {
		element.set_paused(false)
		element.play_range_start_ = element.current_time()
		if element.show_poster_ {
			element.set_show_poster(false)
			element.time_marches_on(.normal_playback)
		}
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('play')
		})
		if int(element.ready_state_) <= int(MediaReadyState.have_current_data) {
			element.queue_a_media_element_task(fn [element_pointer] () {
				mut media := unsafe { &HTMLMediaElement(element_pointer) }
				media.fire_event('waiting')
			})
		} else {
			element.notify_about_playing()
			if element.official_playback_position_ == element.duration_ {
				element.reached_end_of_media_playback()
			}
		}
	} else if int(element.ready_state_) >= int(MediaReadyState.have_future_data) {
		promises := element.take_pending_play_promises()
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer, promises] () {
			media := unsafe { &HTMLMediaElement(element_pointer) }
			media.resolve_pending_play_promises(promises)
		})
	}
	element.can_autoplay_ = false
}

pub fn (mut element HTMLMediaElement) notify_about_playing() {
	promises := element.take_pending_play_promises()
	starting_position := element.current_playback_position()
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer, promises, starting_position] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.set_official_playback_position(starting_position)
		media.fire_event('playing')
		media.resolve_pending_play_promises(promises)
	})
	if hook := element.playback_hooks_.play {
		hook()
	}
	element.has_started_playback_ = true
	element.update_audio_play_state()
	element.update_screen_wake_lock()
}

fn (mut element HTMLMediaElement) reject_pending_play_promises(reason dom.JSValue) {
	promises := element.take_pending_play_promises()
	element.reject_pending_play_promises_with(promises, reason)
}

pub fn (mut element HTMLMediaElement) take_pending_play_promises() []&dom.Promise {
	promises := element.pending_play_promises_.clone()
	element.pending_play_promises_.clear()
	return promises
}

pub fn (element &HTMLMediaElement) resolve_pending_play_promises(promises []&dom.Promise) {
	if document := element.document() {
		context := document.begin_temporary_execution_context()
		defer { document.end_temporary_execution_context(context) }
		resolve_media_play_promise_batch(promises)
		return
	}
	resolve_media_play_promise_batch(promises)
}

fn resolve_media_play_promise_batch(promises []&dom.Promise) {
	for promise in promises {
		mut mutable_promise := unsafe { &dom.Promise(promise) }
		mutable_promise.resolve(dom.js_undefined())
	}
}

pub fn (element &HTMLMediaElement) reject_pending_play_promises_with(promises []&dom.Promise, reason dom.JSValue) {
	if document := element.document() {
		context := document.begin_temporary_execution_context()
		defer { document.end_temporary_execution_context(context) }
		reject_media_play_promise_batch(promises, reason)
		return
	}
	reject_media_play_promise_batch(promises, reason)
}

fn reject_media_play_promise_batch(promises []&dom.Promise, reason dom.JSValue) {
	for promise in promises {
		mut mutable_promise := unsafe { &dom.Promise(promise) }
		mutable_promise.reject(reason)
	}
}

fn (element &HTMLMediaElement) reject_pending_play_promises_with_abort_error(promises []&dom.Promise, message string) {
	reason := dom.js_webidl_value(webidl.dom_exception_value_for_record(
		webidl.DOMException.create_record('AbortError', message)))
	element.reject_pending_play_promises_with(promises, reason)
}

pub fn (mut element HTMLMediaElement) pause() {
	if element.network_state_ == .empty {
		element.select_resource() or {}
	}
	element.pause_element()
}

pub fn (mut element HTMLMediaElement) pause_element() {
	element.can_autoplay_ = false
	if element.paused_ {
		return
	}
	if start := element.play_range_start_ {
		if element.current_time() >= start {
			element.played_.add_range(start, element.current_time())
		}
	}
	element.play_range_start_ = none
	element.set_paused(true)
	promises := element.take_pending_play_promises()
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer, promises] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.dispatch_time_update_event()
		media.fire_event('pause')
		media.reject_pending_play_promises_with_abort_error(promises, 'Media playback was paused')
	})
	element.set_official_playback_position(element.current_playback_position())
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
		return error('IndexSizeError: Volume must be in the range 0.0 to 1.0, inclusive')
	}
	if element.volume_ != volume {
		element.volume_ = volume
		element.volume_or_muted_attribute_changed()
	}
}

pub fn (mut element HTMLMediaElement) set_muted(muted bool) {
	if element.muted_ != muted {
		element.muted_ = muted
		element.volume_or_muted_attribute_changed()
		element.invalidate_media_state_style(['muted'])
	}
}

pub fn (mut element HTMLMediaElement) set_page_muted(muted bool) {
	if document := element.document() {
		if document.has_page() && document.page().set_audio_muted(muted) { return }
	}
	// Standalone/unconfigured Page adapter; concrete media uses its actual Page.
	element.page_muted_ = muted
	element.page_mute_state_changed()
}

pub fn (mut element HTMLMediaElement) volume_or_muted_attribute_changed() {
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.fire_event('volumechange')
	})
	if !element.is_allowed_to_play() {
		element.pause_element()
	}
	element.update_volume()
}

pub fn (mut element HTMLMediaElement) page_mute_state_changed() {
	element.update_volume()
}

pub fn (mut element HTMLMediaElement) update_volume() {
	if hook := element.playback_hooks_.set_volume {
		hook(element.effective_media_volume())
	}
	element.update_audio_play_state()
}

pub fn (element &HTMLMediaElement) effective_media_volume() f64 {
	mut page_muted := element.page_muted_
	if document := element.document() {
		if document.has_page() {
			if muted := document.page().is_audio_muted() { page_muted = muted }
		}
	}
	return if element.muted_ || page_muted { 0 } else { math.clamp(element.volume_, 0, 1) }
}

pub fn (mut element HTMLMediaElement) set_default_playback_rate(rate f64) {
	if element.default_playback_rate_ != rate {
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('ratechange')
		})
	}
	element.default_playback_rate_ = rate
}

pub fn (mut element HTMLMediaElement) set_playback_rate(rate f64) ! {
	if !math.is_finite(rate) || rate < 0 || rate > 64 {
		return error('NotSupportedError: Playback rate is outside of the supported range.')
	}
	if element.playback_rate_ != rate {
		element_pointer := voidptr(&element)
		element.queue_a_media_element_task(fn [element_pointer] () {
			mut media := unsafe { &HTMLMediaElement(element_pointer) }
			media.fire_event('ratechange')
		})
	}
	element.playback_rate_ = rate
	element.update_playback_rate()
}

fn (element &HTMLMediaElement) update_playback_rate() {
	if !element.playback_manager_ready_ {
		return
	}
	if set_rate := element.playback_hooks_.set_playback_rate {
		set_rate(f32(element.playback_rate_))
	}
}

pub fn (mut element HTMLMediaElement) advance_playback(elapsed_seconds f64) {
	if !element.potentially_playing() || elapsed_seconds <= 0 {
		return
	}
	new_position := element.current_playback_position_ + elapsed_seconds * element.playback_rate_
	if element.playback_rate_ >= 0 && !math.is_nan(element.duration_) && new_position >= element.duration_ {
		element.current_playback_position_ = element.duration_
		element.upon_has_ended_playback_possibly_changed()
		element.reached_end_of_media_playback()
		return
	}
	element.current_playback_position_ = if new_position < 0 { 0 } else { new_position }
	element.upon_current_playback_position_possibly_changed()
}

pub fn (element &HTMLMediaElement) is_eligible_for_autoplay() bool {
	if !element.can_autoplay_ || !element.paused_ || !element.autoplay() || !element.allow_autoplay_ {
		return false
	}
	if html_element := element.associated_element_ {
		dom_element := unsafe { &dom.Element(html_element) }
		document := dom_element.document()
		sandboxing := SandboxingFlagSet{ bits: document.active_sandboxing_flag_bits() }
		return !sandboxing.contains(.sandboxed_automatic_features)
			&& document.is_allowed_to_use_feature(.autoplay)
	}
	return true
}

// HTMLMediaElement.cpp:3081. Playback permission follows the live document,
// its sticky Window activation and the user agent's per-origin settings.
pub fn (element &HTMLMediaElement) is_allowed_to_play() bool {
	document := element.document() or { return true }
	if window := document.get_window() {
		if window.has_sticky_activation() {
			return true
		}
	}
	return match AutoplaySettings.the().decision_for_origin(document, document.origin()) {
		.allowed { true }
		.allowed_if_inaudible { element.effective_media_volume() == 0 }
		.blocked { false }
	}
}

pub fn (element &HTMLMediaElement) direction_of_playback() MediaPlaybackDirection {
	return if element.playback_rate_ >= 0 { .forwards } else { .backwards }
}

pub fn (element &HTMLMediaElement) has_ended_playback() bool {
	if int(element.ready_state_) < int(MediaReadyState.have_metadata) {
		return false
	}
	if element.current_playback_position_ == element.duration_ && element.direction_of_playback() == .forwards && !element.loop_was_specified_at_end_ {
		return true
	}
	return element.current_playback_position_ == 0 && element.direction_of_playback() == .backwards
}

pub fn (mut element HTMLMediaElement) upon_has_ended_playback_possibly_changed() {
	element_pointer := voidptr(&element)
	run_when_event_loop_reaches_step_1(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		// The cached attribute reflects the live owner at the last step-1 boundary.
		media.set_ended(media.has_ended_playback() && media.direction_of_playback() == .forwards)
	})
}

pub fn (mut element HTMLMediaElement) reached_end_of_media_playback() {
	element.loop_was_specified_at_end_ = element.loop()
	if element.loop_was_specified_at_end_ {
		if !element.paused_ {
			element.seek_element(0, .accurate)
		}
		return
	}
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.dispatch_time_update_event()
		if media.has_ended_playback() && media.direction_of_playback() == .forwards && !media.paused_ {
			media.set_paused(true)
			media.fire_event('pause')
			promises := media.take_pending_play_promises()
			media.reject_pending_play_promises_with_abort_error(promises, 'Media playback has ended')
		}
		media.fire_event('ended')
	})
}

pub fn (mut element HTMLMediaElement) dispatch_time_update_event() {
	element.running_time_update_event_ = true
	element.last_time_update_event_time_ = time.sys_mono_now()
	element.fire_event('timeupdate')
	element.running_time_update_event_ = false
}

pub fn (mut element HTMLMediaElement) time_marches_on(reason TimeMarchesOnReason) {
	element.time_marches_on_at(reason, time.sys_mono_now())
}

fn (mut element HTMLMediaElement) time_marches_on_at(reason TimeMarchesOnReason, now i64) {
	if reason != .normal_playback || element.running_time_update_event_ {
		return
	}
	// Upstream chooses the 250ms end of the permitted interval and compares
	// monotonic elapsed wall time, independently of the media playback clock.
	if last := element.last_time_update_event_time_ {
		if now - last <= 250_000_000 {
			return
		}
	}
	element.last_time_update_event_time_ = now
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer] () {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.dispatch_time_update_event()
	})
}

pub fn (mut element HTMLMediaElement) set_audio_track_enabled(track &AudioTrack, enabled bool) {
	if hook := element.playback_hooks_.set_audio_track {
		hook(track, enabled)
	}
	element.update_audio_play_state()
	element.update_screen_wake_lock()
}

pub fn (mut element HTMLMediaElement) set_selected_video_track(track ?&VideoTrack) {
	if source := element.video_frame_source_ {
		mut mutable_source := unsafe { &painting.VideoFrameSource(source) }
		mutable_source.clear()
	}
	// Materialize before changing selection so the first size queues resize.
	video_owner := element.ensure_video_element_model()
	element.selected_video_track_ = track
	if mut video := video_owner {
		if selected := track {
			video.set_intrinsic_video_dimensions(VideoDimensions{
				width: selected.base.pixel_width
				height: selected.base.pixel_height
			})
		} else {
			video.set_intrinsic_video_dimensions(none)
		}
	}
	if hook := element.playback_hooks_.set_video_track {
		hook(track)
	}
	element.update_screen_wake_lock()
}

fn (mut element HTMLMediaElement) ensure_video_element_model() ?&HTMLVideoElementModel {
	if video := element.video_element_model_ { return video }
	html_element := element.associated_element_ or { return none }
	dom_element := unsafe { &dom.Element(html_element) }
	if !dom_element.is_html_element() || dom_element.local_name() != 'video' { return none }
	return html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(dom_element) })
}

pub fn (mut element HTMLMediaElement) ensure_video_frame_source() &painting.VideoFrameSource {
	if source := element.video_frame_source_ {
		return source
	}
	source := painting.VideoFrameSource.create()
	element.video_frame_source_ = source
	return source
}

pub fn (mut element HTMLMediaElement) update_video_frame_and_timeline() {
	if !element.playback_manager_ready_ {
		return
	}
	if frame_hook := element.playback_hooks_.current_video_frame {
		frame := frame_hook()
		if current_frame := frame {
			mut source := element.ensure_video_frame_source()
			source.update(current_frame)
			if mut video := element.ensure_video_element_model() {
				video.set_intrinsic_video_dimensions(VideoDimensions{
					width: current_frame.width
					height: current_frame.height
				})
			}
		} else if source := element.video_frame_source_ {
			mut mutable_source := unsafe { &painting.VideoFrameSource(source) }
			mutable_source.clear()
		}
	}
	if element.seeking_ {
		return
	}
	if time_hook := element.playback_hooks_.current_time {
		new_position := time_hook()
		if new_position != element.current_playback_position_ {
			element.set_current_playback_position(new_position)
		}
	}
}

fn (element &HTMLMediaElement) fire_track_add_event(target &dom.EventTarget, track TrackEventTrack) {
	event := TrackEvent.create('addtrack', TrackEventInit{track: track})
	mut base_event := unsafe { &dom.Event(event) }
	if document := element.document() {
		settings := document.relevant_settings_object()
		if settings != unsafe { nil } {
			base_event.set_time_stamp(unsafe { &EnvironmentSettingsObject(settings) }.global_relative_event_timestamp())
		}
	}
	target.dispatch_event(base_event)
}

pub fn (mut element HTMLMediaElement) on_audio_track_added(metadata MediaTrackMetadata) &AudioTrack {
	element_pointer := voidptr(&element)
	track := AudioTrack.create(metadata, media_element_noop_change_task, fn [element_pointer] (track &AudioTrack, enabled bool) {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.set_audio_track_enabled(track, enabled)
	})
	mut mutable_track := unsafe { &AudioTrack(track) }
	mutable_track.base.set_media_element(unsafe { &HTMLMediaElement(element_pointer) })
	mutable_track.queue_change_task_for_list = fn [element_pointer] (list &AudioTrackList) {
		media := unsafe { &HTMLMediaElement(element_pointer) }
		media.queue_a_media_element_task(fn [element_pointer, list] () {
			media := unsafe { &HTMLMediaElement(element_pointer) }
			mut event := dom.Event.create('change', dom.EventInit{})
			if document := media.document() {
				settings := document.relevant_settings_object()
				if settings != unsafe { nil } {
					event.set_time_stamp(unsafe { &EnvironmentSettingsObject(settings) }.global_relative_event_timestamp())
				}
			}
			list.dispatch_event(event)
		})
	}
	element.audio_tracks_.add_track(track)
	enable := !element.audio_tracks_.tracks().any(voidptr(it) != voidptr(track) && it.enabled)
	if enable {
		mutable_track.set_enabled(true)
	}
	if metadata.kind == none {
		mutable_track.base.kind = if enable { 'main' } else { 'translation' }
	}
	element.fire_track_add_event(&element.audio_tracks_.EventTarget, TrackEventTrack.from_audio(track))
	element.request_paint_command_rebuild()
	return track
}

pub fn (mut element HTMLMediaElement) on_video_track_added(metadata MediaTrackMetadata) &VideoTrack {
	element_pointer := voidptr(&element)
	track := VideoTrack.create(metadata, media_element_noop_change_task, fn [element_pointer] (track ?&VideoTrack) {
		mut media := unsafe { &HTMLMediaElement(element_pointer) }
		media.set_selected_video_track(track)
	})
	mut mutable_track := unsafe { &VideoTrack(track) }
	mutable_track.base.set_media_element(unsafe { &HTMLMediaElement(element_pointer) })
	mutable_track.queue_change_task_for_list = fn [element_pointer] (list &VideoTrackList) {
		media := unsafe { &HTMLMediaElement(element_pointer) }
		media.queue_a_media_element_task(fn [element_pointer, list] () {
			media := unsafe { &HTMLMediaElement(element_pointer) }
			mut event := dom.Event.create('change', dom.EventInit{})
			if document := media.document() {
				settings := document.relevant_settings_object()
				if settings != unsafe { nil } {
					event.set_time_stamp(unsafe { &EnvironmentSettingsObject(settings) }.global_relative_event_timestamp())
				}
			}
			list.dispatch_event(event)
		})
	}
	element.video_tracks_.add_track(track)
	should_select := element.video_tracks_.selected_index() == -1
	if should_select {
		mutable_track.set_selected(true)
	}
	if metadata.kind == none {
		mutable_track.base.kind = if should_select { 'main' } else { 'translation' }
	}
	element.fire_track_add_event(&element.video_tracks_.EventTarget, TrackEventTrack.from_video(track))
	return track
}

pub fn (mut element HTMLMediaElement) on_metadata_parsed(duration f64) {
	element.update_volume()
	if start_time_realtime := element.playback_hooks_.start_time_realtime {
		element.timeline_offset_microseconds_ = start_time_realtime()
	} else {
		element.timeline_offset_microseconds_ = element.playback_start_time_realtime_microseconds_
	}
	element.current_playback_position_ = 0
	element.set_official_playback_position(0)
	element.set_duration(duration)
	element.set_ready_state(.have_metadata)
	if element.default_playback_start_ > 0 {
		element.seek_element(element.default_playback_start_, .accurate)
	}
	element.default_playback_start_ = 0
	if !element.audio_tracks_.has_enabled_track() {
		if track := element.audio_tracks_.item(0) {
			mut mutable_track := unsafe { &AudioTrack(track) }
			mutable_track.set_enabled(true)
		}
	}
	if element.video_tracks_.selected_index() == -1 {
		if track := element.video_tracks_.item(0) {
			mut mutable_track := unsafe { &VideoTrack(track) }
			mutable_track.set_selected(true)
		}
	}
	// Source starts the manager only after both track selections, before
	// observing the buffering state that its start operation may change.
	if element.playback_manager_ready_ {
		if start := element.playback_hooks_.start {
			start()
		}
	}
	element.update_ready_state()
}

pub fn (mut element HTMLMediaElement) set_up_playback_manager() {
	element.playback_manager_ready_ = true
	element.update_playback_rate()
}

pub fn (mut element HTMLMediaElement) process_media_data(status MediaFetchingStatus) {
	match status {
		.complete {
			element.fire_event('progress')
			element.network_state_ = .idle
			element.fire_event('suspend')
			element.update_ready_state()
		}
		.ongoing {
			element_pointer := voidptr(&element)
			element.queue_a_media_element_task(fn [element_pointer] () {
				mut element := unsafe { &HTMLMediaElement(element_pointer) }
				element.network_state_ = .loading
			})
			now_ms := time.sys_mono_now() / 1_000_000
			if last := element.last_progress_event_time_ms_ {
				if now_ms - last <= 350 {
					return
				}
			}
			element.last_progress_event_time_ms_ = now_ms
			element.queue_a_media_element_task(fn [element_pointer] () {
				mut element := unsafe { &HTMLMediaElement(element_pointer) }
				element.fire_event('progress')
			})
			element.update_ready_state()
		}
		.interrupted {
			if int(element.ready_state_) > int(MediaReadyState.have_nothing) {
				element.cancel_the_fetching_process()
				element.error_ = &MediaError{
					code: .network
					message: 'Connection interrupted'
				}
				element.network_state_ = .idle
				element.finish_delaying_load_event()
				element.fire_event('error')
			}
		}
	}
}

pub fn (mut element HTMLMediaElement) handle_media_source_failure(promises []&dom.Promise, message string) {
	element.error_ = &MediaError{
		code: .src_not_supported
		message: message
	}
	element.forget_media_resource_specific_tracks()
	element.network_state_ = .no_source
	element.set_show_poster(true)
	element.fire_event('error')
	if element.error_ != none {
		element.reject_pending_play_promises_with(promises, dom.js_webidl_value(webidl.dom_exception_value_for_record(
			webidl.DOMException.create_record('NotSupportedError', 'Media is not supported'))))
		element.finish_delaying_load_event()
	}
}

pub fn (mut element HTMLMediaElement) forget_media_resource_specific_tracks() {
	element.audio_tracks_.remove_all_tracks()
	element.video_tracks_.remove_all_tracks()
	element.update_audio_play_state()
	element.selected_video_track_ = none
	if mut video := element.video_element_model_ {
		video.set_intrinsic_video_dimensions(none)
	}
	element.playback_manager_ready_ = false
	element.last_known_current_playback_position_ = none
	element.playback_has_future_data_ = false
	element.update_screen_wake_lock()
}

pub fn (mut element HTMLMediaElement) on_playback_manager_state_change(buffering bool) {
	if element.seeking_ && !buffering {
		element.finish_seeking_element()
	}
	element.playback_has_future_data_ = !buffering
	if int(element.ready_state_) >= int(MediaReadyState.have_metadata) {
		element.update_ready_state()
	}
}

pub fn (mut element HTMLMediaElement) add_text_track(kind TextTrackKind, label string, language string) &TextTrack {
	mut track := TextTrack.create()
	track.set_kind(kind)
	track.set_label(label)
	track.set_language(language)
	track.set_readiness_state(.loaded)
	track.set_mode(.hidden)
	track.set_media_element(element)
	element.text_tracks_.add_track(track)
	element_pointer := voidptr(&element)
	element.queue_a_media_element_task(fn [element_pointer, track] () {
		media := unsafe { &HTMLMediaElement(element_pointer) }
		media.fire_track_add_event(&media.text_tracks_.EventTarget, TrackEventTrack.from_text(track))
	})
	return track
}

pub fn (mut element HTMLMediaElement) create_controls() {
	if element.destroying_controls_ { return }
	if element.controls_ == none {
		// Optional::emplace publishes its occupied state before construction.
		mut controls := &MediaControls{media: &element}
		element.controls_ = controls
		controls.initialize()
	}
}

pub fn (mut element HTMLMediaElement) destroy_controls() {
	if element.destroying_controls_ { return }
	if mut controls := element.controls_ {
		// Optional::clear keeps its value occupied throughout the destructor.
		// Shadow removal callbacks must not publish another controller mid-detach.
		element.destroying_controls_ = true
		controls.destroy()
		element.controls_ = none
		element.destroying_controls_ = false
	}
}

pub fn (element &HTMLMediaElement) has_controls() bool {
	return element.controls_ != none
}

pub fn (element &HTMLMediaElement) set_on_event(name string, handler ?&dom.CallbackType) {
	element.event_target_.set_event_handler_attribute(name, handler)
}

pub fn (element &HTMLMediaElement) event_target() &dom.EventTarget {
	return element.event_target_
}
