module html

import dom

@[heap]
struct TcrObservation {
mut:
	order []string
	urls  []string
	cors  []CORSSettingAttribute
	cues  []&TextTrackCue
}

fn tcr_document(kind string) !&dom.Document {
	url := dom.URL{ value: 'https://track-reentry.example.test/base/document.html' }
	return parse_navigation_document('<!doctype html><body><${kind} id="tcr-parent" crossorigin="use-credentials"></${kind}></body>',
		url, url.origin(), none)!
}

fn tcr_install_fetch(mut model HTMLTrackElementModel, observed &TcrObservation) {
	model.set_fetch_hook(fn [observed] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut result := unsafe { &TcrObservation(observed) }
		resource := url.serialize().split('/').last()
		result.order << 'fetch:${resource}'
		result.urls << url.serialize()
		result.cors << cors
		if resource == 'missing.vtt' { return TextTrackResourceResponse{ status: 404 } }
		return TextTrackResourceResponse{
			body: 'WEBVTT\n\n${resource}\n00:01.250 --> 00:02.500\nCue from ${resource}'
		}
	})
}

fn tcr_assert_event(event &dom.Event, current ?&dom.EventTarget, target &dom.EventTarget) {
	assert voidptr(event.target() or { panic('Missing reentrant event target') }) == voidptr(target)
	assert voidptr(current or { panic('Missing reentrant callback target') }) == voidptr(target)
	assert voidptr(event.current_target() or { panic('Missing reentrant currentTarget') }) == voidptr(target)
	assert event.is_trusted() && event.event_phase() == 2
	assert !event.bubbles() && !event.cancelable() && !event.composed()
}

fn tcr_first_cue(list &TextTrackCueList) &TextTrackCue {
	assert list.length() == 1
	return list.item(0) or { panic('Missing reentrant completion cue') }
}

fn test_standalone_track_load_listener_replaces_source_before_return_and_keeps_later_url_wait() {
	url := dom.URL{ value: 'https://track-reentry.example.test/base/document.html' }
	media := HTMLMediaElement.create(none, url)
	mut model := HTMLTrackElementModel.create(url)
	model.set_parent_media(media)
	model.set_mode(.hidden)
	model.set_src('first.vtt')
	observed := &TcrObservation{}
	tcr_install_fetch(mut model, observed)
	list := model.track.cues()
	target := model.event_target()
	target.add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [model, observed, list, target] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			tcr_assert_event(event, current, target)
			mut owner := unsafe { &HTMLTrackElementModel(model) }
			mut result := unsafe { &TcrObservation(observed) }
			assert owner.ready_state() == .loaded && !owner.loading_ && owner.awaiting_url_change
			assert voidptr(owner.track.cues()) == voidptr(list)
			cue := tcr_first_cue(list)
			result.cues << cue
			result.order << 'load:${cue.id()}'
			if cue.id() == 'first.vtt' {
				owner.set_src('second.vtt')
				assert owner.event_count('load') == 2 && owner.awaiting_url_change
				assert tcr_first_cue(list).id() == 'second.vtt' && cue.track() == none
				result.order << 'resumed:first.vtt'
			}
			return dom.js_undefined()
		}
	}))
	model.start_the_track_processing_model()
	assert observed.order == ['fetch:first.vtt', 'load:first.vtt', 'fetch:second.vtt', 'load:second.vtt', 'resumed:first.vtt']
	assert model.src_ == 'second.vtt' && model.ready_state() == .loaded
	assert model.awaiting_url_change && !model.loading_ && observed.cues[0].track() == none
	model.set_src('third.vtt')
	assert observed.order[5..] == ['fetch:third.vtt', 'load:third.vtt']
	assert observed.cues.len == 3 && observed.cues[1].track() == none
	assert voidptr(tcr_first_cue(list)) == voidptr(observed.cues[2])
	assert voidptr(observed.cues[2].track() or { panic('Missing replacement cue owner') }) == voidptr(model.track)
	assert model.event_count('load') == 3 && model.event_count('error') == 0
	assert observed.urls == ['https://track-reentry.example.test/base/first.vtt',
		'https://track-reentry.example.test/base/second.vtt', 'https://track-reentry.example.test/base/third.vtt']
	assert observed.cors == [CORSSettingAttribute.no_cors, .no_cors, .no_cors]
}

