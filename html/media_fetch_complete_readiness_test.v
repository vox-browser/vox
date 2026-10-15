module html

import dom

@[heap]
struct FetchCompleteReadinessObservation {
mut:
	steps       []string
	position    f64
	ranges      []MediaBufferedRange
	clock_reads int
	range_reads int
}

fn fetch_complete_readiness_owner(kind string) !&HTMLMediaElement {
	url := dom.URL{ value: 'https://fetch-complete-readiness.example.test/' }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing completion player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing completion owner') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20 }
	})
	media.set_source('/metadata.mp4')
	media.load()!
	fetch_complete_readiness_drain(media)
	assert media.ready_state() == .have_metadata && media.network_state() == .idle
	assert media.queued_media_task_ids_.len == 0
	return media
}

fn fetch_complete_readiness_take(media &HTMLMediaElement) &Task {
	mut queue := main_thread_event_loop().task_queue()
	task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
		return task.id() in media.queued_media_task_ids_
	}) or { panic('missing completion readiness task') }
	assert task.source() == media.media_element_event_task_source()
	assert voidptr(task.document() or { panic('missing completion task document') }) == voidptr(media.document() or { panic('missing completion owner document') })
	return task
}

fn fetch_complete_readiness_drain(media &HTMLMediaElement) {
	for media.queued_media_task_ids_.len > 0 {
		fetch_complete_readiness_take(media).execute()
	}
}

fn fetch_complete_readiness_hooks(seen &FetchCompleteReadinessObservation) MediaPlaybackManagerHooks {
	return MediaPlaybackManagerHooks{
		current_time: fn [seen] () f64 {
			mut observation := unsafe { &FetchCompleteReadinessObservation(seen) }
			observation.steps << 'current-time'
			observation.clock_reads++
			return observation.position
		}
		buffered_ranges: fn [seen] () []MediaBufferedRange {
			mut observation := unsafe { &FetchCompleteReadinessObservation(seen) }
			observation.steps << 'buffered-ranges'
			observation.range_reads++
			return observation.ranges.clone()
		}
	}
}

fn test_completed_fetch_recomputes_each_readiness_from_final_playback_facts() {
	for kind in ['audio', 'video'] {
		for index, expected in [MediaReadyState.have_metadata, .have_current_data,
			.have_future_data, .have_enough_data, .have_enough_data] {
			mut media := fetch_complete_readiness_owner(kind)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			ends := [-1.0, 0.0, 2.0, 8.0, 20.0]
			seen := &FetchCompleteReadinessObservation{
				position: if index == 4 { 18.0 } else { 0.0 }
				ranges: if index == 0 { []MediaBufferedRange{} } else { [MediaBufferedRange{0, ends[index]}] }
			}
			media.set_playback_manager_hooks(fetch_complete_readiness_hooks(seen))
			media.playback_has_future_data_ = index >= 2
			media.network_state_ = .loading
			media.begin_delaying_load_event()
			assert media.document()?.anything_is_delaying_the_load_event()
			media.process_media_data(.complete)
			assert media.ready_state() == expected && media.network_state() == .idle
			assert seen.steps == ['current-time', 'buffered-ranges']
			assert seen.clock_reads == 1 && seen.range_reads == 1
			expected_tasks := if expected == .have_enough_data { 3 } else if expected == .have_future_data { 2 } else if expected == .have_current_data { 1 } else { 0 }
			assert media.queued_media_task_ids_.len == expected_tasks
			assert media.event_count('loadeddata') == 0
			assert media.document()?.anything_is_delaying_the_load_event() == (index == 0)
			fetch_complete_readiness_drain(media)
			assert media.event_count('loadeddata') == if index == 0 { 0 } else { 1 }
			assert media.event_count('canplay') == if index >= 2 { 1 } else { 0 }
			assert media.event_count('canplaythrough') == if index >= 3 { 1 } else { 0 }
		}
	}
}

fn test_completed_fetch_fires_progress_and_suspend_before_sampling_then_queues_owned_readiness_events() {
	for kind in ['audio', 'video'] {
		mut media := fetch_complete_readiness_owner(kind)!
		defer {
			media.remove_queued_media_element_tasks()
			media.finish_delaying_load_event()
			media.finalize()
		}
		seen := &FetchCompleteReadinessObservation{ ranges: [MediaBufferedRange{0, 8}] }
		media.set_playback_manager_hooks(fetch_complete_readiness_hooks(seen))
		media.playback_has_future_data_ = true
		media.network_state_ = .loading
		for name in ['progress', 'suspend', 'loadeddata', 'canplay', 'canplaythrough'] {
			media.set_on_event(name, &dom.CallbackType{
				handle_event: fn [name, media, seen] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
					mut observation := unsafe { &FetchCompleteReadinessObservation(seen) }
					observation.steps << name
					assert voidptr(event.target() or { panic('missing completion event target') }) == voidptr(media.event_target())
					assert voidptr(current or { panic('missing completion current target') }) == voidptr(media.event_target())
					assert event.is_trusted() && !event.bubbles() && !event.cancelable()
					if name in ['progress', 'suspend'] {
						assert media.ready_state() == .have_metadata
						assert observation.clock_reads == 0 && observation.range_reads == 0
						assert media.network_state() == if name == 'progress' { MediaNetworkState.loading } else { MediaNetworkState.idle }
					} else {
						assert media.ready_state() == .have_enough_data && media.network_state() == .idle
					}
					return dom.js_undefined()
				}
			})
		}
		media.process_media_data(.complete)
		assert seen.steps == ['progress', 'suspend', 'current-time', 'buffered-ranges']
		assert media.ready_state() == .have_enough_data && media.queued_media_task_ids_.len == 3
		mut loop := main_thread_event_loop()
		loop.perform_a_microtask_checkpoint()
		assert seen.steps == ['progress', 'suspend', 'current-time', 'buffered-ranges']
		for name in ['loadeddata', 'canplay', 'canplaythrough'] {
			fetch_complete_readiness_take(media).execute()
			assert seen.steps.last() == name
		}
		assert seen.steps == ['progress', 'suspend', 'current-time', 'buffered-ranges',
			'loadeddata', 'canplay', 'canplaythrough']
		assert media.queued_media_task_ids_.len == 0
	}
}

