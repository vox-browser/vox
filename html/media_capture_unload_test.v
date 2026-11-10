// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module html

import dom
import mediacapture

// Ladybird 634a0d962256a560a4cef3bd0b71de8bdb26d166.
fn test_unloading_a_window_ends_retained_capture_tracks() {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/'})
	defer { document.finalize() }
	mut window := WindowModel.create_top_level(document, none, 'capture')!
	document.visibility_state = .visible
	mut navigable := window.navigable_model()
	navigable.set_focused(true)
	mut devices := mediacapture.MediaDevices.create(document, &mediacapture.MediaCaptureEnvironment{
		test_mode: true
		microphone_permission: .granted
		audio_devices: [mediacapture.StoredDevice{
			dom_device_id: 'microphone'
			kind: .audioinput
			label: 'Test microphone'
			is_default: true
			sample_rate_hz: 48000
			channel_count: 1
		}]
	})
	window.navigator_.media_devices_ = devices
	requested := devices.get_user_media(mediacapture.MediaStreamConstraints{audio: .enabled})
	devices.run_until_idle()
	assert requested.state() == .fulfilled
	stream := requested.stream() or { panic('capture stream missing') }
	track := stream.get_audio_tracks()[0]
	assert track.track_ready_state() == .live
	assert stream.active()
	document.run_unloading_cleanup_steps()
	assert track.track_ready_state() == .ended
	assert !stream.active()
	assert track.clone().track_ready_state() == .ended
	document.run_unloading_cleanup_steps()
	assert track.track_ready_state() == .ended
}

fn test_unloading_does_not_create_media_devices() {
	mut document := dom.Document.create(dom.URL{value: 'https://example.test/'})
	defer { document.finalize() }
	window := WindowModel.create_top_level(document, none, 'no-capture')!
	assert window.navigator_.media_devices_ == none
	document.run_unloading_cleanup_steps()
	assert window.navigator_.media_devices_ == none
}
