module html

import dom

@[heap]
struct PauseCallerObservation {
mut:
	fetches int
	pauses  int
}

fn pause_caller_owner() !&HTMLMediaElement {
	url := dom.URL{ value: 'https://pause-caller.example.test/' }
	document := parse_navigation_document('<video id="video"></video>', url, url.origin(), none)!
	element := document.get_element_by_id('video') or { return error('missing video') }
	return html_media_element_for_dom_element(element) or { return error('missing media owner') }
}

fn test_pause_selects_an_empty_resource_before_the_internal_pause_steps() {
	mut media := pause_caller_owner()!
	state := &PauseCallerObservation{}
	media_pointer := voidptr(media)
	media.set_source('/movie.mp4')
	media.set_paused(false)
	media.set_fetch_hook(fn [state, media_pointer] (url dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &PauseCallerObservation(state) }
		owner := unsafe { &HTMLMediaElement(media_pointer) }
		assert !owner.paused() && owner.network_state() == .loading
		assert url.serialize() == 'https://pause-caller.example.test/movie.mp4'
		observation.fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 10, buffered_end: 10 }
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		pause: fn [state, media_pointer] () {
			mut observation := unsafe { &PauseCallerObservation(state) }
			owner := unsafe { &HTMLMediaElement(media_pointer) }
			assert observation.fetches == 1 && owner.paused()
			assert owner.ready_state() == .have_enough_data
			observation.pauses++
		}
	})
	media.pause()
	assert state.fetches == 1 && state.pauses == 1
	assert media.paused() && !media.can_autoplay_
	assert media.current_src() == 'https://pause-caller.example.test/movie.mp4'
	media.pause()
	assert state.fetches == 1 && state.pauses == 1
	media.set_source('')
	media.load()!
}

fn test_pause_continues_after_the_selection_adapters_failure_and_empty_source() {
	mut media := pause_caller_owner()!
	state := &PauseCallerObservation{}
	media.set_source('/missing.mp4')
	media.set_paused(false)
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &PauseCallerObservation(state) }
		observation.fetches++
		return error('selected resource unavailable')
	})
	// Source's pause entry is void. The existing synchronous fetch adapter's
	// Result must not prevent the following internal pause steps.
	media.pause()
	assert state.fetches == 1 && media.network_state() == .no_source
	assert media.paused() && !media.can_autoplay_
	assert media.error_?.code == .src_not_supported
	media.pause()
	assert state.fetches == 1
	mut empty := pause_caller_owner()!
	empty.pause()
	assert empty.network_state() == .empty && empty.paused() && !empty.can_autoplay_
}

fn test_pause_keeps_preload_none_selection_automatic_and_does_not_resume_it() {
	mut media := pause_caller_owner()!
	state := &PauseCallerObservation{}
	media.set_source('/deferred.mp4')
	media.set_preload('none')
	media.set_fetch_hook(fn [state] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &PauseCallerObservation(state) }
		observation.fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 10 }
	})
	media.pause()
	assert media.network_state() == .idle
	assert media.current_src() == 'https://pause-caller.example.test/deferred.mp4'
	assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
	assert !media.current_resource_selection_is_explicit_ && !media.can_autoplay_
	media.pause()
	assert state.fetches == 0 && media.paused() && media.ready_state() == .have_nothing
}
