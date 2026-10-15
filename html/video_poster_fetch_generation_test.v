module html

import dom

$if gcboehm ? { fn C.GC_gcollect() }

@[heap]
struct PfgProbe {
	seed &dom.Bitmap_
	current &dom.Bitmap_
	obsolete &dom.Bitmap_
mut:
	urls []string
	published_widths []int
	stage int
}

fn pfg_document() (&dom.Document, &dom.Element, &HTMLVideoElementModel, &PfgProbe) {
	url := dom.URL{value: 'https://poster-generation.example/base/page.html'}
	mut document := parse_navigation_document('<!doctype html><video id="video" preload="none"></video>',
		url, url.origin(), none) or { panic(err) }
	mut element := document.get_element_by_id('video') or { panic('missing poster video') }
	mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	probe := &PfgProbe{
		seed: &dom.Bitmap_{width: 11, height: 5, pitch: 44, data: []u8{len: 11 * 5 * 4, init: 11}}
		current: &dom.Bitmap_{width: 20, height: 9, pitch: 80, data: []u8{len: 20 * 9 * 4, init: 20}}
		obsolete: &dom.Bitmap_{width: 31, height: 13, pitch: 124, data: []u8{len: 31 * 13 * 4, init: 31}}
	}
	model.set_poster_fetch_hook(fn [probe] (address dom.URL) !&dom.Bitmap_ {
		mut observed := unsafe { &PfgProbe(probe) }
		observed.urls << address.serialize()
		return probe.seed
	})
	element.set_attribute_value('poster', 'seed.png')
	assert voidptr(model.poster_frame() or { panic('missing seed poster') }) == voidptr(probe.seed)
	model.set_paint_facts_update_hook(fn [probe] (owner &dom.HTMLVideoElement) {
		video := html_video_element_model_for_dom_element(owner)
		mut observed := unsafe { &PfgProbe(probe) }
		observed.published_widths << if frame := video.poster_frame() { frame.width } else { 0 }
	})
	return document, element, model, probe
}

fn pfg_assert_current(model &HTMLVideoElementModel, probe &PfgProbe) {
	assert voidptr(model.poster_frame() or { panic('lost current poster') }) == voidptr(probe.current)
	assert (model.natural_element_size() or { panic('missing current poster dimensions') }) == VideoDimensions{20, 9}
	assert model.current_representation() == .poster_frame
	assert probe.published_widths == [20]
	assert model.media.paused() && model.media.current_src() == ''
	assert model.media.network_state() == .empty && model.media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'pause', 'error', 'resize'] {
		assert model.media.event_count(name) == 0
	}
}

fn test_superseded_poster_success_preserves_nested_current_frame_and_later_requests() {
	mut document, mut element, mut model, probe := pfg_document()
	defer { document.finalize() }
	attribute := element.get_attribute_node_ns(none, 'poster') or { panic('missing poster Attr') }
	model.set_poster_fetch_hook(fn [element, model, probe] (address dom.URL) !&dom.Bitmap_ {
		mut observed := unsafe { &PfgProbe(probe) }
		observed.urls << address.serialize()
		if address.serialize().ends_with('/outer.png') {
			assert voidptr(model.poster_frame() or { panic('seed cleared before completion') }) == voidptr(probe.seed)
			mut owner := unsafe { &dom.Element(element) }
			owner.set_attribute_value('poster', 'current.png')
			pfg_assert_current(model, probe)
			return probe.obsolete
		}
		return if address.serialize().ends_with('/later.png') { probe.seed } else { probe.current }
	})
	element.set_attribute_value('poster', 'outer.png')
	$if gcboehm ? { C.GC_gcollect() }
	assert voidptr(model.poster_frame()?) == voidptr(probe.current)
	pfg_assert_current(model, probe)
	assert model.poster_? == 'current.png'
	assert element.get_attribute_value('poster') == 'current.png'
	assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
	assert probe.urls == ['https://poster-generation.example/base/seed.png',
		'https://poster-generation.example/base/outer.png', 'https://poster-generation.example/base/current.png']
	element.set_attribute_value('poster', 'later.png')
	assert voidptr(model.poster_frame()?) == voidptr(probe.seed)
	assert model.natural_element_size()? == VideoDimensions{11, 5}
	assert probe.published_widths == [20, 11] && probe.urls.len == 4
}

