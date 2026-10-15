module html

import dom

const tpc_foreign_namespace = 'urn:track-pending-cues-foreign'

@[heap]
struct TpcObservation {
mut:
	order   []string
	urls    []string
	cors    []CORSSettingAttribute
	manual  []&TextTrackCue
	states  []TrackElementReadyState
	lengths []int
}

fn tpc_document(kind string) !&dom.Document {
	url := dom.URL{ value: 'https://track-pending.example.test/base/document.html' }
	return parse_navigation_document('<!doctype html><body><${kind} id="tpc-parent" crossorigin="use-credentials"></${kind}></body>',
		url, url.origin(), none)!
}

fn tpc_manual(mut model HTMLTrackElementModel, id string) &TextTrackCue {
	mut cue := TextTrackCue.create(3, 4, 'Manual ${id}') or { panic(err) }
	cue.set_id(id)
	mut track := model.track
	track.add_cue(mut cue)
	return cue
}

fn tpc_response(resource string) TextTrackResourceResponse {
	return TextTrackResourceResponse{ body: 'WEBVTT\n\n${resource}\n00:01.250 --> 00:02.500\nFetched ${resource}' }
}

fn tpc_fetch(mut observed TpcObservation, address dom.URL, cors CORSSettingAttribute) string {
	resource := address.serialize().split('/').last()
	observed.order << 'fetch:${resource}'
	observed.urls << address.serialize()
	observed.cors << cors
	return resource
}

fn tpc_listen(model &HTMLTrackElementModel, observed &TpcObservation) {
	target := model.event_target()
	for name in ['load', 'error'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [model, target, observed, name] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert voidptr(event.target() or { panic('Missing pending-cue event target') }) == voidptr(target)
				assert voidptr(current or { panic('Missing pending-cue currentTarget') }) == voidptr(target)
				assert !model.loading_ && model.awaiting_url_change && model.event_count(name) > 0
				assert model.ready_state() == if name == 'load' { TrackElementReadyState.loaded } else { TrackElementReadyState.error }
				mut result := unsafe { &TpcObservation(observed) }
				result.order << name
				result.states << model.ready_state()
				result.lengths << model.track.cues().length()
				return dom.js_undefined()
			}
		}))
	}
}

fn test_same_resolved_source_during_fetch_stops_pending_cues_but_preserves_later_manual_cues_and_completion() {
	for replacement in ['same.vtt', './same.vtt', 'https://track-pending.example.test/base/same.vtt'] {
		for add_manual in [false, true] {
			url := dom.URL{ value: 'https://track-pending.example.test/base/document.html' }
			media := HTMLMediaElement.create(none, url)
			mut model := HTMLTrackElementModel.create(url)
			model.set_parent_media(media)
			model.set_mode(.hidden)
			model.set_src('same.vtt')
			list := model.track.cues()
			before := tpc_manual(mut model, 'before-clear')
			observed := &TpcObservation{}
			tpc_listen(model, observed)
			model.set_fetch_hook(fn [model, observed, replacement, add_manual] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
				mut result := unsafe { &TpcObservation(observed) }
				resource := tpc_fetch(mut result, address, cors)
				if result.urls.len == 1 {
					mut owner := unsafe { &HTMLTrackElementModel(model) }
					owner.set_src(replacement)
					assert owner.track.cues().length() == 0 && owner.ready_state() == .loading
					assert owner.loading_ && !owner.awaiting_url_change && result.urls.len == 1
					result.order << 'cleared:same'
					if add_manual { result.manual << tpc_manual(mut owner, 'after-clear') }
				}
				return tpc_response(resource)
			})
			model.start_the_track_processing_model()
			assert observed.order == ['fetch:same.vtt', 'cleared:same', 'load']
			assert observed.urls == ['https://track-pending.example.test/base/same.vtt']
			assert model.src_ == replacement && model.track_url_ == 'https://track-pending.example.test/base/same.vtt'
			assert before.track() == none && voidptr(model.track.cues()) == voidptr(list)
			assert list.get_cue_by_id('same.vtt') == none && list.length() == if add_manual { 1 } else { 0 }
			if add_manual {
				assert voidptr(list.item(0) or { panic('Missing post-clear manual cue') }) == voidptr(observed.manual[0])
				assert voidptr(observed.manual[0].track() or { panic('Lost post-clear cue owner') }) == voidptr(model.track)
			}
			assert model.ready_state() == .loaded && model.event_count('load') == 1 && model.event_count('error') == 0
			assert model.awaiting_url_change && !model.loading_ && observed.lengths == [if add_manual { 1 } else { 0 }]
			model.set_src('later.vtt')
			assert observed.order[3..] == ['fetch:later.vtt', 'load']
			assert list.length() == 1 && list.get_cue_by_id('later.vtt') != none
			if add_manual { assert observed.manual[0].track() == none }
			assert model.event_count('load') == 2 && model.event_count('error') == 0
			assert observed.cors == [CORSSettingAttribute.no_cors, .no_cors]
		}
	}
}

