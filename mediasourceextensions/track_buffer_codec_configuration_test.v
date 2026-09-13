module mediasourceextensions

fn codec_configuration_test_frame(timestamp f64, configuration ?[]u8) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 1
		codec_id: 'avc1'
		is_keyframe: true
		data: [u8(timestamp)]
		new_codec_configuration: configuration
		timestamp: timestamp
		decode_timestamp: timestamp
		duration: 1
	}
}

fn codec_configuration_test_demuxer() &TrackBufferDemuxer {
	return TrackBufferDemuxer.create(WebMTrackInfo{
		number: 1
		type_: .video
		codec_id: 'avc1'
	})
}

fn test_track_buffer_only_resends_a_configuration_when_it_changes_between_runs() {
	mut demuxer := codec_configuration_test_demuxer()
	demuxer.add_coded_frame(codec_configuration_test_frame(0, [u8(1)]))
	demuxer.add_coded_frame(codec_configuration_test_frame(1, none))
	demuxer.add_coded_frame(codec_configuration_test_frame(4, none))
	demuxer.add_coded_frame(codec_configuration_test_frame(5, none))
	demuxer.add_coded_frame(codec_configuration_test_frame(8, [u8(2)]))

	assert demuxer.next_frame()!.new_codec_configuration? == [u8(1)]
	assert demuxer.next_frame()!.new_codec_configuration == none
	assert demuxer.next_frame()!.new_codec_configuration == none
	assert demuxer.next_frame()!.new_codec_configuration == none
	assert demuxer.next_frame()!.new_codec_configuration? == [u8(2)]
}

fn test_track_buffer_preserves_the_active_configuration_when_evicting_a_run_head() {
	mut demuxer := codec_configuration_test_demuxer()
	demuxer.add_coded_frame(codec_configuration_test_frame(0, [u8(7)]))
	demuxer.add_coded_frame(codec_configuration_test_frame(1, none))

	assert demuxer.take_earliest_frame_and_dependants() == 1
	frame := demuxer.next_frame()!
	assert frame.timestamp == 1
	assert frame.new_codec_configuration? == [u8(7)]
}

fn test_track_buffer_seek_supplies_the_configuration_active_at_the_target() {
	mut demuxer := codec_configuration_test_demuxer()
	demuxer.add_coded_frame(codec_configuration_test_frame(0, [u8(1)]))
	demuxer.add_coded_frame(codec_configuration_test_frame(1, none))
	demuxer.add_coded_frame(codec_configuration_test_frame(4, [u8(2)]))
	demuxer.add_coded_frame(codec_configuration_test_frame(5, none))
	assert demuxer.next_frame()!.new_codec_configuration? == [u8(1)]

	demuxer.seek_to_most_recent_keyframe(5)!
	frame := demuxer.next_frame()!
	assert frame.timestamp == 5
	assert frame.new_codec_configuration? == [u8(2)]
}
