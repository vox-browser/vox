module html

import dom
import highresolutiontime

@[heap]
struct VideoTrackChangeObservation {
mut:
	events     []string
	indices    []i32
	lengths    []int
	timestamps []f64
	backend    []string
}

fn vtc_media_owner() !&HTMLMediaElement {
	url := dom.URL{value: 'https://video-change.example.test/'}
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing video element') }
	video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	return video.media
}

fn vtc_listen(list &VideoTrackList, label string, state &VideoTrackChangeObservation) {
	target := &list.EventTarget
	target.add_event_listener_without_options('change', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [list, label, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == 'change' && event.is_trusted()
			assert !event.bubbles() && !event.cancelable() && !event.composed()
			assert voidptr(event.target() or { panic('Missing change target') }) == voidptr(target)
			assert voidptr(event.current_target() or { panic('Missing current target') }) == voidptr(target)
			assert voidptr(current or { panic('Missing callback target') }) == voidptr(target)
			mut result := unsafe { &VideoTrackChangeObservation(state) }
			result.events << label
			result.indices << list.selected_index()
			result.lengths << list.length()
			result.timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	}))
}

fn vtc_run_next(media &HTMLMediaElement, state &VideoTrackChangeObservation) {
	document := media.document() or { panic('Missing owning document') }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('Missing factory video-track task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('Missing task document') }) == voidptr(document)
	before := settings.global_relative_event_timestamp()
	previous := state.timestamps.len
	task.execute()
	after := settings.global_relative_event_timestamp()
	if state.timestamps.len != previous {
		assert state.timestamps.len == previous + 1
		assert state.timestamps.last() >= before && state.timestamps.last() <= after
	}
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_factory_video_tracks_queue_trusted_list_changes_before_resize_and_after_selection_changes() {
	mut media := vtc_media_owner()!
	mut document := media.document() or { panic('Missing video document') }
	mut settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	original_origin := settings.time_origin()
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		document.finalize()
	}
	mut list := media.video_tracks()
	video := media.video_element_model_ or { panic('Missing actual video model') }
	state := &VideoTrackChangeObservation{}
	vtc_listen(list, 'change', state)
	media.set_on_event('resize', &dom.CallbackType{
		handle_event: fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &VideoTrackChangeObservation(state) }
			result.events << 'resize'
			return dom.js_undefined()
		}
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_video_track: fn [state] (track ?&VideoTrack) {
			mut result := unsafe { &VideoTrackChangeObservation(state) }
			result.backend << if selected := track { selected.base.id } else { 'none' }
		}
	})
	mut first := media.on_video_track_added(MediaTrackMetadata{
		identifier: 1, name: 'Main', pixel_width: 320, pixel_height: 180
	})
	assert first.selected && list.selected_index() == 0 && first.base.kind == 'main'
	assert (video.natural_media_size() or { panic('Missing intrinsic video size') }) == VideoDimensions{320, 180}
	assert media.queued_media_task_ids_.len == 2 && state.events == []
	first.set_selected(true)
	mut second := media.on_video_track_added(MediaTrackMetadata{
		identifier: 2, name: 'Alternate', pixel_width: 320, pixel_height: 180
	})
	assert !second.selected && second.base.kind == 'translation'
	assert media.queued_media_task_ids_.len == 2 && state.backend == ['1']
	// Change the test realm's origin after queueing. A timestamp captured at
	// mutation time cannot satisfy the delivery-time bounds below.
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == []
	vtc_run_next(media, state)
	assert state.events == ['change'] && state.indices == [i32(0)] && state.lengths == [2]
	assert state.timestamps[0] >= 30000 && media.event_count('resize') == 0
	vtc_run_next(media, state)
	assert state.events == ['change', 'resize'] && media.event_count('resize') == 1
	assert media.queued_media_task_ids_.len == 0
	second.set_selected(true)
	second.set_selected(true)
	first.set_selected(false)
	assert !first.selected && second.selected && list.selected_index() == 1
	assert media.queued_media_task_ids_.len == 1 && state.backend == ['1', '2']
	list.remove_all_tracks()
	list.remove_all_tracks()
	assert media.queued_media_task_ids_.len == 2 && state.backend == ['1', '2', 'none']
	assert state.events == ['change', 'resize'] && list.length() == 0
	vtc_run_next(media, state)
	vtc_run_next(media, state)
	assert state.events == ['change', 'resize', 'change', 'change']
	assert state.indices == [i32(0), -1, -1] && state.lengths == [2, 0, 0]
	assert media.queued_media_task_ids_.len == 0 && media.selected_video_track_ == none
	for track in [first, second] {
		assert !track.selected && track.video_track_list == none
		assert voidptr(track.base.media_element() or { panic('Missing factory media owner') }) == voidptr(media)
	}
	assert voidptr(media.video_tracks()) == voidptr(list) && media.paused() && media.network_state() == .empty
}

