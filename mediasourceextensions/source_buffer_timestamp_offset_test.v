module mediasourceextensions

import dom
import html

fn timestamp_offset_test_processor() (&SourceBufferProcessor, &TrackBuffer) {
	mut processor := SourceBufferProcessor.create()
	track_buffer := TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_:  .text
	})
	processor.track_buffers_[1] = track_buffer
	return processor, track_buffer
}

fn test_source_buffer_timestamp_offset_validates_state_and_updates_sequence_group_start() {
	mut unattached := SourceBuffer.create_internal()
	unattached.set_timestamp_offset(1) or {
		assert err.msg() == 'InvalidStateError: SourceBuffer has no MediaSource'
	}

	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	assert buffer.timestamp_offset() == 0
	buffer.set_timestamp_offset(5)!
	assert buffer.timestamp_offset() == 5
	source.run_end_of_stream_algorithm(none)
	assert source.ready_state() == .ended
	buffer.set_timestamp_offset(6)!
	assert source.ready_state() == .open

	buffer.set_mode(.sequence)!
	buffer.set_timestamp_offset(8)!
	assert buffer.processor_.group_start_timestamp_ or { -1 } == 8

	buffer.processor_.set_updating(true)
	buffer.set_timestamp_offset(9) or {
		assert err.msg() == 'InvalidStateError: SourceBuffer is updating'
	}
	assert buffer.timestamp_offset() == 8
	buffer.processor_.set_updating(false)
	buffer.processor_.append_state_ = .parsing_media_segment
	buffer.set_timestamp_offset(9) or {
		assert err.msg() == 'InvalidStateError: Cannot set timestampOffset while parsing a media segment'
	}
	assert buffer.timestamp_offset() == 8
}

fn test_coded_frame_processing_applies_timestamp_offset_before_buffering() {
	mut processor, track_buffer := timestamp_offset_test_processor()
	processor.set_timestamp_offset(5)
	processor.run_coded_frame_processing([
		DemuxedCodedFrame{
			track_number: 1
			timestamp:    2
			is_keyframe:  true
			data:         [u8(1)]
			duration:     1
		},
	])

	frames := track_buffer.demuxer.coded_frames()
	assert frames.len == 1
	assert frames[0].timestamp == 7
	assert processor.group_end_timestamp() == 8
	assert track_buffer.last_decode_timestamp_ or { -1 } == 7
}
