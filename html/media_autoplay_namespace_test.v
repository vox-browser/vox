module html

import dom

const man_namespace_first = 'urn:autoplay-namespace-first'
const man_namespace_second = 'urn:autoplay-namespace-second'

@[heap]
struct ManNamespaceProbe {
mut:
	fetches int
	starts int
}

fn man_namespace_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn man_namespace_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing autoplay namespace element ${id}') }
}

fn man_namespace_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'autoplay') or { return error('Missing autoplay namespace attribute') }
}

fn man_namespace_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing autoplay namespace task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_autoplay_namespace_reflection_preserves_attribute_identity_adoption_and_fallback() {
	mut document := man_namespace_document('https://autoplay-namespace.example.test/',
		'<!doctype html><video id="man-video-first"></video><audio id="man-audio-first"></audio><video id="man-video-last"></video><audio id="man-audio-last"></audio>')!
	mut destination := man_namespace_document('https://autoplay-namespace-adopted.example.test/', '<body></body>')!
	defer { document.finalize(); destination.finalize() }
	for kind in ['audio', 'video'] {
		mut foreign_only := document.create_element(kind)!
		foreign_only.set_attribute_ns_for_bindings(man_namespace_first, 'autoplay', 'foreign before materialization')!
		mut initial := html_media_element_for_dom_element(foreign_only) or { panic('Missing initial autoplay owner') }
		assert foreign_only.has_attribute('autoplay') && !initial.autoplay() && !initial.autoplay_
		assert !initial.is_eligible_for_autoplay() && initial.paused()
		initial.set_autoplay(false)
		assert (foreign_only.get_attribute_ns(man_namespace_first, 'autoplay') or { '' }) == 'foreign before materialization'
	}
	for index, id in ['man-video-first', 'man-audio-first', 'man-video-last', 'man-audio-last'] {
		mut element := man_namespace_element(document, id)!
		if index < 2 { element.set_attribute_value('autoplay', 'initial null') }
		element.set_attribute_ns_for_bindings(man_namespace_first, 'autoplay', 'first raw')!
		if index >= 2 { element.set_attribute_value('autoplay', 'initial null') }
		element.set_attribute_ns_for_bindings(man_namespace_second, 'autoplay', 'second raw')!
		first := man_namespace_attribute(element, man_namespace_first)!
		second := man_namespace_attribute(element, man_namespace_second)!
		original_null := man_namespace_attribute(element, none)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing autoplay namespace owner') }
		assert media.autoplay() && media.autoplay_ && original_null.value() == 'initial null'
		media.set_autoplay(false)
		assert !media.autoplay() && !media.is_eligible_for_autoplay() && !element.has_attribute_ns(none, 'autoplay')
		assert element.has_attribute('autoplay') && original_null.owner_element() == none
		media.set_autoplay(false)
		assert element.get_attribute_names().filter(it == 'autoplay').len == 2
		element.set_attribute_value('autoplay', 'direct live null')
		assert media.autoplay() && media.is_eligible_for_autoplay()
		live_null := man_namespace_attribute(element, none)!
		media.set_autoplay(true)
		assert media.autoplay() && live_null.value() == ''
		assert voidptr(man_namespace_attribute(element, none)!) == voidptr(live_null)
		element.remove_attribute_ns(none, 'autoplay')
		// The null-namespace refinement must also ignore an old true fallback cache.
		assert media.autoplay_ && !media.autoplay() && !media.is_eligible_for_autoplay()
		assert live_null.owner_element() == none
		assert voidptr(man_namespace_attribute(element, man_namespace_first)!) == voidptr(first)
		assert voidptr(man_namespace_attribute(element, man_namespace_second)!) == voidptr(second)
		assert first.value() == 'first raw' && second.value() == 'second raw'
		assert voidptr(first.owner_element() or { panic('Missing first foreign owner') }) == voidptr(element)
		assert voidptr(second.owner_element() or { panic('Missing second foreign owner') }) == voidptr(element)
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html_media_element_for_dom_element(element) or { panic('Missing adopted autoplay owner') }) == voidptr(media)
		assert !media.autoplay()
		media.set_autoplay(true)
		assert media.autoplay() && (element.get_attribute_ns(none, 'autoplay') or { 'missing' }) == ''
		media.set_autoplay(false)
		assert !media.autoplay() && !element.has_attribute_ns(none, 'autoplay')
		assert voidptr(man_namespace_attribute(element, man_namespace_first)!) == voidptr(first)
		assert voidptr(man_namespace_attribute(element, man_namespace_second)!) == voidptr(second)
		assert first.value() == 'first raw' && second.value() == 'second raw'
		assert media.paused() && media.current_time() == 0 && !media.ended()
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert !fallback.autoplay() && !fallback.is_eligible_for_autoplay()
	fallback.set_autoplay(true)
	assert fallback.autoplay() && fallback.autoplay_ && fallback.is_eligible_for_autoplay()
	fallback.set_autoplay(false)
	assert !fallback.autoplay() && !fallback.autoplay_ && !fallback.is_eligible_for_autoplay()
	assert fallback.paused() && fallback.queued_media_task_ids_.len == 0
}

