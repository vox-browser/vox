module browserjs

import dom
import html

const msnh_first = 'urn:media-source-native-first'
const msnh_second = 'urn:media-source-native-second'
const msnh_prefixed = 'urn:media-source-native-prefixed'

@[heap]
struct MsnhProbe {
mut:
	urls []string
	offsets []u64
}

fn msnh_document(markup string) !&dom.Document {
	address := dom.URL{ value: 'https://media-source-namespace.example.test/base/' }
	return html.parse_navigation_document(markup, address, address.origin(), none)!
}

fn msnh_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing source namespace element ${id}') }
}

fn msnh_attr(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'src') or { return error('Missing source namespace attribute') }
}

fn msnh_unmaterialized(element &dom.Element) {
	if element.local_name() == 'audio' {
		assert unsafe { &dom.HTMLAudioElement(element) }.media_element_model_ == unsafe { nil }
	} else {
		assert unsafe { &dom.HTMLVideoElement(element) }.media_element_model_ == unsafe { nil }
	}
}

fn msnh_bind(document &dom.Document) !(&Runtime, &MediaElementHost) {
	mut runtime := Runtime.create()
	mut host := MediaElementHost.create(document, none)!
	host.install(mut runtime)!
	_ = runtime.evaluate_host('globalThis.msnhPlayers={};0')!
	for key, element in host.elements_for_binding() {
		if !element.is_html_element() || element.local_name() !in ['audio', 'video'] { continue }
		id := element.get_attribute('id') or { return error('Missing source namespace ID') }
		msnh_unmaterialized(element)
		_ = runtime.evaluate_host('msnhPlayers["${id}"]={};__ladybirdMediaElementBind(msnhPlayers["${id}"],"${key}","${element.local_name()}");0')!
	}
	return runtime, host
}

fn msnh_drain(document &dom.Document) {
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn [document] (item &html.Task) bool {
			owner := item.document() or { return false }
			return item.source() == .media_element && voidptr(owner) == voidptr(document)
		}) or { break }
		count++
		assert count < 100
		task.execute()
	}
}

fn msnh_same_attr(element &dom.Element, namespace ?string, attribute &dom.Attr_, raw string) ! {
	owner := attribute.owner_element() or { return error('Source namespace attribute lost its owner') }
	assert voidptr(owner) == voidptr(element) && voidptr(msnh_attr(element, namespace)!) == voidptr(attribute)
	if expected_namespace := namespace {
		actual_namespace := attribute.namespace_uri() or { return error('Source attribute lost its namespace') }
		assert actual_namespace == expected_namespace
	} else { assert attribute.namespace_uri() == none }
	assert attribute.local_name() == 'src' && attribute.value() == raw
}