fn test_superseded_poster_error_does_not_clear_nested_success() {
	mut document, mut element, mut model, probe := pfg_document()
	defer { document.finalize() }
	model.set_poster_fetch_hook(fn [element, model, probe] (address dom.URL) !&dom.Bitmap_ {
		mut observed := unsafe { &PfgProbe(probe) }
		observed.urls << address.serialize()
		if address.serialize().ends_with('/outer.png') {
			mut owner := unsafe { &dom.Element(element) }
			owner.set_attribute_value('poster', 'current.png')
			pfg_assert_current(model, probe)
			return error('obsolete outer fetch failure')
		}
		return probe.current
	})
	element.set_attribute_value('poster', 'outer.png')
	assert model.poster_frame() != none
	pfg_assert_current(model, probe)
	assert model.poster_? == 'current.png' && probe.urls.len == 3
}

fn test_clearing_or_failing_latest_poster_prevents_obsolete_frame_resurrection() {
	for action in ['remove', 'empty', 'invalid', 'failure'] {
		mut document, mut element, mut model, probe := pfg_document()
		defer { document.finalize() }
		attribute := element.get_attribute_node_ns(none, 'poster') or { panic('missing poster Attr') }
		model.set_poster_fetch_hook(fn [element, model, probe, action] (address dom.URL) !&dom.Bitmap_ {
			mut observed := unsafe { &PfgProbe(probe) }
			observed.urls << address.serialize()
			if address.serialize().ends_with('/failed.png') { return error('current poster failed') }
			mut owner := unsafe { &dom.Element(element) }
			match action {
				'remove' { owner.remove_attribute('poster') }
				'empty' { owner.set_attribute_value('poster', '') }
				'invalid' { owner.set_attribute_value('poster', 'http://[invalid') }
				else { owner.set_attribute_value('poster', 'failed.png') }
			}
			assert model.poster_frame() == none && model.natural_element_size() == none
			assert probe.published_widths == [0]
			return probe.obsolete
		})
		element.set_attribute_value('poster', 'outer.png')
		assert model.poster_frame() == none && model.natural_element_size() == none
		assert model.current_representation() == .transparent_black
		assert probe.published_widths == [0]
		assert probe.urls.len == if action == 'failure' { 3 } else { 2 }
		if action == 'remove' {
			assert model.poster_ == none && attribute.owner_element() == none
		} else {
			assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
		}
	}
}

fn test_poster_a_to_b_to_a_keeps_the_latest_generation_of_the_same_url() {
	mut document, mut element, mut model, probe := pfg_document()
	defer { document.finalize() }
	model.set_poster_fetch_hook(fn [element, probe] (address dom.URL) !&dom.Bitmap_ {
		mut observed := unsafe { &PfgProbe(probe) }
		observed.urls << address.serialize()
		mut owner := unsafe { &dom.Element(element) }
		if address.serialize().ends_with('/a.png') && observed.stage == 0 {
			observed.stage = 1
			owner.set_attribute_value('poster', 'b.png')
			return probe.obsolete
		}
		if address.serialize().ends_with('/b.png') {
			observed.stage = 2
			owner.set_attribute_value('poster', 'a.png')
			return probe.seed
		}
		return probe.current
	})
	element.set_attribute_value('poster', 'a.png')
	assert voidptr(model.poster_frame()?) == voidptr(probe.current)
	pfg_assert_current(model, probe)
	assert model.poster_? == 'a.png' && probe.stage == 2
	assert probe.urls == ['https://poster-generation.example/base/seed.png',
		'https://poster-generation.example/base/a.png', 'https://poster-generation.example/base/b.png',
		'https://poster-generation.example/base/a.png']
}
