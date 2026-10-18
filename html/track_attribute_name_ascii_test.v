module html

import dom

@[heap]
struct TrackAttributeNameProbe {
mut:
	names []string
}

fn track_name_document() !&dom.Document {
	url := dom.URL{value: 'https://track-attribute-name.example/document.html'}
	return parse_navigation_document('<!doctype html><body></body>', url, url.origin(), none)!
}

fn test_track_dom_notifications_ignore_unicode_lookalike_attribute_names() {
	mut document := track_name_document()!
	defer { document.finalize() }
	mut element := document.create_element('track')!
	element.set_attribute_value('kind', 'captions')
	element.set_attribute_value('id', 'retained-id')
	mut owner := unsafe { &dom.HTMLTrackElement(element) }
	model := html_track_element_model_for_dom_element(owner)
	probe := &TrackAttributeNameProbe{}
	original := owner.track_attribute_changed_hook_ or { panic('Missing track hook') }
	owner.track_attribute_changed_hook_ = fn [probe, original] (target &dom.HTMLTrackElement, name string, value ?string) {
		mut observed := unsafe { &TrackAttributeNameProbe(probe) }
		observed.names << name
		original(target, name, value)
	}
	for name in ['kİnd', 'İd', 'KİND', 'İD'] {
		element.set_attribute_value_ns(name, 'metadata', none, none)
		attribute := element.get_attribute_node_ns(none, name) or { panic('Missing raw attribute') }
		assert attribute.local_name() == name && attribute.value() == 'metadata'
		assert voidptr(attribute.owner_element() or { panic('Missing attribute owner') }) == voidptr(element)
		assert model.track.kind() == .captions && model.track.id() == 'retained-id'
		element.remove_attribute_ns(none, name)
		assert attribute.owner_element() == none
		assert model.track.kind() == .captions && model.track.id() == 'retained-id'
	}
	assert probe.names.len == 0
	element.set_attribute_value('kind', 'chapters')
	assert probe.names == ['kind'] && model.track.kind() == .chapters
	assert voidptr(html_track_element_model_for_dom_element(owner)) == voidptr(model)
}

fn test_concrete_track_attribute_hook_preserves_metadata_and_cues_for_unicode_names() {
	mut document := track_name_document()!
	defer { document.finalize() }
	mut element := document.create_element('track')!
	element.set_attribute_value('kind', 'captions')
	element.set_attribute_value('id', 'retained-id')
	owner := unsafe { &dom.HTMLTrackElement(element) }
	model := html_track_element_model_for_dom_element(owner)
	mut track := model.track
	mut cue := TextTrackCue.create(1, 2, 'Retained cue')!
	track.add_cue(mut cue)
	cues := track.cues()
	for name in ['kİnd', 'İd', 'KİND', 'İD'] {
		html_track_element_attribute_changed(owner, name, none, 'metadata', none)
		assert track.kind() == .captions && track.id() == 'retained-id'
		html_track_element_attribute_changed(owner, name, 'metadata', none, none)
		assert track.kind() == .captions && track.id() == 'retained-id'
	}
	assert voidptr(track.cues()) == voidptr(cues) && cues.length() == 1
	assert voidptr(cues.item(0) or { panic('Lost cue') }) == voidptr(cue)
	assert voidptr(cue.track() or { panic('Lost cue owner') }) == voidptr(track)
	assert model.ready_state() == .none && track.mode() == .disabled
	assert model.event_count('load') == 0 && model.event_count('error') == 0
}

fn test_track_attribute_names_keep_ascii_case_matching_and_namespace_isolation() {
	mut document := track_name_document()!
	defer { document.finalize() }
	mut element := document.create_element('track')!
	owner := unsafe { &dom.HTMLTrackElement(element) }
	model := html_track_element_model_for_dom_element(owner)
	names := ['KiNd', 'LaBeL', 'SrClAnG', 'Id']
	values := ['CaPtIoNs', 'ASCII label', 'en-GB', 'ascii-id']
	for index, name in names {
		// The namespace setter preserves local-name case even in an HTML document.
		element.set_attribute_value_ns(name, values[index], none, none)
		attribute := element.get_attribute_node_ns(none, name) or { panic('Missing ASCII attribute') }
		assert attribute.local_name() == name && attribute.value() == values[index]
	}
	assert model.track.kind() == .captions && model.track.label() == values[1]
	assert model.track.language() == values[2] && model.track.id() == values[3]
	element.set_attribute_value_ns('KiNd', 'metadata', 'p', 'urn:track-attribute-name')
	assert model.track.kind() == .captions
	element.remove_attribute_ns('urn:track-attribute-name', 'KiNd')
	assert model.track.kind() == .captions
	for name in names {
		element.remove_attribute_ns(none, name)
	}
	assert model.track.kind() == .subtitles && model.track.label() == ''
	assert model.track.language() == '' && model.track.id() == ''
	html_track_element_attribute_changed(owner, 'KIND', none, 'chapters', none)
	html_track_element_attribute_changed(owner, 'ID', none, 'concrete-id', none)
	assert model.track.kind() == .chapters && model.track.id() == 'concrete-id'
	assert voidptr(html_track_element_track(owner)) == voidptr(model.track)
}
