module html

import dom

@[heap]
struct TdeObservation {
mut:
	labels []string
	counts []int
	events []&dom.Event
}

@[heap]
struct TdeFetchProbe {
mut:
	urls []string
	cors []CORSSettingAttribute
}

fn tde_document(markup string, address string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn tde_install_fetch(mut model HTMLTrackElementModel) &TdeFetchProbe {
	probe := &TdeFetchProbe{}
	model.set_fetch_hook(fn [probe] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut observed := unsafe { &TdeFetchProbe(probe) }
		observed.urls << url.serialize()
		observed.cors << cors
		if url.serialize().ends_with('/network.vtt') { return error('Controlled track event fetch failure') }
		if url.serialize().ends_with('/missing.vtt') { return TextTrackResourceResponse{ status: 404 } }
		if url.serialize().ends_with('/invalid.vtt') { return TextTrackResourceResponse{ body: 'Invalid WebVTT' } }
		return TextTrackResourceResponse{ body: 'WEBVTT\n\nevent-cue\n00:01.250 --> 00:02.500\nEvent cue text' }
	})
	return probe
}

fn tde_listen(target &dom.EventTarget, name string, label string, expected_target &dom.EventTarget,
	phase u16, capture bool, model &HTMLTrackElementModel, observation &TdeObservation) &dom.IDLEventListener {
	listener := dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [target, name, label, expected_target, phase, model, observation] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert event.type_name() == name && event.is_trusted()
			assert !event.bubbles() && !event.cancelable() && !event.composed()
			assert voidptr(event.target() or { panic('Missing track event target') }) == voidptr(expected_target)
			assert voidptr(current or { panic('Missing track callback target') }) == voidptr(target)
			assert voidptr(event.current_target() or { panic('Missing track currentTarget') }) == voidptr(target)
			assert event.event_phase() == phase
			assert model.event_count(name) > 0
			if name == 'load' {
				assert model.ready_state() == .loaded && model.track.cues().length() == 1
				cue := model.track.cues().item(0) or { panic('Missing event-visible cue') }
				assert cue.id() == 'event-cue' && cue.text() == 'Event cue text'
				assert cue.start_time() == 1.25 && cue.end_time() == 2.5
			} else {
				assert model.ready_state() == .error && model.track.cues().length() == 0
			}
			mut result := unsafe { &TdeObservation(observation) }
			result.labels << '${name}:${label}'
			result.counts << model.event_count(name)
			result.events << event
			return dom.js_undefined()
		}
	})
	target.add_event_listener(name, listener, dom.AddEventListenerOptions{ capture: capture })
	return listener
}

fn tde_assert_delivery(mut observed TdeObservation, name string, count int) {
	assert observed.labels == ['${name}:document', '${name}:parent', '${name}:capture', '${name}:pre', '${name}:model']
	assert observed.counts == [count, count, count, count]
	for event in observed.events {
		assert event.current_target() == none && event.event_phase() == 0
		assert !event.dispatched() && event.path().len == 0
	}
	observed.labels.clear()
	observed.counts.clear()
	observed.events.clear()
}

