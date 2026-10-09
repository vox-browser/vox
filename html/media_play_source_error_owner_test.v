module html

import dom

@[heap]
struct PlaySourceErrorCalls {
mut:
	fetches int
	starts int
}

fn play_source_error_owner(kind string) !(&HTMLMediaElement, &PlaySourceErrorCalls) {
	url := dom.URL{ value: 'https://play-source-error.example.test/' }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing owner') }
	calls := &PlaySourceErrorCalls{}
	media.set_source('/movie.mp4')
	media.set_fetch_hook(fn [calls] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut seen := unsafe { &PlaySourceErrorCalls(calls) }
		seen.fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [calls] () {
			mut seen := unsafe { &PlaySourceErrorCalls(calls) }
			seen.starts++
		}
	})
	return media, calls
}

fn play_source_error_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for media.queued_media_task_ids_.len > 0 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing source error task') }
		task.execute()
	}
}

fn test_unsupported_play_uses_fresh_typed_exceptions_with_the_exact_error_message_and_no_side_effects() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy_
	previous_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = previous_policy; policy.allowlist_ = previous_allowlist }
	policy.set_policy(.allow_audio_and_video, [])
	for kind in ['audio', 'video'] {
		for message in ['', 'unsupported codec', 'Decoder \x00 🎬 failed\r\n'] {
			mut media, calls := play_source_error_owner(kind)!
			failure := &MediaError{ code: .src_not_supported, message: message }
			media.error_ = failure
			existing := dom.Promise.create()
			media.pending_play_promises_ << existing
			first := media.play()
			second := media.play()
			assert first.state() == .rejected && second.state() == .rejected
			assert first.result().kind == .runtime_value
			first_exception := first.result().as_webidl_value()!.dom_exception_?
			second_exception := second.result().as_webidl_value()!.dom_exception_?
			assert first_exception.name() == 'NotSupportedError' && first_exception.code() == 9
			assert first_exception.message() == message && second_exception.message() == message
			assert voidptr(first_exception) != voidptr(second_exception)
			assert voidptr(media.error()?) == voidptr(failure) && failure.message() == message
			assert media.paused() && media.network_state() == .empty && media.current_src() == ''
			assert media.can_autoplay_ && media.show_poster() && media.queued_media_task_ids_.len == 0
			assert calls.fetches == 0 && calls.starts == 0 && media.pending_play_promises_.len == 1
			assert voidptr(media.pending_play_promises_[0]) == voidptr(existing) && existing.state() == .pending
		}
	}
}

fn test_play_after_a_real_selection_failure_preserves_the_actual_media_error_and_does_not_retry() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy_
	previous_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = previous_policy; policy.allowlist_ = previous_allowlist }
	policy.set_policy(.allow_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut media, calls := play_source_error_owner(kind)!
		media.set_fetch_hook(fn [calls] (_ dom.URL, _ u64) !MediaResourceResponse {
			mut seen := unsafe { &PlaySourceErrorCalls(calls) }
			seen.fetches++
			return error('Selected decoder 🎬 unavailable')
		})
		mut failed := false
		media.load() or { failed = true }
		assert failed && calls.fetches == 1 && media.error()?.code == .src_not_supported
		play_source_error_drain(media)
		failure := media.error()?
		events := media.event_count('error')
		promise := media.play()
		assert promise.state() == .rejected && promise.result().kind == .runtime_value
		exception := promise.result().as_webidl_value()!.dom_exception_?
		assert exception.name() == 'NotSupportedError' && exception.code() == 9
		assert exception.message() == 'Selected decoder 🎬 unavailable'
		assert voidptr(media.error()?) == voidptr(failure) && media.network_state() == .no_source
		assert calls.fetches == 1 && calls.starts == 0 && media.paused()
		assert media.queued_media_task_ids_.len == 0 && media.event_count('error') == events
	}
}

fn test_other_media_error_codes_continue_through_the_existing_permitted_play_steps() {
	mut policy := AutoplaySettings.the()
	previous_policy := policy.policy_
	previous_allowlist := policy.allowlist_.clone()
	defer { policy.policy_ = previous_policy; policy.allowlist_ = previous_allowlist }
	policy.set_policy(.allow_audio_and_video, [])
	for code in [MediaErrorCode.aborted, .network, .decode] {
		mut media, calls := play_source_error_owner('video')!
		media.load()!
		play_source_error_drain(media)
		media.error_ = &MediaError{ code: code, message: 'different error' }
		promise := media.play()
		assert promise.state() == .pending && !media.paused() && calls.fetches == 1 && calls.starts == 1
		play_source_error_drain(media)
		assert promise.state() == .fulfilled && media.event_count('play') == 1 && media.event_count('playing') == 1
	}
}
