module html

import dom

@[heap]
struct TrrObservation {
mut:
	order []string
	urls  []string
	cors  []CORSSettingAttribute
	cues  []&TextTrackCue
	acted bool
}

fn trr_document(kind string) !&dom.Document {
	url := dom.URL{ value: 'https://track-readiness.example.test/base/document.html' }
	return parse_navigation_document('<!doctype html><body><${kind} id="trr-parent" crossorigin="use-credentials"></${kind}></body>',
		url, url.origin(), none)!
}

fn trr_cue(list &TextTrackCueList) &TextTrackCue {
	assert list.length() == 1
	return list.item(0) or { panic('Missing readiness-observer cue') }
}

fn trr_fetch(mut observed TrrObservation, address dom.URL, cors CORSSettingAttribute) string {
	resource := address.serialize().split('/').last()
	observed.order << 'fetch:${resource}'
	observed.urls << address.serialize()
	observed.cors << cors
	return resource
}

fn trr_response(resource string) TextTrackResourceResponse {
	return TextTrackResourceResponse{ body: 'WEBVTT\n\n${resource}\n00:01.250 --> 00:02.500\nCue from ${resource}' }
}

fn trr_notify(mut observed TrrObservation, model &HTMLTrackElementModel, state TextTrackReadinessState) {
	assert model.track.readiness_state() == state
	if state == .loading {
		assert model.loading_ && !model.awaiting_url_change
	} else {
		assert !model.loading_ && model.awaiting_url_change
	}
	observed.order << 'notify:${state}:${model.src_}'
}

fn trr_listen(model &HTMLTrackElementModel, observed &TrrObservation) {
	target := model.event_target()
	for name in ['load', 'error'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [model, target, observed, name] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert voidptr(event.target() or { panic('Missing readiness event target') }) == voidptr(target)
				assert voidptr(current or { panic('Missing readiness currentTarget') }) == voidptr(target)
				assert !model.loading_ && model.awaiting_url_change
				if name == 'load' {
					assert model.ready_state() == .loaded && trr_cue(model.track.cues()).id() == model.src_
				} else {
					assert model.ready_state() == .error && model.track.cues().length() == 0
				}
				mut result := unsafe { &TrrObservation(observed) }
				result.order << '${name}:${model.src_}'
				return dom.js_undefined()
			}
		}))
	}
}

fn test_loading_readiness_observer_selects_current_source_before_obsolete_fetch_in_either_active_mode() {
	for mode in [TextTrackMode.hidden, .showing] {
		url := dom.URL{ value: 'https://track-readiness.example.test/base/document.html' }
		media := HTMLMediaElement.create(none, url)
		mut model := HTMLTrackElementModel.create(url)
		model.set_parent_media(media)
		model.set_mode(mode)
		model.set_src('a.vtt')
		mut track := model.track
		mut seed := TextTrackCue.create(3, 4, 'Retained seed') or { panic(err) }
		track.add_cue(mut seed)
		list := track.cues()
		observed := &TrrObservation{}
		trr_listen(model, observed)
		model.set_fetch_hook(fn [observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
			mut result := unsafe { &TrrObservation(observed) }
			return trr_response(trr_fetch(mut result, address, cors))
		})
		mut observer := TextTrackObserver.create(mut track)
		defer { observer.finalize() }
		observer.set_track_readiness_observer(fn [model, observed] (state TextTrackReadinessState) {
			mut result := unsafe { &TrrObservation(observed) }
			trr_notify(mut result, model, state)
			if state == .loading && !result.acted {
				result.acted = true
				mut owner := unsafe { &HTMLTrackElementModel(model) }
				owner.set_src('b.vtt')
				assert owner.ready_state() == .loaded && trr_cue(owner.track.cues()).id() == 'b.vtt'
				result.order << 'resume:loading-a'
			}
		})
		model.start_the_track_processing_model()
		assert observed.order == ['notify:loading:a.vtt', 'notify:loading:b.vtt', 'fetch:b.vtt',
			'notify:loaded:b.vtt', 'load:b.vtt', 'resume:loading-a']
		assert observed.urls == ['https://track-readiness.example.test/base/b.vtt']
		assert seed.track() == none && voidptr(model.track.cues()) == voidptr(list)
		assert model.ready_state() == .loaded && model.awaiting_url_change && !model.loading_
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		model.set_src('later.vtt')
		assert observed.order[6..] == ['notify:loading:later.vtt', 'fetch:later.vtt', 'notify:loaded:later.vtt', 'load:later.vtt']
		assert trr_cue(list).id() == 'later.vtt' && model.event_count('load') == 2
		assert observed.cors == [CORSSettingAttribute.no_cors, .no_cors]
	}
}

