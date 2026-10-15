module html

import dom
import highresolutiontime

@[heap]
struct AudioTrackChangeObservation {
mut:
	events     []string
	enabled    []int
	lengths    []int
	timestamps []f64
	backend    []string
}

@[heap]
struct AudioTrackLegacyObservation {
mut:
	track ?&AudioTrack
	steps []string
}

fn atc_media_owner() !&HTMLMediaElement {
	url := dom.URL{value: 'https://audio-change.example.test/'}
	document := parse_navigation_document('<audio id="player"></audio>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing audio element') }
	return html_media_element_for_dom_element(element) or { return error('Missing audio media owner') }
}

fn atc_listen(list &AudioTrackList, label string, state &AudioTrackChangeObservation) {
	target := list.event_target()
	target.add_event_listener_without_options('change', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [list, label, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == 'change' && event.is_trusted()
			assert !event.bubbles() && !event.cancelable() && !event.composed()
			assert voidptr(event.target() or { panic('Missing change target') }) == voidptr(target)
			assert voidptr(event.current_target() or { panic('Missing current target') }) == voidptr(target)
			assert voidptr(current or { panic('Missing callback target') }) == voidptr(target)
			mut result := unsafe { &AudioTrackChangeObservation(state) }
			result.events << label
			result.enabled << list.tracks().filter(it.enabled).len
			result.lengths << list.length()
			result.timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	}))
}

fn atc_run_next(media &HTMLMediaElement, state &AudioTrackChangeObservation) {
	document := media.document() or { panic('Missing owning document') }
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('Missing factory audio-track task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('Missing task document') }) == voidptr(document)
	before := settings.global_relative_event_timestamp()
	previous := state.timestamps.len
	task.execute()
	after := settings.global_relative_event_timestamp()
	assert state.timestamps.len == previous + 1
	assert state.timestamps.last() >= before && state.timestamps.last() <= after
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_factory_audio_changes_are_trusted_tasks_and_tracks_enable_independently() {
	mut media := atc_media_owner()!
	mut document := media.document() or { panic('Missing audio document') }
	original_origin := document.load_timing_info.navigation_start_time
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		document.finalize()
	}
	mut list := media.audio_tracks()
	state := &AudioTrackChangeObservation{}
	atc_listen(list, 'change', state)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_audio_track: fn [state] (track &AudioTrack, enabled bool) {
			assert track.enabled == enabled
			mut result := unsafe { &AudioTrackChangeObservation(state) }
			result.backend << '${track.base.id}:${enabled}'
		}
	})
	mut first := media.on_audio_track_added(MediaTrackMetadata{identifier: 1, name: 'Main'})
	first.set_enabled(true)
	mut second := media.on_audio_track_added(MediaTrackMetadata{identifier: 2, name: 'Alternate'})
	assert first.enabled && !second.enabled && first.base.kind == 'main' && second.base.kind == 'translation'
	assert media.queued_media_task_ids_.len == 1 && state.events == [] && state.backend == ['1:true']
	// Window timestamps use the Document's origin; move it after queueing to
	// distinguish delivery-time event creation from a captured mutation clock.
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == []
	atc_run_next(media, state)
	assert state.events == ['change'] && state.enabled == [1] && state.lengths == [2]
	assert state.timestamps[0] >= 30000 && media.queued_media_task_ids_.len == 0
	second.set_enabled(true)
	assert first.enabled && second.enabled && media.queued_media_task_ids_.len == 1
	first.set_enabled(false)
	assert !first.enabled && second.enabled && media.queued_media_task_ids_.len == 2
	first.set_enabled(true)
	second.set_enabled(true)
	assert first.enabled && second.enabled && media.queued_media_task_ids_.len == 3
	list.remove_all_tracks()
	list.remove_all_tracks()
	assert media.queued_media_task_ids_.len == 5 && state.events == ['change']
	assert list.length() == 0 && !list.has_enabled_track()
	for _ in 0 .. 5 { atc_run_next(media, state) }
	assert state.events == ['change', 'change', 'change', 'change', 'change', 'change']
	assert state.enabled == [1, 0, 0, 0, 0, 0] && state.lengths == [2, 0, 0, 0, 0, 0]
	assert state.backend == ['1:true', '2:true', '1:false', '1:true', '1:false', '2:false']
	for track in [first, second] {
		assert !track.enabled && track.audio_track_list == none
		assert voidptr(track.base.media_element() or { panic('Missing factory media owner') }) == voidptr(media)
	}
	assert media.queued_media_task_ids_.len == 0 && voidptr(media.audio_tracks()) == voidptr(list)
	assert media.paused() && media.network_state() == .empty && media.video_tracks().length() == 0
}

