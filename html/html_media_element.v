// Copyright (c) 2020, the SerenityOS developers
// Copyright (c) 2023-2026, Tim Flynn <trflynn89@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLMediaElement.{h,cpp}. Decoder/network integration is
// supplied by MediaResourceFetchHook; the HTML state machine remains local.
module html

import dom
import fileapi
import math

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

pub type MediaPlaybackSetAudioTrackHook = fn(&AudioTrack, bool)

pub type MediaPlaybackSetVideoTrackHook = fn(?&VideoTrack)

pub type MediaPlaybackSeekHook = fn(f64, MediaPlaybackSeekMode)

pub type MediaPlaybackCurrentTimeHook = fn() f64

pub type MediaPlaybackCurrentFrameHook = fn() ?&dom.ImmutableBitmap_

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
	play                ?MediaPlaybackNoArgHook
	pause               ?MediaPlaybackNoArgHook
	set_volume          ?MediaPlaybackSetVolumeHook
	set_audio_track     ?MediaPlaybackSetAudioTrackHook
	set_video_track     ?MediaPlaybackSetVideoTrackHook
	seek                ?MediaPlaybackSeekHook
	current_time        ?MediaPlaybackCurrentTimeHook
	current_video_frame ?MediaPlaybackCurrentFrameHook
	buffered_ranges     ?MediaPlaybackBufferedRangesHook
}

@[heap]
pub struct MediaExternalContentSource {
mut:
	frame_ ?&dom.ImmutableBitmap_
}

pub fn (source &MediaExternalContentSource) frame() ?&dom.ImmutableBitmap_ {
	return source.frame_
}

pub fn (mut source MediaExternalContentSource) update(frame ?&dom.ImmutableBitmap_) {
	source.frame_ = frame
}

pub fn (mut source MediaExternalContentSource) clear() {
	source.frame_ = none
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
	duration_                   f64 = math.nan()
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
	text_tracks_                &TextTrackList = unsafe { nil }
	can_autoplay_               bool = true
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
	playback_hooks_             MediaPlaybackManagerHooks
	playback_manager_ready_     bool
	playback_has_future_data_   bool
	selected_video_track_       ?&VideoTrack
	external_content_source_    ?&MediaExternalContentSource
	accepts_byte_ranges_        bool
	last_fetch_offset_          u64
	loop_was_specified_at_end_  bool
	running_time_update_event_  bool
	last_time_update_position_  ?f64
	allow_autoplay_             bool = true
	document_observer_          ?&dom.DocumentObserver
	delaying_load_event_        ?dom.DocumentLoadEventDelayer
	resource_selection_pending_ bool
	resource_fetch_started_     bool
	assigned_media_provider_    ?MediaProviderObject
}

pub fn HTMLMediaElement.create(element ?&dom.HTMLElement, base_url dom.URL) &HTMLMediaElement {
	mut media := &HTMLMediaElement{
		EventTarget: dom.EventTarget{}
		event_target_: dom.EventTarget.new()
		associated_element_: element
		base_url_: base_url
		audio_tracks_: &AudioTrackList{}
		video_tracks_: &VideoTrackList{}
		text_tracks_: &TextTrackList{}
		buffered_: &TimeRanges{}
		played_: &TimeRanges{}
		seekable_: &TimeRanges{}
	}
	if html_element := element {
		dom_element := unsafe { &dom.Element(html_element) }
		mut document := dom_element.document()
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
	}
	return media
}

fn html_media_element_adopted_from_callback(target voidptr, old_document &dom.Document) {
	mut media := unsafe { &HTMLMediaElement(target) }
	media.adopted_from(old_document)
}

