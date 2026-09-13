module webaudio

import mediacapture

fn media_stream_audio_track(label string, channels u32) &mediacapture.MediaStreamTrack {
	mut track := mediacapture.MediaStreamTrack.create(.audio, label, false)
	track.set_settings(mediacapture.MediaTrackSettings{
		sample_rate: 48_000
		channel_count: channels
	})
	return track
}

fn test_media_stream_audio_source_requires_an_audio_track() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	video := mediacapture.MediaStreamTrack.create(.video, 'camera', false)
	stream := mediacapture.MediaStream.create([video])
	context.create_media_stream_source(stream) or {
		assert err.msg().contains('MediaStream has no audio tracks')
		return
	}
	assert false
}

fn test_media_stream_audio_source_selects_lowest_track_id_and_renders_frames() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	first_created := media_stream_audio_track('first', 1)
	second_created := media_stream_audio_track('second', 1)
	selected := if first_created.id() < second_created.id() {
		first_created
	} else {
		second_created
	}
	ignored := if first_created.id() < second_created.id() { second_created } else { first_created }
	stream := mediacapture.MediaStream.create([ignored, selected])
	mut source := context.create_media_stream_source(stream) or { panic(err) }
	assert source.number_of_inputs() == 0
	assert source.number_of_outputs() == 1
	assert source.media_stream() == stream

	mut selected_track := unsafe { &mediacapture.MediaStreamTrack(selected) }
	selected_track.deliver_audio_frames([f32(1), 2, 3], 3, 1, 48_000)
	output := source.render(4)
	assert output.len == 1
	assert output[0] == [f32(1), 2, 3, 0]

	mut ignored_track := unsafe { &mediacapture.MediaStreamTrack(ignored) }
	ignored_track.deliver_audio_frames([f32(9)], 1, 1, 48_000)
	assert source.render(1)[0][0] == 0
}

fn test_media_stream_audio_source_converts_rate_and_channels_and_detaches() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	track := media_stream_audio_track('stereo', 2)
	stream := mediacapture.MediaStream.create([track])
	mut source := context.create_media_stream_source(stream) or { panic(err) }
	mut input := unsafe { &mediacapture.MediaStreamTrack(track) }
	input.deliver_audio_frames([f32(1), 10, 3, 30], 2, 2, 24_000)
	output := source.render(4)
	assert output[0] == [f32(1), 2, 3, 3]
	assert output[1] == [f32(10), 20, 30, 30]

	source.finalize()
	input.deliver_audio_frames([f32(8), 80], 1, 2, 48_000)
	assert source.render(1)[0][0] == 0
}

fn test_media_stream_source_ring_drops_complete_overflow_blocks() {
	mut ring := new_media_stream_audio_ring(3, 1)
	assert push_frames_if_enough_room(mut ring, [f32(1), 2]) == 2
	assert push_frames_if_enough_room(mut ring, [f32(3), 4]) == 0
	assert ring.pop_frames(3) == [f32(1), 2]
}