fn test_dom_track_load_listener_enters_error_then_recovery_with_stable_model_and_cue_list() {
	mut document := tcr_document('video')!
	defer { document.finalize() }
	parent := document.get_element_by_id('tcr-parent') or { panic('Missing reentrant video parent') }
	mut element := document.create_element('track')!
	element.set_attribute_value('src', 'first.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	target := unsafe { &dom.EventTarget(element) }
	observed := &TcrObservation{}
	for name in ['load', 'error'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [track_dom, target, observed, name] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				tcr_assert_event(event, current, target)
				mut owner := html_track_element_model_for_dom_element(track_dom)
				mut element_owner := unsafe { &dom.Element(track_dom) }
				mut result := unsafe { &TcrObservation(observed) }
				assert voidptr(owner.event_target()) == voidptr(target)
				assert owner.awaiting_url_change && !owner.loading_
				if name == 'error' {
					assert owner.ready_state() == .error && owner.track.cues().length() == 0
					assert owner.event_count('error') == 1 && owner.event_count('load') == 1
					result.order << 'error:missing.vtt'
					element_owner.set_attribute_value('src', 'recovered.vtt')
					assert owner.ready_state() == .loaded && owner.event_count('load') == 2
					result.order << 'resumed:error'
				} else {
					assert owner.ready_state() == .loaded
					cue := tcr_first_cue(owner.track.cues())
					result.cues << cue
					result.order << 'load:${cue.id()}'
					if cue.id() == 'first.vtt' {
						element_owner.set_attribute_value('src', 'missing.vtt')
						assert owner.ready_state() == .loaded && owner.event_count('error') == 1
						assert cue.track() == none && tcr_first_cue(owner.track.cues()).id() == 'recovered.vtt'
						result.order << 'resumed:first.vtt'
					}
				}
				return dom.js_undefined()
			}
		}))
	}
	mut model := html_track_element_model_for_dom_element(track_dom)
	list := model.track.cues()
	tcr_install_fetch(mut model, observed)
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	html_track_element_inserted(track_dom)
	assert observed.order == ['fetch:first.vtt', 'load:first.vtt', 'fetch:missing.vtt', 'error:missing.vtt',
		'fetch:recovered.vtt', 'load:recovered.vtt', 'resumed:error', 'resumed:first.vtt']
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert voidptr(model.track.cues()) == voidptr(list) && observed.cues[0].track() == none
	assert voidptr(tcr_first_cue(list)) == voidptr(observed.cues[1])
	assert model.awaiting_url_change && !model.loading_ && model.event_count('error') == 1
	element.set_attribute_value('src', 'later.vtt')
	assert observed.order[8..] == ['fetch:later.vtt', 'load:later.vtt']
	assert observed.cues[1].track() == none && tcr_first_cue(list).id() == 'later.vtt'
	assert model.event_count('load') == 3 && model.event_count('error') == 1
	assert observed.cors == [CORSSettingAttribute.use_credentials, .use_credentials, .use_credentials, .use_credentials]
}

fn test_dom_track_error_listener_recovers_before_return_and_disabled_load_listener_defers_next_url() {
	mut document := tcr_document('audio')!
	defer { document.finalize() }
	parent := document.get_element_by_id('tcr-parent') or { panic('Missing reentrant audio parent') }
	mut element := document.create_element('track')!
	element.set_attribute_value('src', 'missing.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	target := unsafe { &dom.EventTarget(element) }
	observed := &TcrObservation{}
	target.add_event_listener_without_options('error', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [track_dom, target, observed] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			tcr_assert_event(event, current, target)
			owner := html_track_element_model_for_dom_element(track_dom)
			assert owner.ready_state() == .error && owner.awaiting_url_change && !owner.loading_
			assert owner.track.cues().length() == 0 && owner.event_count('error') == 1
			mut result := unsafe { &TcrObservation(observed) }
			result.order << 'error:missing.vtt'
			mut element_owner := unsafe { &dom.Element(track_dom) }
			element_owner.set_attribute_value('src', 'recovered.vtt')
			assert owner.ready_state() == .loaded && owner.track.mode() == .disabled
			assert owner.src_ == 'paused.vtt' && owner.track.cues().length() == 0
			assert owner.awaiting_url_change && owner.event_count('load') == 1
			result.order << 'resumed:error'
			return dom.js_undefined()
		}
	}))
	target.add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [track_dom, target, observed] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			tcr_assert_event(event, current, target)
			mut owner := html_track_element_model_for_dom_element(track_dom)
			assert owner.ready_state() == .loaded && owner.awaiting_url_change && !owner.loading_
			cue := tcr_first_cue(owner.track.cues())
			mut result := unsafe { &TcrObservation(observed) }
			result.cues << cue
			result.order << 'load:${cue.id()}'
			if cue.id() == 'recovered.vtt' {
				owner.set_mode(.disabled)
				mut element_owner := unsafe { &dom.Element(track_dom) }
				element_owner.set_attribute_value('src', 'paused.vtt')
				assert cue.track() == none && owner.track.cues().length() == 0
				assert result.urls.len == 2 && owner.event_count('load') == 1
			}
			return dom.js_undefined()
		}
	}))
	mut model := html_track_element_model_for_dom_element(track_dom)
	list := model.track.cues()
	tcr_install_fetch(mut model, observed)
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	html_track_element_inserted(track_dom)
	assert observed.order == ['fetch:missing.vtt', 'error:missing.vtt', 'fetch:recovered.vtt', 'load:recovered.vtt', 'resumed:error']
	assert model.track_url_ == 'https://track-reentry.example.test/base/paused.vtt'
	assert model.track.mode() == .disabled && model.ready_state() == .loaded
	assert list.length() == 0 && observed.cues[0].track() == none
	model.set_mode(.showing)
	assert observed.urls.len == 2 && model.event_count('load') == 1
	model.start_the_track_processing_model()
	assert observed.order[5..] == ['fetch:paused.vtt', 'load:paused.vtt']
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert voidptr(model.track.cues()) == voidptr(list) && tcr_first_cue(list).id() == 'paused.vtt'
	assert model.event_count('load') == 2 && model.event_count('error') == 1
	element.set_attribute_value('src', './paused.vtt')
	assert list.length() == 0 && observed.cues[1].track() == none
	assert observed.urls.len == 3 && model.event_count('load') == 2 && model.awaiting_url_change
	assert observed.cors == [CORSSettingAttribute.use_credentials, .use_credentials, .use_credentials]
}
