module html

import dom

const vpla_namespace = 'urn:video-poster-live'

@[heap]
struct VplaProbe {
mut:
	urls []string
}

fn vpla_document(markup string) !&dom.Document {
	url := dom.URL{ value: 'https://poster-live.example/base/page.html' }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn vpla_observe(mut model HTMLVideoElementModel) &VplaProbe {
	probe := &VplaProbe{}
	model.set_poster_fetch_hook(fn [probe] (url dom.URL) !&dom.Bitmap_ {
		mut observed := unsafe { &VplaProbe(probe) }
		observed.urls << url.serialize()
		if url.serialize().ends_with('/failed.png') { return error('Controlled live poster failure') }
		width := if url.serialize().ends_with('/wide.png') { 20 } else { 13 }
		return &dom.Bitmap_{ width: width, height: 7, pitch: width * 4, data: []u8{len: width * 7 * 4} }
	})
	return probe
}

fn vpla_assert_media_idle(model &HTMLVideoElementModel) {
	assert model.media.paused() && model.media.current_time() == 0
	assert model.media.current_src() == '' && model.media.network_state() == .empty
	assert model.media.ready_state() == .have_nothing
	assert model.video_width() == 0 && model.video_height() == 0
	for name in ['loadstart', 'play', 'playing', 'pause', 'error', 'resize'] {
		assert model.media.event_count(name) == 0
	}
}

fn test_video_poster_attribute_writes_preserve_lazy_owners() {
	mut document := vpla_document('<!doctype html><body></body>')!
	defer { document.finalize() }
	mut element := document.create_element('video')!
	owner := unsafe { &dom.HTMLVideoElement(element) }
	element.set_attribute_value('poster', 'before.png')
	element.set_attribute_ns_for_bindings(vpla_namespace, 'p:poster', 'foreign.png')!
	element.remove_attribute('poster')
	element.set_attribute_value('data-unrelated', 'before model')
	assert owner.video_element_model_ == unsafe { nil }
	assert owner.media_element_model_ == unsafe { nil }
	mut model := html_video_element_model_for_dom_element(owner)
	probe := vpla_observe(mut model)
	element.set_attribute_value('data-unrelated', 'after model')
	element.set_attribute_value('width', '50')
	assert probe.urls == [] && model.poster_frame() == none
	element.set_attribute_value('poster', 'after.png')
	assert probe.urls == ['https://poster-live.example/base/after.png']
	assert voidptr(html_video_element_model_for_dom_element(owner)) == voidptr(model)
	assert voidptr(model.media) == owner.media_element_model_
	vpla_assert_media_idle(model)
}

fn test_video_live_poster_replacements_equal_writes_and_clearing_fetch_once() {
	mut document := vpla_document('<!doctype html><video id="v"></video>')!
	defer { document.finalize() }
	mut element := document.get_element_by_id('v') or { panic('Missing live poster owner') }
	mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	probe := vpla_observe(mut model)
	element.set_attribute_value('poster', 'first.png')
	attribute := element.get_attribute_node_ns(none, 'poster') or { panic('Missing poster Attr') }
	assert probe.urls == ['https://poster-live.example/base/first.png']
	assert (model.natural_element_size() or { panic('Missing first poster size') }) == VideoDimensions{13, 7}
	element.set_attribute_value('poster', 'wide.png')
	assert probe.urls.len == 2 && probe.urls[1] == 'https://poster-live.example/base/wide.png'
	assert voidptr(element.get_attribute_node_ns(none, 'poster') or { panic('Lost poster Attr') }) == voidptr(attribute)
	assert attribute.value() == 'wide.png'
	assert (model.natural_element_size() or { panic('Missing wide poster size') }) == VideoDimensions{20, 7}
	// Equal explicit DOM writes still execute the upstream attribute-change steps.
	element.set_attribute_value('poster', 'wide.png')
	assert probe.urls.len == 3 && probe.urls[2] == probe.urls[1]
	element.remove_attribute('poster')
	assert attribute.owner_element() == none && model.poster_ == none
	assert model.poster_frame() == none && model.natural_element_size() == none
	assert model.current_representation() == .transparent_black
	element.set_attribute_value('poster', '')
	element.set_attribute_value('poster', 'http://[invalid')
	assert probe.urls.len == 3 && model.poster_frame() == none
	element.set_attribute_value('poster', 'recovered.png')
	assert probe.urls.len == 4 && model.poster_frame() != none
	element.set_attribute_value('poster', 'failed.png')
	assert probe.urls.len == 5 && model.poster_frame() == none
	assert model.natural_element_size() == none
	vpla_assert_media_idle(model)
}

fn test_video_poster_named_node_map_replacement_and_removal_use_actual_owner() {
	mut document := vpla_document('<!doctype html><video id="v" poster="initial.png"></video>')!
	defer { document.finalize() }
	element := document.get_element_by_id('v') or { panic('Missing poster map owner') }
	mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	probe := vpla_observe(mut model)
	initial := element.get_attribute_node_ns(none, 'poster') or { panic('Missing initial poster Attr') }
	mut attributes := element.attributes()
	replacement := &dom.Attr_{ name_: 'poster', local_name_: 'poster', value_: 'map.png?raw=%20#frame' }
	assert voidptr(attributes.set_named_item(replacement)!) == voidptr(initial)
	assert initial.owner_element() == none
	assert voidptr(replacement.owner_element() or { panic('Missing replacement owner') }) == voidptr(element)
	assert probe.urls == ['https://poster-live.example/base/map.png?raw=%20#frame']
	assert (model.poster_ or { '' }) == replacement.value()
	assert model.poster_frame() != none && model.current_representation() == .poster_frame
	assert voidptr(attributes.remove_named_item('poster')!) == voidptr(replacement)
	assert replacement.owner_element() == none && model.poster_frame() == none
	assert model.poster_ == none && probe.urls.len == 1
	vpla_assert_media_idle(model)
}

fn test_video_poster_forwarding_ignores_foreign_attributes_case_and_elements() {
	for foreign_first in [false, true] {
		mut document := vpla_document('<!doctype html><video id="v"></video>')!
		defer { document.finalize() }
		mut element := document.get_element_by_id('v') or { panic('Missing namespace poster owner') }
		mut model := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		probe := vpla_observe(mut model)
		if foreign_first { element.set_attribute_ns_for_bindings(vpla_namespace, 'poster', 'foreign.png')! }
		element.set_attribute_value_ns('poster', 'actual.png', none, none)
		actual := element.get_attribute_node_ns(none, 'poster') or { panic('Missing actual poster Attr') }
		element.set_attribute_ns_for_bindings(vpla_namespace, 'poster', 'foreign-later.png')!
		element.set_attribute_ns_for_bindings('urn:poster-prefixed', 'p:poster', 'prefixed.png')!
		element.set_attribute_ns_for_bindings(none, 'POSTER', 'uppercase.png')!
		assert probe.urls == ['https://poster-live.example/base/actual.png']
		assert (model.poster_ or { '' }) == 'actual.png' && actual.value() == 'actual.png'
		assert (element.get_attribute_ns(vpla_namespace, 'poster') or { '' }) == 'foreign-later.png'
		element.remove_attribute_ns(vpla_namespace, 'poster')
		element.remove_attribute_ns('urn:poster-prefixed', 'poster')
		element.remove_attribute_ns(none, 'POSTER')
		assert probe.urls.len == 1 && model.poster_frame() != none
		element.remove_attribute_ns(none, 'poster')
		assert model.poster_frame() == none && model.poster_ == none
		mut foreign_video := document.create_element_ns('urn:foreign-video', 'video')!
		foreign_video.set_attribute_value('poster', 'must-not-cast.png')
		foreign_video.remove_attribute('poster')
		mut ordinary := document.create_element('div')!
		ordinary.set_attribute_value('poster', 'ordinary.png')
		assert probe.urls.len == 1
		vpla_assert_media_idle(model)
	}
}
