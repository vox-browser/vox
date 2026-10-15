module html

import dom

const tcp_foreign_namespace = 'urn:track-current-parent-foreign'

@[heap]
struct TcpObservation {
mut:
	order []string
	urls  []string
	cors  []CORSSettingAttribute
	acted bool
}

fn tcp_document(markup string, address string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn tcp_append(parent &dom.Element, child &dom.Element) {
	mut node := parent.as_node()
	node.append_child(child.as_node()) or { panic(err) }
}

fn tcp_response() TextTrackResourceResponse {
	return TextTrackResourceResponse{ body: 'WEBVTT\n\ncurrent-parent\n00:01.250 --> 00:02.500\nCurrent parent cue' }
}

fn tcp_fetch(mut observed TcpObservation, address dom.URL, cors CORSSettingAttribute) {
	observed.order << 'fetch'
	observed.urls << address.serialize()
	observed.cors << cors
}

fn tcp_install_fetch(mut model HTMLTrackElementModel, observed &TcpObservation) {
	model.set_fetch_hook(fn [observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut result := unsafe { &TcpObservation(observed) }
		tcp_fetch(mut result, address, cors)
		return tcp_response()
	})
}

fn tcp_listen(model &HTMLTrackElementModel, observed &TcpObservation) {
	target := model.event_target()
	target.add_event_listener_without_options('load', dom.IDLEventListener.create(&dom.CallbackType{
		handle_event: fn [model, target, observed] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
			assert voidptr(event.target() or { panic('Missing current-parent event target') }) == voidptr(target)
			assert voidptr(current or { panic('Missing current-parent currentTarget') }) == voidptr(target)
			assert model.ready_state() == .loaded && model.track.cues().length() == 1
			assert !model.loading_ && model.awaiting_url_change
			mut result := unsafe { &TcpObservation(observed) }
			result.order << 'load'
			return dom.js_undefined()
		}
	}))
}

fn test_dom_track_initial_start_uses_immediate_html_media_parent_even_when_cached_parent_is_stale_or_none() {
	mut document := tcp_document('<!doctype html><body><audio id="old" crossorigin="use-credentials"><div id="wrapper"></div></audio><video id="current" crossorigin></video></body>',
		'https://track-parent.example.test/base/document.html')!
	defer { document.finalize() }
	old := document.get_element_by_id('old') or { panic('Missing cached track parent') }
	mut current := document.get_element_by_id('current') or { panic('Missing actual track parent') }
	wrapper := document.get_element_by_id('wrapper') or { panic('Missing nonmedia track wrapper') }
	cached := html_media_element_for_dom_element(old) or { panic('Missing cached media model') }
	actual := html_media_element_for_dom_element(current) or { panic('Missing current media model') }
	current.set_attribute_ns_for_bindings(tcp_foreign_namespace, 'crossorigin', 'use-credentials')!
	for variant in ['detached', 'wrapper', 'svg-audio', 'svg-video'] {
		mut element := document.create_element('track')!
		element.set_attribute_value('src', '${variant}.vtt')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		model.set_parent_media(cached)
		model.set_mode(.hidden)
		observed := &TcpObservation{}
		tcp_install_fetch(mut model, observed)
		tcp_listen(model, observed)
		if variant == 'wrapper' {
			tcp_append(wrapper, element)
		} else if variant.starts_with('svg-') {
			fake := document.create_element_ns('http://www.w3.org/2000/svg', variant.all_after('svg-'))!
			tcp_append(fake, element)
			assert html_media_element_for_dom_element(fake) == none
		}
		model.start_the_track_processing_model()
		assert observed.urls == [] && observed.order == [] && model.ready_state() == .none
		assert !model.loading_ && !model.awaiting_url_change && model.track.cues().length() == 0
		assert model.event_count('load') == 0 && model.event_count('error') == 0
		tcp_append(current, element)
		model.set_parent_media(none)
		model.start_the_track_processing_model()
		assert observed.order == ['fetch', 'load'] && observed.cors == [CORSSettingAttribute.anonymous]
		assert observed.urls == ['https://track-parent.example.test/base/${variant}.vtt']
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(model.event_target()) == voidptr(element) && model.event_count('load') == 1
	}
	assert cached.network_state() == .empty && actual.network_state() == .empty
	assert cached.event_count('loadstart') == 0 && actual.event_count('loadstart') == 0
}

