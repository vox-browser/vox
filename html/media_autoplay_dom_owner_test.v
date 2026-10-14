module html

import dom

@[heap]
struct MediaAutoplayDOMProbe {
mut:
	fetches int
	starts int
}

fn media_autoplay_dom_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing autoplay DOM task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn media_autoplay_dom_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn test_media_autoplay_reflection_preserves_parsed_values_live_dom_adoption_and_ownerless_gates() {
	mut document := media_autoplay_dom_document('https://autoplay-dom.example.test/',
		'<!doctype html><video id="autoplay-present" autoplay="false"></video><audio id="autoplay-absent"></audio>')!
	mut destination := media_autoplay_dom_document('https://autoplay-adopted.example.test/', '<body></body>')!
	defer {
		document.finalize()
		destination.finalize()
	}
	mut video_element := document.get_element_by_id('autoplay-present')?
	mut audio_element := document.get_element_by_id('autoplay-absent')?
	assert video_element.get_attribute('autoplay')? == 'false'
	mut video := html_media_element_for_dom_element(video_element)?
	mut audio := html_media_element_for_dom_element(audio_element)?
	assert video.autoplay() && video.is_eligible_for_autoplay()
	assert video_element.get_attribute('autoplay')? == 'false' && !audio.autoplay()
	video_element.remove_attribute('autoplay')
	assert !video.autoplay() && !video.is_eligible_for_autoplay()
	video_element.set_attribute_value('autoplay', 'manual nonempty value')
	assert video.autoplay() && video.is_eligible_for_autoplay()
	assert video_element.get_attribute('autoplay')? == 'manual nonempty value'
	video.set_autoplay(true)
	assert video.autoplay() && video_element.get_attribute('autoplay')? == ''
	video.set_autoplay(false)
	assert !video.autoplay() && !video_element.has_attribute('autoplay')
	audio_element.set_attribute_value('autoplay', 'survives adoption')
	destination.adopt_node(audio_element.as_node())
	assert voidptr(audio_element.document()) == voidptr(destination)
	assert voidptr(html_media_element_for_dom_element(audio_element)?) == voidptr(audio)
	assert audio.autoplay() && audio_element.get_attribute('autoplay')? == 'survives adoption'
	destination.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	assert !audio.is_eligible_for_autoplay()
	destination.set_active_sandboxing_flag_bits(0)
	assert audio.is_eligible_for_autoplay()
	audio_element.remove_attribute('autoplay')
	assert !audio.autoplay() && !audio.is_eligible_for_autoplay()
	audio.set_autoplay(true)
	assert audio.autoplay() && audio_element.get_attribute('autoplay')? == ''
	audio.set_autoplay(false)
	assert !audio.autoplay() && !audio_element.has_attribute('autoplay')
	mut unmaterialized := document.create_element_ns(dom.namespace_html_uri, 'audio')!
	assert unsafe { &dom.HTMLAudioElement(unmaterialized) }.media_element_model_ == unsafe { nil }
	unmaterialized.set_attribute_value('autoplay', 'does not create a model')
	assert unsafe { &dom.HTMLAudioElement(unmaterialized) }.media_element_model_ == unsafe { nil }
	mut svg := document.create_element_ns(dom.namespace_svg_uri, 'video')!
	svg.set_attribute_value('autoplay', 'SVG attribute')
	assert html_media_element_for_dom_element(svg) == none
	for media in [video, audio] {
		assert media.paused() && media.current_time() == 0 && !media.ended()
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert !fallback.autoplay() && !fallback.is_eligible_for_autoplay()
	fallback.set_autoplay(true)
	assert fallback.autoplay() && fallback.autoplay_ && fallback.is_eligible_for_autoplay()
	fallback.can_autoplay_ = false
	assert !fallback.is_eligible_for_autoplay()
	fallback.can_autoplay_ = true
	fallback.allow_autoplay_ = false
	assert !fallback.is_eligible_for_autoplay()
	fallback.allow_autoplay_ = true
	fallback.set_paused(false)
	assert !fallback.is_eligible_for_autoplay()
	fallback.set_paused(true)
	assert fallback.is_eligible_for_autoplay()
	fallback.set_autoplay(false)
	assert !fallback.autoplay() && !fallback.autoplay_ && !fallback.is_eligible_for_autoplay()
}

fn test_media_autoplay_dom_notifications_promote_once_and_use_current_adopted_policy_and_sandbox() {
	mut settings := AutoplaySettings.the()
	previous_policy := settings.policy_
	previous_allowlist := settings.allowlist_.clone()
	defer {
		settings.policy_ = previous_policy
		settings.allowlist_ = previous_allowlist
	}
	settings.set_policy(.block_audio_and_video, [])
	mut document := media_autoplay_dom_document('https://autoplay-notify.example.test/',
		'<!doctype html><video id="autoplay-deferred" preload="none"></video>')!
	mut source := media_autoplay_dom_document('https://autoplay-old.example.test/',
		'<!doctype html><audio id="autoplay-adopt" preload="none"></audio>')!
	mut destination := media_autoplay_dom_document('https://autoplay-new.example.test/', '<body></body>')!
	defer {
		document.finalize()
		source.finalize()
		destination.finalize()
	}
	mut element := document.get_element_by_id('autoplay-deferred')?
	mut media := html_media_element_for_dom_element(element)?
	probe := &MediaAutoplayDOMProbe{}
	media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &MediaAutoplayDOMProbe(probe) }
		observation.fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [probe] () {
			mut observation := unsafe { &MediaAutoplayDOMProbe(probe) }
			observation.starts++
		}
	})
	media.set_source('/deferred.mp4')
	media.select_resource()!
	assert probe.fetches == 0 && media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
	element.set_attribute_value_ns('autoplay', 'namespaced value', 'custom', 'urn:autoplay-test')
	assert element.has_attribute_ns('urn:autoplay-test', 'autoplay') && !media.autoplay()
	assert probe.fetches == 0
	element.remove_attribute_ns('urn:autoplay-test', 'autoplay')
	element.set_attribute_value('autoplay', 'blocked policy')
	assert media.autoplay() && media.is_eligible_for_autoplay() && !media.is_allowed_to_play()
	assert probe.fetches == 0 && media.paused()
	element.remove_attribute('autoplay')
	assert !media.autoplay() && probe.fetches == 0
	settings.set_policy(.allow_audio_and_video, [])
	document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	element.set_attribute_value('autoplay', 'blocked sandbox')
	assert !media.is_eligible_for_autoplay() && media.is_allowed_to_play() && probe.fetches == 0
	element.remove_attribute('autoplay')
	document.set_active_sandboxing_flag_bits(0)
	element.set_attribute_value('autoplay', 'allowed direct mutation')
	assert probe.fetches == 1 && probe.starts == 1 && !media.paused() && media.autoplay()
	assert !media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
	assert media.ready_state() == .have_enough_data
	media_autoplay_dom_drain(media)
	assert media.event_count('play') == 1 && media.event_count('playing') == 1
	element.set_attribute_value('autoplay', 'second present value')
	element.remove_attribute('autoplay')
	media.set_autoplay(true)
	media.set_autoplay(false)
	assert probe.fetches == 1 && probe.starts == 1 && !media.autoplay()
	// Adoption registers notifications in the new document; old-origin permission cannot leak.
	mut adopted_element := source.get_element_by_id('autoplay-adopt')?
	mut adopted := html_media_element_for_dom_element(adopted_element)?
	adopted_probe := &MediaAutoplayDOMProbe{}
	adopted.set_fetch_hook(fn [adopted_probe, adopted_element, destination] (_ dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &MediaAutoplayDOMProbe(adopted_probe) }
		assert voidptr(adopted_element.document()) == voidptr(destination)
		observation.fetches++
		return MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
	})
	adopted.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [adopted_probe] () {
			mut observation := unsafe { &MediaAutoplayDOMProbe(adopted_probe) }
			observation.starts++
		}
	})
	source.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	settings.set_policy(.block_audio_and_video, ['https://autoplay-old.example.test/'])
	adopted.set_source('/adopted.webm')
	adopted.select_resource()!
	adopted_element.set_attribute_value('autoplay', 'old blocked sandbox')
	assert adopted_probe.fetches == 0 && adopted.is_allowed_to_play()
	destination.adopt_node(adopted_element.as_node())
	assert voidptr(adopted.document()?) == voidptr(destination)
	assert !adopted.is_allowed_to_play() && adopted.autoplay()
	adopted_element.remove_attribute('autoplay')
	adopted_element.set_attribute_value('autoplay', 'new blocked policy')
	assert adopted_probe.fetches == 0 && adopted.paused()
	settings.set_policy(.block_audio_and_video, ['https://autoplay-new.example.test/'])
	destination.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	adopted_element.remove_attribute('autoplay')
	adopted_element.set_attribute_value('autoplay', 'new blocked sandbox')
	assert adopted_probe.fetches == 0 && !adopted.is_eligible_for_autoplay()
	adopted_element.remove_attribute('autoplay')
	destination.set_active_sandboxing_flag_bits(0)
	adopted_element.set_attribute_value('autoplay', 'new allowed owner')
	assert adopted_probe.fetches == 1 && adopted_probe.starts == 1 && !adopted.paused()
	assert adopted.autoplay() && adopted_element.get_attribute('autoplay')? == 'new allowed owner'
	media_autoplay_dom_drain(adopted)
	assert adopted.event_count('play') == 1 && adopted.event_count('playing') == 1
	adopted_element.remove_attribute('autoplay')
	adopted.set_autoplay(true)
	adopted.set_autoplay(false)
	assert adopted_probe.fetches == 1 && adopted_probe.starts == 1 && !adopted.autoplay()
}
