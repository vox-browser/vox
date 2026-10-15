module html

import dom
import highresolutiontime

@[heap]
struct TextTrackAddTaskObservation {
mut:
	expected   []&TextTrack
	payloads   []voidptr
	lengths    []int
	timestamps []f64
}

fn ttat_owner(tag string) !&HTMLMediaElement {
	url := dom.URL{value: 'https://text-track-add.example.test/'}
	document := parse_navigation_document('<${tag} id="player"></${tag}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media element') }
	return html_media_element_for_dom_element(element) or { return error('Missing media owner') }
}

fn ttat_silent_other_events(media &HTMLMediaElement, list &TextTrackList) {
	media.event_target().set_event_handler_attribute('addtrack', &dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			panic('Text-track addition must target the list instead of the media element')
		}
	})
	for name in ['change', 'removetrack'] {
		list.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				panic('Text-track addition must not synthesize change or removetrack')
			}
		}))
	}
}

fn ttat_payload(event &dom.Event, current ?&dom.EventTarget, list &TextTrackList) &TextTrack {
	target := &list.EventTarget
	assert event.type_name() == 'addtrack' && event.interface_ == .track_event
	assert !event.is_trusted() && !event.bubbles() && !event.cancelable() && !event.composed()
	assert voidptr(event.target() or { panic('Missing addtrack target') }) == voidptr(target)
	assert voidptr(event.current_target() or { panic('Missing current target') }) == voidptr(target)
	assert voidptr(current or { panic('Missing callback target') }) == voidptr(target)
	payload := unsafe { &TrackEvent(event) }.track()
	assert payload.kind == .text && payload.audio == none && payload.video == none
	return payload.text or { panic('Missing text-track payload') }
}

fn ttat_take(media &HTMLMediaElement) &Task {
	assert media.queued_media_task_ids_.len > 0
	first_id := media.queued_media_task_ids_[0]
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('Missing owned text-track addition task') }
	assert task.id() == first_id && task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('Missing task document') }) == voidptr(media.document() or { panic('Missing media document') })
	return task
}

