module html

import dom
import highresolutiontime

@[heap]
struct MediaTrackAddObservation {
mut:
	steps      []string
	payloads   []voidptr
	timestamps []f64
}

fn mta_owner(tag string) !&HTMLMediaElement {
	url := dom.URL{value: 'https://track-add.example.test/'}
	document := parse_navigation_document('<${tag} id="player"></${tag}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media element') }
	return html_media_element_for_dom_element(element) or { return error('Missing media owner') }
}

fn mta_check(event &dom.Event, current ?&dom.EventTarget, target &dom.EventTarget, trusted bool) {
	assert event.is_trusted() == trusted && !event.bubbles() && !event.cancelable() && !event.composed()
	assert voidptr(event.target() or { panic('Missing event target') }) == voidptr(target)
	assert voidptr(event.current_target() or { panic('Missing current target') }) == voidptr(target)
	assert voidptr(current or { panic('Missing callback target') }) == voidptr(target)
}

fn mta_common_listeners(media &HTMLMediaElement, target &dom.EventTarget, state &MediaTrackAddObservation) {
	media.event_target().set_event_handler_attribute('addtrack', &dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			panic('Track addition must target the owning list, not the media element')
		}
	})
	target.set_event_handler_attribute('change', &dom.CallbackType{
		handle_event: fn [target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mta_check(event, current, target, true)
			assert event.type_name() == 'change' && event.interface_ != .track_event
			mut result := unsafe { &MediaTrackAddObservation(state) }
			result.steps << 'change'
			return dom.js_undefined()
		}
	})
}

fn mta_deliver_change(media &HTMLMediaElement, with_resize bool) {
	assert media.queued_media_task_ids_.len == if with_resize { 2 } else { 1 }
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('Missing deferred list change') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('Missing task document') }) == voidptr(media.document() or { panic('Missing media document') })
	task.execute()
	if with_resize {
		assert media.queued_media_task_ids_.len == 1
		resize := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing zero-size resize after list change') }
		assert resize.source() == .media_element && resize.document() == media.document()
		resize.execute()
		assert media.event_count('resize') == 1
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_audio_factory_addtrack_targets_the_list_once_after_enable_backend_and_kind_initialization() {
	mut media := mta_owner('audio')!
	mut document := media.document() or { panic('Missing audio document') }
	original_origin := document.load_timing_info.navigation_start_time
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		document.finalize()
	}
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut list := media.audio_tracks()
	target := list.event_target()
	state := &MediaTrackAddObservation{}
	mta_common_listeners(media, target, state)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_audio_track: fn [state] (track &AudioTrack, enabled bool) {
			assert enabled && track.enabled && track.base.id == '11'
			mut result := unsafe { &MediaTrackAddObservation(state) }
			result.steps << 'backend'
		}
	})
	list.set_onaddtrack(&dom.CallbackType{
		handle_event: fn [media, list, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mta_check(event, current, target, false)
			assert event.type_name() == 'addtrack' && event.interface_ == .track_event
			payload := unsafe { &TrackEvent(event) }.track()
			assert payload.kind == .audio && payload.video == none && payload.text == none
			track := payload.audio or { panic('Missing audio payload') }
			first := track.base.id == '11'
			assert track.enabled == first && track.base.kind == if first { 'main' } else { 'translation' }
			assert track.base.label == if first { 'Main audio' } else { 'Alternate audio' }
			assert track.base.language == 'en-US' && list.length() == if first { 1 } else { 2 }
			assert voidptr(list.get_track_by_id(track.base.id) or { panic('Payload is not a list member') }) == voidptr(track)
			assert voidptr(track.audio_track_list or { panic('Missing audio list backlink') }) == voidptr(list)
			assert voidptr(track.base.media_element() or { panic('Missing audio media owner') }) == voidptr(media)
			mut result := unsafe { &MediaTrackAddObservation(state) }
			assert result.steps == if first { ['backend'] } else { ['backend', 'add:11'] }
			result.steps << 'add:${track.base.id}'
			result.payloads << voidptr(track)
			result.timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	})
	before := settings.global_relative_event_timestamp()
	first := media.on_audio_track_added(MediaTrackMetadata{identifier: 11, name: 'Main audio', parsed_bcp47_language: 'en-US'})
	assert state.payloads == [voidptr(first)] && state.steps == ['backend', 'add:11']
	assert state.timestamps[0] >= before && state.timestamps[0] <= settings.global_relative_event_timestamp()
	before_second := settings.global_relative_event_timestamp()
	second := media.on_audio_track_added(MediaTrackMetadata{identifier: 12, name: 'Alternate audio', parsed_bcp47_language: 'en-US'})
	assert state.payloads == [voidptr(first), voidptr(second)] && state.timestamps[1] >= before_second
	assert state.timestamps[1] <= settings.global_relative_event_timestamp() && state.timestamps.all(it >= 30000)
	assert state.steps == ['backend', 'add:11', 'add:12'] && media.event_count('addtrack') == 0
	mta_deliver_change(media, false)
	assert state.steps == ['backend', 'add:11', 'add:12', 'change']
	assert first.enabled && !second.enabled && list.length() == 2
}

