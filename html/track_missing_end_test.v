module html

import dom

const tme_malformed_only = 'WEBVTT\n\nmissing-end\n00:01.000 -->\nDiscarded identified cue\n\n00:02.000 --> \t\nDiscarded anonymous cue\n\nmissing-at-eof\n00:03.000 -->'
const tme_valid = 'WEBVTT\n\nvalid\n00:01.250 --> 00:02.500 align:start\nValid text'
const tme_mixed = 'WEBVTT\n\nbefore\n00:01.250 --> 00:02.500 align:start\nBefore text\n\nmissing\n00:03.000 --> \t\nDiscarded text\n\nafter\n00:04.125 --> 00:05.750 line:2\nAfter text\nsecond line\n\nmissing-at-eof\n00:06.000 -->'

struct TmeOwner {
	document &dom.Document
	element  ?&dom.Element
	model    &HTMLTrackElementModel
}

@[heap]
struct TmeObservation {
mut:
	urls      []string
	cors      []CORSSettingAttribute
	events    []string
	states    []TrackElementReadyState
	snapshots [][]string
}

fn tme_owner(kind string, source string) !TmeOwner {
	url := dom.URL{ value: 'https://track-missing-end.example.test/base/document.html' }
	if kind == 'standalone' {
		document := dom.Document.create(url)
		media := HTMLMediaElement.create(none, url)
		mut model := HTMLTrackElementModel.create(url)
		model.set_parent_media(media)
		model.set_mode(.hidden)
		model.set_src(source)
		return TmeOwner{ document: document, model: model }
	}
	mut document := parse_navigation_document('<!doctype html><body><${kind} id="tme-parent" crossorigin="use-credentials"></${kind}></body>',
		url, url.origin(), none)!
	parent := document.get_element_by_id('tme-parent') or { return error('Missing malformed-track media parent') }
	mut element := document.create_element('track')!
	element.set_attribute_value('src', source)
	mut parent_node := parent.as_node()
	parent_node.append_child(element.as_node())!
	mut model := html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	model.set_mode(.hidden)
	return TmeOwner{ document: document, element: element, model: model }
}

fn tme_source(owner TmeOwner, source string) {
	if element := owner.element {
		mut actual := unsafe { &dom.Element(element) }
		actual.set_attribute_value('src', source)
	} else {
		mut model := owner.model
		model.set_src(source)
	}
}

fn tme_install(mut model HTMLTrackElementModel, observed &TmeObservation) {
	model.set_fetch_hook(fn [observed] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut result := unsafe { &TmeObservation(observed) }
		result.urls << address.serialize()
		result.cors << cors
		resource := address.serialize().split('/').last()
		if resource == 'network.vtt' { return error('Controlled malformed-track network failure') }
		if resource == 'status.vtt' { return TextTrackResourceResponse{ status: 404, body: tme_mixed } }
		body := match resource {
			'malformed.vtt' { tme_malformed_only }
			'mixed.vtt' { tme_mixed }
			'signature.vtt' { 'Invalid signature\n\n00:01.000 -->' }
			else { tme_valid }
		}
		return TextTrackResourceResponse{ body: body }
	})
	list := model.track.cues()
	target := model.event_target()
	for name in ['load', 'error'] {
		target.add_event_listener_without_options(name, dom.IDLEventListener.create(&dom.CallbackType{
			handle_event: fn [model, observed, list, target, name] (event &dom.Event, current ?&dom.EventTarget) dom.JSValue {
				assert voidptr(event.target() or { panic('Missing malformed-track event target') }) == voidptr(target)
				assert voidptr(current or { panic('Missing malformed-track currentTarget') }) == voidptr(target)
				assert voidptr(model.track.cues()) == voidptr(list) && !model.loading_ && model.awaiting_url_change
				assert model.ready_state() == if name == 'load' { TrackElementReadyState.loaded } else { TrackElementReadyState.error }
				mut ids := []string{}
				for index in 0 .. list.length() {
					ids << (list.item(index) or { panic('Missing live malformed-track cue') }).id()
				}
				mut result := unsafe { &TmeObservation(observed) }
				result.events << name
				result.states << model.ready_state()
				result.snapshots << ids
				return dom.js_undefined()
			}
		}))
	}
}

