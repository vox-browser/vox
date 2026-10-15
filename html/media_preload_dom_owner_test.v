module html

import dom

@[heap]
struct MediaPreloadDOMProbe {
mut:
	fetches   int
	starts    int
	owner_ids []dom.UniqueNodeID
}

fn media_preload_dom_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn media_preload_dom_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing preload DOM task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_preload_reflection_preserves_raw_parser_values_live_dom_adoption_and_fallback() {
	mut document := media_preload_dom_document('https://preload-dom.example.test/',
		'<!doctype html><video id="preload-present" preload="NoNe"></video><audio id="preload-absent"></audio>')!
	mut destination := media_preload_dom_document('https://preload-adopted.example.test/', '<body></body>')!
	defer {
		document.finalize()
		destination.finalize()
	}
	mut video_element := document.get_element_by_id('preload-present')?
	mut audio_element := document.get_element_by_id('preload-absent')?
	assert video_element.get_attribute('preload')? == 'NoNe'
	mut video := html_media_element_for_dom_element(video_element)?
	mut audio := html_media_element_for_dom_element(audio_element)?
	assert video.preload() == 'none' && video.raw_preload()? == 'NoNe'
	assert video_element.get_attribute('preload')? == 'NoNe'
	assert audio.preload() == 'metadata' && audio.raw_preload() == none
	values := ['', 'invalid', ' none ', 'auto\t', 'NONE\u00a0', 'ＮＯＮＥ',
		'none\x00', 'nOnE', 'AUTO', 'MeTaDaTa']
	expected := ['metadata', 'metadata', 'metadata', 'metadata', 'metadata',
		'metadata', 'metadata', 'none', 'auto', 'metadata']
	for index, raw in values {
		video_element.set_attribute_value('preload', raw)
		assert video_element.get_attribute('preload')? == raw
		assert video.raw_preload()? == raw && video.preload() == expected[index]
		video.set_preload(raw)
		assert video_element.get_attribute('preload')? == raw
		assert video.raw_preload()? == raw && video.preload() == expected[index]
	}
	video.set_preload('none')
	video_element.remove_attribute('preload')
	// The retained fallback cannot override absence in an associated DOM owner.
	assert video.preload_? == 'none' && video.raw_preload() == none
	assert video.preload() == 'metadata' && !video.preload_attribute_is_in_none_state()
	video.set_preload(none)
	assert video.preload_ == none && !video_element.has_attribute('preload')
	audio_element.set_attribute_value('preload', 'MeTaDaTa')
	destination.adopt_node(audio_element.as_node())
	assert voidptr(audio_element.document()) == voidptr(destination)
	assert voidptr(html_media_element_for_dom_element(audio_element)?) == voidptr(audio)
	assert audio.raw_preload()? == 'MeTaDaTa' && audio.preload() == 'metadata'
	audio_element.set_attribute_value('preload', 'AuTo')
	assert audio.raw_preload()? == 'AuTo' && audio.preload() == 'auto'
	audio.set_preload(none)
	assert audio.raw_preload() == none && audio.preload() == 'metadata'
	mut unmaterialized := document.create_element_ns(dom.namespace_html_uri, 'audio')!
	assert unsafe { &dom.HTMLAudioElement(unmaterialized) }.media_element_model_ == unsafe { nil }
	unmaterialized.set_attribute_value('preload', 'does not create a model')
	assert unsafe { &dom.HTMLAudioElement(unmaterialized) }.media_element_model_ == unsafe { nil }
	mut svg := document.create_element_ns(dom.namespace_svg_uri, 'video')!
	svg.set_attribute_value('preload', 'none')
	assert html_media_element_for_dom_element(svg) == none
	audio_element.set_attribute_value_ns('preload', 'none', 'custom', 'urn:preload-test')
	assert audio_element.has_attribute_ns('urn:preload-test', 'preload')
	assert audio.raw_preload() == none && audio.preload() == 'metadata'
	for media in [video, audio] {
		assert media.paused() && media.current_time() == 0 && !media.ended()
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert fallback.raw_preload() == none && fallback.preload() == 'metadata'
	for index, raw in values {
		fallback.set_preload(raw)
		assert fallback.preload_? == raw && fallback.raw_preload()? == raw
		assert fallback.preload() == expected[index]
	}
	fallback.set_preload(none)
	assert fallback.raw_preload() == none && fallback.preload() == 'metadata'
	assert fallback.paused() && fallback.queued_media_task_ids_.len == 0
}

fn test_media_preload_notifications_promote_once_preserve_autoplay_gates_and_follow_adoption() {
	mut settings := AutoplaySettings.the()
	previous_policy := settings.policy_
	previous_allowlist := settings.allowlist_.clone()
	defer {
		settings.policy_ = previous_policy
		settings.allowlist_ = previous_allowlist
	}
	settings.set_policy(.block_audio_and_video, [])
	for kind in ['audio', 'video'] {
		for promotion in ['direct-metadata', 'model-padded', 'direct-remove'] {
			mut document := media_preload_dom_document('https://preload-promote.example.test/',
				'<!doctype html><${kind} id="preload-owner" preload="NoNe" autoplay="blocked"></${kind}>')!
			mut element := document.get_element_by_id('preload-owner')?
			mut media := html_media_element_for_dom_element(element)?
			probe := &MediaPreloadDOMProbe{}
			media.set_fetch_hook(fn [probe, element] (_ dom.URL, offset u64) !MediaResourceResponse {
				assert offset == 0
				mut observation := unsafe { &MediaPreloadDOMProbe(probe) }
				observation.fetches++
				observation.owner_ids << element.document().unique_id()
				return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
			})
			media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
				play: fn [probe] () {
					mut observation := unsafe { &MediaPreloadDOMProbe(probe) }
					observation.starts++
				}
			})
			document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
			media.set_source('/automatic.mp4')
			media.select_resource()!
			assert probe.fetches == 0 && media.network_state() == .idle
			assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
			assert !media.current_resource_selection_is_explicit_
			assert !media.is_eligible_for_autoplay() && !media.is_allowed_to_play()
			element.set_attribute_value_ns('preload', 'auto', 'custom', 'urn:preload-test')
			assert probe.fetches == 0 && media.raw_preload()? == 'NoNe'
			element.set_attribute_value('preload', 'NONE')
			assert media.preload() == 'none' && probe.fetches == 0
			match promotion {
				'direct-metadata' { element.set_attribute_value('preload', 'MeTaDaTa') }
				'model-padded' { media.set_preload(' none ') }
				else { element.remove_attribute('preload') }
			}
			assert media.preload() == 'metadata'
			assert probe.fetches == 1 && probe.starts == 0 && media.paused()
			assert probe.owner_ids == [document.unique_id()]
			assert !media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
			assert media.ready_state() == .have_enough_data
			media_preload_dom_drain(media)
			assert media.event_count('play') == 0 && media.event_count('playing') == 0
			element.set_attribute_value('preload', 'none')
			media.set_preload('auto')
			element.remove_attribute('preload')
			media.set_preload(none)
			assert probe.fetches == 1 && probe.starts == 0
			// Explicit load remains independent of both preload and autoplay permission.
			media.set_preload('none')
			media.load()!
			assert probe.fetches == 2 && probe.starts == 0 && media.paused()
			assert media.current_resource_selection_is_explicit_ && media.preload() == 'none'
			media_preload_dom_drain(media)
			assert media.event_count('play') == 0 && media.event_count('playing') == 0
			document.finalize()
		}
	}
	mut source := media_preload_dom_document('https://preload-old.example.test/',
		'<!doctype html><audio id="preload-adopt" preload="none" autoplay></audio>')!
	mut destination := media_preload_dom_document('https://preload-new.example.test/', '<body></body>')!
	defer {
		source.finalize()
		destination.finalize()
	}
	mut element := source.get_element_by_id('preload-adopt')?
	mut media := html_media_element_for_dom_element(element)?
	probe := &MediaPreloadDOMProbe{}
	media.set_fetch_hook(fn [probe, element] (_ dom.URL, offset u64) !MediaResourceResponse {
		assert offset == 0
		mut observation := unsafe { &MediaPreloadDOMProbe(probe) }
		observation.fetches++
		observation.owner_ids << element.document().unique_id()
		return MediaResourceResponse{ mime_type: 'audio/webm', duration: 5, buffered_end: 5 }
	})
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		play: fn [probe] () {
			mut observation := unsafe { &MediaPreloadDOMProbe(probe) }
			observation.starts++
		}
	})
	source.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	settings.set_policy(.block_audio_and_video, ['https://preload-old.example.test/'])
	media.set_source('/adopted.webm')
	media.select_resource()!
	assert probe.fetches == 0 && media.is_allowed_to_play() && !media.is_eligible_for_autoplay()
	destination.adopt_node(element.as_node())
	assert voidptr(media.document()?) == voidptr(destination)
	assert media.raw_preload()? == 'none' && !media.is_allowed_to_play()
	element.set_attribute_value('preload', 'NONE')
	assert probe.fetches == 0 && media.is_eligible_for_autoplay()
	settings.set_policy(.block_audio_and_video, ['https://preload-new.example.test/'])
	destination.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
	element.set_attribute_value('preload', 'none')
	assert probe.fetches == 0 && media.is_allowed_to_play() && !media.is_eligible_for_autoplay()
	// The destination's registered hook promotes this existing owner, despite blocked autoplay.
	element.set_attribute_value('preload', 'metadata')
	assert probe.fetches == 1 && probe.starts == 0 && media.paused()
	assert probe.owner_ids == [destination.unique_id()]
	media_preload_dom_drain(media)
	assert media.event_count('play') == 0 && media.event_count('playing') == 0
	media.set_preload('none')
	destination.set_active_sandboxing_flag_bits(0)
	media.select_resource()!
	assert probe.fetches == 2 && probe.starts == 1 && !media.paused()
	assert media.preload() == 'none' && media.is_allowed_to_play()
	assert !media.current_resource_selection_is_explicit_
	assert probe.owner_ids == [destination.unique_id(), destination.unique_id()]
	media_preload_dom_drain(media)
	assert media.event_count('play') == 1 && media.event_count('playing') == 1
	media.set_preload('auto')
	media.set_preload(none)
	assert probe.fetches == 2 && probe.starts == 1
}
