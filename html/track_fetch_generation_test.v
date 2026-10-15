module html

import dom

@[heap]
struct TfgObservation {
mut:
	order []string
	urls  []string
	cors  []CORSSettingAttribute
	cues  []&TextTrackCue
	stage int
}

fn tfg_document(kind string) !&dom.Document {
	url := dom.URL{ value: 'https://track-generation.example.test/base/document.html' }
	return parse_navigation_document('<!doctype html><body><${kind} id="tfg-parent" crossorigin="use-credentials"></${kind}></body>',
		url, url.origin(), none)!
}

fn tfg_fetch(mut observed TfgObservation, url dom.URL, cors CORSSettingAttribute) string {
	resource := url.serialize().split('/').last()
	observed.order << 'fetch:${resource}'
	observed.urls << url.serialize()
	observed.cors << cors
	return resource
}

fn tfg_response(id string) TextTrackResourceResponse {
	return TextTrackResourceResponse{ body: 'WEBVTT\n\n${id}\n00:01.250 --> 00:02.500\nCue from ${id}' }
}

fn tfg_cue(list &TextTrackCueList) &TextTrackCue {
	assert list.length() == 1
	return list.item(0) or { panic('Missing current generation cue') }
}

fn tfg_seed(mut model HTMLTrackElementModel) &TextTrackCue {
	mut cue := TextTrackCue.create(3, 4, 'Seed cue') or { panic(err) }
	cue.set_id('seed')
	mut track := model.track
	track.add_cue(mut cue)
	return cue
}

fn tfg_listen(model &HTMLTrackElementModel, observed &TfgObservation) {
	target := model.event_target()
	for name in ['load', 'error'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [model, observed, target, name] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert voidptr(event.target() or { panic('Missing generation event target') }) == voidptr(target)
				assert voidptr(current or { panic('Missing generation currentTarget') }) == voidptr(target)
				assert model.awaiting_url_change && !model.loading_
				mut result := unsafe { &TfgObservation(observed) }
				if name == 'load' {
					assert model.ready_state() == .loaded
					cue := tfg_cue(model.track.cues())
					result.cues << cue
					result.order << 'load:${cue.id()}'
				} else {
					assert model.ready_state() == .error && model.track.cues().length() == 0
					result.order << 'error:${model.src_}'
				}
				return dom.js_undefined()
			}
		}))
	}
}

fn test_track_superseded_fetch_success_status_format_and_network_results_preserve_current_completion() {
	for outcome in ['success', 'status', 'format', 'network'] {
		url := dom.URL{ value: 'https://track-generation.example.test/base/document.html' }
		media := HTMLMediaElement.create(none, url)
		mut model := HTMLTrackElementModel.create(url)
		model.set_parent_media(media)
		model.set_mode(.hidden)
		model.set_src('outer.vtt')
		list := model.track.cues()
		seed := tfg_seed(mut model)
		observed := &TfgObservation{}
		tfg_listen(model, observed)
		model.set_fetch_hook(fn [model, observed, outcome, seed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
			mut result := unsafe { &TfgObservation(observed) }
			resource := tfg_fetch(mut result, address, cors)
			if resource != 'outer.vtt' { return tfg_response(resource) }
			mut owner := unsafe { &HTMLTrackElementModel(model) }
			owner.set_src('current.vtt')
			assert owner.ready_state() == .loaded && tfg_cue(owner.track.cues()).id() == 'current.vtt'
			assert seed.track() == none && owner.event_count('load') == 1
			result.order << 'return:outer.vtt'
			if outcome == 'network' { return error('Obsolete controlled network error') }
			if outcome == 'status' { return TextTrackResourceResponse{ status: 404 } }
			if outcome == 'format' { return TextTrackResourceResponse{ body: 'Obsolete invalid WebVTT' } }
			return tfg_response('obsolete-outer')
		})
		model.start_the_track_processing_model()
		assert observed.order == ['fetch:outer.vtt', 'fetch:current.vtt', 'load:current.vtt', 'return:outer.vtt']
		assert voidptr(model.track.cues()) == voidptr(list) && tfg_cue(list).id() == 'current.vtt'
		assert model.ready_state() == .loaded && model.awaiting_url_change && !model.loading_
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		model.set_src('later.vtt')
		assert observed.order[4..] == ['fetch:later.vtt', 'load:later.vtt']
		assert observed.cues[0].track() == none && tfg_cue(list).id() == 'later.vtt'
		assert model.event_count('load') == 2 && model.event_count('error') == 0
		assert observed.urls == ['https://track-generation.example.test/base/outer.vtt',
			'https://track-generation.example.test/base/current.vtt', 'https://track-generation.example.test/base/later.vtt']
		assert observed.cors == [CORSSettingAttribute.no_cors, .no_cors, .no_cors]
	}
}

