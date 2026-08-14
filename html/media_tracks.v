// Copyright (c) 2023, Tim Flynn <trflynn89@serenityos.org>
// Copyright (c) 2025, Gregory Bertilson <gregory@ladybird.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of MediaTrackBase.cpp, AudioTrack.cpp, AudioTrackList.cpp,
// VideoTrack.cpp, and VideoTrackList.cpp. Media-element task queuing and
// playback-manager updates cross module boundaries and are supplied as
// callbacks.
module html

pub struct MediaTrackMetadata {
pub:
	identifier            i64
	name                  string
	parsed_bcp47_language ?string
	playback_track_handle voidptr
}

pub struct MediaTrackBase {
pub:
	playback_track_handle voidptr
	id                    string
	label                 string
	language              string
pub mut:
	kind string
}

pub fn MediaTrackBase.create(metadata MediaTrackMetadata) MediaTrackBase {
	language := if parsed_language := metadata.parsed_bcp47_language {
		if parsed_language == 'und' { '' } else { parsed_language }
	} else {
		''
	}
	return MediaTrackBase{
		playback_track_handle: metadata.playback_track_handle
		id:                    metadata.identifier.str()
		label:                 metadata.name
		language:              language
	}
}

pub type QueueMediaTrackChangeTask = fn ()

pub type SetAudioTrackEnabled = fn (&AudioTrack, bool)

pub type SetSelectedVideoTrack = fn (?&VideoTrack)

@[heap]
pub struct AudioTrack {
pub:
	base                         MediaTrackBase
	queue_change_task            QueueMediaTrackChangeTask @[required]
	set_playback_manager_enabled SetAudioTrackEnabled      @[required]
pub mut:
	enabled          bool
	audio_track_list ?&AudioTrackList
}

pub fn AudioTrack.create(metadata MediaTrackMetadata, queue_change_task QueueMediaTrackChangeTask, set_playback_manager_enabled SetAudioTrackEnabled) &AudioTrack {
	return &AudioTrack{
		base:                         MediaTrackBase.create(metadata)
		queue_change_task:            queue_change_task
		set_playback_manager_enabled: set_playback_manager_enabled
	}
}

// https://html.spec.whatwg.org/multipage/media.html#dom-audiotrack-enabled
pub fn (mut track AudioTrack) set_enabled(enabled bool) {
	if track.enabled == enabled {
		return
	}
	if _ := track.audio_track_list {
		track.queue_change_task()
	}
	track.enabled = enabled
	track.set_playback_manager_enabled(track, enabled)
}

@[heap]
pub struct AudioTrackList {
mut:
	audio_tracks []&AudioTrack
}

pub fn (list &AudioTrackList) length() int {
	return list.audio_tracks.len
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

@[heap]
pub struct VideoTrack {
pub:
	base                        MediaTrackBase
	queue_change_task           QueueMediaTrackChangeTask @[required]
	set_selected_playback_track SetSelectedVideoTrack     @[required]
pub mut:
	selected         bool
	video_track_list ?&VideoTrackList
}

pub fn VideoTrack.create(metadata MediaTrackMetadata, queue_change_task QueueMediaTrackChangeTask, set_selected_playback_track SetSelectedVideoTrack) &VideoTrack {
	return &VideoTrack{
		base:                        MediaTrackBase.create(metadata)
		queue_change_task:           queue_change_task
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
			if other_track != track {
				mut mutable_other_track := unsafe { &VideoTrack(other_track) }
				mutable_other_track.selected = false
			}
		}

		previously_unselected_track_is_selected := !track.selected && selected
		selected_track_was_unselected_without_another_selection := track.selected && !selected
		if previously_unselected_track_is_selected
			|| selected_track_was_unselected_without_another_selection {
			track.queue_change_task()
		}
	}

	track.selected = selected
	if selected {
		track.set_selected_playback_track(unsafe { &VideoTrack(track) })
	} else {
		track.set_selected_playback_track(none)
	}
}

@[heap]
pub struct VideoTrackList {
mut:
	video_tracks []&VideoTrack
}

pub fn (list &VideoTrackList) length() int {
	return list.video_tracks.len
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
}

pub fn (mut list VideoTrackList) remove_all_tracks() {
	for track in list.video_tracks {
		mut mutable_track := unsafe { &VideoTrack(track) }
		mutable_track.set_selected(false)
	}
	list.video_tracks.clear()
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
