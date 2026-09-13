module html

import dom

fn media_elements_fetch(url dom.URL, _ u64) !MediaResourceResponse {
	_ = url
	return MediaResourceResponse{
		mime_type: 'video/mp4'
		duration: 120
		video_tracks: [MediaTrackMetadata{
			identifier: 1
			name: 'video'
			pixel_width: 1920
			pixel_height: 1080
		}]
	}
}

fn poster_test_fetch(_ dom.URL) !&dom.Bitmap_ {
	return &dom.Bitmap_{
		width: 320
		height: 180
		pitch: 1280
		data: []u8{len: 320 * 180 * 4}
	}
}

fn track_test_fetch(_ dom.URL, _ CORSSettingAttribute) !TextTrackResourceResponse {
	return TextTrackResourceResponse{
		body: 'WEBVTT\n\nintro\n00:00.000 --> 00:02.500\nHello\n\n00:03.000 --> 00:04.000\nWorld'
	}
}

fn test_video_representation_dimensions_poster_and_controls() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_fetch_hook(media_elements_fetch)
	media.set_source('/movie.mp4')
	mut video := HTMLVideoElementModel.create(media, dom.URL{ value: 'https://example.test/' })
	video.set_poster_fetch_hook(poster_test_fetch)
	video.set_poster('/poster.png')
	assert video.current_representation() == .poster_frame
	assert video.poster_frame()?.width == 320
	assert video.natural_element_size()? == VideoDimensions{320, 180}
	video.set_video_dimensions(1920, 1080)
	assert video.video_width() == 0
	assert video.video_height() == 0
	assert video.natural_media_size()? == VideoDimensions{1920, 1080}
	assert video.natural_element_size()? == VideoDimensions{320, 180}
	media.load()!
	assert video.video_width() == 1920
	assert video.video_height() == 1080
	assert video.current_representation() == .poster_frame
	media.set_show_poster(false)
	assert video.current_representation() == .video_frame
	assert video.natural_element_size()? == VideoDimensions{1920, 1080}
	assert media.event_count('resize') == 2
	mut controls := MediaControls.create(media)
	controls.toggle_playback()
	assert controls.play_icon_is_pause
	controls.set_current_time(30)
	assert controls.timeline_percentage == 25
	assert controls.timestamp == '0:30 / 2:00'
	controls.set_volume(0.25)!
	assert controls.mute_icon == .low
	controls.toggle_mute()
	assert controls.mute_icon == .low
	assert controls.was_muted
	assert controls.shadow_tree_created
	assert controls.registered_event_listeners_.len == 10
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
}

fn test_concrete_video_poster_attribute_change_uses_video_state() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut video_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video') or {
		panic(err)
	}
	video := unsafe { &dom.HTMLVideoElement(video_element) }
	mut model := html_video_element_model_for_dom_element(video)
	model.set_poster_fetch_hook(poster_test_fetch)
	html_video_element_attribute_changed(video, 'poster', none, '/poster.png', none)
	assert model.poster_frame()?.width == 320
}

fn test_track_element_loads_webvtt_and_failure() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	mut track_element := HTMLTrackElementModel.create(dom.URL{ value: 'https://example.test/' })
	track_element.set_parent_media(media)
	track_element.set_fetch_hook(track_test_fetch)
	track_element.set_src('/captions.vtt')
	track_element.set_mode(.hidden)
	track_element.start_the_track_processing_model()
	assert track_element.ready_state() == .loaded
	assert track_element.track.cues().length() == 2
	assert track_element.track.cues().item(0)?.id() == 'intro'
	assert track_element.track.cues().item(0)?.text() == 'Hello'
	assert track_element.event_count('load') == 1

	mut broken := HTMLTrackElementModel.create(dom.URL{ value: 'https://example.test/' })
	broken.set_parent_media(media)
	broken.set_src('')
	broken.set_mode(.showing)
	broken.start_the_track_processing_model()
	assert broken.ready_state() == .error
	assert broken.event_count('error') == 1
}

fn test_concrete_track_element_attributes_and_insertion_use_track_state() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/root/' })
	mut audio_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'audio') or {
		panic(err)
	}
	mut track_dom_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'track') or {
		panic(err)
	}
	mut audio_node := unsafe { &dom.Node(audio_element) }
	track_node := unsafe { &dom.Node(track_dom_element) }
	audio_node.append_child(track_node) or { panic(err) }

	track_element := unsafe { &dom.HTMLTrackElement(track_dom_element) }
	mut model := html_track_element_model_for_dom_element(track_element)
	model.set_fetch_hook(track_test_fetch)

	html_track_element_attribute_changed(track_element, 'kind', none, 'captions', none)
	html_track_element_attribute_changed(track_element, 'label', none, 'English', none)
	html_track_element_attribute_changed(track_element, 'srclang', none, 'en', none)
	html_track_element_attribute_changed(track_element, 'id', none, 'captions-en', none)
	html_track_element_attribute_changed(track_element, 'src', none, '/captions.vtt', none)
	html_track_element_inserted(track_element)

	assert model.track.kind() == .captions
	assert model.track.label() == 'English'
	assert model.track.language() == 'en'
	assert model.track.id() == 'captions-en'
	assert model.track.mode() == .hidden
	assert model.ready_state() == .loaded
	assert model.track.cues().length() == 2
	assert model.event_count('load') == 1
}
