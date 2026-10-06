module html

import dom
import math

@[heap]
struct MediaRateTaskObservation {
mut:
	defaults []f64
	rates    []f64
	depth    int
	depths   []int
}

fn media_rate_drain_owner(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_default_rate_changes_wait_for_tasks_and_observe_live_values() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	state := &MediaRateTaskObservation{}
	media.set_on_event('ratechange', &dom.CallbackType{
		handle_event: fn [media, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &MediaRateTaskObservation(state) }
			result.defaults << media.default_playback_rate()
			result.rates << media.playback_rate()
			return dom.js_undefined()
		}
	})
	media.set_default_playback_rate(2)
	media.set_default_playback_rate(2)
	media.set_default_playback_rate(3)
	assert media.default_playback_rate() == 3 && media.playback_rate() == 1
	assert state.defaults == [] && media.queued_media_task_ids_.len == 2
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.defaults == []
	media_rate_drain_owner(media)
	assert state.defaults == [3.0, 3.0] && state.rates == [1.0, 1.0]
}

fn test_playback_rate_accepts_source_bounds_and_rejects_without_mutation_or_tasks() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	for rate in [0.0, 0.5, 2.0, 64.0] {
		media.set_playback_rate(rate)!
		assert media.playback_rate() == rate
	}
	assert media.event_count('ratechange') == 0
	assert media.queued_media_task_ids_.len == 4
	media.set_playback_rate(64)!
	assert media.queued_media_task_ids_.len == 4
	for rate in [-0.01, 64.01, math.inf(1), math.inf(-1), math.nan()] {
		mut rejected := false
		media.set_playback_rate(rate) or {
			rejected = true
			assert err.msg().starts_with('NotSupportedError:')
		}
		assert rejected && media.playback_rate() == 64
		assert media.queued_media_task_ids_.len == 4
	}
	media_rate_drain_owner(media)
	assert media.event_count('ratechange') == 4
}

fn test_equal_signed_zero_rates_update_the_field_without_an_extra_event() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_default_playback_rate(0)
	media.set_default_playback_rate(-0.0)
	assert math.signbit(media.default_playback_rate())
	assert media.queued_media_task_ids_.len == 1
	media.set_playback_rate(-0.0)!
	assert math.signbit(media.playback_rate())
	media.set_playback_rate(0)!
	assert !math.signbit(media.playback_rate())
	assert media.queued_media_task_ids_.len == 2
	media_rate_drain_owner(media)
	assert media.event_count('ratechange') == 2
}

fn test_accepted_rates_drive_the_existing_playback_clock_compatibility_path() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_duration(100)
	media.set_ready_state(.have_enough_data)
	media_rate_drain_owner(media)
	media.set_paused(false)
	media.set_playback_rate(0.5)!
	media.advance_playback(2)
	assert media.current_time() == 1
	media.set_playback_rate(2)!
	media.advance_playback(2)
	assert media.current_time() == 5
	media.set_playback_rate(0)!
	media.advance_playback(20)
	assert media.current_time() == 5 && !media.paused()
	media_rate_drain_owner(media)
}

fn test_rate_listener_changes_queue_a_separate_nonrecursive_task() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	state := &MediaRateTaskObservation{}
	media.set_on_event('ratechange', &dom.CallbackType{
		handle_event: fn [media, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &MediaRateTaskObservation(state) }
			result.depth++
			result.depths << result.depth
			result.defaults << media.default_playback_rate()
			if media.default_playback_rate() == 2 {
				mut owner := unsafe { &HTMLMediaElement(media) }
				owner.set_default_playback_rate(4)
				assert media.event_count('ratechange') == 1
			}
			result.depth--
			return dom.js_undefined()
		}
	})
	media.set_default_playback_rate(2)
	assert state.defaults == []
	media_rate_drain_owner(media)
	assert state.defaults == [2.0, 4.0] && state.depths == [1, 1]
}

fn test_rate_task_carries_the_real_document_and_guards_inactive_delivery() {
	document := parse_navigation_document('<audio id="player"></audio>', dom.url_about_blank(),
		dom.url_about_blank().origin(), none)!
	mut media := html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_default_playback_rate(2)
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	})?
	assert voidptr(task.document()?) == voidptr(document)
	assert task.source() == media.media_element_event_task_source()
	mut navigable := document.cached_navigable()?
	navigable.set_active_document(none)
	assert !document.is_fully_active()
	task.execute()
	assert media.event_count('ratechange') == 0 && media.queued_media_task_ids_.len == 0
}
