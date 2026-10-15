module html

import css
import dom

@[heap]
struct ReadyNetworkGateObservation {
mut:
	calls  int
	events []string
}

fn ready_network_gate_owner(kind string, loaded bool) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://ready-network-gate.example.test/' }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing readiness gate player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing readiness gate owner') }
	if loaded {
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
		})
		media.set_source('/metadata.mp4')
		media.load()!
		ready_network_gate_drain(media)
		assert media.ready_state() == .have_metadata && media.network_state() == .idle
	}
	return media
}

fn ready_network_gate_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing readiness gate task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('missing readiness gate task document') }) == voidptr(media.document() or { panic('missing readiness gate owner document') })
	return task
}

fn ready_network_gate_drain(media &HTMLMediaElement) {
	for _ in 0 .. 20 {
		if media.queued_media_task_ids_.len == 0 { return }
		ready_network_gate_take(media).execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_empty_network_readiness_drops_refresh_style_and_ended_without_media_events_or_tasks() {
	for kind in ['audio', 'video'] {
		for index, next in [MediaReadyState.have_current_data, .have_metadata, .have_nothing] {
			mut media := ready_network_gate_owner(kind, false)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			document := media.document()?
			css.css_style_computer_for(document)
			element := document.get_element_by_id('player')?
			mut node := element.as_node()
			media.ready_state_ = if index == 0 { MediaReadyState.have_future_data } else { MediaReadyState.have_enough_data }
			media.duration_ = 1
			media.current_playback_position_ = 1
			media.set_ended(next == .have_nothing)
			media.set_paused(false)
			assert css.element_matches_selector(element, ':playing:not(:buffering)')
			node.set_needs_style_update(false)
			mut loop := main_thread_event_loop()
			pending := loop.reached_step_1_tasks.len
			media.set_ready_state(next)
			assert media.ready_state() == next && media.network_state() == .empty
			assert node.needs_style_update() && css.element_matches_selector(element, ':playing:buffering')
			assert loop.reached_step_1_tasks.len == pending + 1
			assert media.ended() == (next == .have_nothing)
			assert media.queued_media_task_ids_.len == 0
			for name in ['waiting', 'timeupdate', 'loadedmetadata', 'loadeddata', 'canplay', 'canplaythrough', 'play', 'playing'] {
				assert media.event_count(name) == 0
			}
			loop.process()
			assert media.ended() == (next != .have_nothing)
			assert media.queued_media_task_ids_.len == 0 && media.event_count('waiting') == 0
		}
	}
}

fn test_nonempty_readiness_drops_retain_the_waiting_adapter_and_queued_readiness_notifications() {
	for kind in ['audio', 'video'] {
		for network in [MediaNetworkState.idle, .loading, .no_source] {
			mut media := ready_network_gate_owner(kind, false)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			media.network_state_ = network
			media.ready_state_ = .have_future_data
			media.set_paused(false)
			seen := &ReadyNetworkGateObservation{}
			for name in ['waiting', 'canplay', 'canplaythrough'] {
				media.set_on_event(name, &dom.CallbackType{
					handle_event: fn [name, network, media, seen] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
						mut observation := unsafe { &ReadyNetworkGateObservation(seen) }
						observation.events << name
						assert media.network_state() == network
						assert media.ready_state() == if name == 'waiting' { MediaReadyState.have_current_data } else { MediaReadyState.have_enough_data }
						assert voidptr(event.target() or { panic('missing gate event target') }) == voidptr(media.event_target())
						assert voidptr(current or { panic('missing gate current target') }) == voidptr(media.event_target())
						assert event.is_trusted() && !event.bubbles() && !event.cancelable()
						return dom.js_undefined()
					}
				})
			}
			media.set_ready_state(.have_current_data)
			assert seen.events == ['waiting'] && media.event_count('waiting') == 1
			assert media.queued_media_task_ids_.len == 0
			media.set_paused(true)
			media.set_ready_state(.have_future_data)
			media.set_ready_state(.have_enough_data)
			assert seen.events == ['waiting'] && media.queued_media_task_ids_.len == 2
			ready_network_gate_drain(media)
			assert seen.events == ['waiting', 'canplay', 'canplaythrough']
			assert media.event_count('loadeddata') == 0 && media.event_count('waiting') == 1
		}
	}
}

fn test_empty_network_does_not_consume_first_data_or_release_its_document_load_blocker() {
	for kind in ['audio', 'video'] {
		mut media := ready_network_gate_owner(kind, true)!
		mut document := media.document()?
		mut independent := dom.DocumentLoadEventDelayer.new(mut document)
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			independent.finish()
			media.finalize()
		}
		assert media.first_data_load_event_since_load_start_
		media.begin_delaying_load_event()
		media.network_state_ = .empty
		media.set_ready_state(.have_current_data)
		media.set_ready_state(.have_enough_data)
		assert media.first_data_load_event_since_load_start_ && media.delaying_load_event_ != none
		assert document.anything_is_delaying_the_load_event() && media.queued_media_task_ids_.len == 0
		assert media.event_count('loadeddata') == 0 && media.event_count('canplaythrough') == 0
		media.network_state_ = .idle
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_current_data)
		assert !media.first_data_load_event_since_load_start_ && media.delaying_load_event_ == none
		assert document.anything_is_delaying_the_load_event() && media.queued_media_task_ids_.len == 1
		assert media.event_count('loadeddata') == 0
		ready_network_gate_take(media).execute()
		assert media.event_count('loadeddata') == 1 && media.queued_media_task_ids_.len == 0
		media.begin_delaying_load_event()
		media.set_ready_state(.have_metadata)
		media.set_ready_state(.have_current_data)
		assert media.delaying_load_event_ == none && media.queued_media_task_ids_.len == 0
		assert media.event_count('loadeddata') == 1 && document.anything_is_delaying_the_load_event()
		independent.finish()
		assert !document.anything_is_delaying_the_load_event()
	}
}

fn test_empty_readiness_guard_blocks_waiting_listener_reentry_and_equal_state_side_effects() {
	for kind in ['audio', 'video'] {
		mut media := ready_network_gate_owner(kind, false)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		document := media.document()?
		css.css_style_computer_for(document)
		mut node := document.get_element_by_id('player')?.as_node()
		media.ready_state_ = .have_future_data
		media.set_paused(false)
		seen := &ReadyNetworkGateObservation{}
		media.set_on_event('waiting', &dom.CallbackType{
			handle_event: fn [media, seen] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut observation := unsafe { &ReadyNetworkGateObservation(seen) }
				observation.calls++
				mut owner := unsafe { &HTMLMediaElement(media) }
				owner.set_source(none)
				owner.load() or { panic(err) }
				owner.pause()
				return dom.js_undefined()
			}
		})
		generation := media.fetch_generation_
		media.set_ready_state(.have_current_data)
		assert seen.calls == 0 && media.ready_state() == .have_current_data && !media.paused()
		assert media.fetch_generation_ == generation && media.can_autoplay_ && media.queued_media_task_ids_.len == 0
		node.set_needs_style_update(false)
		mut loop := main_thread_event_loop()
		pending := loop.reached_step_1_tasks.len
		media.set_ready_state(.have_current_data)
		assert !node.needs_style_update() && loop.reached_step_1_tasks.len == pending
		media.set_ready_state(.have_future_data)
		media.set_ready_state(.have_current_data)
		assert seen.calls == 0 && media.event_count('waiting') == 0
		assert media.ready_state() == .have_current_data && !media.paused() && media.can_autoplay_
		assert media.fetch_generation_ == generation && media.queued_media_task_ids_.len == 0
	}
}
