module html

import dom

const msn_namespace_first = 'urn:media-source-namespace-first'
const msn_namespace_second = 'urn:media-source-namespace-second'
const msn_namespace_prefixed = 'urn:media-source-namespace-prefixed'

@[heap]
struct MsnNamespaceProbe {
mut:
	urls []string
	owners []dom.UniqueNodeID
}

fn msn_namespace_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn msn_namespace_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing media source namespace element ${id}') }
}

fn msn_namespace_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'src') or { return error('Missing media source namespace attribute') }
}

fn msn_namespace_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('Missing media source namespace task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_source_namespace_materialization_uses_only_initial_null_slot_and_retains_adopted_cache() {
	mut document := msn_namespace_document('https://media-source-namespace.example.test/base/',
		'<!doctype html><video id="msn-video-first"></video><audio id="msn-audio-first"></audio><video id="msn-video-last"></video><audio id="msn-audio-last"></audio>')!
	mut destination := msn_namespace_document('https://media-source-namespace-adopted.example.test/next/', '<body></body>')!
	defer { document.finalize(); destination.finalize() }
	for kind in ['audio', 'video'] {
		mut foreign_only := document.create_element(kind)!
		foreign_only.set_attribute_ns_for_bindings(msn_namespace_first, 'src', 'https://foreign-media.example.test/ignored.mp4')!
		foreign_only.set_attribute_ns_for_bindings(msn_namespace_prefixed, 'p:src', 'prefixed only raw')!
		foreign := msn_namespace_attribute(foreign_only, msn_namespace_first)!
		prefixed := msn_namespace_attribute(foreign_only, msn_namespace_prefixed)!
		mut media := html_media_element_for_dom_element(foreign_only) or { panic('Missing foreign-only media owner') }
		probe := &MsnNamespaceProbe{}
		media.set_fetch_hook(fn [probe] (url dom.URL, _ u64) !MediaResourceResponse {
			mut observation := unsafe { &MsnNamespaceProbe(probe) }
			observation.urls << url.serialize()
			return error('Foreign-only initial src must not fetch')
		})
		assert media.source_ == none && foreign_only.has_attribute('src') && !foreign_only.has_attribute_ns(none, 'src')
		media.select_resource()!
		assert media.source_ == none && media.current_src() == '' && media.network_state() == .empty
		assert probe.urls == [] && media.error() == none && media.ready_state() == .have_nothing
		assert voidptr(msn_namespace_attribute(foreign_only, msn_namespace_first)!) == voidptr(foreign)
		assert voidptr(msn_namespace_attribute(foreign_only, msn_namespace_prefixed)!) == voidptr(prefixed)
		assert foreign.value() == 'https://foreign-media.example.test/ignored.mp4' && prefixed.value() == 'prefixed only raw'
		for name in ['loadstart', 'error', 'play', 'playing'] { assert media.event_count(name) == 0 }
	}
	for index, id in ['msn-video-first', 'msn-audio-first', 'msn-video-last', 'msn-audio-last'] {
		mut element := msn_namespace_element(document, id)!
		raw := 'selected-${index}.mp4?raw=%20#clip'
		if index < 2 { element.set_attribute_value('src', raw) }
		element.set_attribute_ns_for_bindings(msn_namespace_first, 'src', 'foreign first raw')!
		if index >= 2 { element.set_attribute_value('src', raw) }
		element.set_attribute_ns_for_bindings(msn_namespace_second, 'src', 'foreign second raw')!
		element.set_attribute_ns_for_bindings(msn_namespace_prefixed, 'p:src', 'prefixed raw')!
		first := msn_namespace_attribute(element, msn_namespace_first)!
		second := msn_namespace_attribute(element, msn_namespace_second)!
		prefixed := msn_namespace_attribute(element, msn_namespace_prefixed)!
		null_attr := msn_namespace_attribute(element, none)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing selected media owner') }
		assert (media.source_ or { '' }) == raw && null_attr.value() == raw
		probe := &MsnNamespaceProbe{}
		media.set_fetch_hook(fn [probe, element] (url dom.URL, offset u64) !MediaResourceResponse {
			assert offset == 0
			mut observation := unsafe { &MsnNamespaceProbe(probe) }
			observation.urls << url.serialize()
			observation.owners << element.document().unique_id()
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
		})
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html_media_element_for_dom_element(element) or { panic('Missing adopted source owner') }) == voidptr(media)
		assert (media.source_ or { '' }) == raw && probe.urls == []
		media.select_resource()!
		selected := 'https://media-source-namespace-adopted.example.test/next/${raw}'
		assert probe.urls == [selected] && probe.owners == [destination.unique_id()] && media.current_src() == selected
		assert media.ready_state() == .have_enough_data && media.paused() && !media.current_resource_selection_is_explicit_
		msn_namespace_drain(media)
		assert (media.source_ or { '' }) == raw && null_attr.value() == raw
		assert voidptr(msn_namespace_attribute(element, none)!) == voidptr(null_attr)
		for attribute_index, attribute in [first, second, prefixed] {
			namespace := [msn_namespace_first, msn_namespace_second, msn_namespace_prefixed][attribute_index]
			assert voidptr(msn_namespace_attribute(element, namespace)!) == voidptr(attribute)
			assert voidptr(attribute.owner_element() or { panic('Missing adopted src attribute owner') }) == voidptr(element)
		}
		assert first.value() == 'foreign first raw' && second.value() == 'foreign second raw'
		assert prefixed.value() == 'prefixed raw' && prefixed.name() == 'p:src' && (prefixed.prefix() or { '' }) == 'p'
		assert media.event_count('loadstart') == 1 && media.event_count('error') == 0
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
	}
	mut fallback := HTMLMediaElement.create(none, dom.URL{ value: 'https://media-source-fallback.example.test/' })
	fallback_probe := &MsnNamespaceProbe{}
	fallback.set_fetch_hook(fn [fallback_probe] (url dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &MsnNamespaceProbe(fallback_probe) }
		observation.urls << url.serialize()
		return MediaResourceResponse{ mime_type: 'audio/webm', duration: 2, buffered_end: 2 }
	})
	fallback.set_source('fallback.webm')
	fallback.select_resource()!
	assert (fallback.source_ or { '' }) == 'fallback.webm' && fallback_probe.urls == ['https://media-source-fallback.example.test/fallback.webm']
	msn_namespace_drain(fallback)
	fallback.set_source(none)
	assert fallback.source_ == none && fallback.paused()
}

