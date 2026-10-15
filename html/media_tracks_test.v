@[has_globals]
module html

import dom

__global (
	media_track_change_tasks        int
	media_track_audio_updates       int
	media_track_last_audio_enabled  bool
	media_track_video_updates       int
	media_track_last_selected_video &VideoTrack
)

fn media_track_test_queue_change() {
	media_track_change_tasks++
}

fn media_track_test_set_audio_enabled(track &AudioTrack, enabled bool) {
	assert track.base.id != ''
	media_track_audio_updates++
	media_track_last_audio_enabled = enabled
}

fn media_track_test_set_selected_video(track ?&VideoTrack) {
	media_track_video_updates++
	media_track_last_selected_video = track or { unsafe { nil } }
}

fn reset_media_track_test_state() {
	media_track_change_tasks = 0
	media_track_audio_updates = 0
	media_track_last_audio_enabled = false
	media_track_video_updates = 0
	media_track_last_selected_video = unsafe { nil }
}

fn media_track_event_handler() &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			return dom.js_undefined()
		}
	}
}

fn test_media_track_base_metadata() {
	base := MediaTrackBase.create(MediaTrackMetadata{
		identifier:            42
		name:                  'Commentary'
		parsed_bcp47_language: 'en-US'
	})
	assert base.id == '42'
	assert base.label == 'Commentary'
	assert base.language == 'en-US'
	assert MediaTrackBase.create(MediaTrackMetadata{
		parsed_bcp47_language: 'und'
	}).language == ''
	assert MediaTrackBase.create(MediaTrackMetadata{}).language == ''
	assert MediaTrackBase.create(MediaTrackMetadata{ kind: '' }).kind == ''
	assert MediaTrackBase.create(MediaTrackMetadata{ kind: 'commentary' }).kind == 'commentary'
}

fn test_audio_track_enabled_and_list_algorithms() {
	reset_media_track_test_state()
	track := AudioTrack.create(MediaTrackMetadata{
		identifier: 7
	}, media_track_test_queue_change, media_track_test_set_audio_enabled)
	mut mutable_track := track
	mutable_track.set_enabled(true)
	assert media_track_change_tasks == 0
	assert media_track_audio_updates == 1

	mut list := &AudioTrackList{}
	list.add_track(track)
	assert list.length() == 1
	assert list.item(0)? == track
	assert list.internal_get_own_property(dom.js_number(0))? == track
	assert list.internal_get_own_property(dom.js_string('0')) == none
	handler := media_track_event_handler()
	list.set_onchange(handler)
	list.set_onaddtrack(handler)
	list.set_onremovetrack(handler)
	assert list.onchange()? == handler
	assert list.onaddtrack()? == handler
	assert list.onremovetrack()? == handler
	assert list.item(1) == none
	assert list.get_track_by_id('7')? == track
	assert list.has_enabled_track()
	mutable_track.set_enabled(false)
	assert media_track_change_tasks == 1
	assert media_track_audio_updates == 2
	assert !media_track_last_audio_enabled
	list.remove_all_tracks()
	assert list.length() == 0
}

fn test_video_track_selection_and_list_algorithms() {
	reset_media_track_test_state()
	first := VideoTrack.create(MediaTrackMetadata{
		identifier: 1
	}, media_track_test_queue_change, media_track_test_set_selected_video)
	second := VideoTrack.create(MediaTrackMetadata{
		identifier: 2
	}, media_track_test_queue_change, media_track_test_set_selected_video)
	mut list := &VideoTrackList{}
	list.add_track(first)
	list.add_track(second)
	mut mutable_first := first
	mut mutable_second := second
	mutable_first.set_selected(true)
	assert list.selected_index() == 0
	assert list.internal_get_own_property(dom.js_number(0))? == first
	handler := media_track_event_handler()
	list.set_onchange(handler)
	list.set_onaddtrack(handler)
	list.set_onremovetrack(handler)
	assert list.onchange()? == handler
	assert list.onaddtrack()? == handler
	assert list.onremovetrack()? == handler
	assert media_track_change_tasks == 1
	assert media_track_last_selected_video == first
	mutable_second.set_selected(true)
	assert !first.selected
	assert second.selected
	assert list.selected_index() == 1
	assert list.get_track_by_id('2')? == second
	assert media_track_change_tasks == 2
	mutable_second.set_selected(false)
	assert list.selected_index() == -1
	assert media_track_change_tasks == 3
	assert media_track_last_selected_video == unsafe { nil }
	mutable_first.set_selected(true)
	assert media_track_change_tasks == 4
	list.remove_all_tracks()
	assert list.length() == 0
	assert first.video_track_list == none
	assert second.video_track_list == none
	assert !first.selected
	assert media_track_change_tasks == 5
	assert media_track_last_selected_video == unsafe { nil }
}
