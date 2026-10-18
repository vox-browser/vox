module html

import dom
import math

@[heap]
struct MediaKeyboardProbe {
mut:
	position f64 = 110
	seeks []f64
	modes []MediaPlaybackSeekMode
	volumes []f64
}

fn media_keyboard_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing media keyboard task') }
		assert task.source() == .media_element && task.document() == media.document()
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn media_keyboard_owner(kind string) !(&dom.Document, &HTMLMediaElement, &MediaControls, &MediaKeyboardProbe) {
	url := dom.URL{value: 'https://media-keyboard.example/'}
	mut document := parse_navigation_document('<!doctype html><${kind} id="player" preload="none"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('Missing media keyboard owner') }
	mut media := html_media_element_for_dom_element(element) or { return error('Missing media keyboard model') }
	media.set_duration(200)
	media.set_ready_state(.have_enough_data)
	media.network_state_ = .idle
	media.seekable_.add_range(0, 20)
	media.seekable_.add_range(100, 140)
	media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
	probe := &MediaKeyboardProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [probe] () f64 { return probe.position }
		seek: fn [probe] (target f64, mode MediaPlaybackSeekMode) {
			mut seen := unsafe { &MediaKeyboardProbe(probe) }
			seen.seeks << target
			seen.modes << mode
			seen.position = target
		}
		set_volume: fn [probe] (volume f64) {
			mut seen := unsafe { &MediaKeyboardProbe(probe) }
			seen.volumes << volume
		}
	})
	media.set_current_playback_position(110)
	media.set_official_playback_position(110)
	controls := MediaControls.create(media)
	media_keyboard_drain(media)
	return document, media, controls, probe
}

fn media_keyboard_send(media &HTMLMediaElement, key dom.KeyCode, handled bool) {
	event := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{
		key_code: u32(key)
		// Source dispatches on the platform key code, independently of key text.
		key: 'unrelated key text'
		cancelable: true
	})
	base := unsafe { &dom.Event(event) }
	assert media.event_target().dispatch_event(base) == !handled
	assert base.default_prevented() == handled
	assert (base.target() or { panic('Missing media keyboard event target') }) == media.event_target() && base.current_target() == none
}

fn test_controls_keyboard_seeks_five_seconds_and_uses_the_last_seekable_end_on_actual_media() {
	for kind in ['video', 'audio'] {
		mut document, mut media, mut controls, probe := media_keyboard_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		for i, key in [dom.KeyCode.right, .left, .end, .right, .home, .left] {
			controls.visible = false
			media_keyboard_send(media, key, true)
			expected := [115.0, 110, 140, 140, 0, 0][i]
			assert media.current_time() == expected && media.seeking() && controls.visible
			assert probe.seeks.last() == expected && probe.modes.last() == .accurate
			assert media.event_count('seeking') == i
			if i == 0 { assert controls.timeline_percentage == 37.5 && controls.timestamp == '01:55 / 03:20' }
			if i == 2 { assert controls.timeline_percentage == 100 && media.duration() == 200 }
			media.finish_seeking_element()
			media_keyboard_drain(media)
			assert media.event_count('seeking') == i + 1 && !media.seeking()
		}
		assert probe.seeks == [115.0, 110, 140, 140, 0, 0]
		assert probe.modes.all(it == .accurate) && media.current_time() == 0
		assert media.paused() && media.current_src() == '' && !document.anything_is_delaying_the_load_event()
	}
}

fn test_controls_keyboard_volume_steps_clamp_unmute_and_mute_through_queued_owner_events() {
	for kind in ['video', 'audio'] {
		mut document, mut media, mut controls, probe := media_keyboard_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		media.set_volume(0.95)!
		media.set_muted(true)
		media_keyboard_drain(media)
		before := media.event_count('volumechange')
		controls.visible = false
		media_keyboard_send(media, .up, true)
		assert media.volume() == 1 && !media.muted() && controls.visible
		assert controls.volume_percentage == 100 && probe.volumes.last() == 1
		assert media.event_count('volumechange') == before && media.queued_media_task_ids_.len == 2
		media_keyboard_drain(media)
		assert media.event_count('volumechange') == before + 2
		media_keyboard_send(media, .up, true)
		assert media.volume() == 1 && media.queued_media_task_ids_.len == 0
		media_keyboard_send(media, .down, true)
		assert math.abs(media.volume() - 0.9) < 0.000001 && !media.muted()
		media_keyboard_drain(media)
		media.set_volume(0.05)!
		media_keyboard_drain(media)
		media_keyboard_send(media, .down, true)
		assert media.volume() == 0 && !media.muted() && controls.mute_icon == .empty
		media_keyboard_drain(media)
		media_keyboard_send(media, .m, true)
		assert media.muted() && controls.was_muted && media.queued_media_task_ids_.len == 1
		media_keyboard_drain(media)
		media_keyboard_send(media, .m, true)
		assert !media.muted() && !controls.was_muted && media.volume() == 0
		media_keyboard_drain(media)
		assert media.paused() && probe.seeks == []
	}
}

fn test_controls_keyboard_space_toggles_playback_and_preserves_scrubbing_and_event_type_guards() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy()
	previous_allowlist := policy.allowlist().map(it.serialize())
	defer { policy.set_policy(previous_policy, previous_allowlist) }
	policy.set_policy(.allow_audio_and_video, [])
	for kind in ['video', 'audio'] {
		mut document, media, mut controls, probe := media_keyboard_owner(kind)!
		defer { controls.remove_event_listeners(); document.finalize() }
		media_keyboard_send(media, .space, true)
		assert !media.paused() && controls.play_icon_is_pause
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
		media_keyboard_drain(media)
		assert media.event_count('play') == 1 && media.event_count('playing') == 1
		controls.scrubbing_timeline = .while_playing
		media_keyboard_send(media, .space, true)
		assert !media.paused() && media.queued_media_task_ids_.len == 0
		controls.scrubbing_timeline = .no
		media_keyboard_send(media, .space, true)
		assert media.paused() && !controls.play_icon_is_pause && media.event_count('pause') == 0
		media_keyboard_drain(media)
		assert media.event_count('pause') == 1
		controls.visible = false
		media_keyboard_send(media, .a, false)
		for event in [dom.Event.create('keydown', dom.EventInit{cancelable: true}), unsafe { &dom.Event(dom.MouseEvent.create('keydown', dom.MouseEventInit{cancelable: true})) }] {
			assert media.event_target().dispatch_event(event) && !event.default_prevented()
		}
		assert !controls.visible && media.paused() && probe.seeks == []
		assert media.queued_media_task_ids_.len == 0
	}
}

fn test_controls_keyboard_end_requires_a_finite_positive_last_seekable_range() {
	mut document, mut media, mut controls, probe := media_keyboard_owner('video')!
	defer { controls.remove_event_listeners(); document.finalize() }
	media.seekable_.clear()
	controls.visible = false
	media_keyboard_send(media, .end, false)
	for range_ in [[1.0, 1.0], [3.0, 2.0], [math.nan(), 2.0], [0.0, math.inf(1)], [math.inf(-1), 3.0]] {
		media.seekable_.clear()
		media.seekable_.add_range(0, 20)
		media.seekable_.add_range(range_[0], range_[1])
		media_keyboard_send(media, .end, false)
		assert !controls.visible && media.current_time() == 110 && !media.seeking()
		assert media.queued_media_task_ids_.len == 0 && probe.seeks == []
	}
}
