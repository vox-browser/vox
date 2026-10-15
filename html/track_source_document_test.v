module html

import dom

@[heap]
struct TrackSourceDocumentProbe {
mut:
	urls []string
	cors []CORSSettingAttribute
}

fn track_source_document(address string, base string) !&dom.Document {
	url := dom.URL{value: address}
	return parse_navigation_document('<!doctype html><base id="base" href="${base}"><video id="media" crossorigin></video>',
		url, url.origin(), none)!
}

fn track_source_document_owner(document &dom.Document) (&dom.Element, &HTMLTrackElementModel) {
	mut owner := unsafe { &dom.Document(document) }
	element := owner.create_element('track') or { panic(err) }
	parent := owner.get_element_by_id('media') or { panic('missing track source parent') }
	mut node := parent.as_node()
	node.append_child(element.as_node()) or { panic(err) }
	mut model := html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })
	model.set_mode(.hidden)
	return element, model
}

fn track_source_document_response() TextTrackResourceResponse {
	return TextTrackResourceResponse{body: 'WEBVTT\n\ncurrent\n00:01.000 --> 00:02.000\nCurrent document cue'}
}

fn track_source_document_fetch(mut probe TrackSourceDocumentProbe, address dom.URL, cors CORSSettingAttribute) {
	probe.urls << address.serialize()
	probe.cors << cors
}

fn track_source_document_observe(mut model HTMLTrackElementModel) &TrackSourceDocumentProbe {
	probe := &TrackSourceDocumentProbe{}
	model.set_fetch_hook(fn [probe] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut seen := unsafe { &TrackSourceDocumentProbe(probe) }
		track_source_document_fetch(mut seen, address, cors)
		return track_source_document_response()
	})
	return probe
}

fn test_track_model_source_setter_uses_live_base_then_current_document_url_without_an_attribute_write() {
	mut document := track_source_document('https://track-source.example/root/page.html', 'assets/')!
	defer { document.finalize() }
	element, mut model := track_source_document_owner(document)
	probe := track_source_document_observe(mut model)
	mut base := document.get_element_by_id('base') or { panic('missing track source base') }
	base.set_attribute_value('href', '../captions/')
	model.set_src('first.vtt?raw=%20#cue')
	assert model.track_url_ == 'https://track-source.example/captions/first.vtt?raw=%20#cue'
	assert probe.urls == [] && model.ready_state() == .none
	model.start_the_track_processing_model()
	list := model.track.cues()
	first := list.item(0) or { panic('missing first track source cue') }
	assert probe.urls == ['https://track-source.example/captions/first.vtt?raw=%20#cue']
	document.set_url(dom.URL{value: 'https://track-current.example/next/page.html'})
	base.remove_attribute('href')
	model.set_src('second.vtt')
	assert model.track_url_ == 'https://track-current.example/next/second.vtt'
	assert probe.urls[1] == model.track_url_ && probe.cors == [CORSSettingAttribute.anonymous, .anonymous]
	assert first.track() == none && voidptr(model.track.cues()) == voidptr(list)
	assert list.length() == 1 && model.event_count('load') == 2 && model.event_count('error') == 0
	assert !element.has_attribute('src') && model.src_ == 'second.vtt'
	// A source-less standalone model still uses its explicit constructor base.
	media := HTMLMediaElement.create(none, dom.URL{value: 'https://standalone.example/media/'})
	mut standalone := HTMLTrackElementModel.create(dom.URL{value: 'https://standalone.example/captions/'})
	standalone.set_parent_media(media)
	standalone.set_mode(.hidden)
	seen := track_source_document_observe(mut standalone)
	standalone.set_src('local.vtt')
	standalone.start_the_track_processing_model()
	assert seen.urls == ['https://standalone.example/captions/local.vtt']
	assert seen.cors == [CORSSettingAttribute.no_cors]
}

fn test_track_model_source_setter_uses_adopted_document_and_preserves_equal_url_cue_clearing() {
	mut original := track_source_document('https://track-old.example/root/page.html', 'old/')!
	mut destination := track_source_document('https://track-new.example/next/page.html', '../new/')!
	defer { original.finalize(); destination.finalize() }
	element, mut model := track_source_document_owner(original)
	probe := track_source_document_observe(mut model)
	model.set_src('first.vtt')
	model.start_the_track_processing_model()
	list := model.track.cues()
	first := list.item(0) or { panic('missing pre-adoption cue') }
	destination.adopt_node(element.as_node())
	mut parent := destination.get_element_by_id('media') or { panic('missing adopting media parent') }
	parent.set_attribute_value('crossorigin', 'use-credentials')
	mut node := parent.as_node()
	node.append_child(element.as_node())!
	model.set_src('second.vtt')
	assert model.track_url_ == 'https://track-new.example/new/second.vtt'
	assert probe.urls == ['https://track-old.example/root/old/first.vtt', 'https://track-new.example/new/second.vtt']
	assert probe.cors == [CORSSettingAttribute.anonymous, .use_credentials]
	assert voidptr(html_track_element_model_for_dom_element(unsafe { &dom.HTMLTrackElement(element) })) == voidptr(model)
	assert first.track() == none && voidptr(model.track.cues()) == voidptr(list)
	second := list.item(0) or { panic('missing adopted cue') }
	model.set_src('./second.vtt')
	assert second.track() == none && list.length() == 0 && probe.urls.len == 2
	assert model.event_count('load') == 2 && model.event_count('error') == 0
	for source in ['', 'http://[invalid'] {
		model.set_src(source)
		assert model.track_url_ == '' && list.length() == 0 && probe.urls.len == 2
	}
	assert model.ready_state() == .error && model.event_count('error') == 1
}

fn test_reentrant_track_source_after_adoption_keeps_the_new_document_fetch_and_cues() {
	for fails in [false, true] {
		mut original := track_source_document('https://track-reentry-old.example/root/page.html', 'old/')!
		mut destination := track_source_document('https://track-reentry-new.example/next/page.html', '../new/')!
		defer { original.finalize(); destination.finalize() }
		element, mut model := track_source_document_owner(original)
		probe := &TrackSourceDocumentProbe{}
		model.set_fetch_hook(fn [element, model, destination, probe, fails] (address dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
			mut seen := unsafe { &TrackSourceDocumentProbe(probe) }
			track_source_document_fetch(mut seen, address, cors)
			if address.serialize().ends_with('/outer.vtt') {
				mut target := unsafe { &dom.Document(destination) }
				target.adopt_node(element.as_node())
				parent := target.get_element_by_id('media') or { panic('missing reentrant media parent') }
				mut node := parent.as_node()
				node.append_child(element.as_node()) or { panic(err) }
				mut current := unsafe { &HTMLTrackElementModel(model) }
				current.set_src('inner.vtt')
				if fails { return error('obsolete original-document fetch') }
				return TextTrackResourceResponse{body: 'WEBVTT\n\nobsolete\n00:03.000 --> 00:04.000\nObsolete cue'}
			}
			return track_source_document_response()
		})
		model.set_src('outer.vtt')
		model.start_the_track_processing_model()
		assert probe.urls == ['https://track-reentry-old.example/root/old/outer.vtt',
			'https://track-reentry-new.example/new/inner.vtt']
		assert model.track_url_ == probe.urls[1] && model.src_ == 'inner.vtt'
		assert model.ready_state() == .loaded && model.event_count('load') == 1 && model.event_count('error') == 0
		assert model.track.cues().length() == 1 && model.track.cues().item(0)?.id() == 'current'
		assert !model.loading_ && model.awaiting_url_change
	}
}
