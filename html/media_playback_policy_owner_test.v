module html

import dom
import math
import page

@[heap]
struct PlaybackPolicyFetches {
mut:
	count int
}

fn playback_policy_owner(kind string, address string) !(&HTMLMediaElement, &PlaybackPolicyFetches) {
	url := dom.URL{
		value: address
	}
	document := parse_navigation_document('<${kind} id="player" autoplay preload="none"></${kind}>',
		url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	mut media := html_media_element_for_dom_element(element) or {
		return error('missing media owner')
	}
	fetches := &PlaybackPolicyFetches{}
	media.set_fetch_hook(fn [fetches] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut seen := unsafe { &PlaybackPolicyFetches(fetches) }
		seen.count++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
	})
	media.set_source('/movie.mp4')
	return media, fetches
}

fn playback_policy_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for media.queued_media_task_ids_.len > 0 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing playback policy task') }
		task.execute()
	}
}

fn test_resource_autoplay_uses_the_policy_and_effective_volume_of_both_actual_owners() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer {
		settings.policy_ = old_policy
		settings.allowlist_ = old_allowlist
	}
	for kind in ['audio', 'video'] {
		for policy in [AutoplayPolicy.allow_audio_and_video, .block_audio, .block_audio_and_video] {
			settings.set_policy(policy, [])
			for volume in ['audible', 'muted', 'zero', 'page-muted'] {
				mut media, fetches := playback_policy_owner(kind,
					'https://policy-owner.example.test/')!
				mut document := media.document()?
				mut owner := page.Page.create(1)!
				document.set_page(unsafe { &dom.Page(owner) })
				if volume == 'muted' { media.set_muted(true) }
				if volume == 'zero' { media.set_volume(0)! }
				if volume == 'page-muted' { owner.set_page_mute_state(.muted) }
				allowed := policy == .allow_audio_and_video
					|| (policy == .block_audio && volume != 'audible')
				media.select_resource()!
				assert fetches.count == if allowed {
					1
				} else {
					0
				}
				assert media.paused() == !allowed
				playback_policy_drain(media)
				assert media.event_count('play') == if allowed {
					1
				} else {
					0
				}
				assert media.event_count('playing') == if allowed {
					1
				} else {
					0
				}
				if !allowed {
					// Explicit load bypasses preload deferral, but not autoplay policy.
					media.load()!
					assert fetches.count == 1 && media.paused()
						&& media.ready_state() == .have_enough_data
					playback_policy_drain(media)
					assert media.event_count('play') == 0 && media.event_count('playing') == 0
				}
			}
		}
	}
}

fn test_sticky_activation_allows_autoplay_after_transient_activation_is_consumed() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer {
		settings.policy_ = old_policy
		settings.allowlist_ = old_allowlist
	}
	settings.set_policy(.block_audio_and_video, [])
	mut media, fetches := playback_policy_owner('video', 'https://sticky-policy.example.test/')!
	mut native := media.document()?.get_window()?
	assert !native.has_sticky_activation()
	media.select_resource()!
	assert fetches.count == 0 && media.paused()
	// Consume actual Window activation, retaining its sticky record.
	native.set_last_activation_timestamp(0)
	mut window := unsafe { &WindowModel(native) }
	window.consume_user_activation()
	assert math.is_inf(native.last_activation_timestamp, -1)
	assert native.has_sticky_activation() && !native.has_transient_activation()
	media.set_autoplay(true)
	assert fetches.count == 1 && !media.paused()
	playback_policy_drain(media)
	assert media.event_count('play') == 1 && media.event_count('playing') == 1
	// Sticky permission does not bypass the independent sandbox eligibility gate.
	media.pause()
	mut document := media.document()?
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	media.load()!
	assert fetches.count == 2 && media.paused()
	playback_policy_drain(media)
}

fn test_allowlist_file_exception_and_adoption_consult_the_current_document_origin_and_window() {
	mut settings := AutoplaySettings.the()
	old_policy := settings.policy_
	old_allowlist := settings.allowlist_.clone()
	defer {
		settings.policy_ = old_policy
		settings.allowlist_ = old_allowlist
	}
	settings.set_policy(.block_audio_and_video, [
		'https://allowed-policy.example.test',
	])
	for address in ['https://allowed-policy.example.test/', 'file:///tmp/playback-policy-owner.html'] {
		mut media, fetches := playback_policy_owner('audio', address)!
		media.select_resource()!
		assert fetches.count == 1 && !media.paused()
		playback_policy_drain(media)
	}
	mut media, fetches := playback_policy_owner('video', 'https://allowed-policy.example.test/')!
	mut original := media.document()?
	mut old_window := original.get_window()?
	old_window.set_last_activation_timestamp(-math.inf(1))
	url := dom.URL{
		value: 'https://blocked-policy.example.test/'
	}
	mut adopted := parse_navigation_document('<body></body>', url, url.origin(), none)!
	adopted.adopt_node(original.get_element_by_id('player')?.as_node())
	// The selected resource remains allowlisted; the current document is not.
	media.set_source('https://allowed-policy.example.test/movie.mp4')
	media.select_resource()!
	assert fetches.count == 0 && media.paused()
	mut current_window := adopted.get_window()?
	assert !current_window.has_sticky_activation()
	current_window.set_last_activation_timestamp(-math.inf(1))
	media.set_autoplay(true)
	assert fetches.count == 1 && !media.paused()
	playback_policy_drain(media)
}
