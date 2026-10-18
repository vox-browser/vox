module html

import dom
import math

@[heap]
struct TimestampControlsClock {
mut:
	position f64
	seeks []f64
}

fn timestamp_controls_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing timestamp media task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn timestamp_controls_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls) {
	url := dom.URL{value: 'https://timestamp-controls.example/'}
	document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing timestamp owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing timestamp media model') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.seekable_.add_range(0, 200)
	controls := MediaControls.create(media)
	timestamp_controls_drain(media)
	return document, media, controls
}

fn timestamp_controls_position(mut media HTMLMediaElement, time f64) {
	media.set_current_playback_position(time)
	media.set_official_playback_position(time)
}

fn timestamp_controls_assert(controls &MediaControls, expected string) {
	assert controls.timestamp == expected
	if element := controls.dom_.timestamp_element {
		assert (element.as_node().text_content() or { panic('Missing timestamp text') }) == expected
		assert element.as_node().children_as_vector().len == 1
	}
}

fn test_timestamp_controls_use_source_clock_padding_i64_seconds_and_nearest_even_rounding() {
	for kind in ['video', 'audio'] {
		mut document, mut media, mut controls := timestamp_controls_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		media.set_duration(math.inf(1))
		timestamp_controls_drain(media)
		for i, time in [0.0, 0.5, 1.5, 2.5, 3.5, 59.5, 3599.5, 2147483648.0] {
			timestamp_controls_position(mut media, time)
			media.fire_event('timeupdate')
			timestamp_controls_assert(controls, ['00:00', '00:00', '00:02', '00:02', '00:04', '01:00', '01:00:00', '596523:14:08'][i])
		}
		timestamp_controls_position(mut media, 0)
		media.set_duration(3600.5)
		timestamp_controls_position(mut media, 91.5)
		timestamp_controls_drain(media)
		timestamp_controls_assert(controls, '01:32 / 01:00:00')
		media.set_duration(math.nan())
		controls.update_timestamp()
		timestamp_controls_assert(controls, '01:32 / 00:00')
		assert media.current_src() == '' && media.paused()
	}
}

fn test_timestamp_controls_retain_text_nodes_until_either_rounded_value_changes_and_remove_the_listener() {
	mut document, mut media, mut controls := timestamp_controls_owner('audio')!
	defer { controls.remove_event_listeners(); document.finalize() }
	element := controls.dom_.timestamp_element?
	node := element.as_node()
	initial := node.children_as_vector()[0]
	for time in [0.1, 0.49, 0.5] {
		timestamp_controls_position(mut media, time)
		media.fire_event('timeupdate')
		assert node.children_as_vector()[0] == initial
	}
	media.set_duration(200.5)
	timestamp_controls_drain(media)
	assert node.children_as_vector()[0] == initial
	timestamp_controls_position(mut media, 1.5)
	media.fire_event('timeupdate')
	timestamp_controls_assert(controls, '00:02 / 03:20')
	changed := node.children_as_vector()[0]
	assert changed != initial
	timestamp_controls_position(mut media, 2.49)
	media.fire_event('timeupdate')
	assert node.children_as_vector()[0] == changed
	media.set_duration(201.5)
	timestamp_controls_drain(media)
	timestamp_controls_assert(controls, '00:02 / 03:22')
	assert node.children_as_vector()[0] != changed
	controls.remove_event_listeners()
	timestamp_controls_position(mut media, 3.5)
	media.fire_event('timeupdate')
	timestamp_controls_assert(controls, '00:02 / 03:22')
	controls.update_timestamp()
	timestamp_controls_assert(controls, '00:04 / 03:22')
}

fn test_timestamp_controls_preview_coalesced_scrub_targets_before_the_backend_seek_finishes() {
	mut document, mut media, mut controls := timestamp_controls_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	clock := &TimestampControlsClock{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [clock] () f64 { return clock.position }
		seek: fn [clock] (time f64, _ MediaPlaybackSeekMode) {
			mut state := unsafe { &TimestampControlsClock(clock) }
			state.seeks << time
		}
	})
	controls.begin_timeline_scrubbing(10.5)
	timestamp_controls_assert(controls, '00:10 / 03:20')
	assert clock.seeks == [10.5] && media.seeking() && media.current_time() == 0
	controls.seek_while_scrubbing(20.5)
	controls.seek_while_scrubbing(30.5)
	timestamp_controls_assert(controls, '00:30 / 03:20')
	assert clock.seeks == [10.5] && (controls.pending_scrub_seek_time_ or { panic('Missing pending timestamp seek') }) == 30.5
	media.fire_event('timeupdate')
	timestamp_controls_assert(controls, '00:30 / 03:20')
	mut backend := unsafe { &TimestampControlsClock(clock) }
	backend.position = 10.5
	media.set_official_playback_position(clock.position)
	media.finish_seeking_element()
	timestamp_controls_drain(media)
	assert clock.seeks == [10.5, 30.5] && media.seeking()
	timestamp_controls_assert(controls, '00:30 / 03:20')
	controls.end_timeline_scrubbing(40.5)
	assert controls.scrubbing_timeline == .no && controls.scrub_seek_preemption_timer_ == none
	assert clock.seeks == [10.5, 30.5, 40.5]
	backend.position = 40.5
	media.set_official_playback_position(clock.position)
	media.finish_seeking_element()
	timestamp_controls_drain(media)
	timestamp_controls_assert(controls, '00:40 / 03:20')
}

fn test_timestamp_controls_keep_both_scrub_previews_while_duration_and_playback_events_change() {
	for phase in [MediaControlsScrubbing.while_paused, .while_playing] {
		mut document, mut media, mut controls := timestamp_controls_owner('audio')!
		defer { controls.remove_event_listeners(); document.finalize() }
		controls.scrubbing_timeline = phase
		controls.set_timestamp(50.5, media.duration())
		timestamp_controls_position(mut media, 5.5)
		media.fire_event('timeupdate')
		timestamp_controls_assert(controls, '00:50 / 03:20')
		media.set_duration(201.5)
		timestamp_controls_drain(media)
		timestamp_controls_assert(controls, '00:50 / 03:22')
		element := controls.dom_.timestamp_element?
		retained := element.as_node().children_as_vector()[0]
		media.fire_event('loadedmetadata')
		assert element.as_node().children_as_vector()[0] == retained
		timestamp_controls_position(mut media, 61.5)
		media.fire_event('timeupdate')
		timestamp_controls_assert(controls, '00:50 / 03:22')
		controls.scrubbing_timeline = .no
		media.fire_event('timeupdate')
		timestamp_controls_assert(controls, '01:02 / 03:22')
	}
}
