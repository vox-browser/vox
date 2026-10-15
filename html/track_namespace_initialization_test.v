module html

import dom

const tni_foreign_namespace = 'urn:track-initialization-foreign'
const tni_second_namespace = 'urn:track-initialization-second'
const tni_prefixed_namespace = 'urn:track-initialization-prefixed'

@[heap]
struct TniFetchProbe {
mut:
	urls []string
	cors []CORSSettingAttribute
}

fn tni_document(markup string) !&dom.Document {
	url := dom.URL{ value: 'https://track-initialization.example.test/base/document.html' }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn tni_attribute(element &dom.Element, namespace ?string, name string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, name) or {
		return error('Missing track initialization attribute ${name}')
	}
}

fn tni_preserved_attribute(element &dom.Element, attribute &dom.Attr_, namespace ?string, name string, raw string) ! {
	assert voidptr(tni_attribute(element, namespace, name)!) == voidptr(attribute)
	assert voidptr(attribute.owner_element() or { panic('Missing track attribute owner') }) == voidptr(element)
	assert attribute.value() == raw
}

fn test_track_namespace_initialization_uses_null_metadata_and_source_without_rewriting_attributes() {
	mut document := tni_document('<!doctype html><body></body>')!
	defer { document.finalize() }
	names := ['kind', 'label', 'srclang', 'id', 'src']
	foreign_values := ['chapters', ' Foreign label ', 'fr', 'foreign-track', 'foreign.vtt']
	null_values := ['CaPtIoNs', ' Selected label\t ', 'en-GB', 'selected-track', 'selected.vtt?raw=%20#cue']
	for variant in ['foreign-only', 'null-first', 'foreign-first'] {
		mut element := document.create_element('track')!
		for index, name in names {
			if variant == 'null-first' { element.set_attribute_value(name, null_values[index]) }
			element.set_attribute_ns_for_bindings(tni_foreign_namespace, name, foreign_values[index])!
			if variant == 'foreign-first' { element.set_attribute_value(name, null_values[index]) }
			element.set_attribute_ns_for_bindings(tni_second_namespace, name, 'second-${name}')!
			element.set_attribute_ns_for_bindings(tni_prefixed_namespace, 'p:${name}', 'prefixed-${name}')!
		}
		mut first := []&dom.Attr_{}
		mut second := []&dom.Attr_{}
		mut prefixed := []&dom.Attr_{}
		mut actual := []&dom.Attr_{}
		for name in names {
			first << tni_attribute(element, tni_foreign_namespace, name)!
			second << tni_attribute(element, tni_second_namespace, name)!
			prefixed << tni_attribute(element, tni_prefixed_namespace, name)!
			if variant != 'foreign-only' { actual << tni_attribute(element, none, name)! }
		}
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		model := html_track_element_model_for_dom_element(track_dom)
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(html_track_element_track(track_dom)) == voidptr(model.track)
		if variant == 'foreign-only' {
			assert model.track.kind() == .subtitles
			assert model.track.label() == '' && model.track.language() == '' && model.track.id() == ''
			assert model.src_ == '' && model.track_url_ == ''
		} else {
			assert model.track.kind() == .captions
			assert model.track.label() == null_values[1] && model.track.language() == null_values[2]
			assert model.track.id() == null_values[3] && model.src_ == null_values[4]
			assert model.track_url_ == 'https://track-initialization.example.test/base/${null_values[4]}'
		}
		assert model.track.mode() == .disabled && model.ready_state() == .none
		assert model.track.cues().length() == 0 && model.parent_media_ == none
		assert model.event_count('load') == 0 && model.event_count('error') == 0
		for index, name in names {
			tni_preserved_attribute(element, first[index], tni_foreign_namespace, name, foreign_values[index])!
			tni_preserved_attribute(element, second[index], tni_second_namespace, name, 'second-${name}')!
			tni_preserved_attribute(element, prefixed[index], tni_prefixed_namespace, name, 'prefixed-${name}')!
			assert prefixed[index].name() == 'p:${name}' && (prefixed[index].prefix() or { '' }) == 'p'
			if variant == 'foreign-only' {
				assert !element.has_attribute_ns(none, name)
			} else {
				tni_preserved_attribute(element, actual[index], none, name, null_values[index])!
			}
			assert element.get_attribute_value(name) == if variant == 'null-first' { null_values[index] } else { foreign_values[index] }
		}
	}
}

