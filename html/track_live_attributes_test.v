module html

import dom

const tla_foreign_namespace = 'urn:track-live-attributes-foreign'

@[heap]
struct TlaFetchProbe {
mut:
	urls []string
	cors []CORSSettingAttribute
}

fn tla_document(markup string, address string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn tla_attribute(element &dom.Element, namespace ?string, name string) !&dom.Attr_ {
	return element.get_attribute_node_ns(namespace, name) or {
		return error('Missing live track attribute ${name}')
	}
}

fn tla_assert_attribute(element &dom.Element, attribute &dom.Attr_, namespace ?string, name string, raw string) ! {
	assert voidptr(tla_attribute(element, namespace, name)!) == voidptr(attribute)
	assert voidptr(attribute.owner_element() or { panic('Missing live track attribute owner') }) == voidptr(element)
	assert attribute.value() == raw
}

fn tla_install_fetch_probe(mut model HTMLTrackElementModel) &TlaFetchProbe {
	probe := &TlaFetchProbe{}
	model.set_fetch_hook(fn [probe] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut observation := unsafe { &TlaFetchProbe(probe) }
		observation.urls << url.serialize()
		observation.cors << cors
		return TextTrackResourceResponse{ body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nLive cue' }
	})
	return probe
}

fn test_track_live_metadata_preserves_lazy_model_and_namespace_attribute_identity() {
	mut document := tla_document('<!doctype html><body></body>', 'https://track-live.example.test/base/document.html')!
	defer { document.finalize() }
	mut element := document.create_element('track')!
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	element.set_attribute_value('data-unrelated', 'before initialization')
	element.set_attribute_ns_for_bindings(tla_foreign_namespace, 'kind', 'chapters')!
	element.set_attribute_value('label', 'Initial label')
	assert track_dom.track_element_model_ == unsafe { nil }
	mut model := html_track_element_model_for_dom_element(track_dom)
	assert model.track.label() == 'Initial label' && model.track.kind() == .subtitles
	names := ['kind', 'label', 'srclang', 'id']
	values := ['CaPtIoNs', ' Updated label\t ', 'en-GB', 'live-track']
	mut actual_attributes := []&dom.Attr_{}
	mut foreign_attributes := []&dom.Attr_{}
	for index, name in names {
		element.set_attribute_value(name, values[index])
		actual_attributes << tla_attribute(element, none, name)!
		element.set_attribute_ns_for_bindings(tla_foreign_namespace, name, 'foreign-${name}')!
		foreign_attributes << tla_attribute(element, tla_foreign_namespace, name)!
	}
	assert model.track.kind() == .captions && model.track.label() == values[1]
	assert model.track.language() == values[2] && model.track.id() == values[3]
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert voidptr(html_track_element_track(track_dom)) == voidptr(model.track)
	for index, name in names {
		tla_assert_attribute(element, actual_attributes[index], none, name, values[index])!
		tla_assert_attribute(element, foreign_attributes[index], tla_foreign_namespace, name, 'foreign-${name}')!
		element.remove_attribute_ns(tla_foreign_namespace, name)
		assert foreign_attributes[index].owner_element() == none
	}
	assert model.track.kind() == .captions && model.track.label() == values[1]
	assert model.track.language() == values[2] && model.track.id() == values[3]
	element.set_attribute_value('data-unrelated', 'after initialization')
	for index, name in names {
		element.remove_attribute_ns(none, name)
		assert actual_attributes[index].owner_element() == none
	}
	assert model.track.kind() == .subtitles && model.track.label() == ''
	assert model.track.language() == '' && model.track.id() == ''
	assert model.track.mode() == .disabled && model.ready_state() == .none
	assert model.event_count('load') == 0 && model.event_count('error') == 0
}

fn test_track_named_node_map_replacement_and_removal_update_existing_model_once() {
	mut document := tla_document('<!doctype html><track id="tla-map" label="Initial label">', 'https://track-live.example.test/base/document.html')!
	defer { document.finalize() }
	mut element := document.get_element_by_id('tla-map') or { panic('Missing live track') }
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	model := html_track_element_model_for_dom_element(track_dom)
	initial := tla_attribute(element, none, 'label')!
	mut attributes := element.attributes()
	replacement := &dom.Attr_{ name_: 'label', local_name_: 'label', value_: ' Replacement label\t ' }
	removed := attributes.set_named_item(replacement)!
	assert voidptr(removed) == voidptr(initial) && initial.owner_element() == none
	assert model.track.label() == replacement.value()
	tla_assert_attribute(element, replacement, none, 'label', ' Replacement label\t ')!
	assert voidptr(attributes.set_named_item(replacement)!) == voidptr(replacement)
	foreign := &dom.Attr_{
		name_: 'p:label'
		local_name_: 'label'
		prefix__: 'p'
		namespace_uri_: tla_foreign_namespace
		value_: 'Foreign label'
	}
	attributes.set_named_item_ns(foreign)!
	assert model.track.label() == replacement.value()
	tla_assert_attribute(element, foreign, tla_foreign_namespace, 'label', 'Foreign label')!
	assert foreign.name() == 'p:label' && (foreign.prefix() or { '' }) == 'p'
	assert voidptr(attributes.remove_named_item_ns(tla_foreign_namespace, 'label')!) == voidptr(foreign)
	assert model.track.label() == replacement.value() && foreign.owner_element() == none
	assert voidptr(attributes.remove_named_item('label')!) == voidptr(replacement)
	assert model.track.label() == '' && replacement.owner_element() == none
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert model.ready_state() == .none && model.track.mode() == .disabled
	assert model.event_count('load') == 0 && model.event_count('error') == 0
}

fn test_track_live_source_writes_fetch_once_with_actual_audio_and_video_parent_cors() {
	for kind in ['audio', 'video'] {
		mut document := tla_document('<!doctype html><${kind} id="tla-parent"></${kind}>', 'https://track-live.example.test/base/document.html')!
		defer { document.finalize() }
		mut parent := document.get_element_by_id('tla-parent') or { panic('Missing live media parent') }
		parent.set_attribute_value('crossorigin', if kind == 'audio' { 'UsE-CrEdEnTiAlS' } else { '' })
		media := html_media_element_for_dom_element(parent) or { panic('Missing live media owner') }
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'first.vtt')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		probe := tla_install_fetch_probe(mut model)
		mut parent_node := parent.as_node()
		parent_node.append_child(element.as_node())!
		html_track_element_inserted(track_dom)
		actual := tla_attribute(element, none, 'src')!
		expected_cors := if kind == 'audio' { CORSSettingAttribute.use_credentials } else { CORSSettingAttribute.anonymous }
		assert probe.urls == ['https://track-live.example.test/base/first.vtt']
		assert probe.cors == [expected_cors] && model.event_count('load') == 1
		element.set_attribute_ns_for_bindings(tla_foreign_namespace, 'p:src', 'ignored.vtt')!
		foreign := tla_attribute(element, tla_foreign_namespace, 'src')!
		element.set_attribute_value('src', 'first.vtt')
		assert probe.urls.len == 1 && model.event_count('load') == 1
		element.set_attribute_value('src', 'second.vtt?raw=%20')
		assert probe.urls == ['https://track-live.example.test/base/first.vtt', 'https://track-live.example.test/base/second.vtt?raw=%20']
		assert probe.cors == [expected_cors, expected_cors]
		assert model.src_ == 'second.vtt?raw=%20' && model.ready_state() == .loaded
		assert model.event_count('load') == 2 && model.event_count('error') == 0
		tla_assert_attribute(element, actual, none, 'src', 'second.vtt?raw=%20')!
		tla_assert_attribute(element, foreign, tla_foreign_namespace, 'src', 'ignored.vtt')!
		element.remove_attribute_ns(tla_foreign_namespace, 'src')
		element.remove_attribute_ns(none, 'src')
		assert model.track_url_ == 'https://track-live.example.test/base/second.vtt?raw=%20'
		assert probe.urls.len == 2 && model.event_count('load') == 2
		element.set_attribute_value('src', '')
		assert model.src_ == '' && model.track_url_ == '' && model.ready_state() == .error
		assert probe.urls.len == 2 && model.event_count('error') == 1
		element.set_attribute_value('src', '')
		assert model.event_count('error') == 1
		element.set_attribute_value('src', 'recovered.vtt')
		assert probe.urls.len == 3 && probe.urls[2] == 'https://track-live.example.test/base/recovered.vtt'
		assert probe.cors == [expected_cors, expected_cors, expected_cors]
		assert model.ready_state() == .loaded && model.event_count('load') == 3
		assert model.event_count('error') == 1
		assert voidptr(model.parent_media_ or { panic('Missing live track parent') }) == voidptr(media)
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert media.paused() && media.current_src() == '' && media.network_state() == .empty
		assert media.event_count('loadstart') == 0 && media.event_count('play') == 0
	}
}