fn test_dom_track_fetch_a_to_b_to_a_keeps_only_latest_generation_in_audio_and_video() {
	for kind in ['audio', 'video'] {
		mut document := tfg_document(kind)!
		defer { document.finalize() }
		parent := document.get_element_by_id('tfg-parent') or { panic('Missing generation media parent') }
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'a.vtt')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		list := model.track.cues()
		seed := tfg_seed(mut model)
		observed := &TfgObservation{}
		tfg_listen(model, observed)
		model.set_fetch_hook(fn [track_dom, observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
			mut result := unsafe { &TfgObservation(observed) }
			resource := tfg_fetch(mut result, address, cors)
			mut element_owner := unsafe { &dom.Element(track_dom) }
			if resource == 'a.vtt' && result.stage == 0 {
				result.stage = 1
				element_owner.set_attribute_value('src', 'b.vtt')
				result.order << 'return:first-a'
				return tfg_response('obsolete-first-a')
			}
			if resource == 'b.vtt' {
				result.stage = 2
				element_owner.set_attribute_value('src', 'a.vtt')
				result.order << 'return:b'
				return tfg_response('obsolete-b')
			}
			return tfg_response(if resource == 'a.vtt' { 'latest-a' } else { resource })
		})
		mut parent_node := parent.as_node()
		parent_node.append_child(element.as_node())!
		html_track_element_inserted(track_dom)
		assert observed.order == ['fetch:a.vtt', 'fetch:b.vtt', 'fetch:a.vtt', 'load:latest-a', 'return:b', 'return:first-a']
		assert observed.stage == 2 && observed.cues.len == 1 && seed.track() == none
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track.cues()) == voidptr(list)
		assert tfg_cue(list).id() == 'latest-a' && model.src_ == 'a.vtt'
		assert model.track_url_ == 'https://track-generation.example.test/base/a.vtt'
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		element.set_attribute_value('src', 'later.vtt')
		assert observed.order[6..] == ['fetch:later.vtt', 'load:later.vtt']
		assert observed.cues[0].track() == none && tfg_cue(list).id() == 'later.vtt'
		assert model.ready_state() == .loaded && model.awaiting_url_change && !model.loading_
		assert model.event_count('load') == 2 && model.event_count('error') == 0
		assert observed.urls == ['https://track-generation.example.test/base/a.vtt',
			'https://track-generation.example.test/base/b.vtt', 'https://track-generation.example.test/base/a.vtt',
			'https://track-generation.example.test/base/later.vtt']
		assert observed.cors == [CORSSettingAttribute.use_credentials, .use_credentials, .use_credentials, .use_credentials]
	}
}

fn test_dom_track_superseded_fetch_cannot_overwrite_nested_listener_failure_and_later_recovery() {
	mut document := tfg_document('video')!
	defer { document.finalize() }
	parent := document.get_element_by_id('tfg-parent') or { panic('Missing nested generation media parent') }
	mut element := document.create_element('track')!
	element.set_attribute_value('src', 'outer.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	mut model := html_track_element_model_for_dom_element(track_dom)
	list := model.track.cues()
	observed := &TfgObservation{}
	for name in ['load', 'error'] {
		model.event_target().add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [track_dom, observed, name] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				mut owner := html_track_element_model_for_dom_element(track_dom)
				assert voidptr(event.target() or { panic('Missing nested generation target') }) == voidptr(track_dom)
				assert voidptr(current or { panic('Missing nested generation currentTarget') }) == voidptr(track_dom)
				assert owner.awaiting_url_change && !owner.loading_
				mut result := unsafe { &TfgObservation(observed) }
				mut element_owner := unsafe { &dom.Element(track_dom) }
				if name == 'error' {
					assert owner.ready_state() == .error && owner.track.cues().length() == 0
					result.order << 'error:${owner.src_}'
					if owner.src_ == 'missing.vtt' {
						element_owner.set_attribute_value('src', 'recovered.vtt')
						result.order << 'resumed:missing'
					}
				} else {
					assert owner.ready_state() == .loaded
					cue := tfg_cue(owner.track.cues())
					result.cues << cue
					result.order << 'load:${cue.id()}'
					if cue.id() == 'recovered.vtt' {
						element_owner.set_attribute_value('src', 'terminal.vtt')
						assert cue.track() == none && owner.ready_state() == .error
						result.order << 'resumed:recovered'
					}
				}
				return dom.js_undefined()
			}
		}))
	}
	model.set_fetch_hook(fn [track_dom, observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut result := unsafe { &TfgObservation(observed) }
		resource := tfg_fetch(mut result, address, cors)
		if resource == 'outer.vtt' {
			mut element_owner := unsafe { &dom.Element(track_dom) }
			element_owner.set_attribute_value('src', 'missing.vtt')
			result.order << 'return:outer.vtt'
			return tfg_response('obsolete-outer')
		}
		if resource == 'missing.vtt' { return TextTrackResourceResponse{ status: 404 } }
		if resource == 'terminal.vtt' { return error('Current controlled network error') }
		return tfg_response(resource)
	})
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	html_track_element_inserted(track_dom)
	assert observed.order == ['fetch:outer.vtt', 'fetch:missing.vtt', 'error:missing.vtt', 'fetch:recovered.vtt',
		'load:recovered.vtt', 'fetch:terminal.vtt', 'error:terminal.vtt', 'resumed:recovered', 'resumed:missing', 'return:outer.vtt']
	assert model.src_ == 'terminal.vtt' && model.ready_state() == .error
	assert model.event_count('load') == 1 && model.event_count('error') == 2
	assert model.awaiting_url_change && !model.loading_ && list.length() == 0
	assert observed.cues.len == 1 && observed.cues[0].track() == none
	element.set_attribute_value('src', 'later.vtt')
	assert observed.order[10..] == ['fetch:later.vtt', 'load:later.vtt']
	assert voidptr(model.track.cues()) == voidptr(list) && tfg_cue(list).id() == 'later.vtt'
	assert model.ready_state() == .loaded && model.event_count('load') == 2 && model.event_count('error') == 2
	assert observed.urls.len == 5 && observed.cors == [CORSSettingAttribute.use_credentials, .use_credentials, .use_credentials, .use_credentials, .use_credentials]
}
