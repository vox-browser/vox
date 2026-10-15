module html

import dom

@[heap]
struct MediaCrossOriginDOMProbe {
mut:
	media_fetches int
	track_modes   []CORSSettingAttribute
	track_urls    []string
	track_owners  []dom.UniqueNodeID
}

fn media_cross_origin_dom_document(address string, markup string) !&dom.Document {
	url := dom.URL{ value: address }
	return parse_navigation_document(markup, url, url.origin(), none)!
}

fn media_cross_origin_dom_load_track(element &dom.Element, probe &MediaCrossOriginDOMProbe, index int) ! {
	mut document := element.document()
	mut track_element := document.create_element_ns(dom.namespace_html_uri, 'track')!
	track_element.set_attribute_value('kind', 'subtitles')
	track_element.set_attribute_value('src', 'captions-${index}.vtt')
	track_dom := unsafe { &dom.HTMLTrackElement(track_element) }
	mut track := html_track_element_model_for_dom_element(track_dom)
	track.set_fetch_hook(fn [probe, element] (url dom.URL, cors CORSSettingAttribute) !TextTrackResourceResponse {
		mut observed := unsafe { &MediaCrossOriginDOMProbe(probe) }
		observed.track_modes << cors
		observed.track_urls << url.serialize()
		observed.track_owners << element.document().unique_id()
		return TextTrackResourceResponse{
			body: 'WEBVTT\n\n00:00.000 --> 00:01.000\nactual owner CORS'
		}
	})
	mut parent := element.as_node()
	parent.append_child(track_element.as_node())!
	html_track_element_inserted(track_dom)
	assert voidptr(track.parent_media_?) == voidptr(html_media_element_for_dom_element(element)?)
	assert track.track.kind() == .subtitles && track.track.mode() == .hidden
	assert track.ready_state() == .loaded && track.event_count('load') == 1
	assert track.track.cues().length() == 1
	assert track.track.cues().item(0)?.text() == 'actual owner CORS'
}

