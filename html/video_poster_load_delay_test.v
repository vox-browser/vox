module html

import dom

@[heap]
struct PosterLoadDelayProbe {
mut:
	calls int
	independent ?dom.DocumentLoadEventDelayer
}

fn poster_load_delay_document(address string) !&dom.Document {
	url := dom.URL{value: address}
	return parse_navigation_document('<!doctype html><video id="video" preload="none"></video>',
		url, url.origin(), none)!
}

fn poster_load_delay_frame() &dom.Bitmap_ {
	return &dom.Bitmap_{width: 13, height: 7, pitch: 52, data: []u8{len: 13 * 7 * 4}}
}

fn test_poster_fetch_delays_its_document_and_releases_only_its_blocker_on_success_or_failure() {
	for fails in [false, true] {
		mut document := poster_load_delay_document('https://poster-delay.example/base/page.html')!
		defer { document.finalize() }
		mut element := document.get_element_by_id('video') or { panic('missing poster owner') }
		mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		mut media := model.media
		probe := &PosterLoadDelayProbe{}
		assert !document.anything_is_delaying_the_load_event()
		model.set_poster_fetch_hook(fn [document, media, probe, fails] (_ dom.URL) !&dom.Bitmap_ {
			mut observed := unsafe { &PosterLoadDelayProbe(probe) }
			observed.calls++
			// Resource-selection delay is independent of the poster request.
			mut owner := unsafe { &HTMLMediaElement(media) }
			owner.finish_delaying_load_event()
			assert document.anything_is_delaying_the_load_event()
			owner.begin_delaying_load_event()
			mut current := unsafe { &dom.Document(document) }
			observed.independent = dom.DocumentLoadEventDelayer.new(mut current)
			if fails { return error('controlled poster failure') }
			return poster_load_delay_frame()
		})
		media.begin_delaying_load_event()
		element.set_attribute_value('poster', 'frame.png')
		assert probe.calls == 1
		assert (model.poster_frame() != none) == !fails
		assert document.anything_is_delaying_the_load_event()
		media.finish_delaying_load_event()
		assert document.anything_is_delaying_the_load_event()
		mut observed := unsafe { &PosterLoadDelayProbe(probe) }
		if mut independent := observed.independent { independent.finish() }
		assert !document.anything_is_delaying_the_load_event()
		assert media.paused() && media.ready_state() == .have_nothing
		assert media.network_state() == .empty && media.current_src() == ''
		for name in ['loadstart', 'load', 'error', 'resize'] { assert media.event_count(name) == 0 }
	}
}

fn test_in_flight_poster_delay_follows_actual_dom_adoption_and_finishes_in_the_new_document() {
	for fails in [false, true] {
		mut original := poster_load_delay_document('https://poster-delay-old.example/base/page.html')!
		mut destination := poster_load_delay_document('https://poster-delay-new.example/next/page.html')!
		defer { original.finalize(); destination.finalize() }
		mut element := original.get_element_by_id('video') or { panic('missing adopted poster owner') }
		mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		probe := &PosterLoadDelayProbe{}
		model.set_poster_fetch_hook(fn [original, destination, element, probe, fails] (url dom.URL) !&dom.Bitmap_ {
			mut observed := unsafe { &PosterLoadDelayProbe(probe) }
			observed.calls++
			assert original.anything_is_delaying_the_load_event()
			assert !destination.anything_is_delaying_the_load_event()
			assert url.serialize() == 'https://poster-delay-old.example/base/frame.png'
			mut target := unsafe { &dom.Document(destination) }
			target.adopt_node(element.as_node())
			assert voidptr(element.document()) == voidptr(destination)
			assert !original.anything_is_delaying_the_load_event()
			assert destination.anything_is_delaying_the_load_event()
			observed.independent = dom.DocumentLoadEventDelayer.new(mut target)
			if fails { return error('controlled adopted poster failure') }
			return poster_load_delay_frame()
		})
		element.set_attribute_value('poster', 'frame.png')
		assert probe.calls == 1 && (model.poster_frame() != none) == !fails
		assert voidptr(model.media.document()?) == voidptr(destination)
		assert !original.anything_is_delaying_the_load_event()
		assert destination.anything_is_delaying_the_load_event()
		mut observed := unsafe { &PosterLoadDelayProbe(probe) }
		if mut independent := observed.independent { independent.finish() }
		assert !destination.anything_is_delaying_the_load_event()
	}
}

fn test_reentrant_poster_replacement_or_clearing_releases_the_superseded_delay_without_touching_other_work() {
	for action in ['success', 'failure', 'remove', 'empty', 'invalid', 'no-hook'] {
		mut document := poster_load_delay_document('https://poster-delay-reentrant.example/base/page.html')!
		defer { document.finalize() }
		mut element := document.get_element_by_id('video') or { panic('missing reentrant poster owner') }
		mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		probe := &PosterLoadDelayProbe{}
		model.set_poster_fetch_hook(fn [document, element, model, probe, action] (url dom.URL) !&dom.Bitmap_ {
			mut observed := unsafe { &PosterLoadDelayProbe(probe) }
			observed.calls++
			assert document.anything_is_delaying_the_load_event()
			if url.serialize().ends_with('/inner.png') {
				if action == 'failure' { return error('controlled nested poster failure') }
				return poster_load_delay_frame()
			}
			mut owner := unsafe { &dom.Element(element) }
			mut video := unsafe { &HTMLVideoElementModel(model) }
			match action {
				'remove' { owner.remove_attribute('poster') }
				'empty' { owner.set_attribute_value('poster', '') }
				'invalid' { owner.set_attribute_value('poster', 'http://[invalid') }
				'no-hook' {
					video.set_poster_fetch_hook(none)
					owner.set_attribute_value('poster', 'inner.png')
				}
				else { owner.set_attribute_value('poster', 'inner.png') }
			}
			assert !document.anything_is_delaying_the_load_event()
			assert (video.poster_frame() != none) == (action == 'success')
			mut current := unsafe { &dom.Document(document) }
			observed.independent = dom.DocumentLoadEventDelayer.new(mut current)
			// Neither stale completion path may release unrelated later work.
			if action == 'failure' { return error('obsolete outer poster failure') }
			return &dom.Bitmap_{width: 31, height: 11, pitch: 124, data: []u8{len: 31 * 11 * 4}}
		})
		element.set_attribute_value('poster', 'outer.png')
		assert probe.calls == if action in ['success', 'failure'] { 2 } else { 1 }
		assert (model.poster_frame() != none) == (action == 'success')
		if action == 'success' { assert model.natural_element_size()? == VideoDimensions{13, 7} }
		assert document.anything_is_delaying_the_load_event()
		mut observed := unsafe { &PosterLoadDelayProbe(probe) }
		if mut independent := observed.independent { independent.finish() }
		assert !document.anything_is_delaying_the_load_event()
	}
}