fn test_dom_source_removal_during_fetch_detaches_attribute_and_pending_cues_without_reselecting_url() {
	for kind in ['audio', 'video'] {
		for method in ['namespace', 'attribute-node', 'named-map'] {
			mut document := tpc_document(kind)!
			defer { document.finalize() }
			parent := document.get_element_by_id('tpc-parent') or { panic('Missing pending-cue media parent') }
			mut element := document.create_element('track')!
			element.set_attribute_value('src', 'same.vtt')
			original := element.get_attribute_node_ns(none, 'src') or { panic('Missing pending source attribute') }
			track_dom := unsafe { &dom.HTMLTrackElement(element) }
			mut model := html_track_element_model_for_dom_element(track_dom)
			list := model.track.cues()
			before := tpc_manual(mut model, 'before-removal')
			observed := &TpcObservation{}
			tpc_listen(model, observed)
			model.set_fetch_hook(fn [track_dom, observed, original, method] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
				mut result := unsafe { &TpcObservation(observed) }
				resource := tpc_fetch(mut result, address, cors)
				if result.urls.len == 1 {
					mut element_owner := unsafe { &dom.Element(track_dom) }
					match method {
						'namespace' { element_owner.remove_attribute_ns(none, 'src') }
						'attribute-node' {
							removed := element_owner.remove_attribute_node(original) or { panic(err) }
							assert voidptr(removed) == voidptr(original)
						}
						else {
							mut attributes := element_owner.attributes()
							removed := attributes.remove_named_item('src') or { panic(err) }
							assert voidptr(removed) == voidptr(original)
						}
					}
					mut owner := html_track_element_model_for_dom_element(track_dom)
					assert original.owner_element() == none && !element_owner.has_attribute_ns(none, 'src')
					assert owner.src_ == 'same.vtt' && owner.track_url_ == address.serialize()
					assert owner.track.cues().length() == 0 && owner.loading_ && !owner.awaiting_url_change
					result.manual << tpc_manual(mut owner, 'after-removal')
					result.order << 'removed:src'
				}
				return tpc_response(resource)
			})
			mut parent_node := parent.as_node()
			parent_node.append_child(element.as_node())!
			html_track_element_inserted(track_dom)
			assert observed.order == ['fetch:same.vtt', 'removed:src', 'load']
			assert before.track() == none && original.owner_element() == none
			assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
			assert voidptr(model.event_target()) == voidptr(element) && voidptr(model.track.cues()) == voidptr(list)
			assert list.length() == 1 && list.get_cue_by_id('same.vtt') == none
			assert voidptr(list.item(0) or { panic('Missing retained removal cue') }) == voidptr(observed.manual[0])
			assert model.ready_state() == .loaded && model.event_count('load') == 1 && observed.lengths == [1]
			element.set_attribute_value('src', 'later.vtt')
			assert observed.order[3..] == ['fetch:later.vtt', 'load']
			assert observed.manual[0].track() == none && list.length() == 1 && list.get_cue_by_id('later.vtt') != none
			assert observed.urls == ['https://track-pending.example.test/base/same.vtt', 'https://track-pending.example.test/base/later.vtt']
			assert model.event_count('load') == 2 && model.event_count('error') == 0
			assert model.awaiting_url_change && !model.loading_
			assert observed.cors == [CORSSettingAttribute.use_credentials, .use_credentials]
		}
	}
}

