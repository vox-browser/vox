module html

import dom
import math

@[heap]
struct MediaEndedBoundaryObservation {
mut:
	values []bool
}

fn test_media_ended_cache_changes_after_microtasks_and_before_the_next_task() {
	mut loop := main_thread_event_loop()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_up_playback_manager()
	media.set_ready_state(.have_metadata)
	media.set_duration(10)
	loop.process()
	assert !media.ended()
	media.set_current_playback_position(10)
	assert media.has_ended_playback()
	assert !media.ended()
	state := &MediaEndedBoundaryObservation{}
	queue_a_microtask(none, fn [state, media] () {
		mut result := unsafe { &MediaEndedBoundaryObservation(state) }
		result.values << media.ended()
	})
	loop.perform_a_microtask_checkpoint()
	assert state.values == [false]
	assert !media.ended()
	queue_a_task(.dom_manipulation, loop, none, fn [state, media] () {
		mut result := unsafe { &MediaEndedBoundaryObservation(state) }
		result.values << media.ended()
	})
	loop.process()
	assert state.values == [false, true]
	assert media.ended()
	media.set_current_playback_position(3)
	assert !media.has_ended_playback()
	assert media.ended()
	loop.process()
	assert !media.ended()
}

fn test_ready_state_changes_refresh_the_ended_cache_at_step_one() {
	mut loop := main_thread_event_loop()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_up_playback_manager()
	media.set_duration(1)
	media.set_current_playback_position(1)
	loop.process()
	assert !media.ended()
	media.set_ready_state(.have_metadata)
	assert media.has_ended_playback()
	assert !media.ended()
	loop.process()
	assert media.ended()
	media.set_ready_state(.have_nothing)
	assert !media.has_ended_playback()
	assert media.ended()
	loop.process()
	assert !media.ended()
	pending := loop.reached_step_1_tasks.len
	media.set_ready_state(.have_nothing)
	assert loop.reached_step_1_tasks.len == pending
}

fn test_ended_uses_live_loop_state_and_replay_starts_at_zero() {
	mut loop := main_thread_event_loop()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_up_playback_manager()
	media.set_ready_state(.have_enough_data)
	media.set_duration(10)
	media.seekable_.add_range(0, 10)
	loop.process()
	media.set_current_playback_position(10)
	loop.process()
	assert media.ended()
	media.set_loop(true)
	assert !media.ended() && !media.has_ended_playback()
	media.set_loop(false)
	assert media.ended() && media.has_ended_playback()
	media.set_loop(true)
	media.network_state_ = .idle
	media.play_element()
	assert !media.paused() && media.seeking()
	assert media.current_time() == 0 && !media.ended()
	media.remove_queued_media_element_tasks()
	loop.process()
}

fn test_pending_ended_checks_use_live_owners_after_reload_and_duration_changes() {
	mut loop := main_thread_event_loop()
	mut first := HTMLMediaElement.create(none, dom.url_about_blank())
	first.set_up_playback_manager()
	mut second := HTMLMediaElement.create(none, dom.url_about_blank())
	second.set_up_playback_manager()
	first.set_ready_state(.have_metadata)
	first.set_duration(10)
	first.set_current_playback_position(10)
	second.set_ready_state(.have_metadata)
	second.set_duration(5)
	second.set_current_playback_position(5)
	first.load()!
	assert !first.ended()
	assert !second.ended()
	loop.process()
	assert !first.ended()
	assert second.ended()
	second.set_duration(math.inf(1))
	assert second.ended()
	loop.process()
	assert !second.ended()
}
