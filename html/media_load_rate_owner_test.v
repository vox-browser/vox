module html

import dom
import math

@[heap]
struct MediaLoadRateFetchObservation {
mut:
	calls int
}

fn media_load_rate_drain_owner(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_load_cancels_old_rate_tasks_and_queues_its_validated_default_reset() {
	mut first := HTMLMediaElement.create(none, dom.url_about_blank())
	mut second := HTMLMediaElement.create(none, dom.url_about_blank())
	first.set_default_playback_rate(2)
	first.set_playback_rate(0.5)!
	second.set_default_playback_rate(3)
	assert first.queued_media_task_ids_.len == 2 && second.queued_media_task_ids_.len == 1
	first.load()!
	assert first.playback_rate() == 2 && first.default_playback_rate() == 2
	assert first.event_count('ratechange') == 0 && first.queued_media_task_ids_.len == 1
	assert second.queued_media_task_ids_.len == 1
	media_load_rate_drain_owner(first)
	media_load_rate_drain_owner(second)
	assert first.event_count('ratechange') == 1 && second.event_count('ratechange') == 1
	first.load_element()!
	assert first.playback_rate() == 2 && first.queued_media_task_ids_.len == 0
	assert first.event_count('ratechange') == 1
}

fn test_invalid_default_rate_load_propagates_before_resource_selection() {
	for value in [-1.0, 65.0, math.inf(1), math.inf(-1), math.nan()] {
		mut media :=
			HTMLMediaElement.create(none, dom.URL{ value: 'https://load-rate.example.test/' })
		state := &MediaLoadRateFetchObservation{}
		media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !MediaResourceResponse {
			mut result := unsafe { &MediaLoadRateFetchObservation(state) }
			result.calls++
			return MediaResourceResponse{ mime_type: 'video/webm', duration: 5 }
		})
		media.set_source('/movie.webm')
		// These are internal setter calls, outside native double conversion.
		media.set_default_playback_rate(value)
		mut rejected := false
		media.load() or {
			rejected = true
			assert err.msg().starts_with('NotSupportedError:')
		}
		assert rejected && state.calls == 0
		assert media.playback_rate() == 1 && media.current_src() == ''
		assert media.event_count('ratechange') == 0 && media.queued_media_task_ids_.len == 0
	}
}

fn test_automatic_load_reset_uses_the_rate_setter_and_default_noop_stays_silent() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.load_element()!
	assert media.playback_rate() == 1 && media.event_count('ratechange') == 0
	assert media.queued_media_task_ids_.len == 0
	media.set_default_playback_rate(0)
	media_load_rate_drain_owner(media)
	assert media.event_count('ratechange') == 1
	media.load_element()!
	assert media.playback_rate() == 0 && media.event_count('ratechange') == 1
	assert media.queued_media_task_ids_.len == 1
	media_load_rate_drain_owner(media)
	assert media.event_count('ratechange') == 2
}
