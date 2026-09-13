module mediasourceextensions

fn range_test_frame(timestamp f64, duration f64) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 1
		is_keyframe:  true
		data:         [u8(1)]
		timestamp:    timestamp
		duration:     duration
	}
}

fn test_track_buffer_ranges_use_the_maximum_buffered_frame_duration_for_gaps() {
	mut demuxer := TrackBufferDemuxer.create(WebMTrackInfo{
		number: 1
		type_:  .video
	})
	demuxer.add_coded_frame(range_test_frame(0, 0.04))
	demuxer.add_coded_frame(range_test_frame(0.1, 0.01))

	coalesced := demuxer.buffered_time_ranges()
	assert coalesced.len == 1
	assert coalesced[0].start == 0
	assert coalesced[0].end == 0.11

	demuxer.remove_coded_frames_and_dependants_in_range(0, 0.01)
	demuxer.add_coded_frame(range_test_frame(0.15, 0.01))
	ranges_after_removing_longest_frame := demuxer.buffered_time_ranges()
	assert ranges_after_removing_longest_frame.len == 2
}