fn test_pending_cue_clear_keeps_normal_failures_while_foreign_and_metadata_changes_keep_delivery() {
	for mutation in ['same-source', 'remove-source', 'foreign-source', 'metadata'] {
		for outcome in ['success', 'status', 'format', 'network'] {
			mut document := tpc_document('video')!
			defer { document.finalize() }
			parent := document.get_element_by_id('tpc-parent') or { panic('Missing pending-cue outcome parent') }
			mut element := document.create_element('track')!
			element.set_attribute_value('src', 'same.vtt')
			track_dom := unsafe { &dom.HTMLTrackElement(element) }
			mut model := html_track_element_model_for_dom_element(track_dom)
			list := model.track.cues()
			before := tpc_manual(mut model, 'retained')
			observed := &TpcObservation{}
			tpc_listen(model, observed)
			model.set_fetch_hook(fn [track_dom, observed, mutation, outcome] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
				mut result := unsafe { &TpcObservation(observed) }
				resource := tpc_fetch(mut result, address, cors)
				mut element_owner := unsafe { &dom.Element(track_dom) }
				match mutation {
					'same-source' { element_owner.set_attribute_value('src', './same.vtt') }
					'remove-source' { element_owner.remove_attribute_ns(none, 'src') }
					'foreign-source' {
						element_owner.set_attribute_ns_for_bindings(tpc_foreign_namespace, 'src', 'foreign.vtt') or { panic(err) }
						element_owner.set_attribute_ns_for_bindings(tpc_foreign_namespace, 'p:src', 'prefixed.vtt') or { panic(err) }
						element_owner.remove_attribute_ns(tpc_foreign_namespace, 'src')
					}
					else {
						element_owner.set_attribute_value('kind', 'captions')
						element_owner.set_attribute_value('label', 'Live label')
						element_owner.set_attribute_value('srclang', 'en')
						element_owner.set_attribute_value('id', 'live-track')
					}
				}
				if outcome == 'network' { return error('Current pending-cue network error') }
				if outcome == 'status' { return TextTrackResourceResponse{ status: 404 } }
				if outcome == 'format' { return TextTrackResourceResponse{ body: 'Current invalid WebVTT' } }
				return tpc_response(resource)
			})
			mut parent_node := parent.as_node()
			parent_node.append_child(element.as_node())!
			html_track_element_inserted(track_dom)
			cleared := mutation in ['same-source', 'remove-source']
			assert observed.urls == ['https://track-pending.example.test/base/same.vtt']
			assert voidptr(model.track.cues()) == voidptr(list)
			assert model.track_url_ == 'https://track-pending.example.test/base/same.vtt'
			assert (before.track() == none) == cleared
			if outcome == 'success' {
				assert model.ready_state() == .loaded && model.event_count('load') == 1 && model.event_count('error') == 0
				assert list.length() == if cleared { 0 } else { 2 }
				assert (list.get_cue_by_id('same.vtt') == none) == cleared
				assert observed.order == ['fetch:same.vtt', 'load']
			} else {
				assert model.ready_state() == .error && model.event_count('load') == 0 && model.event_count('error') == 1
				assert list.length() == if cleared { 0 } else { 1 }
				assert observed.order == ['fetch:same.vtt', 'error']
			}
			if mutation == 'metadata' {
				assert model.track.kind() == .captions && model.track.label() == 'Live label'
				assert model.track.language() == 'en' && model.track.id() == 'live-track'
			}
			assert observed.cors == [CORSSettingAttribute.use_credentials]
			assert model.awaiting_url_change && !model.loading_
		}
	}
}
