// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// Copyright (c) 2025, Gregory Bertilson <gregory@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaTrackBase.cpp, AudioTrack.cpp, AudioTrackList.cpp,
// VideoTrack.cpp, and VideoTrackList.cpp. Media-element task queuing and
// playback-manager updates cross module boundaries and are supplied as
// callbacks.
module html

import dom

pub struct MediaTrackMetadata {
pub:
	identifier            i64
	name                  string
	parsed_bcp47_language ?string
	playback_track_handle voidptr
	pixel_width           u32
	pixel_height          u32
	kind                  ?string
}

pub struct MediaTrackBase {
pub:
	playback_track_handle voidptr
	id                    string
	label                 string
	language              string
	pixel_width           u32
	pixel_height          u32
pub mut:
	kind           string
	media_element_ ?&HTMLMediaElement
}

pub fn MediaTrackBase.create(metadata MediaTrackMetadata) MediaTrackBase {
	language := if parsed_language := metadata.parsed_bcp47_language {
		if parsed_language == 'und' { '' } else { parsed_language }
	} else {
		''
	}
	return MediaTrackBase{
		playback_track_handle: metadata.playback_track_handle
		id: metadata.identifier.str()
		label: metadata.name
		language: language
		pixel_width: metadata.pixel_width
		pixel_height: metadata.pixel_height
		kind: metadata.kind or { '' }
	}
}

pub fn (base &MediaTrackBase) media_element() ?&HTMLMediaElement {
	return base.media_element_
}

pub fn (mut base MediaTrackBase) set_media_element(element ?&HTMLMediaElement) {
	base.media_element_ = element
}

pub fn (base &MediaTrackBase) track_in_playback_manager() voidptr {
	return base.playback_track_handle
}

pub fn (base &MediaTrackBase) id() string {
	return base.id
}

pub fn (base &MediaTrackBase) kind() string {
	return base.kind
}

pub fn (mut base MediaTrackBase) set_kind(value string) {
	base.kind = value
}

pub fn (base &MediaTrackBase) label() string {
	return base.label
}

pub fn (base &MediaTrackBase) language() string {
	return base.language
}

pub type QueueMediaTrackChangeTask = fn()

pub type SetAudioTrackEnabled = fn(&AudioTrack, bool)

pub type SetSelectedVideoTrack = fn(?&VideoTrack)

type QueueAudioTrackListChangeTask = fn(&AudioTrackList)

type QueueVideoTrackListChangeTask = fn(&VideoTrackList)

pub enum MediaTrackIterationDecision {
	continue_
	break_
}

@[heap]
pub struct AudioTrack {
pub:
	queue_change_task            QueueMediaTrackChangeTask @[required]
	set_playback_manager_enabled SetAudioTrackEnabled @[required]
mut:
	queue_change_task_for_list ?QueueAudioTrackListChangeTask
pub mut:
	base             MediaTrackBase
	enabled          bool
	audio_track_list ?&AudioTrackList
}

pub fn AudioTrack.create(metadata MediaTrackMetadata, queue_change_task QueueMediaTrackChangeTask, set_playback_manager_enabled SetAudioTrackEnabled) &AudioTrack {
	return &AudioTrack{
		base: MediaTrackBase.create(metadata)
		queue_change_task: queue_change_task
		set_playback_manager_enabled: set_playback_manager_enabled
	}
}

// https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled
pub fn (mut track AudioTrack) set_enabled(enabled bool) {
	if track.enabled == enabled {
		return
	}
	track.enabled = enabled
	if list := track.audio_track_list {
		if queue_change := track.queue_change_task_for_list {
			queue_change(list)
		} else {
			track.queue_change_task()
		}
	}
	track.set_playback_manager_enabled(track, enabled)
}

pub fn (mut track AudioTrack) set_audio_track_list(list ?&AudioTrackList) {
	track.audio_track_list = list
}

@[heap]
pub struct AudioTrackList {
	dom.EventTarget
mut:
	audio_tracks []&AudioTrack
}