fn test_media_autoplay_namespace_foreign_only_selection_defers_until_one_allowed_null_transition() {
	mut settings := AutoplaySettings.the()
	previous_policy := settings.policy_
	previous_allowlist := settings.allowlist_.clone()
	defer { settings.policy_ = previous_policy; settings.allowlist_ = previous_allowlist }
	for kind in ['audio', 'video'] {
		settings.set_policy(.allow_audio_and_video, [])
		mut document := man_namespace_document('https://autoplay-namespace-fetch.example.test/',
			'<!doctype html><${kind} id="man-deferred" preload="none"></${kind}>')!
		defer { document.finalize() }
		mut element := man_namespace_element(document, 'man-deferred')!
		element.set_attribute_ns_for_bindings(man_namespace_first, 'autoplay', 'first deferred raw')!
		element.set_attribute_ns_for_bindings(man_namespace_second, 'autoplay', 'second deferred raw')!
		first := man_namespace_attribute(element, man_namespace_first)!
		second := man_namespace_attribute(element, man_namespace_second)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing deferred autoplay owner') }
		probe := &ManNamespaceProbe{}
		media.set_fetch_hook(fn [probe, element] (_ dom.URL, offset u64) !MediaResourceResponse {
			assert offset == 0 && element.has_attribute_ns(none, 'autoplay')
			mut observation := unsafe { &ManNamespaceProbe(probe) }
			observation.fetches++
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
		})
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			play: fn [probe] () {
				mut observation := unsafe { &ManNamespaceProbe(probe) }
				observation.starts++
			}
		})
		media.set_source('https://autoplay-namespace-fetch.example.test/deferred.mp4')
		media.select_resource()!
		assert !media.autoplay_ && !media.autoplay() && !media.is_eligible_for_autoplay() && media.is_allowed_to_play()
		assert probe.fetches == 0 && probe.starts == 0 && media.paused() && media.network_state() == .idle
		assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ && !media.current_resource_selection_is_explicit_
		element.set_attribute_ns_for_bindings(man_namespace_first, 'autoplay', 'first changed raw')!
		element.set_attribute_ns_for_bindings(man_namespace_second, 'autoplay', 'second changed raw')!
		element.set_attribute_ns_for_bindings('urn:autoplay-prefixed', 'p:autoplay', 'prefixed raw')!
		media.set_autoplay(false)
		assert !media.autoplay() && probe.fetches == 0 && probe.starts == 0 && media.paused()
		assert voidptr(man_namespace_attribute(element, man_namespace_first)!) == voidptr(first)
		assert voidptr(man_namespace_attribute(element, man_namespace_second)!) == voidptr(second)
		assert first.value() == 'first changed raw' && second.value() == 'second changed raw'
		settings.set_policy(.block_audio_and_video, [])
		element.set_attribute_value('autoplay', 'blocked policy')
		assert media.autoplay() && media.is_eligible_for_autoplay() && !media.is_allowed_to_play() && probe.fetches == 0
		media.set_autoplay(false)
		settings.set_policy(.allow_audio_and_video, [])
		document.set_active_sandboxing_flag_bits(u32(SandboxingFlag.sandboxed_automatic_features))
		element.set_attribute_value('autoplay', 'blocked sandbox')
		assert media.autoplay() && !media.is_eligible_for_autoplay() && media.is_allowed_to_play() && probe.fetches == 0
		element.remove_attribute_ns(none, 'autoplay')
		document.set_active_sandboxing_flag_bits(0)
		assert !media.autoplay() && probe.fetches == 0 && media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		element.set_attribute_value('autoplay', 'allowed actual null slot')
		assert media.autoplay() && probe.fetches == 1 && probe.starts == 1 && !media.paused()
		assert !media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ && media.ready_state() == .have_enough_data
		man_namespace_drain(media)
		assert media.event_count('play') == 1 && media.event_count('playing') == 1
		element.set_attribute_value('autoplay', 'second true value')
		media.set_autoplay(false)
		media.set_autoplay(true)
		media.set_autoplay(false)
		assert !media.autoplay() && probe.fetches == 1 && probe.starts == 1 && !media.paused()
		assert voidptr(man_namespace_attribute(element, man_namespace_first)!) == voidptr(first)
		assert voidptr(man_namespace_attribute(element, man_namespace_second)!) == voidptr(second)
		assert first.value() == 'first changed raw' && second.value() == 'second changed raw'
		assert (element.get_attribute_ns('urn:autoplay-prefixed', 'autoplay') or { '' }) == 'prefixed raw'
		assert media.event_count('pause') == 0 && media.event_count('ended') == 0
	}
}
