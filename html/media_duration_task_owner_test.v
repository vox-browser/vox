module html

import dom
import math

@[heap]
struct MediaDurationTaskObservation {
mut:
	events []string
	values []f64
	ended  []bool
}

fn media_duration_drain_owner(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_duration_events_wait_for_tasks_and_read_the_live_duration_after_step_one() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	state := &MediaDurationTaskObservation{}
	media.set_on_event('durationchange', &dom.CallbackType{
		handle_event: fn [media, state] (event &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &MediaDurationTaskObservation(state) }
			result.events << event.type_name()
			result.values << media.duration()
			result.ended << media.ended()
			return dom.js_undefined()
		}
	})
	media.set_duration(10)
	media.set_duration(20)
	// The pinned internal setter queues every known value, including repeats.
	media.set_duration(20)
	media.set_current_playback_position(20)
	assert media.duration() == 20 && !media.ended()
	assert state.events == []
	assert media.queued_media_task_ids_.len == 3
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == [] && !media.ended()
	media_duration_drain_owner(media)
	assert state.events == ['durationchange', 'durationchange', 'durationchange']
	assert state.values == [20.0, 20.0, 20.0]
	assert state.ended == [true, true, true]
}

fn test_duration_shrink_queues_duration_before_seek_events_and_exposes_the_new_value() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	media.set_duration(10)
	media_duration_drain_owner(media)
	media.seekable_.add_range(0, 10)
	media.set_current_playback_position(8)
	state := &MediaDurationTaskObservation{}
	for name in ['durationchange', 'seeking', 'timeupdate', 'seeked'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut result := unsafe { &MediaDurationTaskObservation(state) }
				result.events << name
				if name == 'durationchange' {
					assert media.duration() == 3 && media.current_time() == 3
					assert media.seeking() && media.ended()
				}
				return dom.js_undefined()
			}
		})
	}
	media.set_duration(3)
	assert media.duration() == 3 && media.current_time() == 3
	assert media.seeking() && !media.ended()
	assert state.events == []
	media_duration_drain_owner(media)
	assert state.events == ['durationchange', 'seeking', 'timeupdate', 'seeked']
	assert !media.seeking()
}

fn test_duration_nan_reset_and_loading_do_not_deliver_a_canceled_owners_event() {
	mut first := HTMLMediaElement.create(none, dom.url_about_blank())
	mut second := HTMLMediaElement.create(none, dom.url_about_blank())
	first.set_duration(10)
	second.set_duration(5)
	assert first.event_count('durationchange') == 0 && second.event_count('durationchange') == 0
	first.load()!
	assert math.is_nan(first.duration())
	assert first.queued_media_task_ids_.len == 0
	assert second.queued_media_task_ids_.len == 1
	media_duration_drain_owner(second)
	assert first.event_count('durationchange') == 0 && second.event_count('durationchange') == 1
	second.set_duration(math.nan())
	assert second.queued_media_task_ids_.len == 0
	assert second.event_count('durationchange') == 1
}

fn test_duration_task_retains_its_actual_document_and_skips_inactive_delivery() {
	mut document := parse_document('<!doctype html><audio id="player"></audio>')
	window := WindowModel.create_top_level(document, none, 'duration-task-owner')!
	mut media := html_media_element_for_dom_element(document.get_element_by_id('player')?)?
	media.set_duration(2)
	assert media.event_count('durationchange') == 0
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	})?
	assert voidptr(task.document()?) == voidptr(document)
	assert task.source() == media.media_element_event_task_source()
	mut navigable := window.navigable()?
	navigable.set_active_document(none)
	assert !document.is_fully_active()
	task.execute()
	assert media.queued_media_task_ids_.len == 0
	assert media.event_count('durationchange') == 0
}
