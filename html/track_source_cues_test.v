module html

import dom

const tsc_foreign_namespace = 'urn:track-source-cues-foreign'

@[heap]
struct TscFetchProbe {
mut:
	urls           []string
	cors           []CORSSettingAttribute
	lengths_before []int
}

fn tsc_document(kind string) !&dom.Document {
	url := dom.URL{ value: 'https://track-cues.example.test/base/document.html' }
	return parse_navigation_document('<!doctype html><${kind} id="tsc-parent" crossorigin="use-credentials"></${kind}>', url, url.origin(), none)!
}

fn tsc_install_fetch_probe(mut model HTMLTrackElementModel) &TscFetchProbe {
	probe := &TscFetchProbe{}
	cue_list := model.track.cues()
	model.set_fetch_hook(fn [probe, cue_list] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut observation := unsafe { &TscFetchProbe(probe) }
		address := url.serialize()
		observation.urls << address
		observation.cors << cors
		observation.lengths_before << cue_list.length()
		if address.ends_with('/network-error.vtt') { return error('Controlled track fetch failure') }
		if address.ends_with('/missing.vtt') { return TextTrackResourceResponse{ status: 404 } }
		if address.ends_with('/invalid.vtt') { return TextTrackResourceResponse{ body: 'Invalid track resource' } }
		return TextTrackResourceResponse{
			body: 'WEBVTT\n\nfetched-${observation.urls.len}\n00:01.250 --> 00:02.500\nFresh text ${observation.urls.len}'
		}
	})
	return probe
}

fn tsc_manual_cue(mut track TextTrack, id string) !&TextTrackCue {
	mut cue := TextTrackCue.create(3, 4, 'Retained ${id}')!
	cue.set_id(id)
	track.add_cue(mut cue)
	return cue
}

fn tsc_first_cue(list &TextTrackCueList) &TextTrackCue {
	return list.item(0) or { panic('Missing source-test cue') }
}

fn test_text_track_clear_cues_preserves_list_and_track_state_and_detaches_only_owned_cues() {
	mut track := TextTrack.create()
	mut other := TextTrack.create()
	track.set_kind(.captions)
	track.set_label('Retained label')
	track.set_language('en-GB')
	track.set_id('retained-track')
	track.set_mode(.showing)
	track.set_readiness_state(.loaded)
	callback := &dom.CallbackType{
		handle_event: fn (event &dom.Event, current_target ?&dom.EventTarget) dom.JSValue {
			return dom.js_undefined()
		}
	}
	track.set_oncuechange(callback)
	mut owned := tsc_manual_cue(mut track, 'owned')!
	owned.set_onexit(callback)
	foreign := tsc_manual_cue(mut other, 'foreign')!
	mut list := track.cues()
	list.add_cue(foreign)
	assert list.length() == 2
	track.clear_cues()
	assert voidptr(track.cues()) == voidptr(list) && list.length() == 0
	assert list.item(0) == none && list.get_cue_by_id('owned') == none
	assert owned.track() == none
	assert voidptr(foreign.track() or { panic('Lost other cue owner') }) == voidptr(other)
	assert other.cues().length() == 1 && voidptr(tsc_first_cue(other.cues())) == voidptr(foreign)
	assert track.kind() == .captions && track.label() == 'Retained label'
	assert track.language() == 'en-GB' && track.id() == 'retained-track'
	assert track.mode() == .showing && track.readiness_state() == .loaded
	assert voidptr(track.oncuechange() or { panic('Lost track handler') }) == voidptr(callback)
	assert voidptr(owned.onexit() or { panic('Lost cue handler') }) == voidptr(callback)
	owned.set_start_time(5)
	owned.set_end_time(6)!
	assert owned.id() == 'owned' && owned.text() == 'Retained owned'
	assert owned.start_time() == 5 && owned.end_time() == 6
	track.clear_cues()
	assert voidptr(track.cues()) == voidptr(list) && list.length() == 0
	assert track.readiness_state() == .loaded && owned.track() == none
}

fn test_track_source_replacement_clears_before_fetch_and_keeps_failures_empty_until_recovery() {
	for kind in ['audio', 'video'] {
		mut document := tsc_document(kind)!
		defer { document.finalize() }
		parent := document.get_element_by_id('tsc-parent') or { panic('Missing cue media parent') }
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'first.vtt')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		probe := tsc_install_fetch_probe(mut model)
		mut parent_node := parent.as_node()
		parent_node.append_child(element.as_node())!
		html_track_element_inserted(track_dom)
		list := model.track.cues()
		first := list.item(0) or { panic('Missing first fetched cue') }
		element.set_attribute_value('src', 'second.vtt')
		assert first.track() == none && first.text() == 'Fresh text 1'
		assert voidptr(model.track.cues()) == voidptr(list) && list.length() == 1
		assert list.get_cue_by_id('fetched-1') == none
		assert tsc_first_cue(list).id() == 'fetched-2'
		assert model.ready_state() == .loaded && model.event_count('load') == 2
		for source in ['missing.vtt', 'invalid.vtt', 'network-error.vtt', '', 'http://['] {
			mut track := model.track
			retained := tsc_manual_cue(mut track, 'before-${source}')!
			element.set_attribute_value('src', source)
			assert retained.track() == none && list.length() == 0
			assert model.ready_state() == .error && model.event_count('load') == 2
		}
		assert model.event_count('error') == 4
		assert probe.urls.len == 5 && probe.lengths_before == [0, 0, 0, 0, 0]
		for cors in probe.cors { assert cors == .use_credentials }
		element.set_attribute_value('src', 'recovered.vtt')
		assert probe.urls.len == 6 && probe.lengths_before[5] == 0
		assert model.ready_state() == .loaded && model.event_count('load') == 3
		assert model.event_count('error') == 4 && list.length() == 1
		assert tsc_first_cue(list).id() == 'fetched-6' && tsc_first_cue(list).text() == 'Fresh text 6'
		assert voidptr(tsc_first_cue(list).track() or { panic('Missing fresh cue owner') }) == voidptr(model.track)
	}
}

