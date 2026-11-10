module mediacapture

import dom

fn capture_test_devices() []StoredDevice {
	return [
		StoredDevice{
			dom_device_id: 'mic-2'
			kind: .audioinput
			label: 'External microphone'
			group_id: 'external'
			sample_rate_hz: 44_100
			channel_count: 1
		},
		StoredDevice{
			dom_device_id: 'mic-default'
			kind: .audioinput
			label: 'Built-in microphone'
			group_id: 'builtin'
			is_default: true
			sample_rate_hz: 48_000
			channel_count: 2
		},
		StoredDevice{
			dom_device_id: 'speaker-default'
			kind: .audiooutput
			label: 'Built-in output'
			group_id: 'builtin'
			is_default: true
		},
	]
}

@[heap]
struct CaptureTestFocus {
mut:
	focused bool = true
}

// A fully active top-level document whose system focus the test controls.
fn capture_test_document(focus &CaptureTestFocus) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{})
	mut navigable := &dom.Navigable{
		is_top_level_traversable_: true
		html_model_handle_: voidptr(focus)
		is_focused_callback_: fn (handle voidptr) bool {
			return unsafe { &CaptureTestFocus(handle) }.focused
		}
	}
	navigable.traversable_navigable_ = navigable
	navigable.set_active_document(document)
	document.set_cached_navigable(navigable)
	// NB: A document starts hidden; the page showing it makes it visible.
	document.visibility_state = .visible
	return document
}

fn capture_test_environment() &MediaCaptureEnvironment {
	return &MediaCaptureEnvironment{
		test_mode: true
		audio_devices: capture_test_devices()
	}
}

fn test_stop_all_sources_ends_tracks_and_invalidates_pending_capture_start() {
	mut devices := MediaDevices.create(capture_test_document(&CaptureTestFocus{}), capture_test_environment())
	first := devices.get_user_media(MediaStreamConstraints{audio: .enabled})
	second := devices.get_user_media(MediaStreamConstraints{audio: .enabled})
	devices.run_until_idle()
	assert first.state() == .fulfilled && second.state() == .fulfilled
	first_stream := first.stream()?
	second_stream := second.stream()?
	mut first_track := first_stream.get_audio_tracks()[0]
	mut second_track := second_stream.get_audio_tracks()[0]
	assert devices.media_stream_track_sources.len == 2
	first_track.stop()
	assert devices.media_stream_track_sources.len == 1
	second_track.ensure_audio_capture_started()
	request_id := second_track.capture_request_id()
	devices.stop_all_sources()
	assert devices.media_stream_track_sources.len == 0
	assert first_track.track_ready_state() == .ended
	assert second_track.track_ready_state() == .ended
	assert !first_stream.active() && !second_stream.active()
	second_track.complete_audio_capture_start(request_id, true)
	assert !second_track.capture_start_pending()
	assert !second_track.capture_stream_active()
	devices.stop_all_sources()
}

fn test_device_info_json_and_supported_constraints() {
	device := MediaDeviceInfo.create('mic', .audioinput, 'Microphone', 'group')
	json := device.to_json()
	assert json.device_id == 'mic'
	assert json.kind == 'audioinput'
	assert json.label == 'Microphone'
	assert json.group_id == 'group'
	environment := capture_test_environment()
	devices := MediaDevices.create(capture_test_document(&CaptureTestFocus{}), environment)
	supported := devices.get_supported_constraints()
	assert supported.width && supported.device_id && supported.background_blur
}

fn test_enumeration_redacts_and_limits_microphones_until_exposed() {
	environment := capture_test_environment()
	mut devices := MediaDevices.create(capture_test_document(&CaptureTestFocus{}), environment)
	promise := devices.enumerate_devices()
	devices.run_until_idle()
	assert promise.state() == .fulfilled
	result := promise.devices()
	assert result.len == 1
	assert result[0].kind() == .audioinput
	assert result[0].device_id() == ''
	assert result[0].label() == ''
	devices.set_device_information_exposure(true, false, true)
	second := devices.enumerate_devices()
	devices.run_until_idle()
	exposed := second.devices()
	assert exposed.len == 3
	assert exposed[0].device_id() == 'mic-default'
	assert exposed[1].device_id() == 'mic-2'
	assert exposed[2].kind() == .audiooutput
}

fn test_enumeration_and_user_media_wait_for_view_focus_and_cache() {
	mut environment := capture_test_environment()
	mut focus := &CaptureTestFocus{
		focused: false
	}
	mut document := capture_test_document(focus)
	document.visibility_state = .hidden
	environment.audio_device_cache_ready = false
	mut devices := MediaDevices.create(document, environment)
	enumeration := devices.enumerate_devices()
	media := devices.get_user_media(MediaStreamConstraints{ audio: .enabled })
	devices.run_until_idle()
	assert enumeration.state() == .pending
	assert media.state() == .pending
	document.visibility_state = .visible
	focus.focused = true
	environment.audio_device_cache_ready = true
	devices.did_observe_audio_device_cache_update()
	devices.run_until_idle()
	assert enumeration.state() == .fulfilled
	assert media.state() == .fulfilled
}

