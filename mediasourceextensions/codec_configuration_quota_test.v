// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Ladybird e45c3172e5a878a813acc7c61a808c39d6dd2eef.
module mediasourceextensions

fn quota_frame(timestamp f64, configuration ?[]u8) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number:            1
		codec_id:                'avc1'
		is_keyframe:             true
		data:                    [u8(1)]
		new_codec_configuration: configuration
		timestamp:               timestamp
		decode_timestamp:        timestamp
		duration:                1
	}
}

fn quota_demuxer() &TrackBufferDemuxer {
	return TrackBufferDemuxer.create(WebMTrackInfo{ number: 1, type_: .video, codec_id: 'avc1' })
}

fn assert_quota_counts_retained_frames(demuxer &TrackBufferDemuxer) {
	mut actual := 0
	for frame in demuxer.coded_frames() {
		actual += frame.data.len
		if configuration := frame.new_codec_configuration {
			actual += configuration.len
		}
	}
	assert demuxer.total_bytes() == actual
}

fn test_codec_quota_counts_copies_at_run_heads_and_configuration_switches() {
	mut demuxer := quota_demuxer()
	demuxer.add_coded_frame(quota_frame(0, [u8(1), 2, 3, 4]))
	demuxer.add_coded_frame(quota_frame(1, none))
	assert demuxer.total_bytes() == 6
	demuxer.add_coded_frame(quota_frame(4, none))
	assert demuxer.total_bytes() == 11
	demuxer.add_coded_frame(quota_frame(5, [u8(5), 6]))
	assert demuxer.total_bytes() == 14
	assert_quota_counts_retained_frames(demuxer)
	demuxer.add_coded_frame(quota_frame(5, [u8(9)]))
	assert demuxer.total_bytes() == 13
	assert_quota_counts_retained_frames(demuxer)
}

fn test_codec_quota_eviction_keeps_surviving_configuration_bytes() {
	mut demuxer := quota_demuxer()
	demuxer.add_coded_frame(quota_frame(0, [u8(1), 2, 3, 4]))
	demuxer.add_coded_frame(quota_frame(1, none))
	assert demuxer.take_earliest_frame_and_dependants() == 1
	assert demuxer.total_bytes() == 5
	assert_quota_counts_retained_frames(demuxer)
	assert demuxer.take_latest_frame().byte_size == 5
	assert demuxer.total_bytes() == 0
}

fn test_codec_quota_accounts_for_a_split_run_and_exact_capacity() {
	mut demuxer := quota_demuxer()
	demuxer.add_coded_frame(quota_frame(0, [u8(1), 2, 3, 4]))
	demuxer.add_coded_frame(quota_frame(1, none))
	demuxer.add_coded_frame(quota_frame(2, none))
	demuxer.remove_coded_frames_and_dependants_in_range(1, 2)
	assert demuxer.total_bytes() == 10
	assert_quota_counts_retained_frames(demuxer)

	mut processor := SourceBufferProcessor.create()
	mut track := TrackBuffer.create(WebMTrackInfo{ number: 1, type_: .text })
	processor.track_buffers_[1] = track
	track.demuxer.add_coded_frame(quota_frame(0, [u8(1), 2, 3, 4]))
	track.demuxer.add_coded_frame(quota_frame(1, none))
	processor.run_coded_frame_eviction(text_track_byte_capacity - 5, 1)
	assert !processor.is_buffer_full()
	assert processor.total_buffered_bytes() == 5
}