fn test_webvtt_missing_end_timestamp_skips_only_its_cue_with_lf_crlf_and_cr_input() {
	for line_ending in ['\n', '\r\n', '\r'] {
		for missing_end in ['', ' ', '\t', '--> 00:08.000'] {
			body := 'WEBVTT\n\nbefore\n00:01.250 --> 00:02.500 align:start position:10%\nBefore text\nsecond line\n\nbroken\n00:03.000 -->${missing_end}\nDiscard identified\n\n00:04.000 -->${missing_end}\nDiscard anonymous\n\nafter\n00:05.125 --> 00:06.750 line:2\nAfter text\nsecond line\n\nbroken-at-eof\n00:07.000 -->${missing_end}'
			cues := parse_web_vtt(body.replace('\n', line_ending))!
			assert cues.len == 2
			assert cues[0].id() == 'before' && cues[0].start_time() == 1.25 && cues[0].end_time() == 2.5
			assert cues[0].text() == 'Before text\nsecond line'
			assert cues[1].id() == 'after' && cues[1].start_time() == 5.125 && cues[1].end_time() == 6.75
			assert cues[1].text() == 'After text\nsecond line'
			assert cues[0].track() == none && cues[1].track() == none
		}
	}
}

fn test_missing_end_only_resources_load_empty_and_recover_for_dom_audio_video_and_standalone_tracks() {
	for kind in ['audio', 'video', 'standalone'] {
		owner := tme_owner(kind, 'malformed.vtt')!
		mut document := owner.document
		defer { document.finalize() }
		mut model := owner.model
		list := model.track.cues()
		observed := &TmeObservation{}
		tme_install(mut model, observed)
		model.start_the_track_processing_model()
		assert model.ready_state() == .loaded && list.length() == 0
		assert model.event_count('load') == 1 && model.event_count('error') == 0
		assert observed.events == ['load'] && observed.states == [TrackElementReadyState.loaded]
		assert observed.snapshots.len == 1 && observed.snapshots[0] == []
		tme_source(owner, 'valid.vtt')
		assert voidptr(model.track.cues()) == voidptr(list) && list.length() == 1
		cue := list.item(0) or { panic('Missing recovered malformed-track cue') }
		assert cue.id() == 'valid' && cue.text() == 'Valid text'
		assert cue.start_time() == 1.25 && cue.end_time() == 2.5
		assert voidptr(cue.track() or { panic('Missing recovered cue owner') }) == voidptr(model.track)
		assert observed.events == ['load', 'load'] && observed.snapshots[1] == ['valid']
		assert model.event_count('load') == 2 && model.event_count('error') == 0
		assert model.ready_state() == .loaded && !model.loading_ && model.awaiting_url_change
		assert observed.urls == ['https://track-missing-end.example.test/base/malformed.vtt',
			'https://track-missing-end.example.test/base/valid.vtt']
		expected := if kind == 'standalone' { CORSSettingAttribute.no_cors } else { CORSSettingAttribute.use_credentials }
		assert observed.cors == [expected, expected]
		if element := owner.element {
			assert voidptr(html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })) == voidptr(model)
			assert voidptr(model.event_target()) == voidptr(element)
		}
	}
}

fn test_mixed_missing_end_replacement_updates_live_cues_and_preserves_resource_failure_classification() {
	owner := tme_owner('video', 'valid.vtt')!
	mut document := owner.document
	defer { document.finalize() }
	mut model := owner.model
	list := model.track.cues()
	observed := &TmeObservation{}
	tme_install(mut model, observed)
	model.start_the_track_processing_model()
	first := list.item(0) or { panic('Missing pre-replacement cue') }
	tme_source(owner, 'mixed.vtt')
	assert first.track() == none && voidptr(model.track.cues()) == voidptr(list) && list.length() == 2
	before := list.item(0) or { panic('Missing valid cue before malformed block') }
	after := list.item(1) or { panic('Missing valid cue after malformed block') }
	assert before.id() == 'before' && before.text() == 'Before text'
	assert before.start_time() == 1.25 && before.end_time() == 2.5
	assert after.id() == 'after' && after.text() == 'After text\nsecond line'
	assert after.start_time() == 4.125 && after.end_time() == 5.75
	assert observed.events == ['load', 'load'] && observed.snapshots[0] == ['valid']
	assert observed.snapshots[1] == ['before', 'after'] && model.event_count('load') == 2
	for index, source in ['signature.vtt', 'status.vtt', 'network.vtt'] {
		tme_source(owner, source)
		assert before.track() == none && after.track() == none && list.length() == 0
		assert model.ready_state() == .error && model.event_count('error') == index + 1
		assert model.event_count('load') == 2 && observed.snapshots[index + 2] == []
	}
	tme_source(owner, 'valid.vtt')
	assert observed.events == ['load', 'load', 'error', 'error', 'error', 'load']
	assert observed.snapshots[5] == ['valid'] && list.length() == 1
	assert model.ready_state() == .loaded && model.event_count('load') == 3 && model.event_count('error') == 3
	assert !model.loading_ && model.awaiting_url_change && voidptr(model.track.cues()) == voidptr(list)
	assert observed.urls.len == 6
	for cors in observed.cors { assert cors == .use_credentials }
}
