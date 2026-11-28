module html

import dom

@[heap]
struct MediaEndObservation {
mut:
	events []string
	states []bool
}

fn media_end_test_model() &HTMLMediaElement {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_up_playback_manager()
	media.set_ready_state(.have_metadata)
	media.set_duration(10)
	media_end_drain_owner(media)
	media.set_current_playback_position(10)
	media.set_paused(false)
	return media
}

fn media_end_drain_owner(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_end_task_observes_cached_ended_and_orders_pause_promise_and_events() {
	mut media := media_end_test_model()
	mut promise := dom.Promise.create()
	media.pending_play_promises_ << promise
	state := &MediaEndObservation{}
	for name in ['timeupdate', 'pause', 'ended'] {
		media.set_on_event(name, &dom.CallbackType{
			handle_event: fn [name, media, promise, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
				mut result := unsafe { &MediaEndObservation(state) }
				result.events << name
				result.states << media.ended()
				result.states << (media.paused() == (name != 'timeupdate'))
				result.states << (promise.state() == if name == 'ended' {
					dom.PromiseState.rejected
				} else {
					dom.PromiseState.pending
				})
				return dom.js_undefined()
			}
		})
	}
	media.reached_end_of_media_playback()
	assert state.events == []
	assert !media.paused() && !media.ended()
	assert promise.state() == .pending
	assert media.queued_media_task_ids_.len == 3
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.events == []
	media_end_drain_owner(media)
	assert state.events == ['timeupdate', 'pause', 'ended']
	assert state.states == [true, true, true, true, true, true, true, true, true]
	assert media.paused() && media.ended()
	assert promise.state() == .rejected
	assert media.pending_play_promises_.len == 0
}

fn test_media_end_task_rechecks_live_position_after_timeupdate_callback() {
	mut media := media_end_test_model()
	promise := dom.Promise.create()
	media.pending_play_promises_ << promise
	state := &MediaEndObservation{}
	media.set_on_event('timeupdate', &dom.CallbackType{
		handle_event: fn [media, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut owner := unsafe { &HTMLMediaElement(media) }
			owner.set_current_playback_position(4)
			mut result := unsafe { &MediaEndObservation(state) }
			result.events << 'timeupdate'
			return dom.js_undefined()
		}
	})
	media.reached_end_of_media_playback()
	assert state.events == []
	media_end_drain_owner(media)
	assert state.events == ['timeupdate']
	assert media.current_time() == 4
	assert !media.paused()
	assert media.event_count('pause') == 0 && media.event_count('ended') == 1
	assert promise.state() == .pending
	assert !media.ended()
}

fn test_loading_cancels_only_the_owning_completion_task_and_loop_queues_no_completion() {
	mut first := media_end_test_model()
	mut second := media_end_test_model()
	first.reached_end_of_media_playback()
	second.reached_end_of_media_playback()
	assert first.event_count('ended') == 0 && second.event_count('ended') == 0
	first.load()!
	assert first.queued_media_task_ids_.len == 0
	assert second.queued_media_task_ids_.len == 3
	media_end_drain_owner(second)
	assert first.event_count('ended') == 0
	assert second.event_count('ended') == 1
	mut looping := media_end_test_model()
	looping.set_loop(true)
	looping.set_paused(true)
	looping.seekable_.add_range(0, 10)
	looping.reached_end_of_media_playback()
	assert looping.current_time() == 0 && looping.seeking() && looping.paused()
	media_end_drain_owner(looping)
	assert !looping.seeking() && looping.event_count('ended') == 0
}

fn test_dom_completion_task_uses_the_owning_document_and_discards_inactive_delivery() {
	mut document := parse_document('<!doctype html><video id="player"></video>')
	mut window := WindowModel.create_top_level(document, none, 'media-end-owner')!
	element := document.get_element_by_id('player')?
	mut media := html_media_element_for_dom_element(element)?
	media.set_up_playback_manager()
	media.set_ready_state(.have_metadata)
	media.set_duration(1)
	media_end_drain_owner(media)
	media.set_current_playback_position(1)
	media.set_paused(false)
	media.reached_end_of_media_playback()
	assert media.event_count('ended') == 0
	mut queue := main_thread_event_loop().task_queue()
	mut tasks := []&Task{}
	for _ in 0 .. 3 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		})?
		assert voidptr(task.document()?) == voidptr(document)
		assert task.source() == media.media_element_event_task_source()
		tasks << task
	}
	mut navigable := window.navigable()?
	navigable.set_active_document(none)
	assert !document.is_fully_active()
	for task in tasks {
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
	assert media.event_count('timeupdate') == 0 && media.event_count('ended') == 0
}

fn test_load_from_timeupdate_cancels_the_remaining_end_events() {
	mut media := media_end_test_model()
	media.set_on_event('timeupdate', &dom.CallbackType{
		handle_event: fn [media] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut owner := unsafe { &HTMLMediaElement(media) }
			owner.set_on_event('timeupdate', none)
			owner.load() or { panic(err) }
			return dom.js_undefined()
		}
	})
	media.reached_end_of_media_playback()
	media_end_drain_owner(media)
	assert media.event_count('timeupdate') >= 1
	assert media.event_count('pause') == 0 && media.event_count('ended') == 0
}

fn test_seek_reports_the_requested_time_until_the_task_boundary() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_up_playback_manager()
	media.set_ready_state(.have_metadata)
	media.set_duration(8)
	media.seekable_.add_range(0, 8)
	media.set_current_time(10)
	assert media.seeking()
	assert media.current_time() == 10 && media.current_playback_position() == 8
	media_end_drain_owner(media)
	assert !media.seeking() && media.current_time() == 8
}
