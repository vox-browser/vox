module html

import dom

@[heap]
struct MetadataManagerStartProbe {
mut:
	steps []string
	starts int
	plays int
	position f64
	start_position f64
	ready_during_start MediaReadyState
}

fn metadata_manager_start_owner(kind string) !&HTMLMediaElement {
	url := dom.URL{value: 'https://metadata-start.example/base/page.html'}
	document := parse_navigation_document('<${kind} id="media"></${kind}>', url, url.origin(), none)!
	return html_media_element_for_dom_element(document.get_element_by_id('media') or {
		return error('missing metadata start element')
	}) or { return error('missing metadata start owner') }
}

fn metadata_manager_start_drain(media &HTMLMediaElement) {
	for _ in 0 .. 50 {
		if media.queued_media_task_ids_.len == 0 { return }
		mut queue := main_thread_event_loop().task_queue()
		task := queue.take_first_runnable_matching(fn [media] (task &Task) bool {
			return task.id() in media.queued_media_task_ids_
		}) or { panic('missing metadata start task') }
		assert task.source() == media.media_element_event_task_source()
		assert voidptr(task.document() or { panic('missing task document') }) == voidptr(media.document() or { panic('missing media document') })
		task.execute()
	}
	assert media.queued_media_task_ids_.len == 0
}

fn test_metadata_starts_the_manager_after_track_selection_before_readiness_without_playing() {
	for kind in ['audio', 'video'] {
		mut media := metadata_manager_start_owner(kind)!
		defer { media.remove_queued_media_element_tasks(); media.finalize() }
		seen := &MetadataManagerStartProbe{}
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			set_audio_track: fn [seen] (_ &AudioTrack, enabled bool) {
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.steps << if enabled { 'enable-audio' } else { 'disable-audio' }
			}
			set_video_track: fn [seen] (track ?&VideoTrack) {
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.steps << if track != none { 'select-video' } else { 'clear-video' }
			}
			start: fn [media, seen] () {
				assert media.ready_state() == .have_metadata && media.duration() == 12
				assert media.default_playback_start_ == 0 && media.paused()
				first := media.audio_tracks().item(0) or { panic('missing first audio track') }
				second := media.audio_tracks().item(1) or { panic('missing second audio track') }
				assert first.enabled && !second.enabled
				assert media.video_tracks().selected_index() == 0
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.steps << 'start'
				probe.starts++
				mut owner := unsafe { &HTMLMediaElement(media) }
				owner.playback_has_future_data_ = true
			}
			play: fn [seen] () {
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.plays++
			}
			current_time: fn [seen] () f64 {
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.steps << 'clock'
				return 0
			}
			buffered_ranges: fn [seen] () []MediaBufferedRange {
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.steps << 'ranges'
				return [MediaBufferedRange{0, 12}]
			}
		})
		first_audio := media.on_audio_track_added(MediaTrackMetadata{identifier: 1})
		media.on_audio_track_added(MediaTrackMetadata{identifier: 2})
		first_video := media.on_video_track_added(MediaTrackMetadata{identifier: 3})
		media.on_video_track_added(MediaTrackMetadata{identifier: 4})
		mut audio := unsafe { &AudioTrack(first_audio) }
		mut video := unsafe { &VideoTrack(first_video) }
		audio.set_enabled(false)
		video.set_selected(false)
		metadata_manager_start_drain(media)
		mut probe := unsafe { &MetadataManagerStartProbe(seen) }
		probe.steps.clear()
		media.network_state_ = .loading
		media.on_metadata_parsed(12)
		expected := if kind == 'video' { ['clock', 'enable-audio', 'clock', 'select-video', 'start', 'clock', 'ranges', 'clock'] } else { ['enable-audio', 'select-video', 'start', 'clock', 'ranges'] }
		assert probe.steps == expected
		assert probe.starts == 1 && probe.plays == 0 && media.paused()
		assert media.ready_state() == .have_enough_data && media.event_count('loadedmetadata') == 0
		metadata_manager_start_drain(media)
		assert media.event_count('loadedmetadata') == 1 && media.event_count('canplaythrough') == 1
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
	}
}

