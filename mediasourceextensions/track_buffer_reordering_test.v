module mediasourceextensions

fn reordered_test_frame(presentation f64, decode f64, duration f64, keyframe bool) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 1
		is_keyframe: keyframe
		data: [u8(presentation)]
		timestamp: presentation
		decode_timestamp: decode
		duration: duration
	}
}

fn reordered_test_demuxer() &TrackBufferDemuxer {
	return TrackBufferDemuxer.create(WebMTrackInfo{
		number: 1
		type_: .video
	})
}

fn test_track_buffer_delivers_reordered_frames_in_decode_order() {
	mut demuxer := reordered_test_demuxer()
	demuxer.add_coded_frame(reordered_test_frame(0, 0, 1, true))
	demuxer.add_coded_frame(reordered_test_frame(2, 1, 1, false))
	demuxer.add_coded_frame(reordered_test_frame(1, 2, 1, false))

	assert demuxer.run_count() == 1
	assert demuxer.coded_frames().map(it.timestamp) == [f64(0), 1, 2]
	assert demuxer.next_frame()!.timestamp == 0
	assert demuxer.next_frame()!.timestamp == 2
	assert demuxer.next_frame()!.timestamp == 1
	ranges := demuxer.buffered_time_ranges()
	assert ranges.len == 1
	assert ranges[0] == MediaSourceTimeRange{ start: 0, end: 3 }
}

fn test_track_buffer_starts_new_runs_at_decode_discontinuities() {
	mut demuxer := reordered_test_demuxer()
	demuxer.add_coded_frame(reordered_test_frame(0, 0, 1, true))
	demuxer.add_coded_frame(reordered_test_frame(1, 1, 1, false))
	demuxer.add_coded_frame(reordered_test_frame(4, 0, 1, true))
	demuxer.add_coded_frame(reordered_test_frame(5, 1, 1, false))

	assert demuxer.run_count() == 2
	assert demuxer.next_frame()!.timestamp == 0
	assert demuxer.next_frame()!.timestamp == 1
	assert demuxer.next_frame()!.timestamp == 4
	assert demuxer.next_frame()!.timestamp == 5

	mut empty_demuxer := reordered_test_demuxer()
	empty_demuxer.add_coded_frame(reordered_test_frame(10, 0, 1, false))
	assert empty_demuxer.coded_frame_count() == 0
}

fn test_track_buffer_seek_prioritizes_the_earlier_overlapping_run() {
	mut demuxer := reordered_test_demuxer()
	demuxer.add_coded_frame(reordered_test_frame(0, 0, 5, true))
	demuxer.add_coded_frame(reordered_test_frame(4, 1, 5, false))
	demuxer.add_coded_frame(reordered_test_frame(3, 0, 5, true))

	assert demuxer.run_count() == 2
	demuxer.seek_to_most_recent_keyframe(4)!
	assert demuxer.next_frame()!.timestamp == 0
}

fn test_coded_frame_processing_uses_decode_timestamps_for_discontinuities() {
	mut processor := SourceBufferProcessor.create()
	mut track_buffer := TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_: .video
	})
	track_buffer.need_random_access_point_flag_ = false
	processor.track_buffers_[1] = track_buffer
	processor.run_coded_frame_processing([
		reordered_test_frame(2, 0, 1, true),
		reordered_test_frame(1, 1, 1, false),
	])

	assert track_buffer.demuxer.coded_frame_count() == 2
	assert track_buffer.demuxer.run_count() == 1
	assert track_buffer.last_decode_timestamp_ or { -1 } == 1
}
