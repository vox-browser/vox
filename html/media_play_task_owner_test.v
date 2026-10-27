module html

import dom
import webidl

@[heap]
struct PlayTaskOwnerObservation {
mut:
	position        f64
	starts          int
	events          []string
	positions       []f64
	new_promise     ?&dom.Promise
	schedule_depths []uint
	reaction_depths []uint
}

fn play_task_drain_owner(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn play_task_owner(ready MediaReadyState) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://play-task.example.test/' }
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing video') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/movie.mp4')
	media.load()!
	play_task_drain_owner(media)
	media.set_ready_state(ready)
	media.set_show_poster(false)
	play_task_drain_owner(media)
	assert media.paused() && media.ready_state() == ready
	return media
}

fn play_task_take_owner(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing play task') }
}

fn test_internal_play_queues_separate_play_and_waiting_tasks_without_resolving_low_ready_promises() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := play_task_owner(.have_metadata)!
	state := &PlayTaskOwnerObservation{}
	target := media.event_target()
	for name in ['play', 'waiting'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, state, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &PlayTaskOwnerObservation(state) }
				observation.events << name
				assert !media.paused() && !media.can_autoplay_
				assert voidptr(event.target() or { panic('missing target') }) == voidptr(target)
				assert voidptr(current or { panic('missing current target') }) == voidptr(target)
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				return dom.js_undefined()
			}
		})
	}
	first := media.play()
	second := media.play()
	assert !media.paused() && !media.can_autoplay_ && !media.show_poster()
	assert state.events == [] && media.queued_media_task_ids_.len == 2
	assert first.state() == .pending && second.state() == .pending
	assert media.pending_play_promises_.len == 2
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == []
	for name in ['play', 'waiting'] {
		task := play_task_take_owner(media)
		assert voidptr(task.document()?) == voidptr(media.document()?)
		assert task.source() == media.media_element_event_task_source()
		task.execute()
		assert state.events.last() == name
		assert first.state() == .pending && second.state() == .pending
	}
	assert state.events == ['play', 'waiting'] && media.queued_media_task_ids_.len == 0
}

fn test_playing_task_captures_start_position_before_the_manager_starts_and_keeps_batches_separate() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := play_task_owner(.have_future_data)!
	state := &PlayTaskOwnerObservation{ position: 2 }
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 { return state.position }
		play: fn [state] () {
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.starts++
			observation.position = 7
		}
	})
	first := media.play()
	second := media.play()
	assert first.state() == .pending && second.state() == .pending
	assert state.starts == 1 && state.position == 7 && !media.paused()
	assert media.queued_media_task_ids_.len == 3 && media.pending_play_promises_.len == 0
	media.set_on_event('play', &dom.CallbackType{
		handle_event: fn [state, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert first.state() == .pending && second.state() == .pending
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.events << 'play'
			return dom.js_undefined()
		}
	})
	media.set_on_event('playing', &dom.CallbackType{
		handle_event: fn [state, media, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert first.state() == .pending && second.state() == .pending
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.events << 'playing'
			observation.positions << media.current_time()
			mut owner := unsafe { &HTMLMediaElement(media) }
			observation.new_promise = owner.play()
			return dom.js_undefined()
		}
	})
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == [] && first.state() == .pending
	play_task_take_owner(media).execute()
	assert state.events == ['play'] && first.state() == .pending
	play_task_take_owner(media).execute()
	assert state.events == ['play', 'playing'] && state.positions == [2.0]
	new_promise := state.new_promise or { panic('missing listener promise') }
	assert first.state() == .fulfilled && second.state() == .pending && new_promise.state() == .pending
	assert first.result().is_undefined() && media.current_time() == 2
	play_task_take_owner(media).execute()
	assert second.state() == .fulfilled && new_promise.state() == .pending
	play_task_take_owner(media).execute()
	assert new_promise.state() == .fulfilled && state.starts == 1
	assert state.events == ['play', 'playing'] && media.queued_media_task_ids_.len == 0
}

fn test_ready_state_notification_captures_the_pending_batch_before_queuing_playing() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := play_task_owner(.have_metadata)!
	first := media.play()
	second := media.play()
	play_task_drain_owner(media)
	state := &PlayTaskOwnerObservation{ position: 3 }
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 { return state.position }
	})
	media.set_on_event('loadeddata', &dom.CallbackType{
		handle_event: fn [state, media, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert first.state() == .pending && second.state() == .pending
			assert media.pending_play_promises_.len == 0
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.events << 'loadeddata'
			mut owner := unsafe { &HTMLMediaElement(media) }
			observation.new_promise = owner.play()
			return dom.js_undefined()
		}
	})
	media.set_on_event('canplay', &dom.CallbackType{
		handle_event: fn [state, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert first.state() == .pending && second.state() == .pending
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.events << 'canplay'
			return dom.js_undefined()
		}
	})
	media.set_on_event('playing', &dom.CallbackType{
		handle_event: fn [state, media, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert first.state() == .pending && second.state() == .pending
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.events << 'playing'
			observation.positions << media.current_time()
			return dom.js_undefined()
		}
	})
	media.set_ready_state(.have_future_data)
	assert first.state() == .pending && second.state() == .pending && state.events == []
	assert media.pending_play_promises_.len == 0 && media.queued_media_task_ids_.len == 3
	mut clock := unsafe { &PlayTaskOwnerObservation(state) }
	clock.position = 9
	play_task_take_owner(media).execute()
	assert state.events == ['loadeddata'] && first.state() == .pending && second.state() == .pending
	new_promise := state.new_promise or { panic('missing loadeddata listener promise') }
	assert new_promise.state() == .pending
	play_task_take_owner(media).execute()
	assert state.events == ['loadeddata', 'canplay']
	assert first.state() == .pending && second.state() == .pending && new_promise.state() == .pending
	play_task_take_owner(media).execute()
	assert state.events == ['loadeddata', 'canplay', 'playing'] && state.positions == [3.0]
	assert first.state() == .fulfilled && second.state() == .fulfilled
	assert new_promise.state() == .pending
	play_task_take_owner(media).execute()
	assert new_promise.state() == .fulfilled && media.queued_media_task_ids_.len == 0
}

