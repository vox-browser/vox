module html

import dom

const mpn_namespace_first = 'urn:preload-namespace-first'
const mpn_namespace_second = 'urn:preload-namespace-second'
const mpn_namespace_prefixed = 'urn:preload-namespace-prefixed'

@[heap]
struct MpnNamespaceProbe {
mut:
	fetches int
	starts int
}

fn mpn_namespace_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn mpn_namespace_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing preload namespace element ${id}') }
}

fn mpn_namespace_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'preload') or { return error('Missing preload namespace attribute') }
}

fn mpn_namespace_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing preload namespace task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_preload_namespace_raw_reflection_preserves_attributes_adoption_and_fallback() {
	mut document := mpn_namespace_document('https://preload-namespace.example.test/',
		'<!doctype html><video id="mpn-video-first"></video><audio id="mpn-audio-first"></audio><video id="mpn-video-last"></video><audio id="mpn-audio-last"></audio>')!
	mut destination := mpn_namespace_document('https://preload-namespace-adopted.example.test/', '<body></body>')!
	defer { document.finalize(); destination.finalize() }
	for kind in ['audio', 'video'] {
		mut foreign_only := document.create_element(kind)!
		foreign_only.set_attribute_ns_for_bindings(mpn_namespace_first, 'preload', 'none')!
		foreign_only.set_attribute_ns_for_bindings(mpn_namespace_second, 'preload', 'auto')!
		initial := html_media_element_for_dom_element(foreign_only) or { panic('Missing initial preload owner') }
		assert foreign_only.has_attribute('preload') && initial.preload_ == none && initial.raw_preload() == none
		assert initial.preload() == 'metadata' && !initial.preload_attribute_is_in_none_state()
	}
	raws := ['NoNe', 'AUTO', '', ' none ', 'NONE\u00a0', 'ＮＯＮＥ', 'none\x00', 'MeTaDaTa']
	canonical := ['none', 'auto', 'metadata', 'metadata', 'metadata', 'metadata', 'metadata', 'metadata']
	for index, id in ['mpn-video-first', 'mpn-audio-first', 'mpn-video-last', 'mpn-audio-last'] {
		mut element := mpn_namespace_element(document, id)!
		if index < 2 { element.set_attribute_value('preload', 'NoNe') }
		element.set_attribute_ns_for_bindings(mpn_namespace_first, 'preload', 'foreign first raw')!
		if index >= 2 { element.set_attribute_value('preload', 'NoNe') }
		element.set_attribute_ns_for_bindings(mpn_namespace_second, 'preload', 'foreign second raw')!
		element.set_attribute_ns_for_bindings(mpn_namespace_prefixed, 'p:preload', 'prefixed raw')!
		first := mpn_namespace_attribute(element, mpn_namespace_first)!
		second := mpn_namespace_attribute(element, mpn_namespace_second)!
		prefixed := mpn_namespace_attribute(element, mpn_namespace_prefixed)!
		original_null := mpn_namespace_attribute(element, none)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing preload namespace owner') }
		assert (media.preload_ or { '' }) == 'NoNe' && (media.raw_preload() or { '' }) == 'NoNe'
		assert media.preload() == 'none' && original_null.value() == 'NoNe'
		media.set_preload(none)
		assert media.raw_preload() == none && media.preload() == 'metadata' && media.preload_ == none
		assert original_null.owner_element() == none && element.has_attribute('preload') && !element.has_attribute_ns(none, 'preload')
		media.set_preload(none)
		assert element.get_attribute_names().filter(it == 'preload').len == 2
		for raw_index, raw in raws {
			element.set_attribute_value('preload', raw)
			live_null := mpn_namespace_attribute(element, none)!
			assert (media.raw_preload() or { 'missing' }) == raw && media.preload() == canonical[raw_index]
			media.set_preload(raw)
			assert (media.preload_ or { 'missing' }) == raw && (media.raw_preload() or { 'missing' }) == raw
			assert media.preload() == canonical[raw_index] && live_null.value() == raw
			assert voidptr(mpn_namespace_attribute(element, none)!) == voidptr(live_null)
		}
		element.remove_attribute_ns(none, 'preload')
		// The retained raw cache cannot override null-namespace absence on a DOM owner.
		assert (media.preload_ or { '' }) == 'MeTaDaTa' && media.raw_preload() == none && media.preload() == 'metadata'
		media.set_preload('AuTo')
		adopted_null := mpn_namespace_attribute(element, none)!
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html_media_element_for_dom_element(element) or { panic('Missing adopted preload owner') }) == voidptr(media)
		assert (media.raw_preload() or { '' }) == 'AuTo' && media.preload() == 'auto'
		assert voidptr(mpn_namespace_attribute(element, none)!) == voidptr(adopted_null)
		media.set_preload(none)
		assert media.raw_preload() == none && media.preload() == 'metadata' && adopted_null.owner_element() == none
		for foreign_index, attribute in [first, second, prefixed] {
			namespace := [mpn_namespace_first, mpn_namespace_second, mpn_namespace_prefixed][foreign_index]
			assert voidptr(mpn_namespace_attribute(element, namespace)!) == voidptr(attribute)
			assert voidptr(attribute.owner_element() or { panic('Missing foreign preload owner') }) == voidptr(element)
		}
		assert first.value() == 'foreign first raw' && second.value() == 'foreign second raw'
		assert prefixed.value() == 'prefixed raw' && prefixed.name() == 'p:preload' && (prefixed.prefix() or { '' }) == 'p'
		assert media.paused() && media.current_time() == 0 && !media.ended()
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'pause'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert fallback.raw_preload() == none && fallback.preload() == 'metadata'
	for index, raw in raws {
		fallback.set_preload(raw)
		assert (fallback.raw_preload() or { 'missing' }) == raw && fallback.preload() == canonical[index]
	}
	fallback.set_preload(none)
	assert fallback.preload_ == none && fallback.raw_preload() == none && fallback.preload() == 'metadata'
	assert fallback.paused() && fallback.queued_media_task_ids_.len == 0
}

