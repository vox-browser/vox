module html

import dom

@[heap]
struct VpdObservation {
mut:
	urls []string
}

fn vpd_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn vpd_frame() &dom.Bitmap_ {
	return &dom.Bitmap_{
		width: 13
		height: 7
		pitch: 52
		data: []u8{len: 13 * 7 * 4}
	}
}

fn vpd_install_fetch(mut video HTMLVideoElementModel, observed &VpdObservation) {
	video.set_poster_fetch_hook(fn [observed] (url dom.URL) !&dom.Bitmap_ {
		mut probe := unsafe { &VpdObservation(observed) }
		probe.urls << url.serialize()
		if url.serialize().ends_with('/failed.png') {
			return error('Controlled poster failure')
		}
		return vpd_frame()
	})
}

fn vpd_change_poster(mut element dom.Element, value string) {
	element.set_attribute_value('poster', value)
}

fn test_video_poster_uses_adopted_owner_document_base_through_live_attribute() {
	mut original := vpd_document('https://poster-old.example/root/page.html',
		'<!doctype html><base href="https://old-cdn.example/assets/"><video id="video"></video>')!
	mut destination := vpd_document('https://poster-new.example/next/page.html',
		'<!doctype html><base href="https://new-cdn.example/images/"><body></body>')!
	defer { original.finalize(); destination.finalize() }
	mut element := original.get_element_by_id('video') or { panic('Missing poster video') }
	video_element := unsafe { &dom.HTMLVideoElement(element) }
	mut video := html_video_element_model_for_dom_element(video_element)
	observed := &VpdObservation{}
	vpd_install_fetch(mut video, observed)
	vpd_change_poster(mut element, 'covers/first.png')
	assert observed.urls == ['https://old-cdn.example/assets/covers/first.png']
	first := video.poster_frame() or { panic('Missing original poster') }
	assert first.width == 13 && first.height == 7
	assert (video.natural_element_size() or { panic('Missing poster size') }) == VideoDimensions{13, 7}

	destination.adopt_node(element.as_node())
	assert voidptr(element.document()) == voidptr(destination)
	assert voidptr(html_video_element_model_for_dom_element(video_element)) == voidptr(video)
	assert voidptr(video.poster_frame() or { panic('Lost retained poster') }) == voidptr(first)
	assert observed.urls.len == 1
	vpd_change_poster(mut element, 'covers/second.png?raw=%20#preview')
	assert observed.urls == ['https://old-cdn.example/assets/covers/first.png',
		'https://new-cdn.example/images/covers/second.png?raw=%20#preview']
	assert (element.get_attribute_ns(none, 'poster') or { '' }) == 'covers/second.png?raw=%20#preview'
	assert video.current_representation() == .poster_frame
	assert video.video_width() == 0 && video.video_height() == 0
	assert video.media.paused() && video.media.network_state() == .empty
	assert video.media.current_src() == '' && video.media.ready_state() == .have_nothing
	for name in ['loadstart', 'play', 'playing', 'error', 'resize'] {
		assert video.media.event_count(name) == 0
	}
}

fn test_video_poster_reprocessing_reads_live_base_and_current_document_url() {
	mut document := vpd_document('https://poster-live.example/root/page.html',
		'<!doctype html><base id="base" href="assets/"><video id="video"></video>')!
	defer { document.finalize() }
	element := document.get_element_by_id('video') or { panic('Missing live-base video') }
	mut base := document.get_element_by_id('base') or { panic('Missing poster base') }
	mut video := html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	observed := &VpdObservation{}
	vpd_install_fetch(mut video, observed)
	video.set_poster('poster.png')
	assert observed.urls == ['https://poster-live.example/root/assets/poster.png']
	base.set_attribute_value('href', '../covers/')
	assert document.base_url().serialize() == 'https://poster-live.example/covers/'
	video.determine_element_poster_frame()
	assert observed.urls == ['https://poster-live.example/root/assets/poster.png',
		'https://poster-live.example/covers/poster.png']
	assert (video.poster_ or { '' }) == 'poster.png'

	document.set_url(dom.URL{ value: 'https://poster-current.example/next/page.html' })
	base.remove_attribute('href')
	assert document.base_url().serialize() == 'https://poster-current.example/next/page.html'
	video.determine_element_poster_frame()
	assert observed.urls[2] == 'https://poster-current.example/next/poster.png'
	assert video.current_representation() == .poster_frame
	assert video.media.network_state() == .empty && video.media.current_src() == ''
}

fn test_standalone_video_poster_keeps_constructor_base_and_existing_failure_clearing() {
	url := dom.URL{ value: 'https://poster-standalone.example/base/page.html' }
	media := HTMLMediaElement.create(none, url)
	mut video := HTMLVideoElementModel.create(media, url)
	observed := &VpdObservation{}
	vpd_install_fetch(mut video, observed)
	video.set_poster('frame.png')
	assert observed.urls == ['https://poster-standalone.example/base/frame.png']
	assert video.poster_frame() != none && video.current_representation() == .poster_frame
	video.set_poster(none)
	assert video.poster_frame() == none && video.natural_element_size() == none
	video.set_poster('')
	video.set_poster('http://[invalid')
	assert observed.urls.len == 1 && video.poster_frame() == none
	assert video.current_representation() == .transparent_black
	video.set_poster('frame.png')
	assert video.poster_frame() != none
	video.set_poster('failed.png')
	assert observed.urls.last() == 'https://poster-standalone.example/base/failed.png'
	assert video.poster_frame() == none && video.natural_element_size() == none
	video.set_poster('https://poster-absolute.example/cover.png')
	assert observed.urls.last() == 'https://poster-absolute.example/cover.png'
	assert video.poster_frame() != none && media.paused() && media.current_src() == ''
}