fn test_native_load_uses_only_initial_null_namespace_media_src_for_audio_and_video() {
	$if !darwin { return }
	mut document := msnh_document('<!doctype html><video id="msnh-video-none"></video><audio id="msnh-audio-none"></audio><video id="msnh-video-first"></video><audio id="msnh-audio-first"></audio><video id="msnh-video-last"></video><audio id="msnh-audio-last"></audio>')!
	ids := ['msnh-video-none', 'msnh-audio-none', 'msnh-video-first', 'msnh-audio-first', 'msnh-video-last', 'msnh-audio-last']
	for index, id in ids {
		mut element := msnh_element(document, id)!
		msnh_unmaterialized(element)
		if index in [2, 3] { element.set_attribute_value('src', '/actual-${id}.mp4') }
		element.set_attribute_ns_for_bindings(msnh_first, 'src', '/foreign-${id}.mp4')!
		element.set_attribute_ns_for_bindings(msnh_second, 'src', '/foreign-second-${id}.mp4')!
		element.set_attribute_ns_for_bindings(msnh_prefixed, 'p:src', '/prefixed-${id}.mp4')!
		if index in [4, 5] { element.set_attribute_value('src', '/actual-${id}.mp4') }
		msnh_unmaterialized(element)
	}
	mut runtime, _ := msnh_bind(document)!
	defer { runtime.close(); document.finalize() }
	probe := &MsnhProbe{}
	for index, id in ids {
		element := msnh_element(document, id)!
		first := msnh_attr(element, msnh_first)!
		second := msnh_attr(element, msnh_second)!
		prefixed := msnh_attr(element, msnh_prefixed)!
		null_before := element.get_attribute_node_ns(none, 'src')
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing initial source model') }
		media.set_fetch_hook(fn [probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
			mut observation := unsafe { &MsnhProbe(probe) }
			observation.urls << url.serialize(); observation.offsets << offset
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 6, buffered_end: 6 }
		})
		player := 'msnhPlayers["${id}"]'
		assert runtime.evaluate_host('${player}.currentSrc===""')! == 'true'
		before_fetches := probe.urls.len
		assert runtime.evaluate_host('${player}.load()===undefined')! == 'true'
		if index < 2 {
			assert runtime.evaluate_host('${player}.currentSrc===""&&${player}.networkState===0&&${player}.readyState===0')! == 'true'
			assert probe.urls.len == before_fetches && media.current_src() == '' && media.error() == none
			assert media.event_count('loadstart') == 0 && !element.has_attribute_ns(none, 'src')
		} else {
			expected := 'https://media-source-namespace.example.test/actual-${id}.mp4'
			assert runtime.evaluate_host('${player}.currentSrc==="${expected}"&&${player}.readyState===4')! == 'true'
			assert media.current_src() == expected && probe.urls.len == before_fetches + 1
			assert probe.urls.last() == expected && probe.offsets.last() == 0 && media.error() == none
			null_attr := null_before or { panic('Missing initial null-namespace source') }
			msnh_same_attr(element, none, null_attr, '/actual-${id}.mp4')!
		}
		msnh_same_attr(element, msnh_first, first, '/foreign-${id}.mp4')!
		msnh_same_attr(element, msnh_second, second, '/foreign-second-${id}.mp4')!
		msnh_same_attr(element, msnh_prefixed, prefixed, '/prefixed-${id}.mp4')!
		assert first.name() == 'src' && second.name() == 'src' && first.prefix() == none && second.prefix() == none
		assert prefixed.name() == 'p:src' && (prefixed.prefix() or { '' }) == 'p'
		assert media.paused() && media.current_time() == 0 && !media.muted() && media.volume() == 1
		for name in ['play', 'playing', 'pause', 'volumechange', 'seeking', 'error'] { assert media.event_count(name) == 0 }
	}
	assert probe.urls.len == 4 && probe.offsets == [u64(0), 0, 0, 0]
	msnh_drain(document)
}