fn test_media_preload_namespace_selection_ignores_foreign_none_and_promotes_real_none_once() {
	mut settings := AutoplaySettings.the()
	previous_policy := settings.policy_
	previous_allowlist := settings.allowlist_.clone()
	defer { settings.policy_ = previous_policy; settings.allowlist_ = previous_allowlist }
	settings.set_policy(.allow_audio_and_video, [])
	for kind in ['audio', 'video'] {
		mut immediate_document := mpn_namespace_document('https://preload-namespace-fetch.example.test/',
			'<!doctype html><${kind} id="mpn-immediate"></${kind}>')!
		defer { immediate_document.finalize() }
		mut immediate_element := mpn_namespace_element(immediate_document, 'mpn-immediate')!
		immediate_element.set_attribute_ns_for_bindings(mpn_namespace_first, 'preload', 'none')!
		foreign_none := mpn_namespace_attribute(immediate_element, mpn_namespace_first)!
		mut immediate := html_media_element_for_dom_element(immediate_element) or { panic('Missing immediate preload owner') }
		immediate_probe := &MpnNamespaceProbe{}
		immediate.set_fetch_hook(fn [immediate_probe] (_ dom.URL, offset u64) !MediaResourceResponse {
			assert offset == 0
			mut observation := unsafe { &MpnNamespaceProbe(immediate_probe) }
			observation.fetches++
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
		})
		immediate.set_source('https://preload-namespace-fetch.example.test/immediate.mp4')
		immediate.select_resource()!
		assert immediate.raw_preload() == none && immediate.preload() == 'metadata' && immediate_probe.fetches == 1
		assert !immediate.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ && !immediate.current_resource_selection_is_explicit_
		assert immediate.ready_state() == .have_enough_data && immediate.paused()
		mpn_namespace_drain(immediate)
		assert immediate.event_count('play') == 0 && immediate.event_count('playing') == 0
		assert voidptr(mpn_namespace_attribute(immediate_element, mpn_namespace_first)!) == voidptr(foreign_none) && foreign_none.value() == 'none'
		for promotion in ['direct-metadata', 'model-remove', 'direct-remove'] {
			mut document := mpn_namespace_document('https://preload-namespace-fetch.example.test/',
				'<!doctype html><${kind} id="mpn-deferred"></${kind}>')!
			defer { document.finalize() }
			mut element := mpn_namespace_element(document, 'mpn-deferred')!
			element.set_attribute_ns_for_bindings(mpn_namespace_first, 'preload', 'auto')!
			element.set_attribute_value('preload', 'NoNe')
			element.set_attribute_ns_for_bindings(mpn_namespace_second, 'preload', 'none')!
			first := mpn_namespace_attribute(element, mpn_namespace_first)!
			second := mpn_namespace_attribute(element, mpn_namespace_second)!
			mut media := html_media_element_for_dom_element(element) or { panic('Missing deferred preload owner') }
			probe := &MpnNamespaceProbe{}
			media.set_fetch_hook(fn [probe] (_ dom.URL, offset u64) !MediaResourceResponse {
				assert offset == 0
				mut observation := unsafe { &MpnNamespaceProbe(probe) }
				observation.fetches++
				return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
			})
			media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
				play: fn [probe] () {
					mut observation := unsafe { &MpnNamespaceProbe(probe) }
					observation.starts++
				}
			})
			media.set_source('https://preload-namespace-fetch.example.test/deferred.mp4')
			media.select_resource()!
			assert (media.raw_preload() or { '' }) == 'NoNe' && media.preload() == 'none'
			assert probe.fetches == 0 && media.paused() && media.network_state() == .idle
			assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ && !media.current_resource_selection_is_explicit_
			element.set_attribute_ns_for_bindings(mpn_namespace_first, 'preload', 'metadata')!
			element.set_attribute_ns_for_bindings(mpn_namespace_second, 'preload', 'auto')!
			element.set_attribute_ns_for_bindings(mpn_namespace_prefixed, 'p:preload', 'auto')!
			assert (media.raw_preload() or { '' }) == 'NoNe' && media.preload() == 'none' && probe.fetches == 0
			match promotion {
				'direct-metadata' { element.set_attribute_value('preload', 'MeTaDaTa') }
				'model-remove' { media.set_preload(none) }
				else { element.remove_attribute_ns(none, 'preload') }
			}
			assert media.preload() == 'metadata' && probe.fetches == 1 && probe.starts == 0 && media.paused()
			assert !media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_ && media.ready_state() == .have_enough_data
			mpn_namespace_drain(media)
			media.set_preload('none')
			media.set_preload(none)
			element.set_attribute_value('preload', 'auto')
			element.remove_attribute_ns(none, 'preload')
			assert media.raw_preload() == none && media.preload() == 'metadata' && probe.fetches == 1 && probe.starts == 0
			assert voidptr(mpn_namespace_attribute(element, mpn_namespace_first)!) == voidptr(first)
			assert voidptr(mpn_namespace_attribute(element, mpn_namespace_second)!) == voidptr(second)
			assert first.value() == 'metadata' && second.value() == 'auto'
			assert (element.get_attribute_ns(mpn_namespace_prefixed, 'preload') or { '' }) == 'auto'
			for name in ['play', 'playing', 'pause', 'ended'] { assert media.event_count(name) == 0 }
		}
	}
}