fn test_video_factory_addtrack_targets_the_list_once_after_selection_backend_and_kind_initialization() {
	mut media := mta_owner('video')!
	mut document := media.document() or { panic('Missing video document') }
	original_origin := document.load_timing_info.navigation_start_time
	defer {
		document.load_timing_info.navigation_start_time = original_origin
		document.finalize()
	}
	document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 30000
	settings := unsafe { &EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut list := media.video_tracks()
	target := &list.EventTarget
	state := &MediaTrackAddObservation{}
	mta_common_listeners(media, target, state)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_video_track: fn [state] (value ?&VideoTrack) {
			track := value or { panic('Unexpected empty video selection') }
			assert track.selected && track.base.id == '21'
			mut result := unsafe { &MediaTrackAddObservation(state) }
			result.steps << 'backend'
		}
	})
	list.set_onaddtrack(&dom.CallbackType{
		handle_event: fn [media, list, target, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			mta_check(event, current, target, false)
			assert event.type_name() == 'addtrack' && event.interface_ == .track_event
			payload := unsafe { &TrackEvent(event) }.track()
			assert payload.kind == .video && payload.audio == none && payload.text == none
			track := payload.video or { panic('Missing video payload') }
			first := track.base.id == '21'
			assert track.selected == first && list.selected_index() == 0
			assert track.base.kind == if first { 'main' } else { 'translation' }
			assert track.base.label == if first { 'Main video' } else { 'Alternate video' }
			assert track.base.language == 'fr' && list.length() == if first { 1 } else { 2 }
			assert voidptr(list.get_track_by_id(track.base.id) or { panic('Payload is not a list member') }) == voidptr(track)
			assert voidptr(track.video_track_list or { panic('Missing video list backlink') }) == voidptr(list)
			assert voidptr(track.base.media_element() or { panic('Missing video media owner') }) == voidptr(media)
			mut result := unsafe { &MediaTrackAddObservation(state) }
			assert result.steps == if first { ['backend'] } else { ['backend', 'add:21'] }
			result.steps << 'add:${track.base.id}'
			result.payloads << voidptr(track)
			result.timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	})
	before := settings.global_relative_event_timestamp()
	first := media.on_video_track_added(MediaTrackMetadata{identifier: 21, name: 'Main video', parsed_bcp47_language: 'fr'})
	assert state.payloads == [voidptr(first)] && state.steps == ['backend', 'add:21']
	assert state.timestamps[0] >= before && state.timestamps[0] <= settings.global_relative_event_timestamp()
	before_second := settings.global_relative_event_timestamp()
	second := media.on_video_track_added(MediaTrackMetadata{identifier: 22, name: 'Alternate video', parsed_bcp47_language: 'fr'})
	assert state.payloads == [voidptr(first), voidptr(second)] && state.timestamps[1] >= before_second
	assert state.timestamps[1] <= settings.global_relative_event_timestamp() && state.timestamps.all(it >= 30000)
	assert state.steps == ['backend', 'add:21', 'add:22'] && media.event_count('addtrack') == 0
	mta_deliver_change(media, true)
	assert state.steps == ['backend', 'add:21', 'add:22', 'change']
	assert first.selected && !second.selected && list.selected_index() == 0 && list.length() == 2
}

fn test_direct_media_track_addition_is_silent_and_track_event_constructors_preserve_untrusted_flags_and_payload() {
	mut audio := &AudioTrackList{}
	mut video := &VideoTrackList{}
	for target in [audio.event_target(), &video.EventTarget] {
		for name in ['addtrack', 'change'] {
			target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue { panic('Direct list insertion must be silent') }
			}))
		}
	}
	audio_track := AudioTrack.create(MediaTrackMetadata{identifier: 31}, fn () { panic('Unexpected audio change') },
		fn (_ &AudioTrack, _ bool) { panic('Unexpected audio backend update') })
	video_track := VideoTrack.create(MediaTrackMetadata{identifier: 32}, fn () { panic('Unexpected video change') },
		fn (_ ?&VideoTrack) { panic('Unexpected video backend update') })
	audio.add_track(audio_track)
	video.add_track(video_track)
	assert audio.length() == 1 && video.length() == 1 && !audio_track.enabled && !video_track.selected
	assert voidptr(audio_track.audio_track_list or { panic('Missing audio association') }) == voidptr(audio)
	assert voidptr(video_track.video_track_list or { panic('Missing video association') }) == voidptr(video)
	assert voidptr(audio.item(0) or { panic('Missing audio member') }) == voidptr(audio_track)
	assert voidptr(video.item(0) or { panic('Missing video member') }) == voidptr(video_track)
	default_event := TrackEvent.create('addtrack', TrackEventInit{})
	assert default_event.interface_ == .track_event && default_event.track().kind == .empty
	assert !default_event.is_trusted() && !default_event.bubbles() && !default_event.cancelable() && !default_event.composed()
	custom := TrackEvent.construct_impl('addtrack', TrackEventInit{
		bubbles: true, cancelable: true, composed: true, track: TrackEventTrack.from_audio(audio_track)
	})!
	assert custom.type_name() == 'addtrack' && custom.interface_ == .track_event && !custom.is_trusted()
	assert custom.bubbles() && custom.cancelable() && custom.composed() && custom.track().kind == .audio
	assert voidptr(custom.track().audio or { panic('Lost constructor payload') }) == voidptr(audio_track)
}
