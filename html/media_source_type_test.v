module html

import dom

struct MediaSourceTypeProbe {
mut:
	urls []string
}

fn media_source_type_mp4_only(type_ string) CanPlayTypeResult {
	return if mime_essence(type_) == 'video/mp4' { .maybe } else { .empty }
}

fn media_source_type_element(probe &MediaSourceTypeProbe) &HTMLMediaElement {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/page' })
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		can_play_type: media_source_type_mp4_only
	})
	media.set_fetch_hook(fn [probe] (url dom.URL, _ u64) !MediaResourceResponse {
		mut observation := unsafe { &MediaSourceTypeProbe(probe) }
		observation.urls << url.serialize()
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 15, buffered_end: 15 }
	})
	return media
}

// cybersport.ru's logo lists `<source src="/logo.webm" type="video/webm">`
// before an MP4. A source whose type the playback backend cannot render must
// fail without being fetched, and selection must continue with the next one.
fn test_sources_with_unrenderable_types_are_skipped_without_fetching() {
	probe := &MediaSourceTypeProbe{}
	mut media := media_source_type_element(probe)
	media.set_typed_source_candidates(['/logo.webm', '/logo.mp4'], ['video/webm', 'video/mp4'])
	media.load()!
	assert probe.urls == ['https://example.test/logo.mp4']
	assert media.current_src() == 'https://example.test/logo.mp4'
	assert media.error() == none
}

fn test_sources_without_a_type_or_with_parameters_are_still_fetched() {
	probe := &MediaSourceTypeProbe{}
	mut media := media_source_type_element(probe)
	media.set_typed_source_candidates(['/a.webm', '/b.mp4'], ['', 'video/mp4; codecs="avc1.42E01E"'])
	media.load()!
	assert probe.urls == ['https://example.test/a.webm']
	assert media.current_src() == 'https://example.test/a.webm'
}

fn test_sources_without_a_src_fail_without_fetching_the_base_url() {
	probe := &MediaSourceTypeProbe{}
	mut media := media_source_type_element(probe)
	media.set_typed_source_candidates(['', ' ', '/b.mp4'], ['video/mp4', '', 'video/mp4'])
	media.load()!
	assert probe.urls == ['https://example.test/b.mp4']
}

fn test_only_unrenderable_sources_report_an_unsupported_source_without_fetching() {
	probe := &MediaSourceTypeProbe{}
	mut media := media_source_type_element(probe)
	media.set_typed_source_candidates(['/a.webm', '/b.ogv'], ['video/webm', 'video/ogg'])
	media.load() or {}
	assert probe.urls == []
	assert media.network_state() == .no_source
	error_ := media.error() or { panic('missing media error') }
	assert error_.code == .src_not_supported
}

fn test_dom_source_children_supply_their_type_attributes() {
	url := dom.URL{ value: 'https://example.test/page' }
	mut document := parse_navigation_document('<!doctype html><video id="logo"><source src="/logo.webm" type="video/webm"><source type="video/mp4"><source src="/logo.mp4" type="video/mp4"><source src="/plain.mp4"></video>',
		url, url.origin(), none)!
	defer { document.finalize() }
	video := document.get_element_by_id('logo') or { panic('missing video') }
	candidates, types := media_source_candidates_from_dom(video)
	assert candidates == ['/logo.webm', '/logo.mp4', '/plain.mp4']
	assert types == ['video/webm', 'video/mp4', '']
}
