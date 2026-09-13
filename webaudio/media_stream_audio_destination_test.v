module webaudio

import mediacapture

fn test_media_stream_audio_destination_exposes_configured_audio_track() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	destination := context.create_media_stream_destination() or { panic(err) }
	assert destination.number_of_inputs() == 1
	assert destination.number_of_outputs() == 0
	assert destination.node.channel_count == 2
	assert destination.node.channel_count_mode == .explicit
	tracks := destination.stream().get_audio_tracks()
	assert tracks.len == 1
	assert tracks[0].label() == 'MediaStreamAudioDestinationNode'
	assert tracks[0].device_id() == none
	assert tracks[0].sample_rate_hz() == 48_000
	assert tracks[0].channel_count() == 2
}

fn test_media_stream_audio_destination_delivers_render_quanta() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut destination := context.create_media_stream_destination() or { panic(err) }
	track := destination.stream().get_audio_tracks()[0]
	mut mutable_track := unsafe { &mediacapture.MediaStreamTrack(track) }
	sink := mediacapture.AudioFrameSink.create(none)
	mutable_track.add_audio_sink(sink)
	left := []f32{len: int(render_quantum_size), init: 1}
	right := []f32{len: int(render_quantum_size), init: 3}
	destination.render([left, right])
	assert sink.frames.len == 1
	assert sink.frames[0].frame_count == int(render_quantum_size)
	assert sink.frames[0].channel_count == 2
	assert sink.frames[0].sample_rate == 48_000
	assert sink.frames[0].samples[..4] == [f32(1), 3, 1, 3]
}

fn test_media_stream_destination_to_source_loopback() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut destination := context.create_media_stream_destination() or { panic(err) }
	mut source := context.create_media_stream_source(destination.stream()) or { panic(err) }
	left := []f32{len: int(render_quantum_size), init: 0.25}
	right := []f32{len: int(render_quantum_size), init: 0.75}
	destination.render([left, right])
	output := source.render(int(render_quantum_size))
	assert output[0] == left
	assert output[1] == right
}

fn test_media_stream_audio_destination_downmixes_to_mono_and_finalizes() {
	mut context := new_audio_context(1, 48_000, true) or { panic(err) }
	mut destination := MediaStreamAudioDestinationNode.create(mut context, AudioNodeOptions{
		channel_count: 1
	}) or { panic(err) }
	track := destination.stream().get_audio_tracks()[0]
	mut mutable_track := unsafe { &mediacapture.MediaStreamTrack(track) }
	sink := mediacapture.AudioFrameSink.create(none)
	mutable_track.add_audio_sink(sink)
	left := []f32{len: int(render_quantum_size), init: 1}
	right := []f32{len: int(render_quantum_size), init: 3}
	destination.render([left, right])
	assert sink.frames[0].samples[0] == 2
	assert track.channel_count() == 1
	destination.finalize()
	destination.render([left, right])
	assert sink.frames.len == 1
}
