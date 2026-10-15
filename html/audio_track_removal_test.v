module html

import dom
import highresolutiontime

@[heap]
struct AudioTrackRemovalObservation {
mut:
	tracks     []&AudioTrack
	steps      []string
	remaining  []bool
	events     int
	timestamps []f64
}

fn atr_no_removetrack(list &AudioTrackList) {
	list.event_target().add_event_listener_without_options('removetrack', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			panic('Removing all audio tracks must not synthesize removetrack')
		}
	}))
}

fn atr_observe_removal(list &AudioTrackList, state &AudioTrackRemovalObservation, index int, phase string) {
	assert list.length() == state.tracks.len
	for position, track in state.tracks {
		assert voidptr(list.item(u32(position)) or { panic('Storage cleared before callbacks finished') }) == voidptr(track)
		if position < index {
			assert track.audio_track_list == none
		} else {
			assert voidptr(track.audio_track_list or { panic('Track detached before its callback') }) == voidptr(list)
		}
	}
	assert !state.tracks[index].enabled
	assert list.has_enabled_track() == (index + 1 < state.tracks.len)
	mut result := unsafe { &AudioTrackRemovalObservation(state) }
	result.steps << '${phase}:${state.tracks[index].base.id}'
	result.remaining << list.has_enabled_track()
}