fn test_media_source_namespace_children_changed_collects_real_raw_candidates_and_retains_fallback_order() {
	for kind in ['audio', 'video'] {
		mut document := msn_namespace_document('https://media-source-candidates.example.test/base/',
			'<!doctype html><${kind} id="msn-candidates"><source id="msn-foreign"><source id="msn-blank" src=" &#9;&#10;"><svg><source id="msn-svg" src="svg-ignored.mp4"></source></svg><div><source id="msn-nested" src="nested-ignored.mp4"></div></${kind}>')!
		defer { document.finalize() }
		mut element := msn_namespace_element(document, 'msn-candidates')!
		mut foreign_only := msn_namespace_element(document, 'msn-foreign')!
		foreign_only.set_attribute_ns_for_bindings(msn_namespace_first, 'src', 'foreign-ignored.mp4')!
		foreign_attr := msn_namespace_attribute(foreign_only, msn_namespace_first)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing source children owner') }
		probe := &MsnNamespaceProbe{}
		media.set_fetch_hook(fn [probe] (url dom.URL, offset u64) !MediaResourceResponse {
			assert offset == 0
			mut observation := unsafe { &MsnNamespaceProbe(probe) }
			observation.urls << url.serialize()
			if url.serialize().contains('/fail.mp4') { return error('Controlled first candidate failure') }
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
		})
		assert media.source_ == none
		media.network_state_ = .no_source
		media.children_changed(dom.ChildrenChangedMetadata{ type_: .inserted, node: foreign_only.as_node() })
		assert media.source_candidates_ == [] && probe.urls == [] && media.network_state() == .empty
		assert foreign_only.get_attribute_value('src') == 'foreign-ignored.mp4' && !foreign_only.has_attribute_ns(none, 'src')
		mut sources := []&dom.Element{}
		for index, raw in ['fail.mp4?raw=%20', 'winner.webm#clip', 'unused.mp4'] {
			mut source := document.create_element('source')!
			if index % 2 == 0 { source.set_attribute_value('src', raw) }
			source.set_attribute_ns_for_bindings(msn_namespace_first, 'src', 'foreign-${index}.mp4')!
			if index % 2 == 1 { source.set_attribute_value('src', raw) }
			source.set_attribute_ns_for_bindings(msn_namespace_prefixed, 'p:src', 'prefixed-${index}.mp4')!
			sources << source
			mut parent := element.as_node()
			parent.append_child(source.as_node())!
		}
		first_null := msn_namespace_attribute(sources[0], none)!
		winner_null := msn_namespace_attribute(sources[1], none)!
		winner_foreign := msn_namespace_attribute(sources[1], msn_namespace_first)!
		media.network_state_ = .no_source
		media.children_changed(dom.ChildrenChangedMetadata{ type_: .inserted, node: sources[2].as_node() })
		assert media.source_ == none && media.source_candidates_ == ['fail.mp4?raw=%20', 'winner.webm#clip', 'unused.mp4']
		assert probe.urls == ['https://media-source-candidates.example.test/base/fail.mp4?raw=%20', 'https://media-source-candidates.example.test/base/winner.webm#clip']
		assert media.current_src() == 'https://media-source-candidates.example.test/base/winner.webm#clip' && media.error() == none
		assert media.ready_state() == .have_enough_data && media.paused() && !media.current_resource_selection_is_explicit_
		msn_namespace_drain(media)
		assert media.event_count('loadstart') == 1 && media.event_count('error') == 0
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
		assert voidptr(msn_namespace_attribute(foreign_only, msn_namespace_first)!) == voidptr(foreign_attr) && foreign_attr.value() == 'foreign-ignored.mp4'
		assert voidptr(msn_namespace_attribute(sources[0], none)!) == voidptr(first_null) && first_null.value() == 'fail.mp4?raw=%20'
		assert voidptr(msn_namespace_attribute(sources[1], none)!) == voidptr(winner_null) && winner_null.value() == 'winner.webm#clip'
		assert voidptr(msn_namespace_attribute(sources[1], msn_namespace_first)!) == voidptr(winner_foreign) && winner_foreign.value() == 'foreign-1.mp4'
		assert sources[1].get_attribute_value('src') == 'foreign-1.mp4'
		assert (sources[1].get_attribute_ns(msn_namespace_prefixed, 'src') or { '' }) == 'prefixed-1.mp4'
	}
}
