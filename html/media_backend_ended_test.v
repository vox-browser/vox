module html

import dom

@[heap]
struct BackendEndedProbe {
mut:
	ended bool
	seeks int
}

fn backend_ended_drain(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { break }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
	loop.process()
}

fn test_backend_completion_state_overrides_a_terminal_clock_and_refreshes_at_step_one() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	media.set_duration(10)
	mut state := &BackendEndedProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		has_ended: fn [state] () bool { return state.ended }
	})
	media.set_current_playback_position(10)
	backend_ended_drain(media)
	assert !media.has_ended_playback() && !media.ended()
	state.ended = true
	media.reached_end_of_media_playback()
	assert media.has_ended_playback() && !media.ended()
	backend_ended_drain(media)
	assert media.ended() && media.event_count('ended') == 1
	state.ended = false
	media.upon_has_ended_playback_possibly_changed()
	assert !media.has_ended_playback() && media.ended()
	backend_ended_drain(media)
	assert !media.ended() && media.current_playback_position_ == 10
}

fn test_replay_does_not_queue_another_end_while_the_backend_seek_keeps_the_old_clock() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.network_state_ = .idle
	media.set_ready_state(.have_enough_data)
	media.set_duration(10)
	media.seekable_.add_range(0, 10)
	state := &BackendEndedProbe{ ended: true }
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn () f64 { return 10 }
		has_ended: fn [state] () bool { return state.ended }
		seek: fn [state] (target f64, _ MediaPlaybackSeekMode) {
			assert target == 0
			mut backend := unsafe { &BackendEndedProbe(state) }
			backend.ended = false
			backend.seeks++
		}
	})
	media.set_current_playback_position(10)
	backend_ended_drain(media)
	assert media.ended() && media.paused()
	media.play_element()
	assert state.seeks == 1 && media.seeking() && !media.paused()
	backend_ended_drain(media)
	assert !media.ended() && !media.paused()
	assert media.event_count('ended') == 0 && media.event_count('pause') == 0
	assert media.official_playback_position_ == 10
}