fn test_native_load_uses_filtered_source_children_and_falls_back_in_real_null_namespace_order() {
	$if !darwin { return }
	mut document := msnh_document('<!doctype html><video id="msnh-video-children"></video><audio id="msnh-audio-children"></audio>')!
	for index, id in ['msnh-video-children', 'msnh-audio-children'] {
		mut element := msnh_element(document, id)!
		element.set_attribute_ns_for_bindings(msnh_first, 'src', '/ignored-owner-${id}.mp4')!
		mut foreign_only := document.create_element('source')!
		foreign_only.set_attribute_value('id', '${id}-foreign')
		foreign_only.set_attribute_ns_for_bindings(msnh_first, 'src', '/ignored-child-${id}.mp4')!
		mut foreign_element := document.create_element_ns(dom.namespace_svg_uri, 'source')!
		foreign_element.set_attribute_value('src', '/ignored-svg-${id}.mp4')
		mut primary := document.create_element('source')!
		primary.set_attribute_value('id', '${id}-primary')
		if index == 0 { primary.set_attribute_value('src', 'primary-${id}.mp4') }
		primary.set_attribute_ns_for_bindings(msnh_first, 'src', '/ignored-primary-${id}.mp4')!
		if index == 1 { primary.set_attribute_value('src', 'primary-${id}.mp4') }
		mut fallback := document.create_element('source')!
		fallback.set_attribute_value('id', '${id}-fallback')
		fallback.set_attribute_ns_for_bindings(msnh_prefixed, 'p:src', '/ignored-fallback-${id}.mp4')!
		fallback.set_attribute_value('src', 'fallback-${id}.mp4')
		mut parent := element.as_node()
		for child in [foreign_only, foreign_element, primary, fallback] { parent.append_child(child.as_node())! }
		msnh_unmaterialized(element)
	}
	mut runtime, _ := msnh_bind(document)!
	defer { runtime.close(); document.finalize() }
	probe := &MsnhProbe{}
	for id in ['msnh-video-children', 'msnh-audio-children'] {
		element := msnh_element(document, id)!
		owner_foreign := msnh_attr(element, msnh_first)!
		foreign_only := msnh_element(document, '${id}-foreign')!
		foreign_attr := msnh_attr(foreign_only, msnh_first)!
		primary := msnh_element(document, '${id}-primary')!
		primary_null := msnh_attr(primary, none)!
		primary_foreign := msnh_attr(primary, msnh_first)!
		fallback := msnh_element(document, '${id}-fallback')!
		fallback_null := msnh_attr(fallback, none)!
		fallback_foreign := msnh_attr(fallback, msnh_prefixed)!
		mut media := html.html_media_element_for_dom_element(element) or { panic('Missing source-child owner') }
		media.set_fetch_hook(fn [probe] (url dom.URL, offset u64) !html.MediaResourceResponse {
			mut observation := unsafe { &MsnhProbe(probe) }
			observation.urls << url.serialize(); observation.offsets << offset
			if url.serialize().contains('/primary-') { return error('Try the next real source candidate') }
			assert url.serialize().contains('/fallback-')
			return html.MediaResourceResponse{ mime_type: 'video/mp4', duration: 9, buffered_end: 9 }
		})
		media.children_changed(dom.ChildrenChangedMetadata{ type_: .inserted, node: fallback.as_node() })
		before_fetches := probe.urls.len
		assert media.current_src() == '' && media.network_state() == .empty
		player := 'msnhPlayers["${id}"]'
		expected := 'https://media-source-namespace.example.test/base/fallback-${id}.mp4'
		assert runtime.evaluate_host('${player}.load()===undefined&&${player}.currentSrc==="${expected}"&&${player}.readyState===4')! == 'true'
		assert probe.urls[before_fetches..] == ['https://media-source-namespace.example.test/base/primary-${id}.mp4', expected]
		assert probe.offsets[before_fetches..] == [u64(0), 0]
		assert media.current_src() == expected && media.error() == none && media.event_count('loadstart') == 1
		msnh_same_attr(element, msnh_first, owner_foreign, '/ignored-owner-${id}.mp4')!
		msnh_same_attr(foreign_only, msnh_first, foreign_attr, '/ignored-child-${id}.mp4')!
		msnh_same_attr(primary, none, primary_null, 'primary-${id}.mp4')!
		msnh_same_attr(primary, msnh_first, primary_foreign, '/ignored-primary-${id}.mp4')!
		msnh_same_attr(fallback, none, fallback_null, 'fallback-${id}.mp4')!
		msnh_same_attr(fallback, msnh_prefixed, fallback_foreign, '/ignored-fallback-${id}.mp4')!
		assert fallback_foreign.name() == 'p:src' && (fallback_foreign.prefix() or { '' }) == 'p'
		assert media.paused() && media.current_time() == 0 && !media.muted() && media.volume() == 1
		for name in ['play', 'playing', 'pause', 'volumechange', 'seeking', 'error'] { assert media.event_count(name) == 0 }
	}
	assert probe.urls.len == 4
	msnh_drain(document)
}
