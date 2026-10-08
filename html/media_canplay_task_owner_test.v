module html

import dom

@[heap]
struct CanPlayTaskObservation {
mut:
	events      []string
	states      []MediaReadyState
	starts      int
	position    f64 = 3
	new_promise ?&dom.Promise
}

fn canplay_task_owner(loaded bool) !&HTMLMediaElement {
	url := dom.URL{
		value: 'https://canplay-task.example.test/'
	}
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or {
		return error('missing media owner')
	}
	if loaded {
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		media.set_source('/movie.mp4')
		media.load()!
		canplay_task_drain(media)
	}
	return media
}

fn canplay_task_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing canplay task') }
}

fn canplay_task_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 {
		canplay_task_take(media).execute()
	}
}

fn test_canplay_requires_nonempty_network_and_a_crossing_into_future_or_enough_data() {
	for network in [MediaNetworkState.empty, .idle, .loading, .no_source] {
		for old in [MediaReadyState.have_nothing, .have_metadata, .have_current_data,
			.have_future_data, .have_enough_data] {
			for next in [MediaReadyState.have_future_data, .have_enough_data] {
				mut media := canplay_task_owner(false)!
				media.network_state_ = network
				media.ready_state_ = old
				media.set_ready_state(next)
				assert media.ready_state() == next && media.event_count('canplay') == 0
				expected := if network != .empty
					&& int(old) <= int(MediaReadyState.have_current_data) {
					1
				} else {
					0
				}
				through := if network != .empty && old != next && next == .have_enough_data { 1 } else { 0 }
				assert media.queued_media_task_ids_.len == expected + through
				canplay_task_drain(media)
				assert media.event_count('canplay') == expected
			}
		}
	}
	mut empty := canplay_task_owner(false)!
	empty.ready_state_ = .have_current_data
	empty.paused_ = false
	promise := dom.Promise.create()
	empty.pending_play_promises_ << promise
	empty.set_ready_state(.have_future_data)
	assert empty.ready_state() == .have_future_data && !empty.blocked()
	assert empty.event_count('canplay') == 0 && empty.queued_media_task_ids_.len == 0
	assert !empty.has_started_playback_ && empty.pending_play_promises_.len == 1
	assert promise.state() == .pending
}

fn test_first_data_precedes_canplay_and_both_tasks_read_live_readiness() {
	for next in [MediaReadyState.have_future_data, .have_enough_data] {
		mut media := canplay_task_owner(true)!
		observation := &CanPlayTaskObservation{}
		for name in ['loadeddata', 'canplay'] {
			media.set_on_event(name, &dom.CallbackType{
				handle_event: fn [name, media, observation] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
					mut seen := unsafe { &CanPlayTaskObservation(observation) }
					seen.events << name
					seen.states << media.ready_state()
					assert voidptr(event.target() or { panic('missing target') }) == voidptr(media.event_target())
					assert voidptr(current or { panic('missing current target') }) == voidptr(media.event_target())
					assert event.is_trusted() && !event.bubbles() && !event.cancelable()
					return dom.js_undefined()
				}
			})
		}
		media.set_ready_state(next)
		pending := if next == .have_enough_data { 3 } else { 2 }
		assert observation.events == [] && media.queued_media_task_ids_.len == pending
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_current_data)
		mut loop := main_thread_event_loop()
		loop.perform_a_microtask_checkpoint()
		assert observation.events == []
		for name in ['loadeddata', 'canplay'] {
			task := canplay_task_take(media)
			assert task.source() == media.media_element_event_task_source()
			assert voidptr(task.document()?) == voidptr(media.document()?)
			task.execute()
			assert observation.events.last() == name
		}
		assert observation.events == ['loadeddata', 'canplay']
		assert observation.states == [MediaReadyState.have_current_data, .have_current_data]
		canplay_task_drain(media)
		media.set_ready_state(next)
		assert media.event_count('canplay') == 1 && media.queued_media_task_ids_.len == pending - 1
		canplay_task_drain(media)
		assert media.event_count('canplay') == 2 && media.event_count('loadeddata') == 1
	}
}

