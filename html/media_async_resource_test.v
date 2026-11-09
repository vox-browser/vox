module html

import dom

@[heap]
struct AsyncMediaResourceProbe {
mut:
	resets int
}

fn test_native_stream_metadata_waits_for_decoder_completion_and_resets_on_source_change() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://media.example/' })
	probe := &AsyncMediaResourceProbe{}
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		reset:         fn [probe] () {
			mut state := unsafe { &AsyncMediaResourceProbe(probe) }
			state.resets++
		}
		can_play_type: fn (type_ string) CanPlayTypeResult {
			return if type_ == 'application/vnd.apple.mpegurl' { .maybe } else { .empty }
		}
	})
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{ mime_type: 'application/vnd.apple.mpegurl', metadata_pending: true }
	})
	assert media.can_play_type('application/vnd.apple.mpegurl') == .maybe
	assert media.can_play_type('video/webm') == .empty
	media.set_source('first.m3u8')
	media.load()!
	assert media.network_state() == .loading
	assert media.ready_state() == .have_nothing
	assert media.audio_tracks().length() == 0 && media.video_tracks().length() == 0
	assert media.event_count('loadedmetadata') == 0 && media.event_count('suspend') == 0
	media.complete_pending_media_resource(MediaResourceResponse{
		mime_type:    'application/vnd.apple.mpegurl'
		duration:     12
		buffered_end: 5
		audio_tracks: [MediaTrackMetadata{ identifier: 1 }]
		video_tracks: [MediaTrackMetadata{ identifier: 2, pixel_width: 160, pixel_height: 90 }]
	})
	assert media.duration() == 12
	assert media.ready_state() == .have_enough_data && media.network_state() == .idle
	assert media.audio_tracks().length() == 1 && media.video_tracks().length() == 1
	// A duplicate completion must not reset the clock or publish tracks twice.
	media.complete_pending_media_resource(MediaResourceResponse{ duration: 99 })
	assert media.duration() == 12 && media.video_tracks().length() == 1
	resets_before := probe.resets
	media.set_source('second.m3u8')
	media.load()!
	assert probe.resets > resets_before
	assert media.ready_state() == .have_nothing && media.network_state() == .loading
	assert media.video_tracks().length() == 0
	before_finalize := probe.resets
	media.finalize()
	assert probe.resets == before_finalize + 1
}

fn test_media_owner_created_after_parsing_its_source_runs_the_initial_load_algorithm() {
	url := dom.URL{value:'https://media-initial.test/'}
	mut document := parse_navigation_document('<!doctype html><audio id="audio" src="audio.wav"></audio>',url,url.origin(),none)!
	defer { document.finalize() }
	element := document.get_element_by_id('audio') or { panic('audio') }
	mut media := html_media_element_for_dom_element(element) or { panic('media') }
	media.set_fetch_hook(fn (_ dom.URL, _ u64) !MediaResourceResponse {
		return MediaResourceResponse{mime_type:'audio/wav',metadata_pending:true}
	})
	media.queue_resource_selection_if_connected_and_empty()
	for _ in 0..8 { main_thread_event_loop().process() }
	assert media.network_state() == .loading
	media.complete_pending_media_resource(MediaResourceResponse{mime_type:'audio/wav',duration:5,buffered_end:5,audio_tracks:[MediaTrackMetadata{identifier:1}]})
	for _ in 0..8 { main_thread_event_loop().process() }
	assert media.ready_state() == .have_enough_data
	assert media.event_count('loadeddata') == 1
}
