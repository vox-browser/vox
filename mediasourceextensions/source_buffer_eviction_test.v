module mediasourceextensions

fn eviction_test_frame(timestamp f64, is_keyframe bool, byte_size int) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 1
		timestamp:    timestamp
		is_keyframe:  is_keyframe
		data:         []u8{len: byte_size, init: u8(1)}
		duration:     1
	}
}

fn eviction_test_processor() (&SourceBufferProcessor, &TrackBuffer) {
	mut processor := SourceBufferProcessor.create()
	track_buffer := TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_:  .text
	})
	processor.track_buffers_[1] = track_buffer
	return processor, track_buffer
}

fn test_coded_frame_eviction_removes_an_old_keyframe_group_before_append() {
	mut processor, track_buffer := eviction_test_processor()
	mut demuxer := track_buffer.demuxer
	demuxer.add_coded_frame(eviction_test_frame(0, true, 1))
	demuxer.add_coded_frame(eviction_test_frame(1, false, 1))
	demuxer.add_coded_frame(eviction_test_frame(2, true, 1))
	assert processor.total_buffered_bytes() == 3
	assert processor.capacity_in_bytes() == text_track_byte_capacity

	processor.run_coded_frame_eviction(text_track_byte_capacity - 2, 2)
	assert !processor.is_buffer_full()
	assert processor.total_buffered_bytes() == 1
	assert demuxer.coded_frames().map(it.timestamp) == [f64(2)]
}

fn test_coded_frame_eviction_preserves_the_current_and_last_appended_run() {
	mut processor, track_buffer := eviction_test_processor()
	mut demuxer := track_buffer.demuxer
	demuxer.add_coded_frame(eviction_test_frame(0, true, 1))

	processor.run_coded_frame_eviction(text_track_byte_capacity, 0)
	assert processor.is_buffer_full()
	assert processor.total_buffered_bytes() == 1
	assert demuxer.coded_frame_count() == 1
}

fn test_coded_frame_eviction_falls_back_to_newest_future_data() {
	mut processor, mut track_buffer := eviction_test_processor()
	mut demuxer := track_buffer.demuxer
	demuxer.add_coded_frame(eviction_test_frame(10, true, 2))
	demuxer.add_coded_frame(eviction_test_frame(0, true, 2))
	track_buffer.last_decode_timestamp_ = 10
	track_buffer.last_frame_duration_ = 1
	track_buffer.highest_end_timestamp_ = 11
	track_buffer.need_random_access_point_flag_ = false
	processor.group_end_timestamp_ = 99

	processor.run_coded_frame_eviction(text_track_byte_capacity - 3, 0)
	assert !processor.is_buffer_full()
	assert processor.total_buffered_bytes() == 2
	assert demuxer.coded_frames().map(it.timestamp) == [f64(0)]
	assert processor.group_end_timestamp() == 10
	assert track_buffer.last_decode_timestamp_ == none
	assert track_buffer.last_frame_duration_ == none
	assert track_buffer.highest_end_timestamp_ == none
	assert track_buffer.need_random_access_point_flag_
}

fn test_source_buffer_processor_capacity_is_per_track_type() {
	mut processor := SourceBufferProcessor.create()
	processor.track_buffers_[1] = TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_:  .audio
	})
	processor.track_buffers_[2] = TrackBuffer.create(WebMTrackInfo{
		number: 2
		type_:  .video
	})
	processor.track_buffers_[3] = TrackBuffer.create(WebMTrackInfo{
		number: 3
		type_:  .text
	})
	assert processor.capacity_in_bytes() == audio_track_byte_capacity
		+ video_track_byte_capacity + text_track_byte_capacity
}