fn test_canplay_listener_cannot_join_the_already_captured_playing_promise_batch() {
	for next in [MediaReadyState.have_future_data, .have_enough_data] {
		mut media := canplay_task_owner(true)!
		media.set_ready_state(.have_current_data)
		canplay_task_drain(media)
		first := media.play()
		second := media.play()
		canplay_task_drain(media)
		observation := &CanPlayTaskObservation{}
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			current_time: fn [observation] () f64 {
				return observation.position
			}
			play:         fn [observation] () {
				mut seen := unsafe { &CanPlayTaskObservation(observation) }
				seen.starts++
			}
		})
		media.set_on_event('canplay', &dom.CallbackType{
			handle_event: fn [media, observation, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert first.state() == .pending && second.state() == .pending
				assert media.pending_play_promises_.len == 0 && observation.starts == 1
				mut seen := unsafe { &CanPlayTaskObservation(observation) }
				seen.events << 'canplay'
				mut owner := unsafe { &HTMLMediaElement(media) }
				seen.new_promise = owner.play()
				return dom.js_undefined()
			}
		})
		media.set_on_event('playing', &dom.CallbackType{
			handle_event: fn [media, observation, first, second] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				assert first.state() == .pending && second.state() == .pending
				mut seen := unsafe { &CanPlayTaskObservation(observation) }
				seen.events << 'playing'
				assert media.current_time() == 3
				return dom.js_undefined()
			}
		})
		media.set_ready_state(next)
		assert observation.events == [] && observation.starts == 1
		pending := if next == .have_enough_data { 3 } else { 2 }
		assert media.pending_play_promises_.len == 0 && media.queued_media_task_ids_.len == pending
		mut clock := unsafe { &CanPlayTaskObservation(observation) }
		clock.position = 9
		canplay_task_take(media).execute()
		assert observation.events == ['canplay'] && first.state() == .pending
			&& second.state() == .pending
		third := observation.new_promise or { panic('missing canplay listener promise') }
		canplay_task_take(media).execute()
		assert observation.events == ['canplay', 'playing']
		assert first.state() == .fulfilled && second.state() == .fulfilled
			&& third.state() == .pending
		if next == .have_enough_data {
			canplay_task_take(media).execute()
			assert media.event_count('canplaythrough') == 1 && third.state() == .pending
		}
		canplay_task_take(media).execute()
		assert third.state() == .fulfilled && observation.starts == 1
			&& media.queued_media_task_ids_.len == 0
	}
}

fn test_reload_cancels_only_its_owners_canplay_task() {
	mut first := canplay_task_owner(true)!
	mut second := canplay_task_owner(true)!
	for owner in [first, second] {
		mut media := unsafe { &HTMLMediaElement(owner) }
		media.set_ready_state(.have_current_data)
		canplay_task_drain(media)
		media.set_ready_state(.have_future_data)
	}
	assert first.queued_media_task_ids_.len == 1 && second.queued_media_task_ids_.len == 1
	first.load()!
	canplay_task_drain(first)
	assert first.event_count('canplay') == 0 && second.queued_media_task_ids_.len == 1
	canplay_task_drain(second)
	assert second.event_count('canplay') == 1
	first.set_ready_state(.have_enough_data)
	canplay_task_drain(first)
	assert first.event_count('canplay') == 1 && first.event_count('loadeddata') == 2
}

fn test_canplay_tasks_follow_the_adopted_owner_and_skip_inactive_delivery() {
	mut media := canplay_task_owner(true)!
	media.set_ready_state(.have_current_data)
	canplay_task_drain(media)
	old_document := media.document()?
	url := dom.URL{
		value: 'https://adopted-canplay.example.test/'
	}
	mut document := parse_navigation_document('<body></body>', url, url.origin(), none)!
	document.adopt_node(old_document.get_element_by_id('player')?.as_node())
	media.set_ready_state(.have_future_data)
	task := canplay_task_take(media)
	assert voidptr(task.document()?) == voidptr(document)
	mut navigable := document.navigable()?
	navigable.set_active_document(none)
	task.execute()
	assert media.event_count('canplay') == 0 && media.queued_media_task_ids_.len == 0
	navigable.set_active_document(document)
	media.set_ready_state(.have_future_data)
	assert media.queued_media_task_ids_.len == 0
	media.set_ready_state(.have_current_data)
	media.set_ready_state(.have_future_data)
	canplay_task_drain(media)
	assert media.event_count('canplay') == 1
}
