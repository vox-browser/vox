module html

import dom
import math

@[heap]
struct PlayPermissionCalls {
mut:
	fetches int
	starts int
}

fn play_permission_owner(kind string, address string) !(&HTMLMediaElement, &PlayPermissionCalls) {
	url := dom.URL{ value: address }
	document := parse_navigation_document('<${kind} id="player"></${kind}>', url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or { return error('missing media owner') }
	calls := &PlayPermissionCalls{}
	media.set_fetch_hook(fn [calls] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut seen := unsafe { &PlayPermissionCalls(calls) }
		seen.fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [calls] () {
			mut seen := unsafe { &PlayPermissionCalls(calls) }
			seen.starts++
		}
	})
	media.set_source('/movie.mp4')
	return media, calls
}

fn play_permission_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for media.queued_media_task_ids_.len > 0 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing play permission task') }
		task.execute()
	}
}

fn play_permission_denied(promise &dom.Promise) {
	assert promise.state() == .rejected
	reason := promise.result().as_webidl_value() or { panic(err) }
	exception := reason.dom_exception_ or { panic('missing NotAllowedError') }
	assert exception.name() == 'NotAllowedError' && exception.code() == 0
	assert exception.message() == 'Media playback is not allowed without user interaction'
}

fn test_denied_play_rejects_before_resource_selection_and_preserves_owner_state() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer { settings.policy_ = old_policy; settings.allowlist_ = old_allowlist }
	for kind in ['audio', 'video'] {
		for policy in [AutoplayPolicy.block_audio, .block_audio_and_video] {
			settings.set_policy(policy, [])
			mut media, calls := play_permission_owner(kind, 'https://denied-play.example.test/')!
			existing := dom.Promise.create()
			media.pending_play_promises_ << existing
			assert media.network_state() == .empty && media.can_autoplay_ && media.show_poster()
			play_permission_denied(media.play())
			assert calls.fetches == 0 && calls.starts == 0
			assert media.paused() && media.network_state() == .empty && media.current_src() == ''
			assert media.can_autoplay_ && media.show_poster() && media.queued_media_task_ids_.len == 0
			assert media.pending_play_promises_.len == 1
			assert voidptr(media.pending_play_promises_[0]) == voidptr(existing)
			assert existing.state() == .pending
		}
	}
}

fn test_play_permission_rejection_precedes_the_unsupported_source_exception() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer { settings.policy_ = old_policy; settings.allowlist_ = old_allowlist }
	settings.set_policy(.block_audio_and_video, [])
	mut media, calls := play_permission_owner('video', 'https://play-errors.example.test/')!
	media.error_ = &MediaError{ code: .src_not_supported, message: 'unsupported source' }
	first := media.play()
	second := media.play()
	play_permission_denied(first)
	play_permission_denied(second)
	assert voidptr(first.result().as_webidl_value()!.dom_exception_?) != voidptr(second.result().as_webidl_value()!.dom_exception_?)
	settings.set_policy(.allow_audio_and_video, [])
	unsupported := media.play()
	assert unsupported.state() == .rejected
	exception := unsupported.result().as_webidl_value()!.dom_exception_?
	assert exception.name() == 'NotSupportedError' && exception.code() == 9
	assert exception.message() == 'unsupported source'
	assert calls.fetches == 0 && calls.starts == 0 && media.pending_play_promises_.len == 0
}

fn test_adopted_play_uses_the_current_document_and_consumed_sticky_activation() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer { settings.policy_ = old_policy; settings.allowlist_ = old_allowlist }
	settings.set_policy(.block_audio_and_video, ['https://allowed-play.example.test'])
	mut media, calls := play_permission_owner('audio', 'https://allowed-play.example.test/')!
	old_document := media.document()?
	mut old_window := old_document.get_window()?
	old_window.set_last_activation_timestamp(-math.inf(1))
	url := dom.URL{ value: 'https://adopted-play.example.test/' }
	mut document := parse_navigation_document('<body></body>', url, url.origin(), none)!
	document.adopt_node(old_document.get_element_by_id('player')?.as_node())
	media.set_source('https://allowed-play.example.test/movie.mp4')
	play_permission_denied(media.play())
	assert calls.fetches == 0 && media.paused()
	mut native := document.get_window()?
	native.set_last_activation_timestamp(0)
	mut window := unsafe { &WindowModel(native) }
	window.consume_user_activation()
	assert native.has_sticky_activation() && !native.has_transient_activation()
	// Sandbox automatic-features blocks autoplay, not this permitted explicit play.
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	promise := media.play()
	assert promise.state() == .pending && calls.fetches == 1 && calls.starts == 1 && !media.paused()
	play_permission_drain(media)
	assert promise.state() == .fulfilled && media.event_count('play') == 1 && media.event_count('playing') == 1
}

fn test_denied_play_on_an_already_playing_owner_keeps_the_original_promise_batch() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer { settings.policy_ = old_policy; settings.allowlist_ = old_allowlist }
	settings.set_policy(.allow_audio_and_video, [])
	mut media, calls := play_permission_owner('video', 'https://pending-play.example.test/')!
	media.load()!
	play_permission_drain(media)
	media.set_ready_state(.have_metadata)
	play_permission_drain(media)
	first := media.play()
	play_permission_drain(media)
	assert !media.paused() && first.state() == .pending && media.pending_play_promises_.len == 1
	settings.set_policy(.block_audio_and_video, [])
	play_permission_denied(media.play())
	assert !media.paused() && first.state() == .pending && media.pending_play_promises_.len == 1
	assert media.queued_media_task_ids_.len == 0 && calls.fetches == 1
	media.set_ready_state(.have_future_data)
	play_permission_drain(media)
	assert first.state() == .fulfilled && calls.starts == 1
}
