module html

import dom

const mln_namespace_first = 'urn:loop-namespace-first'
const mln_namespace_second = 'urn:loop-namespace-second'

@[heap]
struct MlnNamespaceProbe {
mut:
	fetches int
}

fn mln_namespace_element(document &dom.Document, id string) !&dom.Element {
	return document.get_element_by_id(id) or { return error('Missing loop namespace element ${id}') }
}

fn mln_namespace_attribute(element &dom.Element, namespace ?string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, 'loop') or { return error('Missing loop namespace attribute') }
}

fn mln_namespace_drain(media &HTMLMediaElement) {
	mut event_loop := main_thread_event_loop()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		event_loop.process()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_loop_namespace_reflection_preserves_live_owner_attributes_adoption_and_fallback() {
	mut document := parse_document('<!doctype html><video id="mln-video"></video><audio id="mln-audio"></audio>')
	mut destination := dom.Document.create(dom.URL{ value: 'https://loop-namespace-adopted.example.test/' })
	defer { document.finalize(); destination.finalize() }
	for index, id in ['mln-video', 'mln-audio'] {
		mut element := mln_namespace_element(document, id)!
		if index == 1 { element.set_attribute_value('loop', 'initial null') }
		element.set_attribute_ns_for_bindings(mln_namespace_first, 'loop', 'first raw')!
		if index == 0 { element.set_attribute_value('loop', 'initial null') }
		element.set_attribute_ns_for_bindings(mln_namespace_second, 'loop', 'second raw')!
		first := mln_namespace_attribute(element, mln_namespace_first)!
		second := mln_namespace_attribute(element, mln_namespace_second)!
		original_null := mln_namespace_attribute(element, none)!
		mut media := html_media_element_for_dom_element(element) or { panic('Missing loop namespace owner') }
		assert media.loop() && original_null.value() == 'initial null'
		media.set_loop(false)
		assert !media.loop() && !element.has_attribute_ns(none, 'loop')
		assert element.has_attribute('loop') && original_null.owner_element() == none
		assert element.get_attribute('loop') or { '' } == 'first raw'
		media.set_loop(false)
		assert !media.loop() && element.get_attribute_names().filter(it == 'loop').len == 2
		element.set_attribute_value('loop', 'direct live null')
		assert media.loop()
		live_null := mln_namespace_attribute(element, none)!
		media.set_loop(true)
		assert media.loop() && live_null.value() == ''
		assert voidptr(mln_namespace_attribute(element, none)!) == voidptr(live_null)
		element.remove_attribute_ns(none, 'loop')
		// The standalone cache cannot make a DOM-associated foreign-only owner loop.
		assert media.loop_ && !media.loop() && live_null.owner_element() == none
		assert voidptr(mln_namespace_attribute(element, mln_namespace_first)!) == voidptr(first)
		assert voidptr(mln_namespace_attribute(element, mln_namespace_second)!) == voidptr(second)
		assert first.value() == 'first raw' && second.value() == 'second raw'
		assert voidptr(first.owner_element() or { panic('Missing foreign owner') }) == voidptr(element)
		assert voidptr(second.owner_element() or { panic('Missing second foreign owner') }) == voidptr(element)
		destination.adopt_node(element.as_node())
		assert voidptr(element.document()) == voidptr(destination)
		assert voidptr(html_media_element_for_dom_element(element) or { panic('Missing adopted loop owner') }) == voidptr(media)
		assert !media.loop()
		media.set_loop(true)
		assert media.loop() && (element.get_attribute_ns(none, 'loop') or { 'missing' }) == ''
		media.set_loop(false)
		assert !media.loop() && !element.has_attribute_ns(none, 'loop')
		assert voidptr(mln_namespace_attribute(element, mln_namespace_first)!) == voidptr(first)
		assert voidptr(mln_namespace_attribute(element, mln_namespace_second)!) == voidptr(second)
		assert first.value() == 'first raw' && second.value() == 'second raw'
		assert media.paused() && !media.ended() && !media.seeking() && media.current_time() == 0
		assert media.current_src() == '' && media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'pause', 'ended'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert !fallback.loop()
	fallback.set_loop(true)
	assert fallback.loop() && fallback.loop_
	fallback.set_loop(false)
	assert !fallback.loop() && !fallback.loop_ && fallback.queued_media_task_ids_.len == 0
}

fn test_media_loop_namespace_endpoint_uses_null_slot_and_retains_paused_guard_and_captured_decision() {
	mut document := parse_document('<!doctype html><video id="mln-end"></video><audio id="mln-restart"></audio><video id="mln-paused"></video>')
	_ := WindowModel.create_top_level(document, none, 'media-loop-namespace-endpoint')!
	defer { document.finalize() }
	foreign_element := mln_namespace_element(document, 'mln-end')!
	mut looping_element := mln_namespace_element(document, 'mln-restart')!
	mut paused_element := mln_namespace_element(document, 'mln-paused')!
	mut foreign := html_media_element_for_dom_element(foreign_element) or { panic('Missing non-loop endpoint owner') }
	mut looping := html_media_element_for_dom_element(looping_element) or { panic('Missing looping endpoint owner') }
	mut paused := html_media_element_for_dom_element(paused_element) or { panic('Missing paused endpoint owner') }
	probe := &MlnNamespaceProbe{}
	for index, item in [foreign, looping, paused] {
		mut media := unsafe { &HTMLMediaElement(item) }
		mut element := if index == 0 { foreign_element } else if index == 1 { looping_element } else { paused_element }
		element.set_attribute_ns_for_bindings(mln_namespace_first, 'loop', 'foreign endpoint raw')!
		media.set_fetch_hook(fn [probe] (_ dom.URL, _ u64) !MediaResourceResponse {
			mut observed := unsafe { &MlnNamespaceProbe(probe) }
			observed.fetches++
			return MediaResourceResponse{ mime_type: 'video/mp4', duration: 1, buffered_end: 1 }
		})
		media.set_source('https://loop-namespace.example.test/endpoint-${index}.mp4')
		media.load()!
		mln_namespace_drain(media)
		assert media.ready_state() == .have_enough_data && media.seekable().length() == 1
	}
	assert document.is_fully_active() && probe.fetches == 3
	foreign_attr := mln_namespace_attribute(foreign_element, mln_namespace_first)!
	assert !foreign.loop() && foreign_element.has_attribute('loop')
	foreign.set_paused(false)
	foreign.advance_playback(1)
	assert !foreign.loop_was_specified_at_end_ && foreign.current_playback_position() == 1
	assert !foreign.paused() && !foreign.seeking() && !foreign.ended()
	// A real loop added after this endpoint cannot revise its queued non-loop decision.
	mut mutable_foreign_element := unsafe { &dom.Element(foreign_element) }
	mutable_foreign_element.set_attribute_value('loop', 'added after endpoint')
	assert foreign.loop() && !foreign.loop_was_specified_at_end_ && foreign.has_ended_playback()
	mut event_loop := main_thread_event_loop()
	event_loop.perform_a_microtask_checkpoint()
	assert !foreign.ended() && foreign.event_count('ended') == 0
	mln_namespace_drain(foreign)
	assert foreign.paused() && foreign.ended() && foreign.current_time() == 1
	assert foreign.event_count('pause') == 1 && foreign.event_count('ended') == 1
	assert foreign.event_count('seeking') == 0 && foreign.event_count('seeked') == 0
	assert voidptr(mln_namespace_attribute(foreign_element, mln_namespace_first)!) == voidptr(foreign_attr)
	assert foreign_attr.value() == 'foreign endpoint raw'

	looping_element.set_attribute_value('loop', 'real loop')
	looping_foreign := mln_namespace_attribute(looping_element, mln_namespace_first)!
	looping.set_paused(false)
	looping.advance_playback(1)
	assert looping.loop_was_specified_at_end_ && looping.current_playback_position() == 0
	assert looping.seeking() && !looping.paused() && !looping.ended()
	looping_element.remove_attribute_ns(none, 'loop')
	assert !looping.loop() && looping.loop_was_specified_at_end_
	mln_namespace_drain(looping)
	assert !looping.seeking() && !looping.paused() && !looping.ended()
	assert looping.event_count('seeking') == 1 && looping.event_count('seeked') == 1
	assert looping.event_count('pause') == 0 && looping.event_count('ended') == 0
	assert voidptr(mln_namespace_attribute(looping_element, mln_namespace_first)!) == voidptr(looping_foreign)
	assert looping_foreign.value() == 'foreign endpoint raw'

	paused_element.set_attribute_value('loop', 'paused real loop')
	paused.set_current_playback_position(1)
	paused.reached_end_of_media_playback()
	assert paused.loop_was_specified_at_end_ && paused.current_playback_position() == 1 && paused.paused()
	assert !paused.seeking() && paused.queued_media_task_ids_.len == 0
	event_loop.process()
	assert !paused.ended() && paused.event_count('pause') == 0 && paused.event_count('ended') == 0
	assert paused.event_count('seeking') == 0 && paused.event_count('seeked') == 0
	assert probe.fetches == 3
}
