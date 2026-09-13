module mediasourceextensions

fn processing_test_frame(timestamp f64, keyframe bool) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 1
		is_keyframe:  keyframe
		data:         [u8(1)]
		timestamp:    timestamp
		duration:     1
	}
}

fn test_coded_frame_processing_preserves_overlapping_frames_before_highest_end() {
	mut processor := SourceBufferProcessor.create()
	mut track_buffer := TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_:  .video
	})
	processor.track_buffers_[1] = track_buffer
	mut demuxer := track_buffer.demuxer
	demuxer.add_coded_frame(processing_test_frame(5, true))
	demuxer.add_coded_frame(processing_test_frame(5.5, false))
	demuxer.add_coded_frame(processing_test_frame(10, true))
	track_buffer.highest_end_timestamp_ = 11
	track_buffer.last_decode_timestamp_ = 4
	track_buffer.last_frame_duration_ = 1
	track_buffer.need_random_access_point_flag_ = false

	processor.run_coded_frame_processing([
		processing_test_frame(5, true),
	])

	assert demuxer.coded_frames().map(it.timestamp) == [f64(5), 5.5, 10]
}

fn test_source_buffer_processor_and_track_buffer_state_accessors() {
	mut processor := SourceBufferProcessor.create()
	assert !processor.first_initialization_segment_received_flag()
	processor.set_first_initialization_segment_received_flag(true)
	assert processor.first_initialization_segment_received_flag()

	mut track_buffer := TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_:  .video
	})
	assert track_buffer.last_decode_timestamp() == none
	assert track_buffer.last_frame_duration() == none
	assert track_buffer.highest_end_timestamp() == none
	track_buffer.set_last_decode_timestamp(3)
	track_buffer.set_last_frame_duration(0.04)
	track_buffer.set_highest_end_timestamp(3.04)
	assert track_buffer.last_decode_timestamp()? == 3
	assert track_buffer.last_frame_duration()? == 0.04
	assert track_buffer.highest_end_timestamp()? == 3.04
	track_buffer.unset_timestamps()
	assert track_buffer.last_decode_timestamp() == none
	assert track_buffer.last_frame_duration() == none
	assert track_buffer.highest_end_timestamp() == none
}