fn test_track_load_and_error_use_actual_dom_target_capture_path_and_completed_state() {
	for kind in ['audio', 'video'] {
		mut document := tde_document('<!doctype html><body><${kind} id="tde-parent" crossorigin="use-credentials"></${kind}></body>',
			'https://track-events.example.test/base/document.html')!
		defer { document.finalize() }
		parent := document.get_element_by_id('tde-parent') or { panic('Missing event media parent') }
		media := html_media_element_for_dom_element(parent) or { panic('Missing event media owner') }
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'first.vtt')
		target := unsafe { &dom.EventTarget(element) }
		mut observed := &TdeObservation{}
		for name in ['load', 'error'] {
			target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
				handle_event: fn [target, name, observed] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
					assert voidptr(event.target() or { panic('Missing pre-existing track target') }) == voidptr(target)
					assert voidptr(current or { panic('Missing pre-existing track currentTarget') }) == voidptr(target)
					mut result := unsafe { &TdeObservation(observed) }
					result.labels << '${name}:pre'
					return dom.js_undefined()
				}
			}))
		}
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		assert voidptr(model.event_target()) == voidptr(target)
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track) != voidptr(target)
		probe := tde_install_fetch(mut model)
		sibling := document.create_element('track')!
		sibling_model := html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(sibling) })
		assert voidptr(sibling_model.event_target()) == voidptr(sibling)
		assert voidptr(sibling_model.event_target()) != voidptr(target)
		for name in ['load', 'error'] {
			tde_listen(unsafe { &dom.EventTarget(document) }, name, 'document', target, 1, true, model, observed)
			tde_listen(unsafe { &dom.EventTarget(parent) }, name, 'parent', target, 1, true, model, observed)
			tde_listen(target, name, 'capture', target, 2, true, model, observed)
			tde_listen(model.event_target(), name, 'model', target, 2, false, model, observed)
			tde_listen(unsafe { &dom.EventTarget(parent) }, name, 'unexpected-bubble', target, 3, false, model, observed)
			tde_listen(sibling_model.event_target(), name, 'unexpected-sibling', target, 2, false, model, observed)
			tde_listen(unsafe { &dom.EventTarget(model.track) }, name, 'unexpected-text-track', target, 2, false, model, observed)
		}
		mut parent_node := parent.as_node()
		parent_node.append_child(element.as_node())!
		parent_node.append_child(sibling.as_node())!
		assert observed.labels == []
		html_track_element_inserted(track_dom)
		tde_assert_delivery(mut observed, 'load', 1)
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		for index, source in ['missing.vtt', 'invalid.vtt', 'network.vtt', ''] {
			element.set_attribute_value('src', source)
			tde_assert_delivery(mut observed, 'error', index + 1)
			assert model.event_count('load') == 1 && model.event_count('error') == index + 1
		}
		element.set_attribute_value('src', 'recovered.vtt')
		tde_assert_delivery(mut observed, 'load', 2)
		assert probe.urls == ['https://track-events.example.test/base/first.vtt',
			'https://track-events.example.test/base/missing.vtt', 'https://track-events.example.test/base/invalid.vtt',
			'https://track-events.example.test/base/network.vtt', 'https://track-events.example.test/base/recovered.vtt']
		assert probe.cors == [CORSSettingAttribute.use_credentials, .use_credentials, .use_credentials, .use_credentials, .use_credentials]
		assert sibling_model.event_count('load') == 0 && sibling_model.event_count('error') == 0
		assert sibling_model.ready_state() == .none && sibling_model.track.cues().length() == 0
		assert media.event_count('load') == 0 && media.event_count('error') == 0
		assert media.paused() && media.current_src() == '' && media.network_state() == .empty
	}
}

