module html

import dom

@[heap]
struct FastSeekCallerClock {
mut:
	position  f64
	reads     int
	positions []f64
	modes     []MediaPlaybackSeekMode
}

fn fast_seek_caller_owner() !&HTMLMediaElement {
	url := dom.URL{
		value: 'https://fast-seek-caller.example.test/'
	}
	document := parse_navigation_document('<video id="video"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('video') or { return error('missing video') }
	return html_media_element_for_dom_element(element) or { return error('missing media owner') }
}

fn fast_seek_caller_load(mut media HTMLMediaElement) ! {
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.set_source('https://fast-seek-caller.example.test/movie.mp4')
	media.load()!
	mut loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { break
		 }
		loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_fast_seek_caller_clears_poster_before_have_nothing_without_changing_default_start() {
	mut media := fast_seek_caller_owner()!
	media.set_current_time(6)
	assert media.show_poster() && media.ready_state() == .have_nothing
	media.fast_seek(-2)
	assert !media.show_poster()
	assert media.current_time() == 6 && !media.seeking()
	assert media.queued_media_task_ids_.len == 0
}

fn test_fast_seek_caller_selects_direction_from_live_clock_and_commits_adjusted_position() {
	mut media := fast_seek_caller_owner()!
	fast_seek_caller_load(mut media)!
	clock := &FastSeekCallerClock{
		position: 9
	}
	media_pointer := voidptr(media)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [clock, media_pointer] () f64 {
			mut state := unsafe { &FastSeekCallerClock(clock) }
			owner := unsafe { &HTMLMediaElement(media_pointer) }
			// Source chooses direction before queuing the seeking event.
			if state.positions.len == 0 && state.reads == 0 {
				assert owner.queued_media_task_ids_.len == 0
			}
			state.reads++
			return state.position
		}
		seek:         fn [clock] (target f64, mode MediaPlaybackSeekMode) {
			mut state := unsafe { &FastSeekCallerClock(clock) }
			state.positions << target
			state.modes << mode
			state.position = if target == 7 { 4.0 } else { target }
		}
	})
	assert media.current_playback_position_ == 0
	media.fast_seek(7)
	assert clock.positions == [7.0] && clock.modes == [.fast_before]
	assert clock.reads == 2 && media.current_time() == 4
	media.fast_seek(8)
	assert clock.modes == [.fast_before, .fast_after] && clock.reads == 5
	media.fast_seek(8)
	assert clock.modes == [.fast_before, .fast_after, .accurate] && clock.reads == 8
	media.set_source('')
	media.load()!
}

fn test_fast_seek_caller_uses_each_source_clock_comparison_instead_of_one_cached_sample() {
	mut media := fast_seek_caller_owner()!
	fast_seek_caller_load(mut media)!
	clock := &FastSeekCallerClock{}
	media_pointer := voidptr(media)
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		current_time: fn [clock, media_pointer] () f64 {
			mut state := unsafe { &FastSeekCallerClock(clock) }
			owner := unsafe { &HTMLMediaElement(media_pointer) }
			state.reads++
			if state.reads <= 2 { assert owner.queued_media_task_ids_.len == 0
			 }
			return match state.reads {
				1 { -1.0 }
				2 { 9.0 }
				else { 4.0 }
			}
		}
		seek:         fn [clock] (target f64, mode MediaPlaybackSeekMode) {
			mut state := unsafe { &FastSeekCallerClock(clock) }
			state.positions << target
			state.modes << mode
		}
	})
	media.fast_seek(5)
	assert clock.positions == [5.0] && clock.modes == [.accurate]
	assert clock.reads == 3 && media.current_time() == 4
	media.set_source('')
	media.load()!
}