fn test_track_missing_or_empty_source_fails_without_fetching_document_and_recovers_on_real_url() {
	for kind in ['audio', 'video'] {
		mut document := tni_document('<!doctype html><${kind} id="tni-parent"></${kind}>')!
		defer { document.finalize() }
		mut parent := document.get_element_by_id('tni-parent') or { panic('Missing track parent') }
		media := html_media_element_for_dom_element(parent) or { panic('Missing track media owner') }
		for variant in ['absent', 'empty', 'foreign-only'] {
			mut element := document.create_element('track')!
			if variant == 'empty' { element.set_attribute_value('src', '') }
			if variant == 'foreign-only' {
				element.set_attribute_ns_for_bindings(tni_foreign_namespace, 'src', 'ignored.vtt')!
				element.set_attribute_ns_for_bindings(tni_prefixed_namespace, 'p:src', 'prefixed-ignored.vtt')!
			}
			track_dom := unsafe { &dom.HTMLTrackElement(element) }
			mut model := html_track_element_model_for_dom_element(track_dom)
			probe := &TniFetchProbe{}
			model.set_fetch_hook(fn [probe] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
				mut observation := unsafe { &TniFetchProbe(probe) }
				observation.urls << url.serialize()
				observation.cors << cors
				return TextTrackResourceResponse{ body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nrecovered cue' }
			})
			mut parent_node := parent.as_node()
			parent_node.append_child(element.as_node())!
			html_track_element_inserted(track_dom)
			actual_parent := model.parent_media_ or { panic('Missing inserted track media') }
			assert voidptr(actual_parent) == voidptr(media)
			assert model.src_ == '' && model.track_url_ == '' && model.track.mode() == .hidden
			assert model.ready_state() == .error && !model.loading_ && model.awaiting_url_change
			assert probe.urls == [] && probe.cors == [] && model.track.cues().length() == 0
			assert model.event_count('error') == 1 && model.event_count('load') == 0
			if variant == 'empty' { assert element.has_attribute_ns(none, 'src') }
			if variant == 'foreign-only' {
				assert !element.has_attribute_ns(none, 'src')
				assert element.get_attribute_value('src') == 'ignored.vtt'
				assert (element.get_attribute_ns(tni_prefixed_namespace, 'src') or { '' }) == 'prefixed-ignored.vtt'
			}
			model.set_src('recovered.vtt')
			assert probe.urls == ['https://track-initialization.example.test/base/recovered.vtt']
			assert probe.cors == [CORSSettingAttribute.no_cors]
			assert model.ready_state() == .loaded && model.track.cues().length() == 1
			assert model.event_count('error') == 1 && model.event_count('load') == 1
			model.set_src('')
			assert model.src_ == '' && model.track_url_ == '' && model.ready_state() == .error
			assert model.event_count('error') == 2 && model.event_count('load') == 1
			model.set_src('')
			assert probe.urls.len == 1 && model.event_count('error') == 2
			assert media.paused() && media.current_src() == '' && media.network_state() == .empty
			assert media.event_count('loadstart') == 0 && media.event_count('play') == 0
		}
	}
}

fn test_track_null_source_fetches_webvtt_through_actual_media_parent_cors_in_either_attribute_order() {
	for kind in ['audio', 'video'] {
		mut document := tni_document('<!doctype html><${kind} id="tni-parent"></${kind}>')!
		defer { document.finalize() }
		mut parent := document.get_element_by_id('tni-parent') or { panic('Missing track CORS parent') }
		parent.set_attribute_ns_for_bindings(tni_foreign_namespace, 'crossorigin', 'invalid foreign CORS')!
		parent.set_attribute_value('crossorigin', if kind == 'audio' { 'UsE-CrEdEnTiAlS' } else { '' })
		media := html_media_element_for_dom_element(parent) or { panic('Missing track CORS owner') }
		for null_first in [false, true] {
			mut element := document.create_element('track')!
			if null_first { element.set_attribute_value('src', 'selected.vtt?raw=%20') }
			element.set_attribute_ns_for_bindings(tni_foreign_namespace, 'src', 'https://foreign.example.test/ignored.vtt')!
			if !null_first { element.set_attribute_value('src', 'selected.vtt?raw=%20') }
			element.set_attribute_ns_for_bindings(tni_prefixed_namespace, 'p:src', 'prefixed-ignored.vtt')!
			element.set_attribute_value('kind', 'captions')
			element.set_attribute_value('label', 'Selected captions')
			element.set_attribute_value('srclang', 'en')
			element.set_attribute_value('id', 'selected-track')
			foreign := tni_attribute(element, tni_foreign_namespace, 'src')!
			prefixed := tni_attribute(element, tni_prefixed_namespace, 'src')!
			actual := tni_attribute(element, none, 'src')!
			track_dom := unsafe { &dom.HTMLTrackElement(element) }
			mut model := html_track_element_model_for_dom_element(track_dom)
			probe := &TniFetchProbe{}
			model.set_fetch_hook(fn [probe] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
				mut observation := unsafe { &TniFetchProbe(probe) }
				observation.urls << url.serialize()
				observation.cors << cors
				return TextTrackResourceResponse{ body: 'WEBVTT\n\nselected-cue\n00:01.250 --> 00:02.500\nSelected text' }
			})
			mut parent_node := parent.as_node()
			parent_node.append_child(element.as_node())!
			html_track_element_inserted(track_dom)
			assert probe.urls == ['https://track-initialization.example.test/base/selected.vtt?raw=%20']
			expected_cors := if kind == 'audio' { CORSSettingAttribute.use_credentials } else { CORSSettingAttribute.anonymous }
			assert probe.cors == [expected_cors]
			actual_parent := model.parent_media_ or { panic('Missing fetched track media') }
			assert voidptr(actual_parent) == voidptr(media)
			assert model.ready_state() == .loaded && model.track.mode() == .hidden
			assert model.track.kind() == .captions && model.track.label() == 'Selected captions'
			assert model.track.language() == 'en' && model.track.id() == 'selected-track'
			assert model.event_count('load') == 1 && model.event_count('error') == 0
			assert model.track.cues().length() == 1
			cue := model.track.cues().item(0) or { panic('Missing selected WebVTT cue') }
			assert cue.id() == 'selected-cue' && cue.text() == 'Selected text'
			assert cue.start_time() == 1.25 && cue.end_time() == 2.5
			tni_preserved_attribute(element, foreign, tni_foreign_namespace, 'src', 'https://foreign.example.test/ignored.vtt')!
			tni_preserved_attribute(element, prefixed, tni_prefixed_namespace, 'src', 'prefixed-ignored.vtt')!
			tni_preserved_attribute(element, actual, none, 'src', 'selected.vtt?raw=%20')!
			assert media.paused() && media.current_src() == '' && media.network_state() == .empty
			assert media.event_count('loadstart') == 0 && media.event_count('play') == 0
		}
	}
}