fn test_queued_playing_is_unconditional_after_pause_and_resolves_its_earlier_captured_batch() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := play_task_owner(.have_future_data)!
	state := &PlayTaskOwnerObservation{}
	for name in ['play', 'playing', 'timeupdate', 'pause'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert media.paused()
				mut observation := unsafe { &PlayTaskOwnerObservation(state) }
				observation.events << name
				return dom.js_undefined()
			}
		})
	}
	promise := media.play()
	media.pause()
	assert media.paused() && promise.state() == .pending && state.events == []
	assert media.queued_media_task_ids_.len == 3
	play_task_take_owner(media).execute()
	assert state.events == ['play'] && promise.state() == .pending
	play_task_take_owner(media).execute()
	assert state.events == ['play', 'playing'] && promise.state() == .fulfilled
	play_task_take_owner(media).execute()
	assert state.events == ['play', 'playing', 'timeupdate', 'pause'] && promise.state() == .fulfilled
}

fn test_loading_and_inactive_delivery_cancel_only_the_actual_play_task_owner() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut first := play_task_owner(.have_future_data)!
	mut second := play_task_owner(.have_future_data)!
	first_promise := first.play()
	second_promise := second.play()
	assert first_promise.state() == .pending && second_promise.state() == .pending
	assert first.queued_media_task_ids_.len == 2 && second.queued_media_task_ids_.len == 2
	first.set_source('')
	first.load()!
	// Loading cancels the old play tasks, then queues abort and emptied.
	assert first.queued_media_task_ids_.len == 2 && second.queued_media_task_ids_.len == 2
	assert first.event_count('abort') == 0 && first.event_count('emptied') == 0
	for first.queued_media_task_ids_.len > 0 { play_task_take_owner(first).execute() }
	assert second.queued_media_task_ids_.len == 2
	assert first.event_count('abort') == 1 && first.event_count('emptied') == 1
	play_task_drain_owner(second)
	assert first.event_count('play') == 0 && first.event_count('playing') == 0
	assert second.event_count('play') == 1 && second.event_count('playing') == 1
	// Source load_element step 4 still leaves canceled tasks' captured batches pending.
	assert first_promise.state() == .pending && second_promise.state() == .fulfilled
	mut inactive := play_task_owner(.have_future_data)!
	promise := inactive.play()
	tasks := [play_task_take_owner(inactive), play_task_take_owner(inactive)]
	document := inactive.document()?
	mut navigable := document.navigable()?
	navigable.set_active_document(none)
	for task in tasks {
		assert voidptr(task.document()?) == voidptr(document)
		task.execute()
	}
	assert inactive.queued_media_task_ids_.len == 0 && inactive.event_count('play') == 0
	assert inactive.event_count('playing') == 0 && promise.state() == .pending
}

fn test_play_resolution_enters_the_actual_document_context_for_native_capability_jobs() {
	mut media := play_task_owner(.have_future_data)!
	settings := unsafe { &EnvironmentSettingsObject(media.document()?.relevant_settings_object()) }
	canonical := settings.stream_promise_context()
	state := &PlayTaskOwnerObservation{}
	mut native := webidl.create_promise_for(webidl.PromiseContext{
		...canonical
		job_scheduler: fn [canonical, settings, state] (job fn ()) {
			mut observation := unsafe { &PlayTaskOwnerObservation(state) }
			observation.schedule_depths << settings.realm().script_execution_depth
			schedule := canonical.job_scheduler or { panic('missing scheduler') }
			schedule(job)
		}
	})
	webidl.react_to_promise(mut native, fn [settings, state] (value webidl.Value) !webidl.Value {
		assert value.kind == .undefined
		mut observation := unsafe { &PlayTaskOwnerObservation(state) }
		observation.reaction_depths << settings.realm().script_execution_depth
		observation.reaction_depths << settings.realm().callback_execution_depth
		return webidl.undefined_value()
	}, fn (_ webidl.Value) !webidl.Value { return error('play resolution rejected') })
	media.pending_play_promises_ << dom.Promise.from_webidl(native)
	media.set_paused(false)
	media.play_element()
	assert native.state == .pending && state.schedule_depths == []
	assert media.queued_media_task_ids_.len == 1
	play_task_take_owner(media).execute()
	assert native.state == .fulfilled && native.result.kind == .undefined
	assert state.schedule_depths == [uint(1)]
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.reaction_depths == [uint(1), 1]
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
}