pub fn (list &AudioTrackList) internal_get_own_property(property_name dom.JSValue) ?&AudioTrack {
	if property_name.kind != .number
		|| !(property_name.number_data >= 0 && property_name.number_data < f64(list.length())) {
		return none
	}
	index := u32(property_name.number_data)
	if f64(index) != property_name.number_data {
		return none
	}
	return list.item(index)
}

pub fn (mut list AudioTrackList) set_onchange(event_handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('change', event_handler)
}

pub fn (list &AudioTrackList) onchange() ?&dom.CallbackType {
	return list.event_handler_attribute('change')
}

pub fn (mut list AudioTrackList) set_onaddtrack(event_handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('addtrack', event_handler)
}

pub fn (list &AudioTrackList) onaddtrack() ?&dom.CallbackType {
	return list.event_handler_attribute('addtrack')
}

pub fn (mut list AudioTrackList) set_onremovetrack(event_handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('removetrack', event_handler)
}

pub fn (list &AudioTrackList) onremovetrack() ?&dom.CallbackType {
	return list.event_handler_attribute('removetrack')
}

pub fn (list &AudioTrackList) length() int {
	return list.audio_tracks.len
}

pub fn (list &AudioTrackList) event_target() &dom.EventTarget {
	return &list.EventTarget
}

pub fn (list &AudioTrackList) item(index u32) ?&AudioTrack {
	if index < list.audio_tracks.len {
		return list.audio_tracks[index]
	}
	return none
}

pub fn (mut list AudioTrackList) add_track(track &AudioTrack) {
	list.audio_tracks << track
	mut mutable_track := unsafe { &AudioTrack(track) }
	mutable_track.audio_track_list = list
}

pub fn (mut list AudioTrackList) remove_all_tracks() {
	for track in list.audio_tracks {
		mut mutable_track := unsafe { &AudioTrack(track) }
		mutable_track.set_enabled(false)
		mutable_track.set_audio_track_list(none)
	}
	list.audio_tracks.clear()
}

// https://html.spec.whatwg.org/multipage/media.html#dom-audiotracklist-gettrackbyid
pub fn (list &AudioTrackList) get_track_by_id(id string) ?&AudioTrack {
	for track in list.audio_tracks {
		if track.base.id == id {
			return track
		}
	}
	return none
}

pub fn (list &AudioTrackList) has_enabled_track() bool {
	for track in list.audio_tracks {
		if track.enabled {
			return true
		}
	}
	return false
}

pub fn (list &AudioTrackList) tracks() []&AudioTrack {
	return list.audio_tracks.clone()
}

pub fn (list &AudioTrackList) for_each_track(callback fn (&AudioTrack) MediaTrackIterationDecision) {
	for track in list.audio_tracks {
		if callback(track) == .break_ {
			break
		}
	}
}

@[heap]
pub struct VideoTrack {
pub:
	queue_change_task           QueueMediaTrackChangeTask @[required]
	set_selected_playback_track SetSelectedVideoTrack @[required]
mut:
	queue_change_task_for_list ?QueueVideoTrackListChangeTask
pub mut:
	base             MediaTrackBase
	selected         bool
	video_track_list ?&VideoTrackList
}

pub fn VideoTrack.create(metadata MediaTrackMetadata, queue_change_task QueueMediaTrackChangeTask, set_selected_playback_track SetSelectedVideoTrack) &VideoTrack {
	return &VideoTrack{
		base: MediaTrackBase.create(metadata)
		queue_change_task: queue_change_task
		set_selected_playback_track: set_selected_playback_track
	}
}

// https://html.spec.whatwg.org/multipage/media.html#dom-videotrack-selected
pub fn (mut track VideoTrack) set_selected(selected bool) {
	if track.selected == selected {
		return
	}
	if list := track.video_track_list {
		for other_track in list.video_tracks {
			if voidptr(other_track) != voidptr(track) {
				mut mutable_other_track := unsafe { &VideoTrack(other_track) }
				mutable_other_track.selected = false
			}
		}

		previously_unselected_track_is_selected := !track.selected && selected
		selected_track_was_unselected_without_another_selection := track.selected && !selected
		if previously_unselected_track_is_selected || selected_track_was_unselected_without_another_selection {
			if queue_change := track.queue_change_task_for_list {
				queue_change(list)
			} else {
				track.queue_change_task()
			}
		}
	}

	track.selected = selected
	if selected {
		track.set_selected_playback_track(unsafe { &VideoTrack(track) })
	} else {
		track.set_selected_playback_track(none)
	}
}

