module html

import dom

const mcn_namespace_first = 'urn:crossorigin-namespace-first'
const mcn_namespace_second = 'urn:crossorigin-namespace-second'
const mcn_namespace_prefixed = 'urn:crossorigin-namespace-prefixed'

@[heap]
struct McnNamespaceProbe {
mut:
	media_fetches int
	track_modes []CORSSettingAttribute
	track_urls []string
	track_owners []dom.UniqueNodeID
}

fn mcn_namespace_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn mcn_namespace_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing crossorigin namespace element ${id}') }
}

fn mcn_namespace_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'crossorigin') or { return error('Missing crossorigin namespace attribute') }
}

fn mcn_namespace_load_track(element &dom.Element, probe &McnNamespaceProbe, index int) ! {
	mut document := element.document()
	mut track_element := document.create_element_ns(dom.namespace_html_uri, 'track')!
	track_element.set_attribute_value('kind', 'subtitles')
	track_element.set_attribute_value('src', 'captions-${index}.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(track_element) }
	mut track := html_track_element_model_for_dom_element(track_dom)
	track.set_fetch_hook(fn [probe, element] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut observation := unsafe { &McnNamespaceProbe(probe) }
		observation.track_modes << cors
		observation.track_urls << url.serialize()
		observation.track_owners << element.document().unique_id()
		return TextTrackResourceResponse{ body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nnamespace CORS cue' }
	})
	mut parent := element.as_node()
	parent.append_child(track_element.as_node())!
	html_track_element_inserted(track_dom)
	parent_media := track.parent_media_ or { return error('Missing track parent media') }
	expected_media := html_media_element_for_dom_element(element) or { return error('Missing actual media owner') }
	assert voidptr(parent_media) == voidptr(expected_media)
	assert track.track.kind() == .subtitles && track.track.mode() == .hidden
	assert track.ready_state() == .loaded && track.event_count('load') == 1 && track.event_count('error') == 0
	assert track.track.cues().length() == 1
	cue := track.track.cues().item(0) or { return error('Missing namespace CORS cue') }
	assert cue.text() == 'namespace CORS cue'
}

fn mcn_namespace_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing crossorigin namespace task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_crossorigin_namespace_reflection_preserves_raw_identity_adoption_and_fallback() {
	mut document := mcn_namespace_document('https://crossorigin-namespace.example.test/',
		'<!doctype html><video id="mcn-video-first"></video><audio id="mcn-audio-first"></audio><video id="mcn-video-last"></video><audio id="mcn-audio-last"></audio>')!
	mut destination := mcn_namespace_document('https://crossorigin-namespace-adopted.example.test/', '<body></body>')!
	defer { document.finalize(); destination.finalize() }
	for kind in ['audio', 'video'] {
		mut foreign_only := document.create_element(kind)!
		foreign_only.set_attribute_ns_for_bindings(mcn_namespace_first, 'crossorigin', 'use-credentials')!
		initial := html_media_element_for_dom_element(foreign_only) or { panic('Missing initial crossorigin owner') }
		assert foreign_only.has_attribute('crossorigin') && initial.crossorigin_ == .no_cors
		assert initial.cross_origin() == none && initial.crossorigin() == .no_cors
	}
	raws := ['', 'invalid', 'ANONYMOUS', 'UsE-CrEdEnTiAlS', ' use-credentials ', 'use-credentials\u00a0', 'ＵＳＥ－ＣＲＥＤＥＮＴＩＡＬＳ', 'use-credentials\x00']
	for index, id in ['mcn-video-first', 'mcn-audio-first', 'mcn-video-last', 'mcn-audio-last'] {
		mut element := mcn_namespace_element(document, id)!
		if index < 2 { element.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS') }
		element.set_attribute_ns_for_bindings(mcn_namespace_first, 'crossorigin', 'foreign first raw')!
		if index >= 2 { element.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS') }
		element.set_attribute_ns_for_bindings(mcn_namespace_second, 'crossorigin', 'use-credentials')!
		element.set_attribute_ns_for_bindings(mcn_namespace_prefixed, 'p:crossorigin', 'prefixed raw')!
		first := mcn_namespace_attribute(element, mcn_namespace_first)!
		second := mcn_namespace_attribute(element, mcn_namespace_second)!
		prefixed := mcn_namespace_attribute(element, mcn_namespace_prefixed)!
		original_null := mcn_namespace_attribute(element, none)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing crossorigin namespace owner') }
		assert media.crossorigin_ == .use_credentials && media.crossorigin() == .use_credentials
		assert (media.cross_origin() or { '' }) == 'use-credentials' && original_null.value() == 'UsE-CrEdEnTiAlS'
		media.set_crossorigin(none)
		assert media.cross_origin() == none && media.crossorigin() == .no_cors && media.crossorigin_ == .no_cors
		assert original_null.owner_element() == none && element.has_attribute('crossorigin') && !element.has_attribute_ns(none, 'crossorigin')
		media.set_crossorigin(none)
		assert element.get_attribute_names().filter(it == 'crossorigin').len == 2
		for raw_index, raw in raws {
			expected := if raw_index == 3 { 'use-credentials' } else { 'anonymous' }
			expected_mode := if raw_index == 3 { CORSSettingAttribute.use_credentials } else { CORSSettingAttribute.anonymous }
			element.set_attribute_value('crossorigin', raw)
			live_null := mcn_namespace_attribute(element, none)!
			assert (media.cross_origin() or { 'missing' }) == expected && media.crossorigin() == expected_mode
			media.set_crossorigin(raw)
			assert media.crossorigin_ == expected_mode && (media.cross_origin() or { 'missing' }) == expected
			assert voidptr(mcn_namespace_attribute(element, none)!) == voidptr(live_null) && live_null.value() == raw
		}
		media.set_crossorigin('use-credentials')
		element.remove_attribute_ns(none, 'crossorigin')
		assert media.crossorigin_ == .use_credentials && media.crossorigin() == .no_cors && media.cross_origin() == none
		element.set_attribute_value('crossorigin', 'ANONYMOUS')
		adopted_null := mcn_namespace_attribute(element, none)!
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html_media_element_for_dom_element(element) or { panic('Missing adopted crossorigin owner') }) == voidptr(media)
		assert (media.cross_origin() or { '' }) == 'anonymous' && media.crossorigin() == .anonymous
		assert voidptr(mcn_namespace_attribute(element, none)!) == voidptr(adopted_null) && adopted_null.value() == 'ANONYMOUS'
		media.set_crossorigin(none)
		assert media.cross_origin() == none && media.crossorigin() == .no_cors && adopted_null.owner_element() == none
		for foreign_index, attribute in [first, second, prefixed] {
			namespace := [mcn_namespace_first, mcn_namespace_second, mcn_namespace_prefixed][foreign_index]
			assert voidptr(mcn_namespace_attribute(element, namespace)!) == voidptr(attribute)
			assert voidptr(attribute.owner_element() or { panic('Missing foreign crossorigin owner') }) == voidptr(element)
		}
		assert first.value() == 'foreign first raw' && second.value() == 'use-credentials'
		assert prefixed.value() == 'prefixed raw' && prefixed.name() == 'p:crossorigin' && (prefixed.prefix() or { '' }) == 'p'
		assert media.paused() && media.current_time() == 0 && !media.ended()
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'emptied'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert fallback.cross_origin() == none && fallback.crossorigin() == .no_cors
	for index, raw in raws {
		expected := if index == 3 { 'use-credentials' } else { 'anonymous' }
		expected_mode := if index == 3 { CORSSettingAttribute.use_credentials } else { CORSSettingAttribute.anonymous }
		fallback.set_crossorigin(raw)
		assert fallback.crossorigin() == expected_mode && (fallback.cross_origin() or { '' }) == expected
	}
	fallback.set_crossorigin(none)
	assert fallback.cross_origin() == none && fallback.crossorigin_ == .no_cors && fallback.crossorigin() == .no_cors
}

fn test_media_crossorigin_namespace_real_track_fetches_read_live_null_slot_after_adoption() {
	for kind in ['audio', 'video'] {
		mut document := mcn_namespace_document('https://crossorigin-namespace-source.example.test/base/',
			'<!doctype html><${kind} id="mcn-owner" preload="none"></${kind}>')!
		mut destination := mcn_namespace_document('https://crossorigin-namespace-target.example.test/next/', '<body></body>')!
		defer { document.finalize(); destination.finalize() }
		mut element := mcn_namespace_element(document, 'mcn-owner')!
		element.set_attribute_ns_for_bindings(mcn_namespace_first, 'crossorigin', 'use-credentials')!
		element.set_attribute_ns_for_bindings(mcn_namespace_second, 'crossorigin', 'anonymous')!
		first := mcn_namespace_attribute(element, mcn_namespace_first)!
		second := mcn_namespace_attribute(element, mcn_namespace_second)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing track media owner') }
		probe := &McnNamespaceProbe{}
		media.set_fetch_hook(fn [probe] (_ dom.URL, offset u64) !MediaResourceResponse {
			assert offset == 0
			mut observation := unsafe { &McnNamespaceProbe(probe) }
			observation.media_fetches++
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
		})
		media.set_source('https://crossorigin-namespace-source.example.test/base/movie.mp4')
		media.select_resource()!
		assert probe.media_fetches == 0 && media.network_state() == .idle && media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		media.set_current_playback_position(2.5)
		media.set_official_playback_position(2.5)
		before_events := media.event_counts_.clone()
		before_source := media.current_src()
		mcn_namespace_load_track(element, probe, 0)!
		element.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS')
		mcn_namespace_load_track(element, probe, 1)!
		media.set_crossorigin(' use-credentials ')
		mcn_namespace_load_track(element, probe, 2)!
		element.remove_attribute_ns(none, 'crossorigin')
		mcn_namespace_load_track(element, probe, 3)!
		element.set_attribute_ns_for_bindings(mcn_namespace_first, 'crossorigin', 'anonymous')!
		element.set_attribute_ns_for_bindings(mcn_namespace_second, 'crossorigin', 'use-credentials')!
		mcn_namespace_load_track(element, probe, 4)!
		assert probe.track_modes == [CORSSettingAttribute.no_cors, .use_credentials, .anonymous, .no_cors, .no_cors]
		assert probe.track_owners == [document.unique_id(), document.unique_id(), document.unique_id(), document.unique_id(), document.unique_id()]
		for index in 0 .. 5 { assert probe.track_urls[index] == 'https://crossorigin-namespace-source.example.test/base/captions-${index}.vtt' }
		assert probe.media_fetches == 0 && media.current_src() == before_source && media.event_counts_ == before_events && media.current_time() == 2.5
		destination.adopt_node(element.as_node())
		assert voidptr(media.document() or { panic('Missing adopted media document') }) == voidptr(destination)
		mcn_namespace_load_track(element, probe, 5)!
		element.set_attribute_value('crossorigin', '')
		mcn_namespace_load_track(element, probe, 6)!
		media.set_crossorigin('use-credentials')
		mcn_namespace_load_track(element, probe, 7)!
		media.set_crossorigin(none)
		mcn_namespace_load_track(element, probe, 8)!
		assert probe.track_modes[5..] == [CORSSettingAttribute.no_cors, .anonymous, .use_credentials, .no_cors]
		assert probe.track_owners[5..] == [destination.unique_id(), destination.unique_id(), destination.unique_id(), destination.unique_id()]
		for index in 5 .. 9 { assert probe.track_urls[index] == 'https://crossorigin-namespace-target.example.test/next/captions-${index}.vtt' }
		assert voidptr(mcn_namespace_attribute(element, mcn_namespace_first)!) == voidptr(first)
		assert voidptr(mcn_namespace_attribute(element, mcn_namespace_second)!) == voidptr(second)
		assert first.value() == 'anonymous' && second.value() == 'use-credentials' && !element.has_attribute_ns(none, 'crossorigin')
		assert probe.media_fetches == 0 && media.current_src() == before_source && media.event_counts_ == before_events && media.current_time() == 2.5
		assert media.paused() && !media.seeking() && media.ready_state() == .have_nothing && media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
		assert !media.current_resource_selection_is_explicit_
		media.set_preload('metadata')
		assert probe.media_fetches == 1 && media.paused() && media.ready_state() == .have_enough_data
		mcn_namespace_drain(media)
		media.set_crossorigin('anonymous')
		media.set_crossorigin(none)
		assert probe.media_fetches == 1 && media.cross_origin() == none
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
	}
}