fn media_cross_origin_dom_drain(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for _ in 0 .. 100 {
		if media.queued_media_task_ids_.len == 0 { return }
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing cross-origin media task') }
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_media_cross_origin_reflection_preserves_parsed_raw_live_dom_adoption_and_fallback() {
	mut document := media_cross_origin_dom_document('https://media-cors-dom.example.test/',
		'<!doctype html><video id="cors-present" crossorigin="UsE-CrEdEnTiAlS"></video><audio id="cors-absent"></audio>')!
	mut destination := media_cross_origin_dom_document('https://media-cors-adopted.example.test/', '<body></body>')!
	defer {
		document.finalize()
		destination.finalize()
	}
	mut video_element := document.get_element_by_id('cors-present')?
	mut audio_element := document.get_element_by_id('cors-absent')?
	assert video_element.get_attribute('crossorigin')? == 'UsE-CrEdEnTiAlS'
	mut video := html_media_element_for_dom_element(video_element)?
	mut audio := html_media_element_for_dom_element(audio_element)?
	assert video.cross_origin()? == 'use-credentials' && video.crossorigin() == .use_credentials
	assert video_element.get_attribute('crossorigin')? == 'UsE-CrEdEnTiAlS'
	assert audio.cross_origin() == none && audio.crossorigin() == .no_cors
	values := ['', 'invalid', 'anonymous', 'ANONYMOUS', 'UsE-CrEdEnTiAlS',
		' use-credentials ', 'use-credentials\u00a0', 'ＵＳＥ－ＣＲＥＤＥＮＴＩＡＬＳ', 'use-credentials\x00']
	for index, raw in values {
		expected := if index == 4 { 'use-credentials' } else { 'anonymous' }
		expected_mode := if index == 4 { CORSSettingAttribute.use_credentials } else { CORSSettingAttribute.anonymous }
		video_element.set_attribute_value('crossorigin', raw)
		assert video_element.get_attribute('crossorigin')? == raw
		assert video.cross_origin()? == expected && video.crossorigin() == expected_mode
		video.set_crossorigin(raw)
		assert video_element.get_attribute('crossorigin')? == raw
		assert video.cross_origin()? == expected && video.crossorigin() == expected_mode
	}
	video.set_crossorigin('use-credentials')
	video_element.remove_attribute('crossorigin')
	assert video.crossorigin_ == .use_credentials
	assert video.cross_origin() == none && video.crossorigin() == .no_cors
	video.set_crossorigin(none)
	assert video.crossorigin_ == .no_cors && !video_element.has_attribute('crossorigin')
	audio_element.set_attribute_value('crossorigin', 'ANONYMOUS')
	destination.adopt_node(audio_element.as_node())
	assert voidptr(audio_element.document()) == voidptr(destination)
	assert voidptr(html_media_element_for_dom_element(audio_element)?) == voidptr(audio)
	assert audio_element.get_attribute('crossorigin')? == 'ANONYMOUS'
	assert audio.cross_origin()? == 'anonymous' && audio.crossorigin() == .anonymous
	audio_element.set_attribute_value('crossorigin', 'use-credentials')
	assert audio.cross_origin()? == 'use-credentials'
	audio.set_crossorigin(none)
	assert audio.cross_origin() == none && audio.crossorigin() == .no_cors
	audio_element.set_attribute_value_ns('crossorigin', 'use-credentials', 'custom', 'urn:media-cors-test')
	assert audio_element.has_attribute_ns('urn:media-cors-test', 'crossorigin')
	assert audio.cross_origin() == none && audio.crossorigin() == .no_cors
	mut svg := document.create_element_ns(dom.namespace_svg_uri, 'video')!
	svg.set_attribute_value('crossorigin', 'anonymous')
	assert html_media_element_for_dom_element(svg) == none
	for media in [video, audio] {
		assert media.paused() && media.current_time() == 0 && !media.ended()
		assert media.network_state() == .empty && media.ready_state() == .have_nothing
		for name in ['loadstart', 'play', 'playing', 'emptied'] { assert media.event_count(name) == 0 }
	}
	mut fallback := HTMLMediaElement.create(none, dom.url_about_blank())
	assert fallback.cross_origin() == none && fallback.crossorigin() == .no_cors
	for index, raw in values {
		fallback.set_crossorigin(raw)
		assert fallback.crossorigin() == if index == 4 { CORSSettingAttribute.use_credentials } else { CORSSettingAttribute.anonymous }
		assert fallback.cross_origin()? == if index == 4 { 'use-credentials' } else { 'anonymous' }
	}
	fallback.set_crossorigin(none)
	assert fallback.cross_origin() == none && fallback.crossorigin() == .no_cors
	assert fallback.paused() && fallback.queued_media_task_ids_.len == 0
}

fn test_media_cross_origin_real_track_fetches_follow_live_owner_without_restarting_media() {
	mut document := media_cross_origin_dom_document('https://media-cors-source.example.test/base/',
		'<!doctype html><video id="cors-owner" preload="none"></video>')!
	mut destination := media_cross_origin_dom_document('https://media-cors-target.example.test/next/', '<body></body>')!
	defer {
		document.finalize()
		destination.finalize()
	}
	mut element := document.get_element_by_id('cors-owner')?
	mut media := html_media_element_for_dom_element(element)?
	probe := &MediaCrossOriginDOMProbe{}
	media.set_fetch_hook(fn [probe] (_ dom.URL, offset u64) !MediaResourceResponse {
		assert offset == 0
		mut observed := unsafe { &MediaCrossOriginDOMProbe(probe) }
		observed.media_fetches++
		return MediaResourceResponse{ mime_type: 'video/mp4', duration: 5, buffered_end: 5 }
	})
	media.set_source('movie.mp4')
	media.select_resource()!
	assert probe.media_fetches == 0 && media.network_state() == .idle
	assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
	media.set_current_playback_position(2.5)
	media.set_official_playback_position(2.5)
	before_events := media.event_counts_.clone()
	before_source := media.current_src()
	media_cross_origin_dom_load_track(element, probe, 0)!
	element.set_attribute_value('crossorigin', 'UsE-CrEdEnTiAlS')
	media_cross_origin_dom_load_track(element, probe, 1)!
	media.set_crossorigin(' use-credentials ')
	media_cross_origin_dom_load_track(element, probe, 2)!
	element.remove_attribute('crossorigin')
	media_cross_origin_dom_load_track(element, probe, 3)!
	assert probe.track_modes == [CORSSettingAttribute.no_cors, .use_credentials, .anonymous, .no_cors]
	assert probe.track_urls == ['https://media-cors-source.example.test/base/captions-0.vtt',
		'https://media-cors-source.example.test/base/captions-1.vtt',
		'https://media-cors-source.example.test/base/captions-2.vtt',
		'https://media-cors-source.example.test/base/captions-3.vtt']
	assert probe.track_owners == [document.unique_id(), document.unique_id(), document.unique_id(), document.unique_id()]
	assert probe.media_fetches == 0 && media.current_src() == before_source
	assert media.event_counts_ == before_events && media.current_time() == 2.5
	destination.adopt_node(element.as_node())
	assert voidptr(media.document()?) == voidptr(destination)
	element.set_attribute_value('crossorigin', 'ANONYMOUS')
	media_cross_origin_dom_load_track(element, probe, 4)!
	media.set_crossorigin('use-credentials')
	media_cross_origin_dom_load_track(element, probe, 5)!
	media.set_crossorigin(none)
	media_cross_origin_dom_load_track(element, probe, 6)!
	assert probe.track_modes[4..] == [CORSSettingAttribute.anonymous, .use_credentials, .no_cors]
	assert probe.track_urls[4..] == ['https://media-cors-target.example.test/next/captions-4.vtt',
		'https://media-cors-target.example.test/next/captions-5.vtt',
		'https://media-cors-target.example.test/next/captions-6.vtt']
	assert probe.track_owners[4..] == [destination.unique_id(), destination.unique_id(), destination.unique_id()]
	assert probe.media_fetches == 0 && media.current_src() == before_source
	assert media.event_counts_ == before_events && media.current_time() == 2.5
	assert media.paused() && media.ready_state() == .have_nothing && !media.seeking()
	assert media.waiting_for_an_implementation_defined_event_to_fetch_the_resource_
	assert !media.current_resource_selection_is_explicit_
	// Only a resource-selection attribute change promotes the existing deferred fetch.
	media.set_preload('metadata')
	assert probe.media_fetches == 1 && media.paused() && media.ready_state() == .have_enough_data
	media_cross_origin_dom_drain(media)
	media.set_crossorigin('anonymous')
	element.remove_attribute('crossorigin')
	assert probe.media_fetches == 1 && media.cross_origin() == none
	assert media.event_count('play') == 0 && media.event_count('playing') == 0
}