fn atr_take_task(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('Missing owned audio removal task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('Missing task document') }) == voidptr(media.document() or { panic('Missing owner document') })
	return task
}

fn test_audio_removal_retains_full_storage_until_each_enabled_track_has_queued_updated_the_backend_and_detached() {
	media := HTMLMediaElement.create(none, dom.url_about_blank())
	mut list := media.audio_tracks()
	mut state := &AudioTrackRemovalObservation{}
	atr_no_removetrack(list)
	for index in 0 .. 3 {
		mut track := AudioTrack.create(MediaTrackMetadata{identifier: index + 1}, fn [index, list, state] () {
			atr_observe_removal(list, state, index, 'queue')
		}, fn [index, list, state] (actual &AudioTrack, enabled bool) {
			assert !enabled && voidptr(actual) == voidptr(state.tracks[index])
			assert state.steps.last() == 'queue:${actual.base.id}'
			atr_observe_removal(list, state, index, 'backend')
		})
		track.base.set_media_element(media)
		track.enabled = index != 1
		list.add_track(track)
		state.tracks << track
	}
	assert list.has_enabled_track()
	list.remove_all_tracks()
	assert state.steps == ['queue:1', 'backend:1', 'queue:3', 'backend:3']
	assert state.remaining == [true, true, false, false]
	assert list.length() == 0 && list.tracks().len == 0 && !list.has_enabled_track()
	list.remove_all_tracks()
	for index, track in state.tracks {
		mut retained := unsafe { &AudioTrack(track) }
		retained.set_enabled(false)
		assert !track.enabled && track.audio_track_list == none && track.base.id == (index + 1).str()
		assert voidptr(track.base.media_element() or { panic('Lost retained media owner') }) == voidptr(media)
	}
	assert state.steps == ['queue:1', 'backend:1', 'queue:3', 'backend:3']
	assert media.queued_media_task_ids_.len == 0
}

fn test_factory_audio_removal_queues_changes_while_attached_and_delivers_them_after_storage_and_backlinks_are_empty() {
	url := dom.URL{value: 'https://audio-removal.example.test/'}
	mut document := parse_navigation_document('<audio id="player"></audio>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { panic('Missing audio element') }
	mut media := html_media_element_for_dom_element(element) or { panic('Missing audio media owner') }
	original_origin := document.load_timing_info.navigation_start_time
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		document.finalize()
	}
	mut list := media.audio_tracks()
	first := media.on_audio_track_added(MediaTrackMetadata{identifier: 11, name: 'First'})
	mut second := media.on_audio_track_added(MediaTrackMetadata{identifier: 12, name: 'Second'})
	second.set_enabled(true)
	assert first.enabled && second.enabled && media.queued_media_task_ids_.len == 2
	atr_take_task(media).execute()
	atr_take_task(media).execute()
	assert media.queued_media_task_ids_.len == 0
	state := &AudioTrackRemovalObservation{tracks: [first, second]}
	atr_no_removetrack(list)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_audio_track: fn [media, list, first, state] (actual &AudioTrack, enabled bool) {
			assert !enabled
			index := if actual == first { 0 } else { 1 }
			assert voidptr(actual) == voidptr(state.tracks[index])
			atr_observe_removal(list, state, index, 'backend')
			assert media.queued_media_task_ids_.len == index + 1
		}
	})
	target := list.event_target()
	list.set_onchange(&dom.CallbackType{
		handle_event: fn [media, list, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == 'change' && event.is_trusted()
			assert !event.bubbles() && !event.cancelable() && !event.composed()
			assert voidptr(event.target() or { panic('Missing change target') }) == voidptr(target)
			assert voidptr(event.current_target() or { panic('Missing current target') }) == voidptr(target)
			assert voidptr(current or { panic('Missing current target') }) == voidptr(target)
			assert list.length() == 0 && !list.has_enabled_track()
			for track in state.tracks { assert !track.enabled && track.audio_track_list == none }
			mut result := unsafe { &AudioTrackRemovalObservation(state) }
			result.events++
			result.timestamps << event.time_stamp()
			assert media.queued_media_task_ids_.len == 2 - result.events
			return dom.js_undefined()
		}
	})
	list.remove_all_tracks()
	list.remove_all_tracks()
	assert state.steps == ['backend:11', 'backend:12'] && state.remaining == [true, false]
	assert state.events == 0 && media.queued_media_task_ids_.len == 2
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == 0
	for expected in 1 .. 3 {
		before := settings.global_relative_event_timestamp()
		atr_take_task(media).execute()
		assert state.events == expected && state.timestamps.last() >= before
		assert state.timestamps.last() <= settings.global_relative_event_timestamp()
	}
	assert state.timestamps.all(it >= 30000) && media.queued_media_task_ids_.len == 0
	assert state.steps == ['backend:11', 'backend:12'] && voidptr(media.audio_tracks()) == voidptr(list)
	for track in state.tracks {
		assert voidptr(track.base.media_element() or { panic('Lost factory media owner') }) == voidptr(media)
	}
	assert first.base.id == '11' && second.base.id == '12' && media.paused() && media.network_state() == .empty
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_disabled_only_and_empty_audio_removal_detach_silently_without_queue_or_backend_changes() {
	media := HTMLMediaElement.create(none, dom.url_about_blank())
	mut list := media.audio_tracks()
	atr_no_removetrack(list)
	list.set_onchange(&dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue { panic('Unexpected disabled-only change event') }
	})
	list.remove_all_tracks()
	mut retained := []&AudioTrack{}
	for id in [21, 22] {
		mut track := AudioTrack.create(MediaTrackMetadata{identifier: id, name: 'Disabled ${id}'},
			fn () { panic('Unexpected disabled-only change task') },
			fn (_ &AudioTrack, _ bool) { panic('Unexpected disabled-only backend update') })
		track.base.set_media_element(media)
		list.add_track(track)
		retained << track
	}
	assert list.length() == 2 && !list.has_enabled_track()
	list.remove_all_tracks()
	list.remove_all_tracks()
	assert list.length() == 0 && list.item(0) == none && !list.has_enabled_track()
	for index, track in retained {
		assert !track.enabled && track.audio_track_list == none && track.base.id == (21 + index).str()
		assert voidptr(track.base.media_element() or { panic('Lost disabled track owner') }) == voidptr(media)
	}
	assert media.queued_media_task_ids_.len == 0 && voidptr(media.audio_tracks()) == voidptr(list)
}
