module html

import dom
import time

@[heap]
struct PositionObservationClock {
mut:
	position    f64
	step        f64
	reads       int
	range_reads int
	ranges      []MediaBufferedRange
	samples     []f64
	events      []string
	event_times []f64
}

fn position_observation_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing position observation task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('missing position task document') }) == voidptr(media.document() or { panic('missing position owner document') })
	return task
}

fn position_observation_drain(media &HTMLMediaElement) {
	for _ in 0 .. 20 {
		if media.queued_media_task_ids_.len == 0 { return }
		position_observation_take(media).execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn position_observation_owner(kind string) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://position-observation.example.test/' }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing position observation player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing position observation owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/metadata.mp4')
	media.load()!
	position_observation_drain(media)
	assert media.ready_state() == .have_metadata && media.network_state() == .idle
	assert media.last_known_current_playback_position_ == none
	return media
}

fn position_observation_hooks(media &HTMLMediaElement, seen &PositionObservationClock) MediaPlaybackManagerHooks {
	owner_pointer := voidptr(media)
	return MediaPlaybackManagerHooks{
		current_time: fn [owner_pointer, seen] () f64 {
			owner := unsafe { &HTMLMediaElement(owner_pointer) }
			assert owner.playback_manager_ready_ && !owner.seeking()
			mut clock := unsafe { &PositionObservationClock(seen) }
			clock.reads++
			value := clock.position
			clock.samples << value
			clock.position += clock.step
			return value
		}
		buffered_ranges: fn [owner_pointer, seen] () []MediaBufferedRange {
			owner := unsafe { &HTMLMediaElement(owner_pointer) }
			assert owner.playback_manager_ready_
			mut clock := unsafe { &PositionObservationClock(seen) }
			clock.range_reads++
			return clock.ranges.clone()
		}
	}
}

fn position_observation_last(media &HTMLMediaElement) f64 {
	return media.last_known_current_playback_position_ or { panic('missing observed playback position') }
}

fn test_position_observation_uses_live_first_equal_and_changed_samples_without_rewriting_the_scalar() {
	for kind in ['audio', 'video'] {
		mut media := position_observation_owner(kind)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		mut clock := &PositionObservationClock{ position: 2 }
		media.current_playback_position_ = 90
		media.set_playback_manager_hooks(position_observation_hooks(media, clock))
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 1 && position_observation_last(media) == 2
		assert media.current_playback_position_ == 90 && media.queued_media_task_ids_.len == 0
		media.current_playback_position_ = 91
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 2 && position_observation_last(media) == 2
		assert media.current_playback_position_ == 91 && media.queued_media_task_ids_.len == 0
		clock.position = 3
		media.current_playback_position_ = 2
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 3 && position_observation_last(media) == 3
		assert media.current_playback_position_ == 2 && media.queued_media_task_ids_.len == 2
		assert media.event_count('timeupdate') == 0 && media.ready_state() == .have_metadata
		media.remove_queued_media_element_tasks()
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 4 && position_observation_last(media) == 3
		assert media.current_playback_position_ == 2 && media.queued_media_task_ids_.len == 0
		assert clock.samples == [2.0, 2.0, 3.0, 3.0]
	}
}

fn test_position_observation_samples_once_after_both_guards_and_stores_that_single_sample() {
	for kind in ['audio', 'video'] {
		mut media := position_observation_owner(kind)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		clock := &PositionObservationClock{ position: 4, step: 1 }
		media.current_playback_position_ = 77
		media.set_playback_manager_hooks(position_observation_hooks(media, clock))
		media.playback_manager_ready_ = false
		media.upon_current_playback_position_possibly_changed()
		media.playback_manager_ready_ = true
		media.set_seeking(true)
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 0 && media.last_known_current_playback_position_ == none
		assert media.queued_media_task_ids_.len == 0
		media.set_seeking(false)
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 1 && clock.position == 5 && position_observation_last(media) == 4
		assert media.queued_media_task_ids_.len == 0
		media.playback_manager_ready_ = false
		media.upon_current_playback_position_possibly_changed()
		media.playback_manager_ready_ = true
		media.set_seeking(true)
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 1 && position_observation_last(media) == 4
		media.set_seeking(false)
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 2 && clock.position == 6 && position_observation_last(media) == 5
		assert clock.samples == [4.0, 5.0] && media.current_playback_position_ == 77
		assert media.queued_media_task_ids_.len == 2
	}
}

fn test_changed_live_positions_queue_owned_timeupdate_then_monitor_delivery_facts_even_when_throttled() {
	for kind in ['audio', 'video'] {
		mut media := position_observation_owner(kind)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		mut clock := &PositionObservationClock{ ranges: [MediaBufferedRange{0, 1}] }
		media.set_playback_manager_hooks(position_observation_hooks(media, clock))
		media.playback_has_future_data_ = true
		owner_pointer := voidptr(media)
		media.set_on_event('timeupdate', &dom.CallbackType{
			handle_event: fn [owner_pointer, clock] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				owner := unsafe { &HTMLMediaElement(owner_pointer) }
				mut observation := unsafe { &PositionObservationClock(clock) }
				observation.events << 'timeupdate'
				observation.event_times << owner.current_playback_position()
				assert owner.ready_state() == .have_metadata
				assert voidptr(event.target() or { panic('missing position event target') }) == voidptr(owner.event_target())
				assert voidptr(current or { panic('missing position current target') }) == voidptr(owner.event_target())
				assert event.is_trusted() && !event.bubbles() && !event.cancelable()
				observation.position = 9
				observation.ranges = [MediaBufferedRange{9, 20}]
				return dom.js_undefined()
			}
		})
		media.upon_current_playback_position_possibly_changed()
		clock.position = 0.1
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 2 && clock.range_reads == 0 && media.queued_media_task_ids_.len == 2
		assert media.ready_state() == .have_metadata && media.event_count('timeupdate') == 0
		clock.position = 8
		clock.ranges = [MediaBufferedRange{8, 10}]
		position_observation_take(media).execute()
		assert clock.events == ['timeupdate'] && clock.event_times == [8.0]
		assert media.ready_state() == .have_metadata && clock.range_reads == 0
		position_observation_take(media).execute()
		assert media.ready_state() == .have_enough_data && clock.range_reads == 1
		assert position_observation_last(media) == 0.1 && media.queued_media_task_ids_.len == 3
		position_observation_drain(media)
		assert media.event_count('loadeddata') == 1 && media.event_count('canplaythrough') == 1
		// Reserve a later wall-clock slot so the throttle check needs no sleep.
		media.last_time_update_event_time_ = time.sys_mono_now() + 60_000_000_000
		clock.position = 10
		media.upon_current_playback_position_possibly_changed()
		assert position_observation_last(media) == 10 && media.queued_media_task_ids_.len == 1
		assert media.ready_state() == .have_enough_data && media.event_count('timeupdate') == 1
		clock.position = 12
		clock.ranges.clear()
		media.playback_has_future_data_ = false
		position_observation_take(media).execute()
		assert media.ready_state() == .have_metadata && clock.range_reads == 2
		assert position_observation_last(media) == 10 && media.event_count('timeupdate') == 1
		assert media.queued_media_task_ids_.len == 0
	}
}

