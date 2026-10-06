module html

import dom
import math

@[heap]
struct MediaVolumeTaskObservation {
mut:
	hook_values []f64
	values      []f64
	muted       []bool
	depth       int
	depths      []int
}

fn media_volume_drain_owner(media &HTMLMediaElement) {
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_volume_tasks_wait_while_effective_volume_updates_immediately() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	state := &MediaVolumeTaskObservation{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		set_volume: fn [state] (value f64) {
			mut result := unsafe { &MediaVolumeTaskObservation(state) }
			result.hook_values << value
		}
	})
	media.set_on_event('volumechange', &dom.CallbackType{
		handle_event: fn [media, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &MediaVolumeTaskObservation(state) }
			result.values << media.volume()
			result.muted << media.muted()
			return dom.js_undefined()
		}
	})
	media.set_volume(0.5)!
	media.set_muted(true)
	media.set_volume(0.75)!
	assert state.hook_values == [0.5, 0.0, 0.0]
	assert state.values == []
	assert media.queued_media_task_ids_.len == 3
	media.set_page_muted(true)
	assert state.hook_values == [0.5, 0.0, 0.0, 0.0]
	assert media.queued_media_task_ids_.len == 3
	mut loop := main_thread_event_loop()
	loop.perform_a_microtask_checkpoint()
	assert state.values == []
	media_volume_drain_owner(media)
	assert state.values == [0.75, 0.75, 0.75]
	assert state.muted == [true, true, true]
}

fn test_unchanged_or_invalid_volume_and_muted_values_do_not_queue_events() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	media.set_volume(1)!
	media.set_muted(false)
	media.set_volume(-1) or { assert err.msg().starts_with('IndexSizeError:') }
	media.set_volume(2) or { assert err.msg().starts_with('IndexSizeError:') }
	media.set_volume(math.nan()) or { assert err.msg().starts_with('IndexSizeError:') }
	assert media.volume() == 1 && !media.muted()
	assert media.queued_media_task_ids_.len == 0
	media.set_volume(0.5)!
	media.set_volume(0.5)!
	media.set_muted(true)
	media.set_muted(true)
	assert media.event_count('volumechange') == 0
	assert media.queued_media_task_ids_.len == 2
	media_volume_drain_owner(media)
	assert media.event_count('volumechange') == 2
}

fn test_volume_range_error_preserves_source_message_without_mutation_or_tasks() {
	mut media := HTMLMediaElement.create(none, dom.url_about_blank())
	for value in [-1.0, 1.01] {
		mut rejected := false
		media.set_volume(value) or {
			rejected = true
			assert err.msg() == 'IndexSizeError: Volume must be in the range 0.0 to 1.0, inclusive'
		}
		assert rejected && media.volume() == 1 && media.queued_media_task_ids_.len == 0
	}
}

fn test_volume_cancellation_is_owner_specific_and_callback_changes_wait_for_another_task() {
	mut first := HTMLMediaElement.create(none, dom.url_about_blank())
	mut second := HTMLMediaElement.create(none, dom.url_about_blank())
	state := &MediaVolumeTaskObservation{}
	second.set_on_event('volumechange', &dom.CallbackType{
		handle_event: fn [second, state] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut result := unsafe { &MediaVolumeTaskObservation(state) }
			result.depth++
			result.depths << result.depth
			if second.volume() == 1 {
				mut owner := unsafe { &HTMLMediaElement(second) }
				owner.set_volume(0.25) or { panic(err) }
				assert second.event_count('volumechange') == 1
			}
			result.depth--
			return dom.js_undefined()
		}
	})
	first.set_volume(0.5)!
	second.set_muted(true)
	assert first.event_count('volumechange') == 0 && second.event_count('volumechange') == 0
	first.load()!
	assert first.queued_media_task_ids_.len == 0
	media_volume_drain_owner(second)
	assert first.event_count('volumechange') == 0 && second.event_count('volumechange') == 2
	assert second.volume() == 0.25 && second.muted()
	assert state.depths == [1, 1]
}