fn test_track_loading_observer_relocation_uses_current_parent_cors_or_no_cors_before_fetch() {
	for action in ['media', 'detached', 'div', 'svg-video'] {
		mut document := tcp_document('<!doctype html><body><audio id="old" crossorigin="use-credentials"></audio><video id="next" crossorigin></video><div id="box"></div></body>',
			'https://track-parent.example.test/loading/document.html')!
		defer { document.finalize() }
		old := document.get_element_by_id('old') or { panic('Missing loading-observer parent') }
		next := document.get_element_by_id('next') or { panic('Missing replacement media parent') }
		box := document.get_element_by_id('box') or { panic('Missing nonmedia replacement parent') }
		fake := document.create_element_ns('http://www.w3.org/2000/svg', 'video')!
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'selected.vtt')
		tcp_append(old, element)
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		model.set_parent_media(html_media_element_for_dom_element(old) or { panic('Missing old media owner') })
		model.set_mode(.showing)
		observed := &TcpObservation{}
		tcp_listen(model, observed)
		model.set_fetch_hook(fn [observed, next, action] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
			mut result := unsafe { &TcpObservation(observed) }
			tcp_fetch(mut result, address, cors)
			if action == 'media' && result.urls.len == 1 {
				mut next_parent := unsafe { &dom.Element(next) }
				next_parent.set_attribute_value('crossorigin', 'use-credentials')
				assert cors == .anonymous
			}
			return tcp_response()
		})
		mut track := model.track
		mut observer := TextTrackObserver.create(mut track)
		defer { observer.finalize() }
		observer.set_track_readiness_observer(fn [observed, element, next, box, fake, action] (state TextTrackReadinessState) {
			mut result := unsafe { &TcpObservation(observed) }
			result.order << 'notify:${state}'
			if state == .loading && !result.acted {
				result.acted = true
				match action {
					'media' { tcp_append(next, element) }
					'div' { tcp_append(box, element) }
					'svg-video' { tcp_append(fake, element) }
					else {
						mut node := element.as_node()
						node.remove(false)
					}
				}
			}
		})
		model.start_the_track_processing_model()
		assert observed.order == ['notify:loading', 'fetch', 'notify:loaded', 'load']
		expected := if action == 'media' { CORSSettingAttribute.anonymous } else { CORSSettingAttribute.no_cors }
		assert observed.cors == [expected] && observed.urls == ['https://track-parent.example.test/loading/selected.vtt']
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		assert model.ready_state() == .loaded && !model.loading_ && model.awaiting_url_change
		if action == 'media' {
			element.set_attribute_value('src', 'later.vtt')
			assert observed.cors == [CORSSettingAttribute.anonymous, .use_credentials]
			assert model.event_count('load') == 2
		}
	}
}