fn test_get_user_media_validates_and_selects_requested_device() {
	environment := capture_test_environment()
	mut devices := MediaDevices.create(capture_test_document(&CaptureTestFocus{}), environment)
	missing := devices.get_user_media(none)
	assert missing.state() == .rejected
	assert missing.reason().starts_with('TypeError:')
	empty := devices.get_user_media(MediaStreamConstraints{})
	assert empty.state() == .rejected
	video := devices.get_user_media(MediaStreamConstraints{ video: .enabled })
	assert video.state() == .rejected
	assert video.reason().starts_with('NotSupportedError:')
	selected := devices.get_user_media(MediaStreamConstraints{
		audio: .constrained
		audio_constraints: MediaTrackConstraints{
			MediaTrackConstraintSet: MediaTrackConstraintSet{
				device_id: ConstrainDOMString.exact(['mic-2'])
			}
		}
	})
	devices.run_until_idle()
	assert selected.state() == .fulfilled
	stream := selected.stream() or { panic('missing stream') }
	tracks := stream.get_audio_tracks()
	assert tracks.len == 1
	assert tracks[0].device_id()? == 'mic-2'
	assert tracks[0].sample_rate_hz() == 44_100
	assert tracks[0].channel_count() == 1
	assert devices.microphone_information_can_be_exposed()
}

fn test_stream_track_sets_events_clone_and_active_state() {
	audio := MediaStreamTrack.create(.audio, 'microphone', false)
	video := MediaStreamTrack.create(.video, 'camera', false)
	mut stream := MediaStream.create([audio, audio, video])
	assert stream.get_tracks().len == 2
	assert stream.get_audio_tracks() == [audio]
	assert stream.get_video_tracks() == [video]
	assert stream.get_track_by_id(video.id())? == video
	assert stream.active()
	clone := stream.clone()
	assert clone.id() != stream.id()
	assert clone.get_tracks().len == 2
	assert clone.get_tracks()[0].id() != stream.get_tracks()[0].id()
	mut mutable_audio := unsafe { &MediaStreamTrack(audio) }
	mutable_audio.stop()
	mut mutable_video := unsafe { &MediaStreamTrack(video) }
	mutable_video.end()
	assert !stream.active()
	stream.remove_track(audio)
	assert stream.get_tracks() == [video]
}

fn test_audio_fanout_chunks_frames_and_delivers_silence_when_disabled() {
	mut track := MediaStreamTrack.create(.audio, none, false)
	mut sink := AudioFrameSink.create(none)
	track.add_audio_sink(sink)
	mut samples := []f32{len: 2050, init: f32(index + 1)}
	track.deliver_audio_frames(samples, 1025, 2, 48_000)
	assert sink.frames.len == 2
	assert sink.frames[0].frame_count == 1024
	assert sink.frames[1].frame_count == 1
	assert sink.frames[1].samples == samples[2048..2050]
	track.set_enabled(false)
	track.deliver_audio_frames(samples[..4], 2, 2, 48_000)
	assert sink.frames.last().samples == [f32(0), 0, 0, 0]
	track.remove_audio_sink(sink)
	assert !sink.active
}

fn test_device_backed_track_capture_start_ignores_stale_completion() {
	mut track := MediaStreamTrack.create(.audio, 'microphone', false)
	track.set_settings(MediaTrackSettings{ device_id: 'mic-default' })
	sink := AudioFrameSink.create(none)
	track.add_audio_sink(sink)
	assert track.capture_start_pending()
	request_id := track.capture_request_id()
	track.stop()
	track.complete_audio_capture_start(request_id, true)
	assert !track.capture_stream_active()
	assert track.track_ready_state() == .ended
}

fn test_device_change_notification_only_fires_for_exposed_changes() {
	environment := capture_test_environment()
	mut devices := MediaDevices.create(capture_test_document(&CaptureTestFocus{}), environment)
	devices.stored_device_list = capture_test_devices()
	devices.set_device_information_exposure(true, false, true)
	devices.run_until_idle()
	baseline_events := devices.device_change_event_count
	devices.run_device_change_notification_steps(capture_test_devices())
	devices.run_until_idle()
	assert devices.device_change_event_count == baseline_events
	mut changed := capture_test_devices()
	changed[0] = StoredDevice{
		...changed[0]
		label: 'Renamed microphone'
	}
	devices.run_device_change_notification_steps(changed)
	devices.run_until_idle()
	assert devices.device_change_event_count == baseline_events + 1
}

fn test_track_event_retains_its_track() {
	track := MediaStreamTrack.create(.audio, none, false)
	event := MediaStreamTrackEvent.create('addtrack', MediaStreamTrackEventInit{
		EventInit: dom.EventInit{}
		track: track
	}, 12.5)
	assert event.track() == track
	assert event.Event.type_name() == 'addtrack'
}

fn test_pending_enumeration_proceeds_when_the_document_becomes_visible() {
	environment := capture_test_environment()
	mut document := capture_test_document(&CaptureTestFocus{})
	document.visibility_state = .hidden
	mut devices := MediaDevices.create(document, environment)
	enumeration := devices.enumerate_devices()
	devices.run_until_idle()
	assert enumeration.state() == .pending

	document.update_the_visibility_state(.visible)
	devices.run_until_idle()
	assert enumeration.state() == .fulfilled
}