fn test_factory_video_track_changes_capture_each_current_list_and_retain_the_creation_media_task_owner() {
	mut media := vtc_media_owner()!
	other := vtc_media_owner()!
	mut document := media.document() or { panic('Missing creation document') }
	mut other_document := other.document() or { panic('Missing other document') }
	assert voidptr(document) != voidptr(other_document)
	mut settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut other_settings := unsafe { &EnvironmentSettingsObject(other_document.relevant_settings_object()) }
	original_origin := settings.time_origin()
	original_other_origin := other_settings.time_origin()
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		other_document.load_timing_info.navigation_start_time = original_other_origin
		document.finalize()
		other_document.finalize()
	}
	mut origin := media.video_tracks()
	mut destination := other.video_tracks()
	state := &VideoTrackChangeObservation{}
	vtc_listen(origin, 'origin', state)
	vtc_listen(destination, 'destination', state)
	media.set_on_event('resize', &dom.CallbackType{
		handle_event: fn [state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &VideoTrackChangeObservation(state) }
			result.events << 'resize'
			return dom.js_undefined()
		}
	})
	mut track := media.on_video_track_added(MediaTrackMetadata{identifier: 7, name: 'Retained'})
	assert track.selected && media.queued_media_task_ids_.len == 2
	origin.remove_all_tracks()
	assert track.video_track_list == none && !track.selected && media.queued_media_task_ids_.len == 3
	track.set_selected(true)
	track.set_selected(false)
	assert media.queued_media_task_ids_.len == 4
	destination.add_track(track)
	track.set_selected(true)
	assert destination.selected_index() == 0 && media.queued_media_task_ids_.len == 6
	assert voidptr(track.video_track_list or { panic('Missing destination list') }) == voidptr(destination)
	destination.remove_all_tracks()
	destination.remove_all_tracks()
	assert track.video_track_list == none && !track.selected && media.queued_media_task_ids_.len == 7
	track.set_selected(true)
	track.set_selected(false)
	assert media.queued_media_task_ids_.len == 8 && other.queued_media_task_ids_.len == 0
	assert state.events == [] && origin.length() == 0 && destination.length() == 0
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	other_document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 90000
	for expected in ['origin', 'resize', 'origin', 'resize', 'destination', 'resize', 'destination', 'resize'] {
		vtc_run_next(media, state)
		assert state.events.last() == expected
	}
	assert state.events == ['origin', 'resize', 'origin', 'resize', 'destination', 'resize', 'destination', 'resize']
	assert state.indices == [i32(-1), -1, -1, -1] && state.lengths == [0, 0, 0, 0]
	assert state.timestamps.all(it >= 30000) && media.queued_media_task_ids_.len == 0
	assert other.queued_media_task_ids_.len == 0 && media.selected_video_track_ == none
	assert other.selected_video_track_ == none && media.event_count('resize') == 4
	assert voidptr(track.base.media_element() or { panic('Lost creation media owner') }) == voidptr(media)
	assert track.base.id == '7' && track.base.label == 'Retained' && track.video_track_list == none
	assert voidptr(media.video_tracks()) == voidptr(origin) && voidptr(other.video_tracks()) == voidptr(destination)
}