fn test_position_observation_preserves_same_turn_official_time_and_the_no_hook_setter_fallback() {
	for kind in ['audio', 'video'] {
		mut media := position_observation_owner(kind)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		mut clock := &PositionObservationClock{ position: 2 }
		media.current_playback_position_ = 40
		media.set_playback_manager_hooks(position_observation_hooks(media, clock))
		mut loop := main_thread_event_loop()
		loop.process()
		assert media.current_time() == 2 && clock.reads == 1
		generation := loop.task_generation()
		media.upon_current_playback_position_possibly_changed()
		clock.position = 3
		media.upon_current_playback_position_possibly_changed()
		assert clock.reads == 3 && position_observation_last(media) == 3
		assert media.current_playback_position_ == 40 && media.queued_media_task_ids_.len == 2
		assert media.current_time() == 2 && clock.reads == 3
		loop.perform_a_microtask_checkpoint()
		assert media.current_time() == 2 && clock.reads == 3 && loop.task_generation() == generation
		assert media.official_playback_position_ == 2 && media.official_playback_position_task_generation_ == generation
		media.remove_queued_media_element_tasks()
		mut fallback := position_observation_owner(kind)!
		defer {
			fallback.remove_queued_media_element_tasks()
			fallback.finish_delaying_load_event()
			fallback.finalize()
		}
		fallback.set_official_playback_position(5)
		fallback.set_current_playback_position(5)
		assert position_observation_last(fallback) == 5 && fallback.queued_media_task_ids_.len == 0
		fallback.set_current_playback_position(6)
		assert position_observation_last(fallback) == 6 && fallback.current_playback_position_ == 6
		assert fallback.current_time() == 5 && fallback.queued_media_task_ids_.len == 2
		fallback.remove_queued_media_element_tasks()
	}
}