fn test_text_track_addition_initializes_and_inserts_before_its_deferred_list_event() {
	mut media := ttat_owner('video')!
	mut document := media.document() or { panic('Missing video document') }
	defer { document.finalize() }
	mut list := media.text_tracks()
	state := &TextTrackAddTaskObservation{}
	ttat_silent_other_events(media, list)
	list.set_onaddtrack(&dom.CallbackType{
		handle_event: fn [media, list, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			track := ttat_payload(event, current, list)
			assert voidptr(track) == voidptr(state.expected[0])
			assert track.kind() == .captions && track.label() == 'English captions' && track.language() == 'en-GB'
			assert track.readiness_state() == .loaded && track.mode() == .hidden && track.cues().length() == 0
			assert voidptr(track.media_element() or { panic('Missing text-track media owner') }) == voidptr(media)
			assert list.length() == 1 && voidptr(list.item(0) or { panic('Missing inserted track') }) == voidptr(track)
			assert media.queued_media_task_ids_.len == 0
			mut result := unsafe { &TextTrackAddTaskObservation(state) }
			result.payloads << voidptr(track)
			result.timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	})
	track := media.add_text_track(.captions, 'English captions', 'en-GB')
	mut observed := unsafe { &TextTrackAddTaskObservation(state) }
	observed.expected << track
	assert track.kind() == .captions && track.label() == 'English captions' && track.language() == 'en-GB'
	assert track.id() == '' && track.readiness_state() == .loaded && track.mode() == .hidden
	assert track.cues().length() == 0 && voidptr(track.media_element() or { panic('Missing synchronous media association') }) == voidptr(media)
	assert list.length() == 1 && voidptr(media.text_tracks()) == voidptr(list)
	assert voidptr(list.item(0) or { panic('Missing synchronous list insertion') }) == voidptr(track)
	assert state.payloads == [] && media.queued_media_task_ids_.len == 1 && media.event_count('addtrack') == 0
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.payloads == [] && media.queued_media_task_ids_.len == 1
	ttat_take(media).execute()
	assert state.payloads == [voidptr(track)] && media.queued_media_task_ids_.len == 0
	assert media.event_count('addtrack') == 0
}

fn test_text_track_additions_deliver_fifo_and_defer_a_reentrant_addition_once() {
	mut media := ttat_owner('audio')!
	mut document := media.document() or { panic('Missing audio document') }
	defer { document.finalize() }
	mut list := media.text_tracks()
	mut state := &TextTrackAddTaskObservation{}
	ttat_silent_other_events(media, list)
	list.set_onaddtrack(&dom.CallbackType{
		handle_event: fn [media, list, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			track := ttat_payload(event, current, list)
			index := state.payloads.len
			assert index < state.expected.len && voidptr(track) == voidptr(state.expected[index])
			assert track.label() == ['First', 'Second', 'Reentrant'][index]
			assert track.readiness_state() == .loaded && track.mode() == .hidden
			assert list.length() == if index == 0 { 2 } else { 3 }
			for position, member in state.expected {
				assert voidptr(list.item(position) or { panic('Lost inserted track') }) == voidptr(member)
			}
			mut result := unsafe { &TextTrackAddTaskObservation(state) }
			result.payloads << voidptr(track)
			result.lengths << list.length()
			if index == 0 {
				mut owner := unsafe { &HTMLMediaElement(media) }
				third := owner.add_text_track(.chapters, 'Reentrant', 'fr')
				result.expected << third
				assert list.length() == 3 && result.payloads.len == 1
				assert media.queued_media_task_ids_.len == 2
			}
			return dom.js_undefined()
		}
	})
	first := media.add_text_track(.subtitles, 'First', 'en')
	second := media.add_text_track(.metadata, 'Second', '')
	state.expected = [first, second]
	assert state.payloads == [] && list.length() == 2 && media.queued_media_task_ids_.len == 2
	ttat_take(media).execute()
	assert state.payloads == [voidptr(first)] && state.expected.len == 3 && media.queued_media_task_ids_.len == 2
	third := state.expected[2]
	assert third.kind() == .chapters && third.label() == 'Reentrant' && third.language() == 'fr'
	ttat_take(media).execute()
	assert state.payloads == [voidptr(first), voidptr(second)] && media.queued_media_task_ids_.len == 1
	ttat_take(media).execute()
	assert state.payloads == [voidptr(first), voidptr(second), voidptr(third)] && state.lengths == [2, 3, 3]
	assert media.queued_media_task_ids_.len == 0 && media.event_count('addtrack') == 0
}

fn test_text_track_addition_uses_the_delivery_clock_and_load_cancels_only_its_owners_task() {
	mut first := ttat_owner('audio')!
	mut second := ttat_owner('video')!
	mut first_document := first.document() or { panic('Missing first document') }
	mut second_document := second.document() or { panic('Missing second document') }
	original_origin := second_document.load_timing_info.navigation_start_time
	defer {
		second_document.load_timing_info.navigation_start_time = original_origin
		first_document.finalize()
		second_document.finalize()
	}
	assert voidptr(first_document) != voidptr(second_document)
	assert first.media_element_event_task_source() != second.media_element_event_task_source()
	mut first_list := first.text_tracks()
	mut second_list := second.text_tracks()
	ttat_silent_other_events(first, first_list)
	ttat_silent_other_events(second, second_list)
	first_list.set_onaddtrack(&dom.CallbackType{
		handle_event: fn (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			panic('Reload must cancel its outstanding text-track addition')
		}
	})
	state := &TextTrackAddTaskObservation{}
	second_list.set_onaddtrack(&dom.CallbackType{
		handle_event: fn [second_list, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			track := ttat_payload(event, current, second_list)
			assert voidptr(track) == voidptr(state.expected[0])
			mut result := unsafe { &TextTrackAddTaskObservation(state) }
			result.payloads << voidptr(track)
			result.timestamps << event.time_stamp()
			return dom.js_undefined()
		}
	})
	canceled_track := first.add_text_track(.captions, 'Canceled notification', 'en')
	canceled_ids := first.queued_media_task_ids_.clone()
	settings := unsafe { &EnvironmentSettingsObject(second_document.relevant_settings_object()) }
	queued_clock := settings.global_relative_event_timestamp()
	retained_track := second.add_text_track(.descriptions, 'Retained notification', 'de')
	mut observed := unsafe { &TextTrackAddTaskObservation(state) }
	observed.expected << retained_track
	assert canceled_ids.len == 1 && second.queued_media_task_ids_.len == 1 && state.payloads == []
	first.load()!
	assert first.queued_media_task_ids_.len == 0 && second.queued_media_task_ids_.len == 1
	assert first_list.length() == 1 && voidptr(first_list.item(0) or { panic('Lost script-created track on reload') }) == voidptr(canceled_track)
	mut queue := main_thread_event_loop().task_queue()
	assert queue.take_first_runnable_matching(fn [canceled_ids] (task &Task) bool {
		return task.id() in canceled_ids
	}) == none
	// Window event clocks read the Document's navigation origin. Moving it
	// after queueing distinguishes delivery-time creation from a captured clock.
	second_document.load_timing_info.navigation_start_time = highresolutiontime.coarsened_shared_current_time(false) - 45000
	before := settings.global_relative_event_timestamp()
	ttat_take(second).execute()
	assert state.payloads == [voidptr(retained_track)] && state.timestamps.len == 1
	assert state.timestamps[0] >= before && state.timestamps[0] <= settings.global_relative_event_timestamp()
	assert state.timestamps[0] >= 45000 && state.timestamps[0] > queued_clock + 30000
	assert second.queued_media_task_ids_.len == 0 && first.event_count('addtrack') == 0 && second.event_count('addtrack') == 0
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}