pub fn (mut track VideoTrack) set_video_track_list(list ?&VideoTrackList) {
	track.video_track_list = list
}

@[heap]
pub struct VideoTrackList {
	dom.EventTarget
mut:
	video_tracks []&VideoTrack
	media_element_ ?&HTMLMediaElement
}

pub fn VideoTrackList.create(media_element ?&HTMLMediaElement) &VideoTrackList {
	return &VideoTrackList{media_element_: media_element}
}

fn (list &VideoTrackList) update_natural_dimensions() {
	media := list.media_element_ or { return }
	if mut video := media.video_element_model_ {
		video.update_natural_dimensions()
	}
}

pub fn (list &VideoTrackList) internal_get_own_property(property_name dom.JSValue) ?&VideoTrack {
	if property_name.kind != .number
		|| !(property_name.number_data >= 0 && property_name.number_data < f64(list.length())) {
		return none
	}
	index := u32(property_name.number_data)
	if f64(index) != property_name.number_data {
		return none
	}
	return list.item(index)
}

pub fn (mut list VideoTrackList) set_onchange(event_handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('change', event_handler)
}

pub fn (list &VideoTrackList) onchange() ?&dom.CallbackType {
	return list.event_handler_attribute('change')
}

pub fn (mut list VideoTrackList) set_onaddtrack(event_handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('addtrack', event_handler)
}

pub fn (list &VideoTrackList) onaddtrack() ?&dom.CallbackType {
	return list.event_handler_attribute('addtrack')
}

pub fn (mut list VideoTrackList) set_onremovetrack(event_handler ?&dom.CallbackType) {
	list.set_event_handler_attribute('removetrack', event_handler)
}

pub fn (list &VideoTrackList) onremovetrack() ?&dom.CallbackType {
	return list.event_handler_attribute('removetrack')
}

pub fn (list &VideoTrackList) length() int {
	return list.video_tracks.len
}

pub fn (list &VideoTrackList) video_tracks() []&VideoTrack {
	return list.video_tracks.clone()
}

pub fn (list &VideoTrackList) for_each_track(callback fn (&VideoTrack) MediaTrackIterationDecision) {
	for track in list.video_tracks {
		if callback(track) == .break_ {
			break
		}
	}
}

pub fn (list &VideoTrackList) item(index u32) ?&VideoTrack {
	if index < list.video_tracks.len {
		return list.video_tracks[index]
	}
	return none
}

pub fn (mut list VideoTrackList) add_track(track &VideoTrack) {
	list.video_tracks << track
	mut mutable_track := unsafe { &VideoTrack(track) }
	mutable_track.video_track_list = list
	list.update_natural_dimensions()
}

pub fn (mut list VideoTrackList) remove_all_tracks() {
	for track in list.video_tracks {
		mut mutable_track := unsafe { &VideoTrack(track) }
		mutable_track.set_selected(false)
		mutable_track.set_video_track_list(none)
	}
	list.video_tracks.clear()
	list.update_natural_dimensions()
}

// https://html.spec.whatwg.org/multipage/media.html#dom-videotracklist-gettrackbyid
pub fn (list &VideoTrackList) get_track_by_id(id string) ?&VideoTrack {
	for track in list.video_tracks {
		if track.base.id == id {
			return track
		}
	}
	return none
}

// https://html.spec.whatwg.org/multipage/media.html#dom-videotracklist-selectedindex
pub fn (list &VideoTrackList) selected_index() i32 {
	for index, track in list.video_tracks {
		if track.selected {
			return i32(index)
		}
	}
	return -1
}

pub fn (list &VideoTrackList) tracks() []&VideoTrack {
	return list.video_tracks.clone()
}
