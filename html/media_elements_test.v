module html

import dom

fn media_elements_fetch(url dom.URL, _ u64) !MediaResourceResponse {
	_ = url
	return MediaResourceResponse{
		mime_type:    'video/mp4'
		duration:     120
		video_tracks: [MediaTrackMetadata{ identifier: 1, name: 'video' }]
	}
}

fn poster_test_fetch(_ dom.URL) !&dom.ImmutableBitmap_ {
	return &dom.ImmutableBitmap_{
		width:  320
		height: 180
		pitch:  1280
		data:   []u8{len: 320 * 180 * 4}
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
	assert video.bitmap()?.width == 320
	video.set_video_dimensions(1920, 1080)
	assert video.video_width() == 1920
	media.load()!
	assert video.current_representation() == .poster_frame
	mut controls := MediaControls.create(media)
	controls.toggle_playback()
	assert controls.play_icon_is_pause
	controls.set_current_time(30)
	assert controls.timeline_percentage == 0.25
	assert controls.timestamp == '0:30 / 2:00'
	controls.set_volume(0.25)!
	assert controls.mute_icon == .low
	controls.toggle_mute()
	assert controls.mute_icon == .empty
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
