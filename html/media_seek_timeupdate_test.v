module html

import dom
import time

fn media_timing_take_task(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	return queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('expected runnable media task') }
}

fn media_timing_drain_setup_tasks(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_seek_without_seekable_ranges_does_not_change_position_or_queue_events() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	media.set_duration(10)
	media_timing_drain_setup_tasks(media)
	media.set_current_playback_position(2)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		seek: fn (_ f64, _ MediaPlaybackSeekMode) {
			panic('empty range reached decoder seek')
		}
	})
	media.seek_element(7, .accurate)
	assert !media.seeking()
	assert !media.show_poster()
	assert media.current_time() == 2
	assert media.current_playback_position_ == 2
	assert media.event_count('seeking') == 0
	assert media.event_count('seeked') == 0
	assert media.event_count('timeupdate') == 0
	assert media.queued_media_task_ids_.len == 0
}

fn test_seek_completion_runs_after_seeking_and_queues_timeupdate_before_seeked() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_ready_state(.have_metadata)
	media.set_duration(10)
	media_timing_drain_setup_tasks(media)
	media.seekable_.add_range(0, 10)
	media.seek_element(7, .accurate)
	assert media.seeking()
	assert media.current_time() == 7
	assert media.event_count('seeking') == 0
	media_timing_take_task(media).execute()
	assert media.seeking()
	assert media.event_count('seeking') == 1
	media_timing_take_task(media).execute()
	assert !media.seeking()
	assert media.event_count('timeupdate') == 0
	assert media.event_count('seeked') == 0
	media_timing_take_task(media).execute()
	assert media.event_count('timeupdate') == 1
	assert media.event_count('seeked') == 0
	media_timing_take_task(media).execute()
	assert media.event_count('seeked') == 1
	assert media.queued_media_task_ids_.len == 0
}

fn test_timeupdate_uses_elapsed_wall_time_and_reserves_interval_when_queued() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	now := time.sys_mono_now()
	media.time_marches_on_at(.normal_playback, now)
	assert media.event_count('timeupdate') == 0
	assert media.queued_media_task_ids_.len == 1
	for index in 0 .. 100 {
		media.current_playback_position_ = f64(index * 10)
		media.time_marches_on_at(.normal_playback, now + 1_000_000)
	}
	assert media.queued_media_task_ids_.len == 1
	media_timing_take_task(media).execute()
	assert media.event_count('timeupdate') == 1
	last_event := media.last_time_update_event_time_?
	media.time_marches_on_at(.normal_playback, last_event + 250_000_000)
	assert media.queued_media_task_ids_.len == 0
	// An unchanged media timestamp still permits an event after wall time elapses.
	media.time_marches_on_at(.normal_playback, last_event + 250_000_001)
	assert media.queued_media_task_ids_.len == 1
	media_timing_take_task(media).execute()
	assert media.event_count('timeupdate') == 2
	media.running_time_update_event_ = true
	media.time_marches_on_at(.normal_playback, last_event + 1_000_000_000)
	assert media.queued_media_task_ids_.len == 0
	media.running_time_update_event_ = false
	media.time_marches_on_at(.other, last_event + 1_000_000_000)
	assert media.queued_media_task_ids_.len == 0
}

fn test_loading_cancels_only_the_owning_media_elements_pending_tasks() {
	mut first := HTMLMediaElement.create(none, dom.url_about_blank())
	mut second := HTMLMediaElement.create(none, dom.url_about_blank())
	first.time_marches_on(.normal_playback)
	second.time_marches_on(.normal_playback)
	first.load()!
	assert first.queued_media_task_ids_.len == 0
	assert second.queued_media_task_ids_.len == 1
	media_timing_take_task(second).execute()
	assert first.event_count('timeupdate') == 0
	assert second.event_count('timeupdate') == 1
}

fn test_playback_position_changes_queue_buffer_monitoring_between_timeupdates() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_up_playback_manager()
	media.set_ready_state(.have_metadata)
	media.set_duration(20)
	media_timing_drain_setup_tasks(media)
	media.buffered_.add_range(0, 1)
	media.playback_has_future_data_ = true
	media.set_current_playback_position(0)
	assert media.queued_media_task_ids_.len == 0
	media.set_current_playback_position(0.1)
	assert media.ready_state() == .have_metadata
	assert media.event_count('timeupdate') == 0
	for media.queued_media_task_ids_.len > 0 {
		media_timing_take_task(media).execute()
	}
	assert media.ready_state() == .have_future_data
	assert media.event_count('timeupdate') == 1
	media.buffered_.clear()
	media.playback_has_future_data_ = false
	media.set_current_playback_position(0.2)
	assert media.ready_state() == .have_future_data
	assert media.queued_media_task_ids_.len == 1
	media_timing_take_task(media).execute()
	assert media.ready_state() == .have_metadata
	assert media.event_count('timeupdate') == 1
}
