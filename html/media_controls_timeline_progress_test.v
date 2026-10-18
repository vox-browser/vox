module html

import css
import dom

@[heap]
struct TimelineProgressClock {
mut:
	position f64 = 125
	seeks []f64
}

fn timeline_progress_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing timeline progress task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn timeline_progress_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://timeline-progress.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing timeline progress owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing timeline progress media') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.seekable_.add_range(0, 20)
	media.seekable_.add_range(100, 200)
	media.set_current_playback_position(125)
	media.set_official_playback_position(125)
	controls := MediaControls.create(media)
	timeline_progress_drain(media)
	return document, media, controls
}

fn timeline_progress_assert(controls &MediaControls, percentage f64, width string) {
	assert controls.timeline_percentage == percentage
	fill := controls.dom_.timeline_fill or { panic('Missing timeline progress fill') }
	assert css.element_style(fill).get_property_value('width') == width
}

fn test_timeline_progress_updates_only_width_and_caches_the_fraction_through_actual_media_events() {
	for kind in ['video', 'audio'] {
		mut document, mut media, mut controls := timeline_progress_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		fill := controls.dom_.timeline_fill?
		mut style := css.element_style(fill)
		style.set_property('height', '3px', '')!
		style.set_property('color', 'blue', 'important')!
		timeline_progress_assert(controls, 25, '25%')
		media.set_current_playback_position(150)
		media.set_official_playback_position(150)
		media.fire_event('timeupdate')
		timeline_progress_assert(controls, 50, '50%')
		assert style.get_property_value('height') == '3px'
		assert style.get_property_value('color') == 'blue' && style.get_property_priority('color') == 'important'
		// Source's cache skips the CSSOM operation even if a caller changed the DOM width.
		style.set_property('width', '7%', '')!
		media.fire_event('timeupdate')
		timeline_progress_assert(controls, 50, '7%')
		for i, time in [0.0, 250.0] {
			media.set_current_playback_position(time)
			media.set_official_playback_position(time)
			media.fire_event('timeupdate')
			timeline_progress_assert(controls, [0.0, 100.0][i], ['0%', '100%'][i])
		}
		media.seekable_.clear()
		media.fire_event('durationchange')
		timeline_progress_assert(controls, 0, '0%')
		assert style.get_property_value('height') == '3px'
	}
}

fn test_timeline_progress_previews_pending_targets_before_backend_seek_completion_and_returns_to_the_clock() {
	mut document, mut media, mut controls := timeline_progress_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	clock := &TimelineProgressClock{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [clock] () f64 { return clock.position }
		seek: fn [clock] (time f64, _ MediaPlaybackSeekMode) {
			mut state := unsafe { &TimelineProgressClock(clock) }
			state.seeks << time
		}
	})
	controls.begin_timeline_scrubbing(110)
	timeline_progress_assert(controls, 10, '10%')
	assert media.current_time() == 125 && media.seeking() && clock.seeks == [110.0]
	controls.seek_while_scrubbing(140)
	controls.seek_while_scrubbing(180)
	timeline_progress_assert(controls, 80, '80%')
	assert controls.timestamp == '03:00 / 03:20'
	assert clock.seeks == [110.0] && (controls.pending_scrub_seek_time_ or { panic('Missing progress target') }) == 180
	media.fire_event('timeupdate')
	timeline_progress_assert(controls, 80, '80%')
	mut backend := unsafe { &TimelineProgressClock(clock) }
	backend.position = 110
	media.set_official_playback_position(clock.position)
	media.finish_seeking_element()
	timeline_progress_drain(media)
	assert clock.seeks == [110.0, 180.0] && media.seeking()
	timeline_progress_assert(controls, 80, '80%')
	controls.end_timeline_scrubbing(160)
	assert controls.scrubbing_timeline == .no && controls.scrub_seek_preemption_timer_ == none
	assert clock.seeks == [110.0, 180.0, 160.0]
	timeline_progress_assert(controls, 10, '10%')
	backend.position = 160
	media.set_official_playback_position(clock.position)
	media.finish_seeking_element()
	timeline_progress_drain(media)
	timeline_progress_assert(controls, 60, '60%')
}

fn test_timeline_progress_keeps_both_scrub_states_clamped_and_uses_the_live_final_seekable_range() {
	for phase in [MediaControlsScrubbing.while_paused, .while_playing] {
		mut document, mut media, mut controls := timeline_progress_owner('audio')!
		defer { controls.remove_event_listeners(); document.finalize() }
		controls.scrubbing_timeline = phase
		controls.seek_while_scrubbing(90)
		timeline_progress_assert(controls, 0, '0%')
		controls.seek_while_scrubbing(250)
		timeline_progress_assert(controls, 100, '100%')
		for event_name in ['timeupdate', 'durationchange', 'loadedmetadata'] {
			media.fire_event(event_name)
			timeline_progress_assert(controls, 100, '100%')
		}
		media.seekable_.clear()
		media.seekable_.add_range(0, 20)
		media.seekable_.add_range(150, 250)
		controls.seek_while_scrubbing(200)
		timeline_progress_assert(controls, 50, '50%')
		media.seekable_.clear()
		controls.seek_while_scrubbing(175)
		timeline_progress_assert(controls, 50, '50%')
		controls.end_timeline_scrubbing(175)
		timeline_progress_assert(controls, 0, '0%')
		timeline_progress_drain(media)
	}
}

fn test_timeline_progress_cache_preserves_initial_zero_and_removed_listener_boundaries() {
	mut document, mut media, mut controls := timeline_progress_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	controls.set_timeline_progress(0)
	fill := controls.dom_.timeline_fill?
	mut style := css.element_style(fill)
	style.remove_property('width')!
	controls.set_timeline_progress(0)
	assert style.get_property_value('width') == '' && controls.timeline_percentage == 0
	controls.remove_event_listeners()
	media.set_current_playback_position(175)
	media.set_official_playback_position(175)
	media.fire_event('timeupdate')
	assert style.get_property_value('width') == '' && controls.timeline_percentage == 0
	controls.update_timeline()
	timeline_progress_assert(controls, 75, '75%')
}