fn test_track_events_follow_shadow_boundary_and_adopted_tree_with_cached_target_and_listener() {
	mut original := tde_document('<!doctype html><body><div id="tde-host"></div></body>',
		'https://track-events.example.test/original/document.html')!
	mut adopted := tde_document('<!doctype html><body><audio id="tde-new-parent" crossorigin="anonymous"></audio></body>',
		'https://track-adopted.example.test/new/document.html')!
	defer { original.finalize(); adopted.finalize() }
	mut host := original.get_element_by_id('tde-host') or { panic('Missing track shadow host') }
	shadow := host.attach_shadow(dom.ShadowRootInit{ mode: .closed })!
	parent := original.create_element('video')!
	mut shadow_node := unsafe { &dom.Node(shadow) }
	shadow_node.append_child(parent.as_node())!
	mut element := original.create_element('track')!
	element.set_attribute_value('src', 'shadow.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	mut model := html_track_element_model_for_dom_element(track_dom)
	target := unsafe { &dom.EventTarget(element) }
	probe := tde_install_fetch(mut model)
	mut observed := &TdeObservation{}
	for name in ['load', 'error'] {
		tde_listen(unsafe { &dom.EventTarget(original) }, name, 'old-document', target, 1, true, model, observed)
		tde_listen(unsafe { &dom.EventTarget(host) }, name, 'host', target, 1, true, model, observed)
		tde_listen(unsafe { &dom.EventTarget(shadow) }, name, 'shadow', target, 1, true, model, observed)
		tde_listen(unsafe { &dom.EventTarget(parent) }, name, 'old-parent', target, 1, true, model, observed)
		tde_listen(target, name, 'retained', target, 2, false, model, observed)
	}
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	html_track_element_inserted(track_dom)
	assert observed.labels == ['load:shadow', 'load:old-parent', 'load:retained']
	assert observed.counts == [1, 1, 1]
	observed.labels.clear()
	observed.counts.clear()
	new_parent := adopted.get_element_by_id('tde-new-parent') or { panic('Missing adopted track parent') }
	new_media := html_media_element_for_dom_element(new_parent) or { panic('Missing adopted track media') }
	for name in ['load', 'error'] {
		tde_listen(unsafe { &dom.EventTarget(adopted) }, name, 'new-document', target, 1, true, model, observed)
		tde_listen(unsafe { &dom.EventTarget(new_parent) }, name, 'new-parent', target, 1, true, model, observed)
	}
	adopted.adopt_node(element.as_node())
	mut new_parent_node := new_parent.as_node()
	new_parent_node.append_child(element.as_node())!
	model.set_parent_media(new_media)
	assert voidptr(element.document()) == voidptr(adopted)
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert voidptr(model.event_target()) == voidptr(target)
	element.set_attribute_value('src', 'adopted.vtt')
	assert observed.labels == ['load:new-document', 'load:new-parent', 'load:retained']
	assert observed.counts == [2, 2, 2]
	observed.labels.clear()
	observed.counts.clear()
	element.set_attribute_value('src', 'missing.vtt')
	assert observed.labels == ['error:new-document', 'error:new-parent', 'error:retained']
	assert observed.counts == [1, 1, 1]
	assert probe.urls == ['https://track-events.example.test/original/shadow.vtt',
		'https://track-adopted.example.test/new/adopted.vtt', 'https://track-adopted.example.test/new/missing.vtt']
	assert probe.cors == [CORSSettingAttribute.no_cors, .anonymous, .anonymous]
	assert model.event_count('load') == 2 && model.event_count('error') == 1
	assert voidptr(model.parent_media_ or { panic('Missing retained adopted media owner') }) == voidptr(new_media)
}

fn test_standalone_track_event_targets_remain_independent_and_keep_their_own_listeners() {
	mut document := tde_document('<!doctype html><body></body>', 'https://track-events.example.test/standalone/')!
	defer { document.finalize() }
	element := document.create_element('track')!
	dom_model := html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	mut first := HTMLTrackElementModel.create(document.base_url())
	mut second := HTMLTrackElementModel.create(document.base_url())
	assert voidptr(first.event_target()) != voidptr(second.event_target())
	assert voidptr(first.event_target()) != voidptr(dom_model.event_target())
	assert voidptr(second.event_target()) != voidptr(dom_model.event_target())
	media := HTMLMediaElement.create(none, document.base_url())
	first.set_parent_media(media)
	second.set_parent_media(media)
	first.set_mode(.hidden)
	second.set_mode(.showing)
	first.set_src('first.vtt')
	second.set_src('missing.vtt')
	first_probe := tde_install_fetch(mut first)
	second_probe := tde_install_fetch(mut second)
	mut observed := &TdeObservation{}
	first_target := first.event_target()
	second_target := second.event_target()
	listener := tde_listen(first_target, 'load', 'first', first_target, 2, false, first, observed)
	tde_listen(second_target, 'error', 'second', second_target, 2, false, second, observed)
	tde_listen(dom_model.event_target(), 'load', 'unexpected-dom', first_target, 2, false, first, observed)
	tde_listen(dom_model.event_target(), 'error', 'unexpected-dom', second_target, 2, false, second, observed)
	first.start_the_track_processing_model()
	assert observed.labels == ['load:first'] && observed.counts == [1]
	assert second.ready_state() == .none && second.event_count('error') == 0
	second.start_the_track_processing_model()
	assert observed.labels == ['load:first', 'error:second'] && observed.counts == [1, 1]
	assert first.event_count('load') == 1 && first.event_count('error') == 0
	assert second.event_count('load') == 0 && second.event_count('error') == 1
	first_target.remove_event_listener_without_options('load', listener)
	first.set_src('next.vtt')
	assert first.event_count('load') == 2 && observed.labels == ['load:first', 'error:second']
	assert first_probe.urls == ['https://track-events.example.test/standalone/first.vtt',
		'https://track-events.example.test/standalone/next.vtt']
	assert second_probe.urls == ['https://track-events.example.test/standalone/missing.vtt']
	assert dom_model.event_count('load') == 0 && dom_model.event_count('error') == 0
	assert dom_model.ready_state() == .none && dom_model.track.cues().length() == 0
}
