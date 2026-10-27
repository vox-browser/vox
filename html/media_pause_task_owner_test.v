module html

import dom
import webidl

@[heap]
struct PauseTaskObservation {
mut:
	position        f64
	events          []string
	pending         []bool
	resumed         ?&dom.Promise
	schedule_depths []uint
	reaction_depths []uint
	reason          ?webidl.Value
}

fn pause_task_drain_setup(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn pause_task_owner() !&HTMLMediaElement {
	url := dom.URL{ value: 'https://pause-task.example.test/' }
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/pending.mp4')
	media.load()!
	pause_task_drain_setup(media)
	media.set_show_poster(false)
	assert media.ready_state() == .have_metadata
	return media
}

fn pause_task_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing pause task') }
}

fn pause_task_exception(promise &dom.Promise) &webidl.DOMException {
	value := promise.result().as_webidl_value() or { panic(err) }
	exception := value.dom_exception_ or { panic('missing actual AbortError') }
	assert exception.name() == 'AbortError' && exception.message() == 'Media playback was paused'
	assert exception.code() == 20
	return exception
}

fn test_pause_task_defers_ordered_events_and_shared_rejection_but_commits_state_immediately() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := pause_task_owner()!
	state := &PauseTaskObservation{ position: 2 }
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 { return state.position }
	})
	first := media.play()
	second := media.play()
	pause_task_drain_setup(media)
	target := media.event_target()
	for name in ['timeupdate', 'pause'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, first, second, state, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &PauseTaskObservation(state) }
				observation.events << name
				observation.pending << (first.state() == .pending && second.state() == .pending)
				assert media.paused()
				assert voidptr(event.target() or { panic('missing target') }) == voidptr(target)
				assert voidptr(current or { panic('missing current target') }) == voidptr(target)
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				return dom.js_undefined()
			}
		})
	}
	mut clock := unsafe { &PauseTaskObservation(state) }
	clock.position = 6
	media.pause()
	assert state.events == [] && first.state() == .pending && second.state() == .pending
	assert media.paused() && !media.can_autoplay_ && media.current_time() == 6
	assert media.pending_play_promises_.len == 0 && media.queued_media_task_ids_.len == 1
	media.pause()
	assert media.queued_media_task_ids_.len == 1
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == [] && first.state() == .pending
	task := pause_task_take(media)
	assert voidptr(task.document()?) == voidptr(media.document()?)
	assert task.source() == media.media_element_event_task_source()
	task.execute()
	assert state.events == ['timeupdate', 'pause'] && state.pending == [true, true]
	assert first.state() == .rejected && second.state() == .rejected
	assert voidptr(pause_task_exception(first)) == voidptr(pause_task_exception(second))
	assert media.queued_media_task_ids_.len == 0
}

fn test_pause_task_keeps_its_captured_batch_when_a_listener_resumes_playback() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := pause_task_owner()!
	original := media.play()
	pause_task_drain_setup(media)
	state := &PauseTaskObservation{}
	media.set_on_event('timeupdate', &dom.CallbackType{
		handle_event: fn [media, original, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert original.state() == .pending
			mut owner := unsafe { &HTMLMediaElement(media) }
			mut observation := unsafe { &PauseTaskObservation(state) }
			observation.events << 'timeupdate'
			observation.resumed = owner.play()
			return dom.js_undefined()
		}
	})
	media.set_on_event('pause', &dom.CallbackType{
		handle_event: fn [media, original, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert !media.paused() && original.state() == .pending
			assert (state.resumed or { panic('missing resumed promise') }).state() == .pending
			mut observation := unsafe { &PauseTaskObservation(state) }
			observation.events << 'pause'
			return dom.js_undefined()
		}
	})
	media.pause()
	assert state.events == [] && media.paused()
	pause_task_take(media).execute()
	assert state.events == ['timeupdate', 'pause'] && !media.paused()
	assert original.state() == .rejected
	pause_task_exception(original)
	resumed := state.resumed or { panic('missing resumed promise') }
	assert resumed.state() == .pending && media.pending_play_promises_.len == 1
	assert voidptr(media.pending_play_promises_[0]) == voidptr(resumed)
}

fn test_pause_task_cancellation_and_inactive_delivery_keep_the_actual_owner_boundary() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut first := pause_task_owner()!
	mut second := pause_task_owner()!
	first_promise := first.play()
	second_promise := second.play()
	pause_task_drain_setup(first)
	pause_task_drain_setup(second)
	first.pause()
	second.pause()
	assert first.queued_media_task_ids_.len == 1 && second.queued_media_task_ids_.len == 1
	first.set_source('')
	first.load()!
	// The old pause task is canceled; abort and emptied belong to the new load.
	assert first.queued_media_task_ids_.len == 2 && second.queued_media_task_ids_.len == 1
	assert first.event_count('abort') == 0 && first.event_count('emptied') == 0
	for first.queued_media_task_ids_.len > 0 { pause_task_take(first).execute() }
	assert second.queued_media_task_ids_.len == 1
	assert first.event_count('abort') == 1 && first.event_count('emptied') == 1
	pause_task_take(second).execute()
	assert first.event_count('pause') == 0 && second.event_count('pause') == 1
	// Pinned load_element step 4 is itself FIXME: captured promises belonging
	// to canceled tasks remain pending. Preserve that boundary explicitly.
	assert first_promise.state() == .pending && second_promise.state() == .rejected
	pause_task_exception(second_promise)
	mut inactive := pause_task_owner()!
	promise := inactive.play()
	pause_task_drain_setup(inactive)
	inactive.pause()
	task := pause_task_take(inactive)
	document := inactive.document()?
	assert voidptr(task.document()?) == voidptr(document)
	mut navigable := document.navigable()?
	navigable.set_active_document(none)
	assert !document.is_fully_active()
	task.execute()
	assert inactive.queued_media_task_ids_.len == 0 && inactive.event_count('pause') == 0
	assert promise.state() == .pending
}

fn test_pause_rejection_enters_the_actual_document_context_and_schedules_native_jobs() {
	mut media := pause_task_owner()!
	settings := unsafe { &EnvironmentSettingsObject(media.document()?.relevant_settings_object()) }
	canonical := settings.stream_promise_context()
	state := &PauseTaskObservation{}
	mut native := webidl.create_promise_for(webidl.PromiseContext{
		...canonical
		job_scheduler: fn [canonical, settings, state] (job fn ()) {
			mut observation := unsafe { &PauseTaskObservation(state) }
			observation.schedule_depths << settings.realm().script_execution_depth
			schedule := canonical.job_scheduler or { panic('missing actual job scheduler') }
			schedule(job)
		}
	})
	webidl.react_to_promise(mut native, fn (_ webidl.Value) !webidl.Value {
		return error('pause fulfilled a pending play promise')
	}, fn [settings, state] (reason webidl.Value) !webidl.Value {
		mut observation := unsafe { &PauseTaskObservation(state) }
		observation.reaction_depths << settings.realm().script_execution_depth
		observation.reaction_depths << settings.realm().callback_execution_depth
		observation.reason = reason
		return webidl.undefined_value()
	})
	media.pending_play_promises_ << dom.Promise.from_webidl(native)
	media.set_paused(false)
	media.pause()
	assert native.state == .pending && state.schedule_depths == []
	pause_task_take(media).execute()
	assert native.state == .rejected && state.schedule_depths == [uint(1)]
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.reaction_depths == [uint(1), 1]
	value := state.reason or { panic('missing native reaction reason') }
	assert voidptr(value.dom_exception_?) == voidptr(native.result.dom_exception_?)
	assert native.result.dom_exception_?.name() == 'AbortError'
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}