fn test_track_equal_resolved_source_clears_without_refetch_while_foreign_and_metadata_writes_preserve_cues() {
	mut document := tsc_document('video')!
	defer { document.finalize() }
	parent := document.get_element_by_id('tsc-parent') or { panic('Missing cue media parent') }
	mut element := document.create_element('track')!
	element.set_attribute_value('src', 'same.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(element) }
	mut model := html_track_element_model_for_dom_element(track_dom)
	probe := tsc_install_fetch_probe(mut model)
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	html_track_element_inserted(track_dom)
	list := model.track.cues()
	loaded := list.item(0) or { panic('Missing equal-source cue') }
	element.set_attribute_ns_for_bindings(tsc_foreign_namespace, 'p:src', 'foreign.vtt')!
	element.set_attribute_value('kind', 'captions')
	element.set_attribute_value('label', 'Caption label')
	element.set_attribute_value('srclang', 'en')
	element.set_attribute_value('id', 'same-source-track')
	element.remove_attribute_ns(tsc_foreign_namespace, 'src')
	assert list.length() == 1 && voidptr(tsc_first_cue(list)) == voidptr(loaded)
	assert voidptr(loaded.track() or { panic('Lost unchanged cue owner') }) == voidptr(model.track)
	for source in ['same.vtt', './same.vtt', 'https://track-cues.example.test/base/same.vtt'] {
		mut track := model.track
		retained := tsc_manual_cue(mut track, 'same-${source}')!
		element.set_attribute_value('src', source)
		assert retained.track() == none && loaded.track() == none
		assert voidptr(model.track.cues()) == voidptr(list) && list.length() == 0
		assert model.src_ == source && model.track_url_ == 'https://track-cues.example.test/base/same.vtt'
		assert probe.urls.len == 1 && model.ready_state() == .loaded
		assert model.event_count('load') == 1 && model.event_count('error') == 0
	}
	assert model.track.kind() == .captions && model.track.label() == 'Caption label'
	assert model.track.language() == 'en' && model.track.id() == 'same-source-track'
	assert model.track.mode() == .hidden
}

fn test_track_source_attribute_removal_and_named_map_replacement_clear_live_cues_without_resetting_url() {
	for method in ['namespace', 'attribute-node', 'named-map'] {
		mut document := tsc_document('audio')!
		defer { document.finalize() }
		parent := document.get_element_by_id('tsc-parent') or { panic('Missing removal media parent') }
		mut element := document.create_element('track')!
		element.set_attribute_value('src', 'retained.vtt')
		track_dom := unsafe { &dom.HTMLTrackElement(element) }
		mut model := html_track_element_model_for_dom_element(track_dom)
		probe := tsc_install_fetch_probe(mut model)
		mut parent_node := parent.as_node()
		parent_node.append_child(element.as_node())!
		html_track_element_inserted(track_dom)
		list := model.track.cues()
		retained := list.item(0) or { panic('Missing removed-source cue') }
		original := element.get_attribute_node_ns(none, 'src') or { panic('Missing source attribute') }
		mut attributes := element.attributes()
		match method {
			'namespace' { element.remove_attribute_ns(none, 'src') }
			'attribute-node' { assert voidptr(element.remove_attribute_node(original)!) == voidptr(original) }
			else { assert voidptr(attributes.remove_named_item('src')!) == voidptr(original) }
		}
		assert original.owner_element() == none && retained.track() == none
		assert !element.has_attribute_ns(none, 'src') && list.length() == 0
		assert model.src_ == 'retained.vtt' && model.track_url_ == 'https://track-cues.example.test/base/retained.vtt'
		assert model.ready_state() == .loaded && model.event_count('load') == 1 && model.event_count('error') == 0
		mut track := model.track
		after_removal := tsc_manual_cue(mut track, 'after-removal')!
		element.remove_attribute_ns(none, 'src')
		assert list.length() == 1 && after_removal.track() != none
		element.set_attribute_value('src', 'retained.vtt')
		assert list.length() == 0 && after_removal.track() == none
		before_replacement := tsc_manual_cue(mut track, 'before-replacement')!
		replacement := &dom.Attr_{ name_: 'src', local_name_: 'src', value_: './retained.vtt' }
		removed := attributes.set_named_item(replacement)!
		assert removed.owner_element() == none
		assert voidptr(replacement.owner_element() or { panic('Missing replacement owner') }) == voidptr(element)
		assert before_replacement.track() == none && list.length() == 0
		assert voidptr(model.track.cues()) == voidptr(list) && probe.urls.len == 1
		assert model.src_ == './retained.vtt' && model.ready_state() == .loaded
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		assert voidptr(html_track_element_model_for_dom_element(track_dom)) == voidptr(model)
		assert voidptr(html_track_element_track(track_dom)) == voidptr(track)
	}
}