fn test_completed_fetch_uses_live_suspend_mutations_and_respects_a_reentrant_source_less_load() {
	for kind in ['audio', 'video'] {
		for reset in [false, true] {
			mut media := fetch_complete_readiness_owner(kind)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			seen := &FetchCompleteReadinessObservation{ ranges: [MediaBufferedRange{0, 8}] }
			media.set_playback_manager_hooks(fetch_complete_readiness_hooks(seen))
			media.playback_has_future_data_ = true
			media.network_state_ = .loading
			media.set_on_event('suspend', &dom.CallbackType{
				handle_event: fn [media, seen, reset] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
					assert media.network_state() == .idle && media.ready_state() == .have_metadata
					mut observation := unsafe { &FetchCompleteReadinessObservation(seen) }
					assert observation.clock_reads == 0 && observation.range_reads == 0
					observation.steps << 'suspend'
					if reset {
						mut owner := unsafe { &HTMLMediaElement(media) }
						owner.set_source(none)
						owner.load() or { panic(err) }
					} else {
						observation.position = 10
						observation.ranges = [MediaBufferedRange{10, 12}]
					}
					return dom.js_undefined()
				}
			})
			media.process_media_data(.complete)
			if reset {
				assert media.ready_state() == .have_nothing && media.network_state() == .empty
				assert !media.playback_manager_ready_ && media.current_src() == ''
				assert seen.steps == ['suspend'] && seen.clock_reads == 0 && seen.range_reads == 0
				fetch_complete_readiness_drain(media)
				assert media.event_count('abort') == 1 && media.event_count('emptied') == 1
				assert media.event_count('loadeddata') == 0 && media.event_count('canplay') == 0
				assert media.event_count('canplaythrough') == 0
			} else {
				assert media.ready_state() == .have_future_data && media.network_state() == .idle
				assert seen.steps == ['suspend', 'current-time', 'buffered-ranges']
				assert media.queued_media_task_ids_.len == 2
				fetch_complete_readiness_drain(media)
				assert media.event_count('loadeddata') == 1 && media.event_count('canplay') == 1
				assert media.event_count('canplaythrough') == 0
			}
		}
	}
}

fn test_completed_fetch_preserves_readiness_guards_and_does_not_repeat_same_state_events() {
	for kind in ['audio', 'video'] {
		for guard in ['no-manager', 'have-nothing', 'same-state'] {
			mut media := fetch_complete_readiness_owner(kind)!
			defer {
				media.remove_queued_media_element_tasks()
				media.finish_delaying_load_event()
				media.finalize()
			}
			seen := &FetchCompleteReadinessObservation{ ranges: [MediaBufferedRange{0, 8}] }
			media.set_playback_manager_hooks(fetch_complete_readiness_hooks(seen))
			media.playback_has_future_data_ = true
			match guard {
				'no-manager' { media.playback_manager_ready_ = false }
				'have-nothing' { media.set_ready_state(.have_nothing) }
				else {
					media.set_ready_state(.have_enough_data)
					fetch_complete_readiness_drain(media)
				}
			}
			expected := media.ready_state()
			progress := media.event_count('progress')
			suspend := media.event_count('suspend')
			loadeddata := media.event_count('loadeddata')
			canplay := media.event_count('canplay')
			canplaythrough := media.event_count('canplaythrough')
			media.begin_delaying_load_event()
			for _ in 0 .. 2 {
				media.network_state_ = .loading
				media.process_media_data(.complete)
				assert media.ready_state() == expected && media.network_state() == .idle
				assert media.queued_media_task_ids_.len == 0
			}
			expected_reads := if guard == 'same-state' { 2 } else { 0 }
			assert seen.clock_reads == expected_reads && seen.range_reads == expected_reads
			assert media.event_count('progress') == progress + 2 && media.event_count('suspend') == suspend + 2
			assert media.event_count('loadeddata') == loadeddata && media.event_count('canplay') == canplay
			assert media.event_count('canplaythrough') == canplaythrough
			assert media.document()?.anything_is_delaying_the_load_event()
		}
	}
}
