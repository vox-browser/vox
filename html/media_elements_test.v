module html

import dom
import math

__global media_controls_scrub_seek_times = []f64{}

fn media_controls_scrub_seek(time f64, _ MediaPlaybackSeekMode) {
	media_controls_scrub_seek_times << time
}

fn run_media_elements_test_tasks(media &HTMLMediaElement) {
	mut queue := main_thread_event_loop().task_queue()
	for media.queued_media_task_ids_.len > 0 {
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing queued media task') }
		task.execute()
	}
}

fn media_elements_fetch(url dom.URL, _ u64) !MediaResourceResponse {
	_ = url
	return MediaResourceResponse{
		mime_type: 'video/mp4'
		duration: 120
		buffered_end: 120
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
	assert media.event_count('resize') == 0
	run_media_elements_test_tasks(media)
	// load() cancels the resize task from before resource selection.
	assert media.event_count('resize') == 1
	mut controls := MediaControls.create(media)
	controls.toggle_playback()
	assert controls.play_icon_is_pause
	controls.set_current_time(30)
	assert controls.timeline_percentage == 25
	assert controls.timestamp == '00:30 / 02:00'
	controls.set_volume(0.25)!
	assert controls.mute_icon == .low
	controls.toggle_mute()
	assert controls.mute_icon == .low
	assert controls.was_muted
	assert controls.shadow_tree_created
	assert controls.registered_event_listeners_.len == 13
	controls.remove_event_listeners()
	assert controls.registered_event_listeners_.len == 0
}

fn test_media_controls_toggle_fullscreen_for_the_f_key() {
	media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	controls := MediaControls.create(media)
	event := dom.KeyboardEvent.create('keydown', dom.KeyboardEventInit{
		key_code: u32(dom.KeyCode.f)
	})
	media.event_target().dispatch_event(unsafe { &dom.Event(event) })
	assert controls.fullscreen
}

fn test_media_controls_coalesce_scrub_seeks_and_preempt_a_stalled_seek() {
	media_controls_scrub_seek_times.clear()
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_duration(100)
	media.set_ready_state(.have_enough_data)
	media.seekable_.add_range(0, 100)
	media.playback_hooks_ = MediaPlaybackManagerHooks{
		seek: media_controls_scrub_seek
	}
	mut controls := MediaControls.create(media)

	controls.begin_timeline_scrubbing(10)
	assert media_controls_scrub_seek_times == [10.0]
	controls.seek_while_scrubbing(20)
	controls.seek_while_scrubbing(30)
	assert media_controls_scrub_seek_times == [10.0]

	media.finish_seeking_element()
	assert media_controls_scrub_seek_times == [10.0]
	run_media_elements_test_tasks(media)
	assert media_controls_scrub_seek_times == [10.0, 30.0]
	controls.seek_while_scrubbing(40)
	assert media_controls_scrub_seek_times == [10.0, 30.0]
	mut timer := controls.scrub_seek_preemption_timer_ or { panic('missing preemption timer') }
	timer.fire()
	assert media_controls_scrub_seek_times == [10.0, 30.0, 40.0]

	controls.end_timeline_scrubbing(50)
	assert media_controls_scrub_seek_times == [10.0, 30.0, 40.0, 50.0]
	assert controls.scrubbing_timeline == .no
	assert controls.scrub_seek_preemption_timer_ == none
}

fn test_media_controls_follow_audio_additions_and_queued_emptied_after_resource_reset() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	mut controls := MediaControls.create(media)
	assert !controls.had_audio

	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{
			mime_type: 'audio/mpeg'
			duration: 120
			buffered_end: 120
			audio_tracks: [MediaTrackMetadata{identifier: 42, name: 'main'}]
		}
	})
	media.set_source('/audio.mp3')
	media.load()!
	assert controls.had_audio
	assert controls.volume_percentage == 100
	run_media_elements_test_tasks(media)

	media.set_source(none)
	media.load()!
	assert media.audio_tracks().length() == 0
	assert controls.had_audio && controls.volume_percentage == 100
	assert media.event_count('emptied') == 0
	run_media_elements_test_tasks(media)
	assert media.event_count('emptied') == 1
	assert !controls.had_audio
	assert controls.volume_percentage == 0
}

fn test_media_controls_timeline_uses_the_last_seekable_range() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_ready_state(.have_enough_data)
	media.seekable_.add_range(0, 5)
	media.seekable_.add_range(10, 50)
	media.set_current_playback_position(20)
	media.set_duration(math.inf(1))
	mut loop := main_thread_event_loop()
	loop.process()

	mut controls := MediaControls.create(media)
	controls.update_timeline()
	controls.update_timestamp()
	assert controls.timeline_percentage == 25
	assert controls.timestamp == '00:20'

	media.seekable_.clear()
	controls.update_timeline()
	assert controls.timeline_percentage == 0
}

fn test_concrete_video_poster_attribute_change_uses_video_state() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut video_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video') or {
		panic(err)
	}
	video := unsafe { &dom.HTMLVideoElement(video_element) }
	mut model := html_video_element_model_for_dom_element(video)
	controls := MediaControls.create(model.media)
	assert (controls.dom_.fullscreen_icon or { panic('missing fullscreen control') }).local_name() == 'button'
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
