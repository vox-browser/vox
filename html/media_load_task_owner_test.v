module html

import dom
import webidl

@[heap]
struct LoadTaskObservation {
mut:
	events          []string
	old_task        bool
	other_task      bool
	schedule_depths []uint
	reaction_depths []uint
	reaction_names  []string
}

fn load_task_owner() !&HTMLMediaElement {
	url := dom.URL{ value: 'https://load-task.example.test/' }
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	return html_media_element_for_dom_element(element) or { return error('missing media owner') }
}

fn load_task_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing load task') }
}

fn load_task_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 {
		load_task_take(media).execute()
	}
}

fn test_load_queues_reset_events_after_canceling_only_its_own_previous_tasks() {
	for network in [MediaNetworkState.empty, .loading, .idle, .no_source] {
		mut media := load_task_owner()!
		mut other := load_task_owner()!
		state := &LoadTaskObservation{}
		media.set_default_playback_rate(2)
		load_task_drain(media)
		media.network_state_ = network
		if network != .empty { media.set_official_playback_position(3) }
		media.queue_a_media_element_task(fn [state] () {
			mut observation := unsafe { &LoadTaskObservation(state) }
			observation.old_task = true
		})
		other.queue_a_media_element_task(fn [state] () {
			mut observation := unsafe { &LoadTaskObservation(state) }
			observation.other_task = true
		})
		for name in ['abort', 'emptied', 'timeupdate', 'ratechange'] {
			media.set_on_event(name, &dom.CallbackType{
				handle_event: fn [name, media, state] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
					mut observation := unsafe { &LoadTaskObservation(state) }
					observation.events << name
					assert media.paused() && media.current_time() == 0 && media.playback_rate() == 2
					assert voidptr(event.target() or { panic('missing event target') }) == voidptr(media.event_target())
					assert voidptr(current or { panic('missing current target') }) == voidptr(media.event_target())
					assert event.is_trusted() && !event.bubbles() && !event.cancelable()
					return dom.js_undefined()
				}
			})
		}
		media.load()!
		assert state.events == [] && !state.old_task && !state.other_task
		assert media.network_state() == .empty && media.current_time() == 0
		mut expected := []string{}
		if network in [.loading, .idle] { expected << 'abort' }
		if network != .empty { expected << ['emptied', 'timeupdate'] }
		expected << 'ratechange'
		assert media.queued_media_task_ids_.len == expected.len && other.queued_media_task_ids_.len == 1
		mut loop := main_thread_event_loop()
		loop.perform_a_microtask_checkpoint()
		assert state.events == []
		for name in expected {
			task := load_task_take(media)
			assert voidptr(task.document()?) == voidptr(media.document()?)
			assert task.source() == media.media_element_event_task_source()
			task.execute()
			assert state.events.last() == name
		}
		assert state.events == expected && !state.old_task && !state.other_task
		load_task_drain(other)
		assert state.other_task
	}
}

fn test_load_rejects_the_current_pending_batch_synchronously_with_one_actual_abort_error() {
	mut media := load_task_owner()!
	settings := unsafe { &EnvironmentSettingsObject(media.document()?.relevant_settings_object()) }
	canonical := settings.stream_promise_context()
	state := &LoadTaskObservation{}
	mut promises := []&dom.Promise{}
	for _ in 0 .. 2 {
		mut native := webidl.create_promise_for(webidl.PromiseContext{
			...canonical
			job_scheduler: fn [canonical, settings, state] (job fn ()) {
				mut observation := unsafe { &LoadTaskObservation(state) }
				observation.schedule_depths << settings.realm().script_execution_depth
				schedule := canonical.job_scheduler or { panic('missing actual job scheduler') }
				schedule(job)
			}
		})
		webidl.react_to_promise(mut native, fn (_ webidl.Value) !webidl.Value {
			return error('load fulfilled a pending play promise')
		}, fn [settings, state] (reason webidl.Value) !webidl.Value {
			mut observation := unsafe { &LoadTaskObservation(state) }
			observation.reaction_depths << settings.realm().script_execution_depth
			observation.reaction_depths << settings.realm().callback_execution_depth
			observation.reaction_names << if exception := reason.dom_exception_ { exception.name() } else { 'missing DOMException' }
			return webidl.undefined_value()
		})
		promise := dom.Promise.from_webidl(native)
		promises << promise
		media.pending_play_promises_ << promise
	}
	media.network_state_ = .idle
	media.set_paused(false)
	media.load()!
	assert media.paused() && media.pending_play_promises_.len == 0
	assert state.schedule_depths == [uint(1), 1]
	// With no outer author script, closing the temporary context performs the
	// microtask checkpoint. Reset event tasks still wait for the task queue.
	assert state.reaction_depths == [uint(1), 1, 1, 1]
	for promise in promises {
		assert promise.state() == .rejected
		exception := promise.result().as_webidl_value()!.dom_exception_?
		assert exception.name() == 'AbortError' && exception.message() == 'Media playback was aborted'
		assert exception.code() == 20
	}
	assert voidptr(promises[0].result().as_webidl_value()!.dom_exception_?) == voidptr(promises[1].result().as_webidl_value()!.dom_exception_?)
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.reaction_depths == [uint(1), 1, 1, 1]
	assert state.reaction_names == ['AbortError', 'AbortError']
	assert media.event_count('abort') == 0 && media.event_count('emptied') == 0
	load_task_drain(media)
	assert media.event_count('abort') == 1 && media.event_count('emptied') == 1
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}

fn test_reloading_cancels_reset_delivery_and_inactive_documents_skip_their_tasks() {
	mut media := load_task_owner()!
	media.network_state_ = .idle
	media.set_official_playback_position(3)
	media.load()!
	assert media.queued_media_task_ids_.len == 3
	media.load()!
	assert media.queued_media_task_ids_.len == 0
	assert media.event_count('abort') == 0 && media.event_count('emptied') == 0 && media.event_count('timeupdate') == 0
	media.network_state_ = .loading
	media.load()!
	tasks := [load_task_take(media), load_task_take(media)]
	mut navigable := media.document()?.navigable()?
	navigable.set_active_document(none)
	for task in tasks { task.execute() }
	assert media.queued_media_task_ids_.len == 0
	assert media.event_count('abort') == 0 && media.event_count('emptied') == 0
}

fn test_load_preserves_source_empty_and_already_paused_pending_promise_guards() {
	for network in [MediaNetworkState.empty, .no_source] {
		mut media := load_task_owner()!
		promise := dom.Promise.create()
		media.pending_play_promises_ << promise
		media.network_state_ = network
		if network == .empty { media.set_paused(false) }
		media.load()!
		assert promise.state() == .pending && media.pending_play_promises_.len == 1
		assert media.paused() == (network != .empty)
		load_task_drain(media)
		assert media.event_count('abort') == 0 && media.event_count('timeupdate') == 0
		assert media.event_count('emptied') == if network == .empty { 0 } else { 1 }
	}
}
