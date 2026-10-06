module html

import dom

@[heap]
struct MediaPositionClockObservation {
mut:
	position f64
	reads    int
	values   []f64
}

fn media_position_clock_hooks(state &MediaPositionClockObservation) MediaPlaybackManagerHooks {
	return MediaPlaybackManagerHooks{
		current_time: fn [state] () f64 {
			mut clock := unsafe { &MediaPositionClockObservation(state) }
			clock.reads++
			return clock.position
		}
	}
}

fn test_nonzero_default_start_precedes_readiness_and_does_not_sample_the_clock() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	mut state := &MediaPositionClockObservation{
		position: 9
	}
	media.set_playback_manager_hooks(media_position_clock_hooks(state))
	media.set_current_time(-2)
	assert media.current_time() == -2
	media.set_ready_state(.have_metadata)
	assert media.current_time() == -2 && state.reads == 0
	loop.process()
	assert media.current_time() == -2 && state.reads == 0
}

fn test_zero_default_start_reads_the_official_position_even_without_metadata() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	mut state := &MediaPositionClockObservation{
		position: 3
	}
	media.set_playback_manager_hooks(media_position_clock_hooks(state))
	media.set_current_time(-0.0)
	assert media.ready_state() == .have_nothing
	assert media.current_time() == 3 && state.reads == 1
}

fn test_official_position_samples_once_per_actual_generation_and_survives_microtasks() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	mut state := &MediaPositionClockObservation{
		position: 2
	}
	media.set_playback_manager_hooks(media_position_clock_hooks(state))
	assert media.current_time() == 2 && state.reads == 1
	state.position = 3
	assert media.current_time() == 2 && state.reads == 1
	queue_a_microtask(none, fn [state, media] () {
		mut clock := unsafe { &MediaPositionClockObservation(state) }
		clock.values << media.current_time()
	})
	generation := loop.task_generation()
	loop.perform_a_microtask_checkpoint()
	assert state.values == [2.0] && state.reads == 1
	assert loop.task_generation() == generation
	loop.process()
	assert loop.task_generation() == generation + 1
	assert media.current_time() == 3 && state.reads == 2
	assert media.current_time() == 3 && state.reads == 2
}

fn test_position_notifications_and_compatibility_clock_do_not_overwrite_a_same_turn_sample() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_enough_data)
	media.set_paused(false)
	media.set_current_playback_position(2)
	assert media.current_time() == 2
	media.set_current_playback_position(3)
	media.advance_playback(1)
	assert media.current_time() == 2
	loop.process()
	assert media.current_time() == 4
}

fn test_seek_commits_the_post_request_clock_sample_and_stamps_its_generation() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	media.seekable_.add_range(0, 10)
	mut state := &MediaPositionClockObservation{
		position: 2
	}
	base_hooks := media_position_clock_hooks(state)
	hooks := MediaPlaybackManagerHooks{
		...base_hooks
		seek: fn [state] (requested f64, _ MediaPlaybackSeekMode) {
			assert requested == 7
			mut clock := unsafe { &MediaPositionClockObservation(state) }
			clock.position = 4
		}
	}
	media.set_playback_manager_hooks(hooks)
	assert media.current_time() == 2 && state.reads == 1
	media.seek_element(7, .accurate)
	assert media.seeking() && media.current_time() == 4 && state.reads == 2
	state.position = 8
	assert media.current_time() == 4 && state.reads == 2
	loop.process()
	assert media.current_time() == 8 && state.reads == 3
	media.remove_queued_media_element_tasks()
}

fn test_pause_while_seeking_explicitly_commits_the_current_clock_sample() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	media.seekable_.add_range(0, 10)
	media.set_paused(false)
	mut state := &MediaPositionClockObservation{
		position: 2
	}
	base_hooks := media_position_clock_hooks(state)
	hooks := MediaPlaybackManagerHooks{
		...base_hooks
		seek: fn (_ f64, _ MediaPlaybackSeekMode) {}
	}
	media.set_playback_manager_hooks(hooks)
	media.seek_element(7, .accurate)
	state.position = 8
	media.pause()
	assert media.paused() && media.seeking()
	assert media.current_time() == 8
	state.position = 9
	assert media.current_time() == 8
	loop.process()
	assert media.current_time() == 9
	media.remove_queued_media_element_tasks()
}

fn test_metadata_and_load_reset_commit_zero_without_an_immediate_clock_resample() {
	mut loop := main_thread_event_loop()
	loop.process()
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	mut state := &MediaPositionClockObservation{
		position: 7
	}
	media.set_playback_manager_hooks(media_position_clock_hooks(state))
	media.on_metadata_parsed(10)
	metadata_reads := state.reads
	assert media.current_time() == 0 && state.reads == metadata_reads
	loop.process()
	assert media.current_time() == 7 && state.reads == metadata_reads + 1
	media.load()!
	assert media.current_time() == 0 && state.reads == metadata_reads + 1
	loop.process()
	assert media.current_time() == 7 && state.reads == metadata_reads + 2
	media.remove_queued_media_element_tasks()
}

fn test_dom_media_owners_keep_separate_official_samples_on_the_real_main_loop() {
	address := dom.URL{
		value: 'https://media-position-owner.example.test/'
	}
	document := parse_navigation_document('<video id="first"></video><audio id="second"></audio>',
		address, address.origin(), none)!
	mut first := html_media_element_for_dom_element(document.get_element_by_id('first')?)?
	mut second := html_media_element_for_dom_element(document.get_element_by_id('second')?)?
	mut first_state := &MediaPositionClockObservation{
		position: 3
	}
	mut second_state := &MediaPositionClockObservation{
		position: 9
	}
	first.set_playback_manager_hooks(media_position_clock_hooks(first_state))
	second.set_playback_manager_hooks(media_position_clock_hooks(second_state))
	mut loop := main_thread_event_loop()
	loop.process()
	assert first.current_time() == 3 && second.current_time() == 9
	first_state.position = 4
	second_state.position = 10
	assert first.current_time() == 3 && second.current_time() == 9
	assert first_state.reads == 1 && second_state.reads == 1
	loop.process()
	assert first.current_time() == 4 && second.current_time() == 10
	assert first_state.reads == 2 && second_state.reads == 2
	assert first.document()? == document && second.document()? == document
}
