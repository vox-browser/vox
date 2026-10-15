module html

import dom
import math

@[heap]
struct PlaybackRateBackendProbe {
mut:
	rates []f32
	values []f64
	queued []int
	events []f64
	reentered bool
}

fn playback_rate_backend_owner(kind string) !&HTMLMediaElement {
	url := dom.URL{value: 'https://rate-backend.example/base/page.html'}
	document := parse_navigation_document('<${kind} id="media"></${kind}>', url, url.origin(), none)!
	return html_media_element_for_dom_element(document.get_element_by_id('media') or {
		return error('missing backend rate element')
	}) or { return error('missing backend rate model') }
}

fn playback_rate_backend_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing backend rate task') }
	assert task.source() == media.media_element_event_task_source()
	return task
}

fn playback_rate_backend_drain(media &HTMLMediaElement) {
	for _ in 0 .. 40 {
		if media.queued_media_task_ids_.len == 0 { return }
		playback_rate_backend_take(media).execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn playback_rate_backend_observe(media &HTMLMediaElement) &PlaybackRateBackendProbe {
	probe := &PlaybackRateBackendProbe{}
	mut current := unsafe { &HTMLMediaElement(media) }
	current.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_playback_rate: fn [media, probe] (rate f32) {
			mut seen := unsafe { &PlaybackRateBackendProbe(probe) }
			seen.rates << rate
			seen.values << media.playback_rate()
			seen.queued << media.queued_media_task_ids_.len
		}
	})
	return probe
}

fn test_backend_rate_attachment_and_accepted_equal_values_apply_before_queued_ratechange_events() {
	for kind in ['audio', 'video'] {
		mut media := playback_rate_backend_owner(kind)!
		defer { media.remove_queued_media_element_tasks(); media.finalize() }
		probe := playback_rate_backend_observe(media)
		assert probe.rates == [f32(1)] && probe.values == [1.0] && probe.queued == [0]
		assert media.paused() && media.network_state() == .empty
		media.set_default_playback_rate(2)
		assert probe.rates.len == 1 && media.playback_rate() == 1
		media.set_playback_rate(2)!
		media.set_playback_rate(2)!
		assert probe.rates == [f32(1), 2, 2] && probe.values == [1.0, 2.0, 2.0]
		assert probe.queued == [0, 2, 2] && media.event_count('ratechange') == 0
		assert media.queued_media_task_ids_.len == 2 && media.paused()
		playback_rate_backend_drain(media)
		assert media.event_count('ratechange') == 2
	}
}

fn test_backend_rate_keeps_float_conversion_signed_zero_and_rejects_without_a_callback_or_mutation() {
	mut media := playback_rate_backend_owner('video')!
	defer { media.remove_queued_media_element_tasks(); media.finalize() }
	probe := playback_rate_backend_observe(media)
	for rate in [0.0, -0.0, 0.1, 64.0, 1.0e-100] {
		media.set_playback_rate(rate)!
		assert media.playback_rate() == rate
		assert probe.rates.last() == f32(rate) && probe.values.last() == rate
	}
	assert math.signbit(f64(probe.rates[2])) && !math.signbit(f64(probe.rates[1]))
	assert f64(probe.rates[3]) != probe.values[3] && probe.rates.last() == 0
	assert media.playback_rate() != 0 && probe.rates.len == 6
	queued := media.queued_media_task_ids_.len
	for rate in [-0.01, 64.01, math.inf(1), math.inf(-1), math.nan()] {
		mut rejected := false
		media.set_playback_rate(rate) or {
			rejected = true
			assert err.msg() == 'NotSupportedError: Playback rate is outside of the supported range.'
		}
		assert rejected && probe.rates.len == 6 && media.playback_rate() == 1.0e-100
		assert media.queued_media_task_ids_.len == queued
	}
	playback_rate_backend_drain(media)
	assert media.event_count('ratechange') == 4
}

fn test_backend_rate_resource_setup_reset_replacement_and_adoption_use_the_current_manager() {
	mut media := playback_rate_backend_owner('video')!
	defer { media.remove_queued_media_element_tasks(); media.finalize() }
	probe := playback_rate_backend_observe(media)
	media.set_default_playback_rate(1.75)
	media.set_playback_rate(0.5)!
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{mime_type: 'video/mp4', duration: 20}
	})
	media.set_source('/movie.mp4')
	media.load()!
	assert probe.rates == [f32(1), 0.5, 1.75] && media.playback_rate() == 1.75
	playback_rate_backend_drain(media)
	media.forget_media_resource_specific_tracks()
	media.set_playback_rate(3)!
	assert probe.rates.len == 3 && !media.playback_manager_ready_
	media.set_up_playback_manager()
	assert probe.rates == [f32(1), 0.5, 1.75, 3]
	playback_rate_backend_drain(media)
	current := playback_rate_backend_observe(media)
	assert current.rates == [f32(3)] && current.queued == [0]
	original := media.document()?
	url := dom.URL{value: 'https://rate-backend-adopted.example/next/page.html'}
	mut destination := parse_navigation_document('<body></body>', url, url.origin(), none)!
	defer { destination.finalize() }
	element := original.get_element_by_id('media') or { panic('missing adopting rate element') }
	destination.adopt_node(element.as_node())
	media.set_playback_rate(4)!
	assert current.rates == [f32(3), 4] && probe.rates.len == 4
	task := playback_rate_backend_take(media)
	assert voidptr(task.document()?) == voidptr(destination)
	assert media.event_count('ratechange') == 2
	task.execute()
	assert media.event_count('ratechange') == 3 && media.playback_rate() == 4
}

fn test_backend_rate_reentry_keeps_inner_values_and_ratechange_listeners_queue_later_work() {
	mut media := playback_rate_backend_owner('audio')!
	defer { media.remove_queued_media_element_tasks(); media.finalize() }
	probe := &PlaybackRateBackendProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_playback_rate: fn [media, probe] (rate f32) {
			mut seen := unsafe { &PlaybackRateBackendProbe(probe) }
			seen.rates << rate
			seen.values << media.playback_rate()
			if rate == 2 && !seen.reentered {
				seen.reentered = true
				mut owner := unsafe { &HTMLMediaElement(media) }
				owner.set_playback_rate(3) or { panic(err) }
			}
		}
	})
	media.set_on_event('ratechange', &dom.CallbackType{
		handle_event: fn [media, probe] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut seen := unsafe { &PlaybackRateBackendProbe(probe) }
			seen.events << media.playback_rate()
			if seen.events.len == 1 {
				mut owner := unsafe { &HTMLMediaElement(media) }
				owner.set_playback_rate(0.5) or { panic(err) }
				assert media.event_count('ratechange') == 1
			}
			return dom.js_undefined()
		}
	})
	media.set_playback_rate(2)!
	assert probe.rates == [f32(1), 2, 3] && probe.values == [1.0, 2.0, 3.0]
	assert media.playback_rate() == 3 && probe.events == []
	assert media.queued_media_task_ids_.len == 2 && media.event_count('ratechange') == 0
	playback_rate_backend_drain(media)
	assert probe.rates == [f32(1), 2, 3, 0.5] && probe.events == [3.0, 0.5, 0.5]
	assert media.playback_rate() == 0.5 && media.event_count('ratechange') == 3
}
