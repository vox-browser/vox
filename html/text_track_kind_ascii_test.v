module html

import dom

const tka_foreign_namespace = 'urn:text-track-kind-ascii-foreign'

fn tka_document() !&dom.Document {
	url := dom.URL{ value: 'https://text-track-kind.example.test/document.html' }
	return parse_navigation_document('<!doctype html><body></body>', url, url.origin(), none)!
}

fn test_text_track_kind_conversion_accepts_only_ascii_case_variants_of_complete_keywords() {
	keywords := ['subtitles', 'captions', 'descriptions', 'chapters', 'metadata']
	mixed := ['SuBtItLeS', 'CaPtIoNs', 'DeScRiPtIoNs', 'ChApTeRs', 'MeTaDaTa']
	expected := [TextTrackKind.subtitles, .captions, .descriptions, .chapters, .metadata]
	for index, keyword in keywords {
		for raw in [keyword, keyword.to_upper(), mixed[index]] {
			assert text_track_kind_from_string(raw) == expected[index]
		}
	}
	assert text_track_kind_from_string('') == .subtitles
	// Unicode simple lowercasing maps dotted capital I to ASCII i; HTML kind matching does not.
	for raw in ['subtİtles', 'captİons', 'descrİptİons', 'SUBTİTLES', 'CAPTİONS',
		'DESCRİPTİONS', ' captions', 'captions ', '\tcaptions\n', 'captions\u00a0',
		'ＣＡＰＴＩＯＮＳ', 'cap\x00tions', 'captions\x00', 'caption', 'unknown'] {
		assert text_track_kind_from_string(raw) == .metadata
	}
}

fn test_text_track_kind_lazy_initialization_preserves_unicode_attributes_and_namespace_selection() {
	mut document := tka_document()!
	defer { document.finalize() }
	for raw in ['subtİtles', 'captİons', 'descrİptİons'] {
		for foreign_first in [false, true] {
			mut element := document.create_element('track')!
			if foreign_first {
				element.set_attribute_ns_for_bindings(tka_foreign_namespace, 'p:kind', 'ChApTeRs')!
			}
			element.set_attribute_value('kind', raw)
			if !foreign_first {
				element.set_attribute_ns_for_bindings(tka_foreign_namespace, 'p:kind', 'ChApTeRs')!
			}
			actual := element.get_attribute_node_ns(none, 'kind') or { panic('Missing null-namespace kind') }
			foreign := element.get_attribute_node_ns(tka_foreign_namespace, 'kind') or { panic('Missing foreign kind') }
			track_dom := unsafe { &dom.HTMLTrackElement(element) }
			assert track_dom.track_element_model_ == unsafe { nil }
			model := html_track_element_model_for_dom_element(track_dom)
			assert model.track.kind() == .metadata
			assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
			assert voidptr(html_track_element_track(track_dom)) == voidptr(model.track)
			assert voidptr(element.get_attribute_node_ns(none, 'kind') or { panic('Lost null kind') }) == voidptr(actual)
			assert voidptr(element.get_attribute_node_ns(tka_foreign_namespace, 'kind') or { panic('Lost foreign kind') }) == voidptr(foreign)
			assert actual.value() == raw && foreign.value() == 'ChApTeRs'
			assert model.track.mode() == .disabled && model.ready_state() == .none
			assert model.track.cues().length() == 0
			assert model.event_count('load') == 0 && model.event_count('error') == 0
		}
	}
}

fn test_text_track_kind_live_mutations_recover_without_replacing_the_track_or_cues() {
	mut document := tka_document()!
	defer { document.finalize() }
	mut element := document.create_element('track')!
	element.set_attribute_value('kind', 'CaPtIoNs')
	element.set_attribute_value('label', 'Retained label')
	element.set_attribute_value('srclang', 'en-GB')
	element.set_attribute_value('id', 'retained-track')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	model := html_track_element_model_for_dom_element(track_dom)
	mut track := model.track
	assert track.kind() == .captions
	track.set_mode(.hidden)
	track.set_readiness_state(.loaded)
	mut cue := TextTrackCue.create(1, 2, 'Retained cue')!
	track.add_cue(mut cue)
	cues := track.cues()
	actual := element.get_attribute_node_ns(none, 'kind') or { panic('Missing initial kind') }
	for index, raw in ['captİons', 'DeScRiPtIoNs'] {
		element.set_attribute_value('kind', raw)
		assert track.kind() == if index == 0 { TextTrackKind.metadata } else { TextTrackKind.descriptions }
		assert voidptr(element.get_attribute_node_ns(none, 'kind') or { panic('Lost live kind') }) == voidptr(actual)
		assert actual.value() == raw
		// Foreign attributes neither override the null-namespace value nor normalize its raw bytes.
		element.set_attribute_ns_for_bindings(tka_foreign_namespace, 'p:kind', 'ChApTeRs')!
		assert track.kind() == if index == 0 { TextTrackKind.metadata } else { TextTrackKind.descriptions }
		element.remove_attribute_ns(tka_foreign_namespace, 'kind')
		assert track.kind() == if index == 0 { TextTrackKind.metadata } else { TextTrackKind.descriptions }
	}
	element.remove_attribute_ns(none, 'kind')
	assert actual.owner_element() == none && track.kind() == .subtitles
	element.set_attribute_ns_for_bindings(tka_foreign_namespace, 'p:kind', 'CaPtIoNs')!
	assert track.kind() == .subtitles
	assert !element.has_attribute_ns(none, 'kind')
	assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
	assert voidptr(html_track_element_track(track_dom)) == voidptr(track)
	assert track.label() == 'Retained label' && track.language() == 'en-GB' && track.id() == 'retained-track'
	assert track.mode() == .hidden && track.readiness_state() == .loaded
	assert voidptr(track.cues()) == voidptr(cues) && cues.length() == 1
	assert voidptr(cues.item(0) or { panic('Lost retained cue') }) == voidptr(cue)
	assert voidptr(cue.track() or { panic('Lost retained cue owner') }) == voidptr(track)
	assert cue.start_time() == 1 && cue.end_time() == 2 && cue.text() == 'Retained cue'
	assert model.event_count('load') == 0 && model.event_count('error') == 0
}