fn test_resource_load_and_mse_initialization_use_the_metadata_start_boundary() {
	for kind in ['audio', 'video'] {
		mut media := metadata_manager_start_owner(kind)!
		defer { media.remove_queued_media_element_tasks(); media.finish_delaying_load_event(); media.finalize() }
		seen := &MetadataManagerStartProbe{}
		media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
			start: fn [media, seen] () {
				assert media.playback_manager_ready_ && media.ready_state() == .have_metadata
				assert media.paused() && media.duration() == 20
				mut probe := unsafe { &MetadataManagerStartProbe(seen) }
				probe.starts++
			}
		})
		media.set_up_playback_manager()
		assert seen.starts == 0
		media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
			return MediaResourceResponse{mime_type: 'video/mp4', duration: 20, buffered_end: 8}
		})
		media.set_source('/one.mp4')
		media.load()!
		assert seen.starts == 1 && media.ready_state() == .have_enough_data && media.network_state() == .idle
		metadata_manager_start_drain(media)
		media.load()!
		assert seen.starts == 2 && media.paused()
		metadata_manager_start_drain(media)
		media.forget_media_resource_specific_tracks()
		media.set_up_playback_manager()
		assert seen.starts == 2
		media.media_source_initialization_segment_received(20)
		assert seen.starts == 3
		assert media.event_count('play') == 0 && media.event_count('playing') == 0
	}
}

fn test_metadata_start_observes_the_seek_timeline_and_adopted_document_before_queued_events() {
	mut media := metadata_manager_start_owner('video')!
	defer { media.remove_queued_media_element_tasks(); media.finalize() }
	seen := &MetadataManagerStartProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		start_time_realtime: fn () ?i64 { return i64(1234567) }
		seek: fn [seen] (position f64, mode MediaPlaybackSeekMode) {
			assert mode == .accurate
			mut probe := unsafe { &MetadataManagerStartProbe(seen) }
			probe.position = position
			probe.steps << 'seek'
		}
		current_time: fn [seen] () f64 { return seen.position }
		start: fn [media, seen] () {
			assert media.ready_state() == .have_metadata && media.default_playback_start_ == 0
			assert (media.timeline_offset_microseconds_ or { panic('missing metadata timeline offset') }) == 1234567
			assert media.current_time() == 3 && media.official_playback_position_ == 3
			assert media.seeking() && media.event_count('loadedmetadata') == 0
			mut probe := unsafe { &MetadataManagerStartProbe(seen) }
			probe.steps << 'start'
			probe.start_position = media.current_time()
			probe.starts++
		}
	})
	media.seekable_.add_range(0, 10)
	media.set_current_time(3)
	url := dom.URL{value: 'https://metadata-start-adopted.example/new/page.html'}
	mut destination := parse_navigation_document('<body></body>', url, url.origin(), none)!
	defer { destination.finalize() }
	element := media.document()?.get_element_by_id('media') or { panic('missing adopted media') }
	destination.adopt_node(element.as_node())
	media.network_state_ = .loading
	media.on_metadata_parsed(10)
	assert seen.steps == ['seek', 'start'] && seen.starts == 1 && seen.start_position == 3
	assert media.event_count('loadedmetadata') == 0
	metadata_manager_start_drain(media)
	assert media.event_count('loadedmetadata') == 1 && media.event_count('seeking') == 1
}

fn test_metadata_start_skips_absent_managers_and_rechecks_readiness_after_backend_reentry() {
	mut media := metadata_manager_start_owner('audio')!
	defer { media.remove_queued_media_element_tasks(); media.finalize() }
	seen := &MetadataManagerStartProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		start: fn [media, seen] () {
			mut probe := unsafe { &MetadataManagerStartProbe(seen) }
			probe.starts++
			probe.ready_during_start = media.ready_state()
			mut owner := unsafe { &HTMLMediaElement(media) }
			owner.forget_media_resource_specific_tracks()
		}
		buffered_ranges: fn () []MediaBufferedRange { panic('readiness must stop after manager teardown') }
	})
	media.network_state_ = .loading
	media.on_metadata_parsed(10)
	assert seen.starts == 1 && seen.ready_during_start == .have_metadata
	assert !media.playback_manager_ready_ && media.ready_state() == .have_metadata
	media.on_metadata_parsed(11)
	assert seen.starts == 1 && media.duration() == 11
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		start: fn [media, seen] () {
			mut probe := unsafe { &MetadataManagerStartProbe(seen) }
			probe.starts++
			mut owner := unsafe { &HTMLMediaElement(media) }
			owner.on_playback_manager_state_change(false)
		}
		buffered_ranges: fn () []MediaBufferedRange { return [MediaBufferedRange{0, 15}] }
	})
	assert seen.starts == 1
	media.on_metadata_parsed(15)
	assert seen.starts == 2 && media.ready_state() == .have_enough_data
	metadata_manager_start_drain(media)
	assert media.event_count('canplaythrough') == 1 && media.event_count('play') == 0
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{})
	media.on_metadata_parsed(16)
	assert seen.starts == 2 && media.playback_manager_ready_ && media.duration() == 16
}
