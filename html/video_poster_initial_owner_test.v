module html

import dom
import fetch

@[heap]
struct InitialPosterProbe {
mut:
	urls []string
}

fn initial_poster_document(address string, markup string) !&dom.Document {
	url := dom.URL{value: address}
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn initial_poster_transport(mut video HTMLVideoElementModel, document &dom.Document) &InitialPosterProbe {
	seen := &InitialPosterProbe{}
	video.set_poster_request_fetch_hook(fn [seen, document] (request &fetch.Request) !&dom.Bitmap_ {
		assert document.anything_is_delaying_the_load_event()
		client := request.client or { panic('missing current poster client') }
		assert (client.fetch_request_client_document_url() or { panic('missing client document URL') }) == document.url
		mut probe := unsafe { &InitialPosterProbe(seen) }
		probe.urls << request.current_url().serialize()
		return &dom.Bitmap_{width: 13, height: 7, pitch: 52, data: []u8{len: 364}}
	})
	return seen
}

fn initial_poster_assert_idle(video &HTMLVideoElementModel, document &dom.Document) {
	assert video.media.paused() && video.media.current_src() == ''
	assert video.media.network_state() == .empty && video.media.ready_state() == .have_nothing
	assert !document.anything_is_delaying_the_load_event()
	for name in ['loadstart', 'play', 'playing', 'error', 'resize'] {
		assert video.media.event_count(name) == 0
	}
}

fn test_parsed_poster_is_materialized_without_a_synthetic_dom_write_or_implicit_fetch() {
	mut document := initial_poster_document('https://initial-poster.example/base/page.html',
		'<!doctype html><base href="https://initial-images.example/covers/"><video id="video" poster=" frame.png?x=%20#part " preload="none"></video>')!
	defer { document.finalize() }
	element := document.get_element_by_id('video') or { panic('missing parsed poster owner') }
	owner := unsafe { &dom.HTMLVideoElement(element) }
	attribute := element.get_attribute_node_ns(none, 'poster') or { panic('missing parsed poster Attr') }
	assert owner.video_element_model_ == unsafe { nil }
	mut video := html_video_element_model_for_dom_element(owner)
	assert video.poster_? == ' frame.png?x=%20#part '
	assert video.poster_frame() == none && video.poster_fetch_generation_ == 0
	seen := initial_poster_transport(mut video, document)
	assert seen.urls == [] && video.poster_fetch_generation_ == 0
	assert voidptr(html_video_element_model_for_dom_element(owner)) == voidptr(video)
	video.determine_element_poster_frame()
	assert seen.urls == ['https://initial-images.example/covers/frame.png?x=%20#part']
	assert video.poster_frame()?.width == 13 && video.natural_element_size()? == VideoDimensions{13, 7}
	assert attribute.value() == ' frame.png?x=%20#part '
	assert voidptr(element.get_attribute_node_ns(none, 'poster')?) == voidptr(attribute)
	initial_poster_assert_idle(video, document)
}

fn test_created_video_reads_the_last_pre_model_attribute_and_preserves_clearing_values() {
	for value in ['latest.png', '', 'http://[invalid'] {
		mut document := initial_poster_document('https://initial-created.example/base/page.html', '<!doctype html><body></body>')!
		defer { document.finalize() }
		mut element := document.create_element('video')!
		element.set_attribute_value('poster', 'obsolete.png')
		mut attributes := element.attributes()
		replacement := &dom.Attr_{name_: 'poster', local_name_: 'poster', value_: value}
		attributes.set_named_item(replacement)!
		owner := unsafe { &dom.HTMLVideoElement(element) }
		assert owner.video_element_model_ == unsafe { nil } && owner.media_element_model_ == unsafe { nil }
		mut video := html_video_element_model_for_dom_element(owner)
		assert video.poster_? == value
		seen := initial_poster_transport(mut video, document)
		assert seen.urls == []
		video.determine_element_poster_frame()
		if value == 'latest.png' {
			assert seen.urls == ['https://initial-created.example/base/latest.png'] && video.poster_frame() != none
		} else {
			assert seen.urls == [] && video.poster_frame() == none
		}
		element.remove_attribute('poster')
		assert video.poster_ == none && replacement.owner_element() == none
		assert video.poster_frame() == none && voidptr(html_video_element_model_for_dom_element(owner)) == voidptr(video)
		initial_poster_assert_idle(video, document)
	}
}

fn test_initial_poster_uses_only_the_exact_null_namespace_attribute_in_either_tree_order() {
	for foreign_first in [true, false] {
		mut document := initial_poster_document('https://initial-namespace.example/base/page.html', '<!doctype html>')!
		defer { document.finalize() }
		mut element := document.create_element('video')!
		if !foreign_first { element.set_attribute_value('poster', 'actual.png') }
		element.set_attribute_ns_for_bindings('urn:initial-poster', 'poster', 'foreign.png')!
		element.set_attribute_ns_for_bindings(none, 'POSTER', 'uppercase.png')!
		if foreign_first { element.set_attribute_value_ns('poster', 'actual.png', none, none) }
		mut video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
		assert video.poster_? == 'actual.png'
		seen := initial_poster_transport(mut video, document)
		video.determine_element_poster_frame()
		assert seen.urls == ['https://initial-namespace.example/base/actual.png']
		initial_poster_assert_idle(video, document)
		mut foreign_only := document.create_element('video')!
		foreign_only.set_attribute_ns_for_bindings('urn:initial-poster', 'poster', 'foreign-only.png')!
		mut absent := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(foreign_only) })
		assert absent.poster_ == none
		absent_seen := initial_poster_transport(mut absent, document)
		absent.determine_element_poster_frame()
		assert absent_seen.urls == [] && absent.poster_frame() == none
	}
}

fn test_initial_poster_follows_pre_model_adoption_and_cached_owners_do_not_reinitialize_it() {
	mut original := initial_poster_document('https://initial-old.example/base/page.html',
		'<!doctype html><video id="video" poster="frame.png"></video>')!
	mut destination := initial_poster_document('https://initial-new.example/page.html',
		'<!doctype html><base href="https://initial-current.example/covers/"><body></body>')!
	defer { original.finalize(); destination.finalize() }
	mut element := original.get_element_by_id('video') or { panic('missing adopted initial owner') }
	owner := unsafe { &dom.HTMLVideoElement(element) }
	destination.adopt_node(element.as_node())
	assert owner.video_element_model_ == unsafe { nil }
	mut video := html_video_element_model_for_dom_element(owner)
	assert video.poster_? == 'frame.png' && voidptr(video.media.document()?) == voidptr(destination)
	seen := initial_poster_transport(mut video, destination)
	video.determine_element_poster_frame()
	assert seen.urls == ['https://initial-current.example/covers/frame.png']
	video.set_poster('adapter.png')
	assert element.get_attribute_value('poster') == 'frame.png'
	assert voidptr(html_video_element_model_for_dom_element(owner)) == voidptr(video)
	assert video.poster_? == 'adapter.png' && seen.urls.len == 2
	element.set_attribute_value('poster', 'live.png')
	assert video.poster_? == 'live.png' && seen.urls == ['https://initial-current.example/covers/frame.png',
		'https://initial-current.example/covers/adapter.png', 'https://initial-current.example/covers/live.png']
	initial_poster_assert_idle(video, destination)
	assert !original.anything_is_delaying_the_load_event()
}
