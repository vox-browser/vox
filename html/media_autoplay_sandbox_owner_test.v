module html

import dom

@[heap]
struct AutoplaySandboxFetches {
mut:
	count int
}

fn autoplay_sandbox_owner(kind string) !&HTMLMediaElement {
	url := dom.URL{
		value: 'https://autoplay-sandbox.example.test/'
	}
	document := parse_navigation_document('<${kind} id="player" autoplay preload="none"></${kind}>',
		url, url.origin(), none)!
	element := document.get_element_by_id('player') or { return error('missing player') }
	return html_media_element_for_dom_element(element) or { return error('missing media owner') }
}

fn autoplay_sandbox_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for media.queued_media_task_ids_.len > 0 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing autoplay sandbox task') }
		task.execute()
	}
}

fn test_autoplay_eligibility_checks_only_the_automatic_features_sandbox_bit_on_both_owners() {
	for kind in ['audio', 'video'] {
		mut media := autoplay_sandbox_owner(kind)!
		mut document := media.document()?
		assert media.is_eligible_for_autoplay()
		for flag in [SandboxingFlag.sandboxed_navigation, .sandboxed_auxiliary_navigation,
			.sandboxed_top_level_navigation_without_user_activation,
			.sandboxed_top_level_navigation_with_user_activation, .sandboxed_plugins,
			.sandboxed_origin, .sandboxed_forms, .sandboxed_pointer_lock, .sandboxed_scripts,
			.sandboxed_automatic_features, .sandboxed_document_domain,
			.sandbox_propagates_to_auxiliary_browsing_contexts, .sandboxed_modals,
			.sandboxed_orientation_lock, .sandboxed_presentation, .sandboxed_downloads,
			.sandboxed_custom_protocols] {
			document.set_active_sandboxing_flag_bits(u32(flag))
			assert media.is_eligible_for_autoplay() == (flag != .sandboxed_automatic_features)
		}
		document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features) | u32(SandboxingFlag.sandboxed_forms))
		media.set_muted(true)
		media.set_volume(0)!
		assert !media.is_eligible_for_autoplay()
		document.set_active_sandboxing_flag_bits(0)
		assert media.is_eligible_for_autoplay()
		media.can_autoplay_ = false
		assert !media.is_eligible_for_autoplay()
		media.can_autoplay_ = true
		media.set_paused(false)
		assert !media.is_eligible_for_autoplay()
		media.set_paused(true)
		media.set_autoplay(false)
		assert !media.is_eligible_for_autoplay()
		media.set_autoplay(true)
		media.allow_autoplay_ = false
		assert !media.is_eligible_for_autoplay()
		media.allow_autoplay_ = true
		assert media.is_eligible_for_autoplay()
		autoplay_sandbox_drain(media)
	}
}

fn test_autoplay_eligibility_reads_the_live_adopted_document_sandbox() {
	mut media := autoplay_sandbox_owner('video')!
	mut original := media.document()?
	url := dom.URL{
		value: 'https://adopted-autoplay-sandbox.example.test/'
	}
	mut adopted := parse_navigation_document('<body></body>', url, url.origin(), none)!
	adopted.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	assert media.is_eligible_for_autoplay()
	adopted.adopt_node(original.get_element_by_id('player')?.as_node())
	assert voidptr(media.document()?) == voidptr(adopted)
	assert !media.is_eligible_for_autoplay()
	original.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	adopted.set_active_sandboxing_flag_bits(0)
	assert media.is_eligible_for_autoplay()
	adopted.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	assert !media.is_eligible_for_autoplay()
	autoplay_sandbox_drain(media)
}

fn test_sandboxed_autoplay_keeps_automatic_preload_none_deferred_but_explicit_load_fetches() {
	for kind in ['audio', 'video'] {
		mut media := autoplay_sandbox_owner(kind)!
		mut document := media.document()?
		document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
		fetches := &AutoplaySandboxFetches{}
		media.set_fetch_hook(fn [fetches] (_ dom.URL, _ u64) !MediaResourceResponse {
			mut observed := unsafe { &AutoplaySandboxFetches(fetches) }
			observed.count++
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 20, buffered_end: 20 }
		})
		media.set_source('/movie.mp4')
		media.select_resource()!
		assert fetches.count == 0 && media.network_state() == .idle && media.paused()
		assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		assert media.event_count('suspend') == 1 && media.ready_state() == .have_nothing
		assert !document.anything_is_delaying_the_load_event()
		media.set_autoplay(true)
		assert fetches.count == 0 && media.paused()
		media.load()!
		assert fetches.count == 1 && media.paused() && media.ready_state() == .have_enough_data
		assert media.current_resource_selection_is_explicit_ && media.can_autoplay_
		autoplay_sandbox_drain(media)
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
		assert media.event_count('loadeddata') == 1 && media.event_count('canplaythrough') == 1
		media.select_resource()!
		assert fetches.count == 1
			&& media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		// A later resumption consults this document's current flag set.
		document.set_active_sandboxing_flag_bits(0)
		media.set_autoplay(true)
		assert fetches.count == 1 && media.paused()
		media.set_muted(true)
		media.set_autoplay(true)
		assert fetches.count == 2
			&& !media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		autoplay_sandbox_drain(media)
	}
}
