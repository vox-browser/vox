module html

import dom

@[heap]
struct CanPlayThroughObservation {
mut:
	events   []string
	states   []MediaReadyState
	position f64 = 5
	starts   int
}

fn canplaythrough_owner(loaded bool) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://canplaythrough-task.example.test/' }
	document := parse_navigation_document('<video id="player"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	if loaded {
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		media.set_source('/movie.mp4')
		media.load()!
		canplaythrough_drain(media)
	}
	return media
}

fn canplaythrough_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing canplaythrough task') }
}

fn canplaythrough_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 {
		canplaythrough_take(media).execute()
	}
}

fn test_canplaythrough_requires_nonempty_network_and_a_changed_enough_data_destination() {
	for network in [MediaNetworkState.empty, .idle, .loading, .no_source] {
		for old in [MediaReadyState.have_nothing, .have_metadata, .have_current_data,
			.have_future_data, .have_enough_data] {
			for next in [MediaReadyState.have_current_data, .have_future_data, .have_enough_data] {
				mut media := canplaythrough_owner(false)!
				media.network_state_ = network
				media.ready_state_ = old
				media.set_ready_state(next)
				assert media.ready_state() == next && media.event_count('canplaythrough') == 0
				canplaythrough_drain(media)
				expected := if network != .empty && old != next && next == .have_enough_data { 1 } else { 0 }
				assert media.event_count('canplaythrough') == expected
			}
		}
	}
}

fn test_canplaythrough_follows_first_data_canplay_and_the_captured_playing_batch() {
	// This task/state regression exercises a permitted explicit play request.
	mut playback_policy := AutoplaySettings.the()
	previous_policy := playback_policy.policy()
	previous_allowlist := playback_policy.allowlist().map(it.serialize())
	defer { playback_policy.set_policy(previous_policy, previous_allowlist) }
	playback_policy.set_policy(.allow_audio_and_video, [])
	mut media := canplaythrough_owner(true)!
	first := media.play()
	second := media.play()
	canplaythrough_drain(media)
	seen := &CanPlayThroughObservation{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [seen] () f64 { return seen.position }
		play: fn [seen] () {
			mut observation := unsafe { &CanPlayThroughObservation(seen) }
			observation.starts++
		}
	})
	for name in ['loadeddata', 'canplay', 'playing', 'canplaythrough'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, seen, first, second] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &CanPlayThroughObservation(seen) }
				observation.events << name
				observation.states << media.ready_state()
				assert voidptr(event.target() or { panic('missing target') }) == voidptr(media.event_target())
				assert voidptr(current or { panic('missing current target') }) == voidptr(media.event_target())
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				if name == 'canplaythrough' {
					assert first.state() == .fulfilled && second.state() == .fulfilled
					assert media.current_time() == 5
				} else {
					assert first.state() == .pending && second.state() == .pending
				}
				return dom.js_undefined()
			}
		})
	}
	media.set_ready_state(.have_enough_data)
	assert seen.events == [] && seen.starts == 1 && media.pending_play_promises_.len == 0
	assert media.queued_media_task_ids_.len == 4
	mut clock := unsafe { &CanPlayThroughObservation(seen) }
	clock.position = 12
	media.set_ready_state(.have_future_data)
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert seen.events == []
	for name in ['loadeddata', 'canplay', 'playing', 'canplaythrough'] {
		task := canplaythrough_take(media)
		assert task.source() == media.media_element_event_task_source()
		assert voidptr(task.document()?) == voidptr(media.document()?)
		task.execute()
		assert seen.events.last() == name
	}
	assert seen.states == [MediaReadyState.have_future_data, .have_future_data,
		.have_future_data, .have_future_data]
	assert first.state() == .fulfilled && second.state() == .fulfilled
	assert media.queued_media_task_ids_.len == 0
}

fn test_future_to_enough_queues_only_canplaythrough_and_later_crossings_can_repeat_it() {
	mut media := canplaythrough_owner(true)!
	media.set_ready_state(.have_future_data)
	canplaythrough_drain(media)
	seen := &CanPlayThroughObservation{}
	media.set_on_event('canplaythrough', &dom.CallbackType{
		handle_event: fn [media, seen] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut observation := unsafe { &CanPlayThroughObservation(seen) }
			observation.states << media.ready_state()
			return dom.js_undefined()
		}
	})
	media.set_ready_state(.have_enough_data)
	media.set_ready_state(.have_enough_data)
	assert seen.states == [] && media.queued_media_task_ids_.len == 1
	media.set_ready_state(.have_current_data)
	canplaythrough_drain(media)
	assert seen.states == [MediaReadyState.have_current_data]
	assert media.event_count('canplay') == 1 && media.event_count('loadeddata') == 1
	media.set_ready_state(.have_enough_data)
	canplaythrough_drain(media)
	assert seen.states == [MediaReadyState.have_current_data, .have_enough_data]
	assert media.event_count('canplaythrough') == 2 && media.event_count('canplay') == 2
	assert media.event_count('loadeddata') == 1
}

fn test_reload_cancels_only_its_owners_pending_canplaythrough() {
	mut first := canplaythrough_owner(true)!
	mut second := canplaythrough_owner(true)!
	for owner in [first, second] {
		mut media := unsafe { &HTMLMediaElement(owner) }
		media.set_ready_state(.have_future_data)
		canplaythrough_drain(media)
		media.set_ready_state(.have_enough_data)
	}
	assert first.queued_media_task_ids_.len == 1 && second.queued_media_task_ids_.len == 1
	first.load()!
	canplaythrough_drain(first)
	assert first.event_count('canplaythrough') == 0 && second.queued_media_task_ids_.len == 1
	canplaythrough_drain(second)
	assert second.event_count('canplaythrough') == 1
	first.set_ready_state(.have_enough_data)
	canplaythrough_drain(first)
	assert first.event_count('canplaythrough') == 1
}

fn test_canplaythrough_uses_the_adopted_document_and_discards_inactive_delivery() {
	mut media := canplaythrough_owner(true)!
	media.set_ready_state(.have_future_data)
	canplaythrough_drain(media)
	old_document := media.document()?
	url := dom.URL{ value: 'https://adopted-canplaythrough.example.test/' }
	mut document := parse_navigation_document('<body></body>', url, url.origin(), none)!
	document.adopt_node(old_document.get_element_by_id('player')?.as_node())
	media.set_ready_state(.have_enough_data)
	task := canplaythrough_take(media)
	assert voidptr(task.document()?) == voidptr(document)
	mut navigable := document.navigable()?
	navigable.set_active_document(none)
	task.execute()
	assert media.event_count('canplaythrough') == 0 && media.queued_media_task_ids_.len == 0
	navigable.set_active_document(document)
	media.set_ready_state(.have_enough_data)
	assert media.queued_media_task_ids_.len == 0
	media.set_ready_state(.have_future_data)
	media.set_ready_state(.have_enough_data)
	canplaythrough_drain(media)
	assert media.event_count('canplaythrough') == 1
}
