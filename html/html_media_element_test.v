module html

import dom
import math

fn media_test_fetch(url dom.URL, offset u64) !MediaResourceResponse {
	assert offset == 0
	if url.serialize().ends_with('bad.mp4') {
		return error('network failed')
	}
	return MediaResourceResponse{
		mime_type:    'video/mp4; codecs="avc1"'
		duration:     10
		total_length: 1000
		buffered_end: 10
		audio_tracks: [MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
		video_tracks: [MediaTrackMetadata{ identifier: 2, name: 'Video' }]
	}
}

fn test_media_element_resource_selection_metadata_and_tracks() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/page' })
	media.set_fetch_hook(media_test_fetch)
	media.set_source_candidates(['/bad.mp4', '/movie.mp4'])
	media.load()!
	assert media.current_src() == 'https://example.test/movie.mp4'
	assert media.network_state() == .idle
	assert media.ready_state() == .have_enough_data
	assert media.duration() == 10
	assert media.buffered().start(0)! == 0
	assert media.buffered().end(0)! == 10
	assert media.seekable().end(0)! == 10
	assert media.audio_tracks().length() == 1
	assert media.video_tracks().length() == 1
	assert media.event_count('loadedmetadata') == 1
	assert media.can_play_type('video/mp4') == .maybe
	assert media.can_play_type('video/mp4; codecs="avc1"') == .probably
	assert media.can_play_type('application/json') == .empty
}

fn test_media_element_play_pause_seek_end_and_loop() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_fetch_hook(media_test_fetch)
	media.set_source('/movie.mp4')
	media.load()!
	promise := media.play()
	assert promise.state() == .fulfilled
	assert !media.paused()
	assert media.potentially_playing()
	media.advance_playback(3)
	assert media.current_time() == 3
	media.pause()
	assert media.paused()
	assert media.played().end(0)! == 3
	media.fast_seek(9)
	assert media.current_time() == 9
	_ = media.play()
	media.advance_playback(2)
	assert media.ended()
	assert media.event_count('ended') == 1

	media.set_loop(true)
	media.set_current_time(9)
	_ = media.play()
	media.advance_playback(2)
	assert !media.ended()
	assert media.current_time() == 0
}

fn test_media_element_volume_rate_text_track_and_failures() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_volume(0.25)!
	assert media.effective_media_volume() == 0.25
	media.set_muted(true)
	assert media.effective_media_volume() == 0
	media.set_playback_rate(-2)!
	assert media.playback_rate() == -2
	media.set_volume(2) or { assert err.msg().starts_with('IndexSizeError:') }
	media.set_playback_rate(math.inf(1)) or { assert err.msg().starts_with('NotSupportedError:') }
	track := media.add_text_track(.captions, 'English', 'en')
	assert track.mode() == .hidden
	assert media.text_tracks().length() == 1
	media.create_controls()
	assert media.has_controls()
	media.destroy_controls()
	assert !media.has_controls()

	media.set_decoder_error('broken stream')
	assert media.error()?.code == .decode
	assert media.ready_state() == .have_nothing
}

fn test_media_element_no_source_and_unsupported_source() {
	mut empty := HTMLMediaElement.create(none, dom.url_about_blank())
	empty.load()!
	assert empty.network_state() == .empty
	assert math.is_nan(empty.duration())

	mut unsupported := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	unsupported.set_source('/movie.mp4')
	unsupported.load() or { assert err.msg().starts_with('NotSupportedError:') }
	assert unsupported.network_state() == .no_source
	assert unsupported.error()?.code == .src_not_supported
	assert unsupported.play().state() == .rejected
}