fn test_track_live_source_resolves_against_adopted_and_current_document_base() {
	mut original := tla_document('<!doctype html><body></body>', 'https://old-track.example.test/old/document.html')!
	defer { original.finalize() }
	mut destination := tla_document('<!doctype html><video id="tla-destination" crossorigin></video>', 'https://new-track.example.test/new/document.html')!
	defer { destination.finalize() }
	mut element := original.create_element('track')!
	element.set_attribute_value('src', 'before-adoption.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	mut model := html_track_element_model_for_dom_element(track_dom)
	probe := tla_install_fetch_probe(mut model)
	assert model.track_url_ == 'https://old-track.example.test/old/before-adoption.vtt'
	destination.adopt_node(element.as_node())
	element.set_attribute_value('src', 'after-adoption.vtt')
	assert voidptr(element.document()) == voidptr(destination)
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert model.track_url_ == 'https://new-track.example.test/new/after-adoption.vtt'
	assert probe.urls == [] && model.event_count('load') == 0
	parent := destination.get_element_by_id('tla-destination') or { panic('Missing adopted track parent') }
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	html_track_element_inserted(track_dom)
	assert probe.urls == ['https://new-track.example.test/new/after-adoption.vtt']
	assert probe.cors == [CORSSettingAttribute.anonymous]
	destination.set_url(dom.URL{ value: 'https://new-track.example.test/updated/document.html' })
	element.set_attribute_value('src', 'after-adoption.vtt')
	assert (element.get_attribute_ns(none, 'src') or { '' }) == 'after-adoption.vtt'
	assert probe.urls == ['https://new-track.example.test/new/after-adoption.vtt', 'https://new-track.example.test/updated/after-adoption.vtt']
	assert probe.cors == [CORSSettingAttribute.anonymous, CORSSettingAttribute.anonymous]
	assert model.ready_state() == .loaded && model.event_count('load') == 2
	assert model.event_count('error') == 0 && model.track.mode() == .hidden
}