fn test_dom_loaded_readiness_observer_replaces_installed_cue_and_suppresses_old_load_for_audio_and_video() {
	for kind in ['audio', 'video'] {
		for replacement in ['b.vtt', 'missing.vtt'] {
			mut document := trr_document(kind)!
			defer { document.finalize() }
			parent := document.get_element_by_id('trr-parent') or { panic('Missing loaded-observer media parent') }
			mut element := document.create_element('track')!
			element.set_attribute_value('src', 'a.vtt')
			track_dom := unsafe { &dom.HTMLTrackElement(element) }
			mut model := html_track_element_model_for_dom_element(track_dom)
			mut track := model.track
			list := track.cues()
			observed := &TrrObservation{}
			trr_listen(model, observed)
			model.set_fetch_hook(fn [observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
				mut result := unsafe { &TrrObservation(observed) }
				resource := trr_fetch(mut result, address, cors)
				if resource == 'missing.vtt' { return TextTrackResourceResponse{ status: 404 } }
				return trr_response(resource)
			})
			mut observer := TextTrackObserver.create(mut track)
			defer { observer.finalize() }
			observer.set_track_readiness_observer(fn [track_dom, observed, replacement] (state TextTrackReadinessState) {
				mut result := unsafe { &TrrObservation(observed) }
				owner := html_track_element_model_for_dom_element(track_dom)
				trr_notify(mut result, owner, state)
				if state == .loaded {
					cue := trr_cue(owner.track.cues())
					result.cues << cue
					if !result.acted {
						result.acted = true
						mut element_owner := unsafe { &dom.Element(track_dom) }
						element_owner.set_attribute_value('src', replacement)
						assert cue.track() == none
						result.order << 'resume:loaded-a'
					}
				}
			})
			mut parent_node := parent.as_node()
			parent_node.append_child(element.as_node())!
			html_track_element_inserted(track_dom)
			terminal_state := if replacement == 'b.vtt' { 'loaded' } else { 'failed_to_load' }
			terminal_event := if replacement == 'b.vtt' { 'load' } else { 'error' }
			assert observed.order == ['notify:loading:a.vtt', 'fetch:a.vtt', 'notify:loaded:a.vtt',
				'notify:loading:${replacement}', 'fetch:${replacement}', 'notify:${terminal_state}:${replacement}',
				'${terminal_event}:${replacement}', 'resume:loaded-a']
			assert observed.cues[0].id() == 'a.vtt' && observed.cues[0].track() == none
			assert model.event_count('load') == if replacement == 'b.vtt' { 1 } else { 0 }
			assert model.event_count('error') == if replacement == 'missing.vtt' { 1 } else { 0 }
			assert voidptr(model.track.cues()) == voidptr(list) && voidptr(model.event_target()) == voidptr(element)
			assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
			element.set_attribute_value('src', 'later.vtt')
			assert observed.order[8..] == ['notify:loading:later.vtt', 'fetch:later.vtt', 'notify:loaded:later.vtt', 'load:later.vtt']
			assert trr_cue(list).id() == 'later.vtt' && model.ready_state() == .loaded
			assert model.awaiting_url_change && !model.loading_
			for cors in observed.cors { assert cors == .use_credentials }
		}
	}
}

fn test_dom_failed_readiness_observer_keeps_nested_failure_or_fetch_recovery_without_old_error() {
	for replacement in ['recover.vtt', 'missing-again.vtt'] {
		mut document := trr_document('audio')!
		defer { document.finalize() }
		parent := document.get_element_by_id('trr-parent') or { panic('Missing failed-observer media parent') }
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'missing.vtt')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		mut track := model.track
		list := track.cues()
		observed := &TrrObservation{}
		trr_listen(model, observed)
		model.set_fetch_hook(fn [track_dom, observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
			mut result := unsafe { &TrrObservation(observed) }
			resource := trr_fetch(mut result, address, cors)
			if resource.starts_with('missing') { return TextTrackResourceResponse{ status: 404 } }
			if resource == 'recover.vtt' {
				mut element_owner := unsafe { &dom.Element(track_dom) }
				element_owner.set_attribute_value('src', 'final.vtt')
				result.order << 'return:recover'
				return error('Obsolete recovery fetch error')
			}
			return trr_response(resource)
		})
		mut observer := TextTrackObserver.create(mut track)
		defer { observer.finalize() }
		observer.set_track_readiness_observer(fn [track_dom, observed, replacement] (state TextTrackReadinessState) {
			mut result := unsafe { &TrrObservation(observed) }
			owner := html_track_element_model_for_dom_element(track_dom)
			trr_notify(mut result, owner, state)
			if state == .failed_to_load && !result.acted {
				result.acted = true
				mut element_owner := unsafe { &dom.Element(track_dom) }
				element_owner.set_attribute_value('src', replacement)
				result.order << 'resume:failed-missing'
			}
		})
		mut parent_node := parent.as_node()
		parent_node.append_child(element.as_node())!
		html_track_element_inserted(track_dom)
		if replacement == 'recover.vtt' {
			assert observed.order == ['notify:loading:missing.vtt', 'fetch:missing.vtt', 'notify:failed_to_load:missing.vtt',
				'notify:loading:recover.vtt', 'fetch:recover.vtt', 'notify:loading:final.vtt', 'fetch:final.vtt',
				'notify:loaded:final.vtt', 'load:final.vtt', 'return:recover', 'resume:failed-missing']
			assert model.ready_state() == .loaded && trr_cue(list).id() == 'final.vtt'
			assert model.event_count('load') == 1 && model.event_count('error') == 0
		} else {
			assert observed.order == ['notify:loading:missing.vtt', 'fetch:missing.vtt', 'notify:failed_to_load:missing.vtt',
				'notify:loading:missing-again.vtt', 'fetch:missing-again.vtt', 'notify:failed_to_load:missing-again.vtt',
				'error:missing-again.vtt', 'resume:failed-missing']
			assert model.ready_state() == .error && list.length() == 0
			assert model.event_count('load') == 0 && model.event_count('error') == 1
		}
		assert model.awaiting_url_change && !model.loading_
		before := observed.order.len
		element.set_attribute_value('src', 'later.vtt')
		assert observed.order[before..] == ['notify:loading:later.vtt', 'fetch:later.vtt', 'notify:loaded:later.vtt', 'load:later.vtt']
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.track.cues()) == voidptr(list) && trr_cue(list).id() == 'later.vtt'
		assert model.ready_state() == .loaded && model.awaiting_url_change && !model.loading_
		for cors in observed.cors { assert cors == .use_credentials }
	}
}
