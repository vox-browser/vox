@[has_globals]
module html

import dom
import math

__global media_test_seek_modes = []MediaPlaybackSeekMode{}

fn media_test_seek(_ f64, mode MediaPlaybackSeekMode) {
	media_test_seek_modes << mode
}

fn media_test_fetch(url dom.URL, offset u64) !MediaResourceResponse {
	assert offset == 0
	if url.serialize().ends_with('bad.mp4') {
		return error('network failed')
	}
	return MediaResourceResponse{
		mime_type: 'video/mp4; codecs="avc1"'
		duration: 10
		total_length: 1000
		buffered_end: 10
		audio_tracks: [MediaTrackMetadata{ identifier: 1, name: 'Audio' }]
		video_tracks: [MediaTrackMetadata{ identifier: 2, name: 'Video' }]
	}
}

fn media_range_test_fetch(_ dom.URL, offset u64) !MediaResourceResponse {
	return MediaResourceResponse{
		mime_type:           'video/mp4'
		duration:            20
		total_length:        2048
		buffered_end:        if offset == 0 { 5 } else { 20 }
		accepts_byte_ranges: true
	}
}

fn media_test_buffered_ranges() []MediaBufferedRange {
	return [MediaBufferedRange{ start: 1, end: 7 }, MediaBufferedRange{ start: 9, end: 12 }]
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

fn test_media_element_fast_seek_at_current_position_is_accurate() {
	media_test_seek_modes.clear()
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_fetch_hook(media_test_fetch)
	media.set_source('/movie.mp4')
	media.load()!
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		seek: media_test_seek
	})
	media.set_current_playback_position(5)

	media.fast_seek(5)
	media.fast_seek(4)
	media.fast_seek(6)

	assert media_test_seek_modes == [.accurate, .fast_before, .fast_after]
}

fn test_media_element_volume_rate_text_track_and_failures() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_volume(0.25)!
	assert media.effective_media_volume() == 0.25
	media.set_muted(true)
	assert media.effective_media_volume() == 0
	media.set_playback_rate(-2) or { assert err.msg().starts_with('NotSupportedError:') }
	assert media.playback_rate() == 1
	media.set_volume(2) or { assert err.msg().starts_with('IndexSizeError:') }
	media.set_playback_rate(math.inf(1)) or { assert err.msg().starts_with('NotSupportedError:') }
	track := media.add_text_track(.captions, 'English', 'en')
	assert track.mode() == .hidden
	assert media.text_tracks().length() == 1
	media.create_controls()
	assert media.has_controls()
	media.destroy_controls()
	assert !media.has_controls()

	media.set_fetch_hook(media_test_fetch)
	media.set_source('/movie.mp4')
	media.load()!
	media.set_decoder_error('broken stream')
	assert media.error()?.code == .decode
	assert media.ready_state() == .have_enough_data
}

fn test_media_element_literal_state_machine_boundaries() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_fetch_hook(media_test_fetch)
	media.set_source('/movie.mp4')
	media.load()!
	assert media.audio_tracks().item(0)?.enabled
	assert media.video_tracks().selected_index() == 0
	assert media.direction_of_playback() == .forwards
	assert !media.has_ended_playback()
	media.set_current_playback_position(10)
	assert media.has_ended_playback()
	assert media.ended()
	media.process_media_data(.interrupted)
	assert media.error()?.code == .network
	assert media.network_state() == .idle
}

fn test_media_element_ready_state_follows_buffered_data() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_up_playback_manager()
	media.set_duration(20)
	media.set_ready_state(.have_metadata)
	media.buffered_.add_range(0, 2)
	media.playback_has_future_data_ = true
	media.update_ready_state()
	assert media.ready_state() == .have_future_data

	media.buffered_.clear()
	media.buffered_.add_range(0, 8)
	media.update_ready_state()
	assert media.ready_state() == .have_enough_data

	media.set_current_playback_position(8)
	media.playback_has_future_data_ = false
	media.update_ready_state()
	assert media.ready_state() == .have_current_data

	media.buffered_.clear()
	media.update_ready_state()
	assert media.ready_state() == .have_metadata
}

fn test_media_element_throttles_ready_state_monitoring_with_time_updates() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_up_playback_manager()
	media.set_duration(20)
	media.set_ready_state(.have_metadata)
	media.buffered_.add_range(0, 1)
	media.playback_has_future_data_ = true
	media.time_marches_on(.normal_playback)
	assert media.ready_state() == .have_future_data
	assert media.event_count('timeupdate') == 1

	media.buffered_.clear()
	media.playback_has_future_data_ = false
	media.time_marches_on(.normal_playback)
	assert media.ready_state() == .have_future_data
	assert media.event_count('timeupdate') == 1

	media.set_current_playback_position(0.02)
	media.time_marches_on(.normal_playback)
	assert media.ready_state() == .have_metadata
	assert media.event_count('timeupdate') == 2
}

fn test_media_element_exposes_playback_manager_buffered_ranges() {
	mut media := HTMLMediaElement.create(none, dom.URL{ value: 'https://example.test/' })
	media.set_playback_manager_hooks(MediaPlaybackManagerHooks{
		buffered_ranges: media_test_buffered_ranges
	})
	ranges := media.buffered()
	assert ranges.length() == 2
	assert ranges.start(0)! == 1
	assert ranges.end(0)! == 7
	assert ranges.start(1)! == 9
	assert ranges.end(1)! == 12

	media.set_duration(20)
	media.set_ready_state(.have_metadata)
	media.playback_has_future_data_ = true
	media.update_ready_state()
	assert media.ready_state() == .have_enough_data
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

fn test_media_element_concrete_removal_fullscreen_children_and_fetch_overloads() {
	mut document := dom.Document.create(dom.URL{ value: 'https://example.test/' })
	mut navigable := &dom.Navigable{
		active_document_:          document
		is_top_level_traversable_: true
	}
	navigable.traversable_navigable_ = navigable
	document.set_cached_navigable(navigable)
	mut video_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video') or {
		panic(err)
	}
	mut source_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'source') or {
		panic(err)
	}
	source_element.set_attribute_value('src', '/movie.mp4')
	mut video_node := unsafe { &dom.Node(video_element) }
	video_node.append_child(source_element.as_node()) or { panic(err) }
	mut document_node := unsafe { &dom.Node(document) }
	document_node.append_child(video_element.as_node()) or { panic(err) }
	mut media := html_media_element_for_dom_element(video_element) or { panic('missing media state') }
	media.set_fetch_hook(media_range_test_fetch)
	media.network_state_ = .no_source
	media.children_changed(dom.ChildrenChangedMetadata{
		type_: .inserted
		node:  source_element.as_node()
	})
	assert media.current_src() == 'https://example.test/movie.mp4'
	assert media.ready_state() == .have_enough_data

	media.fetch_resource(dom.URL{ value: 'https://example.test/direct.mp4' }, none)!
	assert media.current_src() == 'https://example.test/direct.mp4'
	media.fetch_resource_byte_range(MediaByteRange{ offset: 128 })!
	assert media.last_fetch_offset() == 128

	mut concrete_video := unsafe { &dom.Element(video_element) }
	document.fullscreen_element_within_doc(mut concrete_video)
	assert document.fullscreen_element() or { panic('missing fullscreen video') } == concrete_video
	media.toggle_fullscreen()
	assert document.fullscreen_element() == none

	_ = media.play()
	assert !media.paused()
	document_node.remove_child(video_element.as_node())!
	media.removed_from(document_node, document_node)
	assert media.paused()
}