pub fn (media &HTMLMediaElement) is_focusable() bool {
	_ = media
	return true
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
	if element.local_name() == 'audio' {
		mut audio := unsafe { &dom.HTMLAudioElement(element) }
		if audio.media_element_model_ == unsafe { nil } {
			mut model := HTMLMediaElement.create(unsafe { &dom.HTMLElement(element) },
				element.document().base_url())
			model.set_source(element.get_attribute('src'))
			model.set_crossorigin(element.get_attribute('crossorigin'))
			audio.media_element_model_ = model
		}
		return unsafe { &HTMLMediaElement(audio.media_element_model_) }
	}
	if element.local_name() == 'video' {
		mut video := unsafe { &dom.HTMLVideoElement(element) }
		if video.media_element_model_ == unsafe { nil } {
			mut model := HTMLMediaElement.create(unsafe { &dom.HTMLElement(element) },
				element.document().base_url())
			model.set_source(element.get_attribute('src'))
			model.set_crossorigin(element.get_attribute('crossorigin'))
			video.media_element_model_ = model
		}
		return unsafe { &HTMLMediaElement(video.media_element_model_) }
	}
	return none
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
	if observer := element.document_observer_ {
		mut mutable_observer := unsafe { &dom.DocumentObserver(observer) }
		mutable_observer.retarget_for_adoption(mut new_document)
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

	// Resource-selection tasks queued against an inactive document cannot run.
	// Drop their stale task-source entries and continue in the adopting document
	// unless a resource fetch had already begun.
	if !old_document.is_fully_active() && !element.resource_fetch_started_
		&& element.resource_selection_pending_ {
		mut queue := main_thread_event_loop().task_queue()
		queue.remove_tasks_matching(fn (task &Task) bool {
			return task.source() == .media_element
		})
		element.select_resource() or {}
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

pub fn (mut element HTMLMediaElement) media_source_attachment_did_open() {
	element.finish_delaying_load_event()
	element.set_up_playback_manager()
}

pub fn (mut element HTMLMediaElement) media_source_set_duration(duration f64) {
	element.set_duration(duration)
}

pub fn (mut element HTMLMediaElement) media_source_initialization_segment_received(duration f64) {
	element.on_metadata_parsed(duration)
}

pub fn (mut element HTMLMediaElement) media_source_update_buffered_ranges(ranges []MediaBufferedRange) {
	element.buffered_.clear()
	for range_ in ranges {
		element.buffered_.add_range(range_.start, range_.end)
	}
	element.playback_has_future_data_ = ranges.any(it.end > element.current_playback_position_)
	element.update_ready_state()
}

pub fn (mut element HTMLMediaElement) toggle_fullscreen() {
	html_element := element.associated_element_ or { return }
	mut dom_element := unsafe { &dom.Element(html_element) }
	mut document := dom_element.document()
	if fullscreen_element := document.fullscreen_element() {
		if fullscreen_element == dom_element {
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
				source := source_element.get_attribute_value('src')
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
}

// V's host event loop drains this module-local task source synchronously. The
// algorithm boundary is retained so embedders can replace it with their task
// queue without changing media state-machine callers.
pub fn (_ &HTMLMediaElement) queue_a_media_element_task(steps MediaElementTask) {
	steps()
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
	element.load_element()!
}

pub fn (mut element HTMLMediaElement) load_element() ! {
	if element.network_state_ in [.loading, .idle] {
		element.fire_event('abort')
	}
	if element.network_state_ != .empty {
		element.fire_event('emptied')
		if !element.paused_ {
			element.set_paused(true)
			promises := element.take_pending_play_promises()
			element.reject_pending_play_promises_with(promises, dom.js_string('AbortError: Media playback was aborted'))
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
		element.official_playback_position_ = 0
		element.dispatch_time_update_event()
	}
	element.official_playback_position_ = 0
	element.set_duration(math.nan())
	element.set_ended(false)
	element.set_show_poster(true)
	element.playback_rate_ = element.default_playback_rate_
	element.can_autoplay_ = true
	element.buffered_.clear()
	element.played_.clear()
	element.seekable_.clear()
	element.select_resource()!
}

pub fn (mut element HTMLMediaElement) select_resource() ! {
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
	element.reject_pending_play_promises(dom.js_string('NotSupportedError: ${last_error}'))
	element.fire_event('error')
	return error('NotSupportedError: ${last_error}')
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
	entry := fileapi.resolve_a_blob_url(url.serialize()) or { return false }
	if entry.object.kind != .media_source {
		return false
	}

	mut access := fileapi.BlobURLObtainEnvironment(fileapi.BlobURLEnvironment{})
	if html_element := element.associated_element_ {
		document := unsafe { &dom.Element(html_element) }.document()
		document_url := dom.URL{document.url_string()}
		is_top_level_self_fetch := if navigable := document.navigable() {
			navigable.parent() == none && document_url == url
		} else {
			false
		}
		if is_top_level_self_fetch {
			access = fileapi.BlobURLObtainEnvironment(fileapi.TopLevelSelfFetch{})
		} else {
			origin := document.origin()
			access = fileapi.BlobURLObtainEnvironment(fileapi.BlobURLEnvironment{
				id: document_url.serialize()
				origin: origin.serialize()
				storage_key: origin.serialize_for_ipc()
			})
		}
	} else {
		origin := element.base_url_.origin()
		access = fileapi.BlobURLObtainEnvironment(fileapi.BlobURLEnvironment{
			id: element.base_url_.serialize()
			origin: origin.serialize()
			storage_key: origin.serialize_for_ipc()
		})
	}
	object := fileapi.obtain_a_blob_object(entry, access) or {
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
	for metadata in response.audio_tracks {
		element.on_audio_track_added(metadata)
	}
	for metadata in response.video_tracks {
		element.on_video_track_added(metadata)
	}
	element.on_metadata_parsed(response.duration)
	element.fire_event('loadedmetadata')
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
	if element.is_eligible_for_autoplay() {
		_ = element.play()
	}
}

pub fn (mut element HTMLMediaElement) set_ready_state(state MediaReadyState) {
	old_state := element.ready_state_
	if old_state == state {
		return
	}
	element.ready_state_ = state
	if int(old_state) < int(MediaReadyState.have_current_data) && int(state) >= int(MediaReadyState.have_current_data) {
		element.fire_event('loadeddata')
	}
	if int(old_state) < int(MediaReadyState.have_future_data) && int(state) >= int(MediaReadyState.have_future_data) {
		element.fire_event('canplay')
		if !element.paused_ {
			element.notify_about_playing()
		}
	}
	if int(old_state) < int(MediaReadyState.have_enough_data) && int(state) >= int(MediaReadyState.have_enough_data) {
		element.fire_event('canplaythrough')
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
}

pub fn (mut element HTMLMediaElement) set_duration(duration f64) {
	if !math.is_nan(duration) {
		element.fire_event('durationchange')
		if element.current_playback_position_ > duration {
			element.seek_element(duration, .accurate)
		}
	}
	element.duration_ = duration
	element.upon_has_ended_playback_possibly_changed()
}

pub fn (mut element HTMLMediaElement) set_show_poster(show_poster bool) {
	if element.show_poster_ == show_poster {
		return
	}
	element.show_poster_ = show_poster
}

pub fn (mut element HTMLMediaElement) set_paused(paused bool) {
	if element.paused_ == paused {
		return
	}
	element.paused_ = paused
	if paused {
		if hook := element.playback_hooks_.pause {
			hook()
		}
	}
}

pub fn (mut element HTMLMediaElement) set_ended(ended bool) {
	element.ended_ = ended
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

pub fn (mut element HTMLMediaElement) seek_element(value f64, mode MediaSeekMode) {
	element.set_show_poster(false)
	if element.ready_state_ == .have_nothing {
		return
	}
	element.set_seeking(true)
	element.fire_event('seeking')
	mut target := if value < 0 { 0.0 } else { value }
	if !math.is_nan(element.duration_) && target > element.duration_ {
		target = element.duration_
	}
	if !element.seekable_.in_range(target) && element.seekable_.length() > 0 {
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
	element.official_playback_position_ = target
	if hook := element.playback_hooks_.seek {
		mut playback_seek_mode := MediaPlaybackSeekMode.accurate
		if mode == .approximate_for_speed {
			if target < element.current_playback_position_ {
				playback_seek_mode = .fast_before
			} else if target > element.current_playback_position_ {
				playback_seek_mode = .fast_after
			}
		}
		hook(target, playback_seek_mode)
	} else {
		element.current_playback_position_ = target
		element.upon_has_ended_playback_possibly_changed()
		element.finish_seeking_element()
	}
}

pub fn (mut element HTMLMediaElement) finish_seeking_element() {
	element.set_seeking(false)
	element.update_video_frame_and_timeline()
	element.time_marches_on(.other)
	element.dispatch_time_update_event()
	element.fire_event('seeked')
}

pub fn (mut element HTMLMediaElement) set_current_playback_position(value f64) {
	element.current_playback_position_ = value
	element.official_playback_position_ = value
	element.upon_has_ended_playback_possibly_changed()
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
	mut promise := dom.Promise.create()
	if media_error := element.error_ {
		if media_error.code == .src_not_supported {
			promise.reject(dom.js_string('NotSupportedError: media source is unsupported'))
			return promise
		}
	}
	element.pending_play_promises_ << promise
	element.play_element()
	return promise
}

pub fn (mut element HTMLMediaElement) play_element() {
	if element.network_state_ == .empty {
		element.select_resource() or {}
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
		element.fire_event('play')
		if int(element.ready_state_) <= int(MediaReadyState.have_current_data) {
			element.fire_event('waiting')
		} else {
			element.notify_about_playing()
			if element.official_playback_position_ == element.duration_ {
				element.reached_end_of_media_playback()
			}
		}
	} else if int(element.ready_state_) >= int(MediaReadyState.have_future_data) {
		promises := element.take_pending_play_promises()
		element.resolve_pending_play_promises(promises)
	}
	element.can_autoplay_ = false
}

pub fn (mut element HTMLMediaElement) notify_about_playing() {
	promises := element.take_pending_play_promises()
	element.fire_event('playing')
	element.resolve_pending_play_promises(promises)
	if hook := element.playback_hooks_.play {
		hook()
	}
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

pub fn (_ &HTMLMediaElement) resolve_pending_play_promises(promises []&dom.Promise) {
	for promise in promises {
		mut mutable_promise := unsafe { &dom.Promise(promise) }
		mutable_promise.resolve(dom.js_undefined())
	}
}

pub fn (_ &HTMLMediaElement) reject_pending_play_promises_with(promises []&dom.Promise, reason dom.JSValue) {
	for promise in promises {
		mut mutable_promise := unsafe { &dom.Promise(promise) }
		mutable_promise.reject(reason)
	}
}

pub fn (mut element HTMLMediaElement) pause() {
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
	element.dispatch_time_update_event()
	element.fire_event('pause')
	element.reject_pending_play_promises_with(promises, dom.js_string('AbortError: Media playback was paused'))
	if !element.seeking_ {
		element.official_playback_position_ = element.current_playback_position_
	}
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
		element.volume_or_muted_attribute_changed()
	}
}

pub fn (mut element HTMLMediaElement) set_muted(muted bool) {
	if element.muted_ != muted {
		element.muted_ = muted
		element.volume_or_muted_attribute_changed()
	}
}

pub fn (mut element HTMLMediaElement) set_page_muted(muted bool) {
	element.page_muted_ = muted
	element.page_mute_state_changed()
}

pub fn (mut element HTMLMediaElement) volume_or_muted_attribute_changed() {
	element.fire_event('volumechange')
	element.update_volume()
}

pub fn (mut element HTMLMediaElement) page_mute_state_changed() {
	element.update_volume()
}

pub fn (mut element HTMLMediaElement) update_volume() {
	if hook := element.playback_hooks_.set_volume {
		hook(element.effective_media_volume())
	}
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
	if rate != 1.0 {
		return error('NotSupportedError: Playback rates other than 1 are not supported')
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
	if element.playback_rate_ >= 0 && !math.is_nan(element.duration_) && new_position >= element.duration_ {
		element.current_playback_position_ = element.duration_
		element.official_playback_position_ = element.duration_
		element.upon_has_ended_playback_possibly_changed()
		element.reached_end_of_media_playback()
		return
	}
	element.current_playback_position_ = if new_position < 0 { 0 } else { new_position }
	element.official_playback_position_ = element.current_playback_position_
	element.time_marches_on(.normal_playback)
}

pub fn (element &HTMLMediaElement) is_eligible_for_autoplay() bool {
	if !element.can_autoplay_ || !element.paused_ || !element.autoplay_ || !element.allow_autoplay_ {
		return false
	}
	if html_element := element.associated_element_ {
		dom_element := unsafe { &dom.Element(html_element) }
		return dom_element.document().is_allowed_to_use_feature(.autoplay)
	}
	return true
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
	element.set_ended(element.has_ended_playback() && element.direction_of_playback() == .forwards)
}

pub fn (mut element HTMLMediaElement) reached_end_of_media_playback() {
	element.loop_was_specified_at_end_ = element.loop_
	if element.loop_was_specified_at_end_ {
		if !element.paused_ {
			element.seek_element(0, .accurate)
		}
		return
	}
	element.dispatch_time_update_event()
	if element.has_ended_playback() && element.direction_of_playback() == .forwards && !element.paused_ {
		element.set_paused(true)
		element.fire_event('pause')
		promises := element.take_pending_play_promises()
		element.reject_pending_play_promises_with(promises, dom.js_string('AbortError: Media playback has ended'))
	}
	element.fire_event('ended')
}

pub fn (mut element HTMLMediaElement) dispatch_time_update_event() {
	element.running_time_update_event_ = true
	element.last_time_update_position_ = element.current_playback_position_
	element.fire_event('timeupdate')
	element.running_time_update_event_ = false
}

pub fn (mut element HTMLMediaElement) time_marches_on(reason TimeMarchesOnReason) {
	if reason != .normal_playback || element.running_time_update_event_ {
		return
	}
	last_position := element.last_time_update_position_ or {
		element.dispatch_time_update_event()
		element.update_ready_state()
		return
	}
	// The host tick does not expose wall-clock time. Advancing by at least one
	// frame is the equivalent opportunity to satisfy upstream's 15-250ms rule.
	if math.abs(element.current_playback_position_ - last_position) >= 0.015 {
		element.dispatch_time_update_event()
		element.update_ready_state()
	}
}

pub fn (mut element HTMLMediaElement) set_audio_track_enabled(track &AudioTrack, enabled bool) {
	if hook := element.playback_hooks_.set_audio_track {
		hook(track, enabled)
	}
}

pub fn (mut element HTMLMediaElement) set_selected_video_track(track ?&VideoTrack) {
	if source := element.external_content_source_ {
		mut mutable_source := unsafe { &MediaExternalContentSource(source) }
		mutable_source.clear()
	}
	element.selected_video_track_ = track
	if hook := element.playback_hooks_.set_video_track {
		hook(track)
	}
}

pub fn (mut element HTMLMediaElement) ensure_external_content_source() &MediaExternalContentSource {
	if source := element.external_content_source_ {
		return source
	}
	source := &MediaExternalContentSource{}
	element.external_content_source_ = source
	return source
}

pub fn (mut element HTMLMediaElement) update_video_frame_and_timeline() {
	if !element.playback_manager_ready_ {
		return
	}
	if frame_hook := element.playback_hooks_.current_video_frame {
		frame := frame_hook()
		mut source := element.ensure_external_content_source()
		source.update(frame)
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

pub fn (mut element HTMLMediaElement) on_audio_track_added(metadata MediaTrackMetadata) &AudioTrack {
	track := AudioTrack.create(metadata, media_element_noop_change_task, media_element_noop_audio_enabled)
	element.audio_tracks_.add_track(track)
	mut mutable_track := unsafe { &AudioTrack(track) }
	enable := !element.audio_tracks_.tracks().any(it != track && it.enabled)
	if enable {
		mutable_track.set_enabled(true)
		element.set_audio_track_enabled(track, true)
	}
	mutable_track.base.kind = if enable { 'main' } else { 'translation' }
	element.fire_event('addtrack')
	return track
}

pub fn (mut element HTMLMediaElement) on_video_track_added(metadata MediaTrackMetadata) &VideoTrack {
	track := VideoTrack.create(metadata, media_element_noop_change_task, media_element_noop_video_selected)
	element.video_tracks_.add_track(track)
	mut mutable_track := unsafe { &VideoTrack(track) }
	should_select := element.video_tracks_.selected_index() == -1
	if should_select {
		mutable_track.set_selected(true)
		element.set_selected_video_track(track)
	}
	mutable_track.base.kind = if should_select { 'main' } else { 'translation' }
	element.fire_event('addtrack')
	return track
}

pub fn (mut element HTMLMediaElement) on_metadata_parsed(duration f64) {
	element.update_volume()
	element.current_playback_position_ = 0
	element.official_playback_position_ = 0
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
			element.set_audio_track_enabled(track, true)
		}
	}
	if element.video_tracks_.selected_index() == -1 {
		if track := element.video_tracks_.item(0) {
			mut mutable_track := unsafe { &VideoTrack(track) }
			mutable_track.set_selected(true)
			element.set_selected_video_track(track)
		}
	}
	element.update_ready_state()
}

pub fn (mut element HTMLMediaElement) set_up_playback_manager() {
	element.playback_manager_ready_ = true
}

pub fn (mut element HTMLMediaElement) process_media_data(status MediaFetchingStatus) {
	match status {
		.complete {
			element.fire_event('progress')
			element.network_state_ = .idle
			element.fire_event('suspend')
		}
		.ongoing {
			element.network_state_ = .loading
		}
		.interrupted {
			if int(element.ready_state_) > int(MediaReadyState.have_nothing) {
				element.cancel_the_fetching_process()
				element.error_ = &MediaError{
					code: .network
					message: 'Connection interrupted'
				}
				element.network_state_ = .idle
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
		element.reject_pending_play_promises_with(promises, dom.js_string('NotSupportedError: Media is not supported'))
	}
}

pub fn (mut element HTMLMediaElement) forget_media_resource_specific_tracks() {
	element.audio_tracks_.remove_all_tracks()
	element.video_tracks_.remove_all_tracks()
	element.selected_video_track_ = none
	element.playback_manager_ready_ = false
	element.playback_has_future_data_ = false
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
	track.set_mode(.hidden)
	track.set_media_element(element)
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