fn test_factory_audio_changes_capture_the_current_list_and_keep_the_creation_media_task_owner() {
	mut media := atc_media_owner()!
	other := atc_media_owner()!
	mut document := media.document() or { panic('Missing creation document') }
	mut other_document := other.document() or { panic('Missing destination document') }
	original_origin := document.load_timing_info.navigation_start_time
	original_other_origin := other_document.load_timing_info.navigation_start_time
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		other_document.load_timing_info.navigation_start_time = original_other_origin
		document.finalize()
		other_document.finalize()
	}
	assert voidptr(document) != voidptr(other_document)
	mut origin := media.audio_tracks()
	mut destination := other.audio_tracks()
	state := &AudioTrackChangeObservation{}
	atc_listen(origin, 'origin', state)
	atc_listen(destination, 'destination', state)
	mut track := media.on_audio_track_added(MediaTrackMetadata{identifier: 7, name: 'Retained'})
	origin.remove_all_tracks()
	assert !track.enabled && track.audio_track_list == none && media.queued_media_task_ids_.len == 2
	track.set_enabled(true)
	track.set_enabled(false)
	assert media.queued_media_task_ids_.len == 2
	destination.add_track(track)
	track.set_enabled(true)
	track.set_enabled(true)
	assert track.enabled && media.queued_media_task_ids_.len == 3
	assert voidptr(track.audio_track_list or { panic('Missing destination list') }) == voidptr(destination)
	destination.remove_all_tracks()
	destination.remove_all_tracks()
	track.set_enabled(true)
	track.set_enabled(false)
	assert !track.enabled && track.audio_track_list == none && media.queued_media_task_ids_.len == 4
	assert state.events == [] && other.queued_media_task_ids_.len == 0
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	other_document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 90000
	for expected in ['origin', 'origin', 'destination', 'destination'] {
		atc_run_next(media, state)
		assert state.events.last() == expected
	}
	assert state.events == ['origin', 'origin', 'destination', 'destination']
	assert state.enabled == [0, 0, 0, 0] && state.lengths == [0, 0, 0, 0]
	assert state.timestamps.all(it >= 30000) && media.queued_media_task_ids_.len == 0
	assert other.queued_media_task_ids_.len == 0 && voidptr(media.audio_tracks()) == voidptr(origin)
	assert voidptr(other.audio_tracks()) == voidptr(destination) && origin.length() == 0 && destination.length() == 0
	assert voidptr(track.base.media_element() or { panic('Lost creation media owner') }) == voidptr(media)
	assert track.base.id == '7' && track.base.label == 'Retained'
}

fn test_legacy_audio_queue_callback_observes_new_enabled_state_before_backend_with_equal_and_detached_guards() {
	media := atc_media_owner()!
	mut document := media.document() or { panic('Missing legacy owner document') }
	defer { document.finalize() }
	mut list := media.audio_tracks()
	mut state := &AudioTrackLegacyObservation{}
	mut track := AudioTrack.create(MediaTrackMetadata{identifier: 9}, fn [state, list] () {
		actual := state.track or { panic('Missing retained legacy track') }
		assert voidptr(actual.audio_track_list or { panic('Queued while detached') }) == voidptr(list)
		mut result := unsafe { &AudioTrackLegacyObservation(state) }
		result.steps << 'queue:${actual.enabled}'
	}, fn [state] (actual &AudioTrack, enabled bool) {
		assert actual.enabled == enabled
		mut result := unsafe { &AudioTrackLegacyObservation(state) }
		if actual.audio_track_list != none { assert result.steps.last() == 'queue:${enabled}' }
		result.steps << 'backend:${enabled}'
	})
	state.track = track
	track.base.set_media_element(media)
	list.add_track(track)
	track.set_enabled(true)
	track.set_enabled(true)
	track.set_enabled(false)
	track.set_enabled(false)
	assert state.steps == ['queue:true', 'backend:true', 'queue:false', 'backend:false']
	list.remove_all_tracks()
	track.set_enabled(true)
	track.set_enabled(false)
	track.set_enabled(false)
	assert state.steps == ['queue:true', 'backend:true', 'queue:false', 'backend:false', 'backend:true', 'backend:false']
	assert !track.enabled && track.audio_track_list == none && list.length() == 0
	assert media.queued_media_task_ids_.len == 0
	assert voidptr(track.base.media_element() or { panic('Lost legacy media owner') }) == voidptr(media)
}