fn test_completed_track_reparenting_and_adoption_use_current_media_cors_and_document_base_without_inserted() {
	mut original := tcp_document('<!doctype html><body><audio id="old" crossorigin="use-credentials"></audio><video id="local"></video></body>',
		'https://old-track-parent.example.test/old/document.html')!
	mut destination := tcp_document('<!doctype html><body><video id="adopted" crossorigin></video></body>',
		'https://new-track-parent.example.test/new/document.html')!
	defer { original.finalize(); destination.finalize() }
	old := original.get_element_by_id('old') or { panic('Missing original completed-track parent') }
	local := original.get_element_by_id('local') or { panic('Missing local completed-track parent') }
	adopted := destination.get_element_by_id('adopted') or { panic('Missing adopted completed-track parent') }
	mut element := original.create_element('track')!
	element.set_attribute_value('src', 'first.vtt')
	tcp_append(old, element)
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	mut model := html_track_element_model_for_dom_element(track_dom)
	observed := &TcpObservation{}
	tcp_install_fetch(mut model, observed)
	tcp_listen(model, observed)
	html_track_element_inserted(track_dom)
	list := model.track.cues()
	first := list.item(0) or { panic('Missing first completed-track cue') }
	tcp_append(local, element)
	element.set_attribute_value('src', 'second.vtt')
	assert first.track() == none && list.length() == 1
	second := list.item(0) or { panic('Missing reparented track cue') }
	destination.adopt_node(element.as_node())
	tcp_append(adopted, element)
	element.set_attribute_value('src', 'third.vtt')
	assert second.track() == none && voidptr(element.document()) == voidptr(destination)
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track.cues()) == voidptr(list)
	assert observed.cors == [CORSSettingAttribute.use_credentials, .no_cors, .anonymous]
	assert observed.urls == ['https://old-track-parent.example.test/old/first.vtt',
		'https://old-track-parent.example.test/old/second.vtt', 'https://new-track-parent.example.test/new/third.vtt']
	assert observed.order == ['fetch', 'load', 'fetch', 'load', 'fetch', 'load']
	assert model.track_url_ == 'https://new-track-parent.example.test/new/third.vtt'
	assert model.event_count('load') == 3 && model.event_count('error') == 0
	assert model.ready_state() == .loaded && list.length() == 1 && !model.loading_ && model.awaiting_url_change
	for parent in [old, local, adopted] {
		media := html_media_element_for_dom_element(parent) or { panic('Missing unchanged media owner') }
		assert media.network_state() == .empty && media.current_src() == '' && media.paused()
		assert media.event_count('loadstart') == 0 && media.event_count('play') == 0
	}
}

fn test_standalone_track_keeps_parent_fallback_none_gate_and_observes_replacement_parent_cors() {
	url := dom.URL{ value: 'https://standalone-track-parent.example.test/base/' }
	mut first := HTMLMediaElement.create(none, url)
	mut second := HTMLMediaElement.create(none, url)
	first.set_crossorigin('use-credentials')
	second.set_crossorigin('anonymous')
	mut model := HTMLTrackElementModel.create(url)
	model.set_mode(.hidden)
	model.set_src('first.vtt')
	observed := &TcpObservation{}
	tcp_install_fetch(mut model, observed)
	tcp_listen(model, observed)
	model.start_the_track_processing_model()
	assert observed.urls == [] && model.ready_state() == .none && !model.loading_
	assert model.event_count('load') == 0 && model.event_count('error') == 0
	model.set_parent_media(first)
	model.start_the_track_processing_model()
	model.set_parent_media(second)
	model.set_src('second.vtt')
	model.set_parent_media(none)
	model.start_the_track_processing_model()
	assert observed.urls.len == 2 && model.ready_state() == .loaded && model.event_count('load') == 2
	model.set_parent_media(first)
	first.set_crossorigin(none)
	model.set_src('third.vtt')
	assert observed.cors == [CORSSettingAttribute.use_credentials, .anonymous, .no_cors]
	assert observed.urls == ['https://standalone-track-parent.example.test/base/first.vtt',
		'https://standalone-track-parent.example.test/base/second.vtt', 'https://standalone-track-parent.example.test/base/third.vtt']
	assert observed.order == ['fetch', 'load', 'fetch', 'load', 'fetch', 'load']
	assert model.event_count('load') == 3 && model.event_count('error') == 0
	assert model.ready_state() == .loaded && !model.loading_ && model.awaiting_url_change
	assert first.network_state() == .empty && second.network_state() == .empty
}
