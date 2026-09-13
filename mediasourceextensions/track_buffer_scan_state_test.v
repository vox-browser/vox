module mediasourceextensions

__global track_buffer_scan_state_change_count = 0
__global track_buffer_read_blocked_changes = []TrackBufferReadBlocked{}

fn record_track_buffer_scan_state_change() {
	track_buffer_scan_state_change_count++
}

fn record_track_buffer_read_blocked_change(value TrackBufferReadBlocked) {
	track_buffer_read_blocked_changes << value
}

fn scan_state_test_frame(timestamp f64) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 7
		codec_id: 'V_VP9'
		is_keyframe: true
		data: [u8(1), 2, 3]
		timestamp: timestamp
		decode_timestamp: timestamp
		duration: 1
	}
}

fn scan_state_test_demuxer() &TrackBufferDemuxer {
	return TrackBufferDemuxer.create(WebMTrackInfo{
		number: 7
		type_: .video
		codec_id: 'V_VP9'
	})
}

fn test_track_buffer_dispatches_scan_state_changes() {
	track_buffer_scan_state_change_count = 0
	mut demuxer := scan_state_test_demuxer()
	demuxer.set_scan_state_change_handler(record_track_buffer_scan_state_change)
	assert track_buffer_scan_state_change_count == 1
	assert demuxer.scan_state().tracks.len == 1
	assert demuxer.scan_state().tracks[0].buffered_ranges.len == 0

	demuxer.add_coded_frame(scan_state_test_frame(2))
	assert track_buffer_scan_state_change_count == 2
	state := demuxer.scan_state()
	assert state.duration == 0
	assert state.tracks[0].track.number == 7
	assert state.tracks[0].buffered_ranges == [MediaSourceTimeRange{ start: 2, end: 3 }]
	assert !state.tracks[0].reached_end_of_stream

	demuxer.set_reached_end_of_stream()
	assert track_buffer_scan_state_change_count == 3
	assert demuxer.scan_state().tracks[0].reached_end_of_stream

	demuxer.clear_reached_end_of_stream()
	assert track_buffer_scan_state_change_count == 4
	assert !demuxer.scan_state().tracks[0].reached_end_of_stream
}

fn test_track_buffer_reports_blocked_and_unblocked_reads() {
	track_buffer_read_blocked_changes = []TrackBufferReadBlocked{}
	mut demuxer := scan_state_test_demuxer()
	demuxer.set_read_blocked_change_handler_for_track(record_track_buffer_read_blocked_change)

	demuxer.next_frame() or { assert err.msg() == 'NeedMoreData' }
	assert track_buffer_read_blocked_changes == [.yes]
	demuxer.next_frame() or { assert err.msg() == 'NeedMoreData' }
	assert track_buffer_read_blocked_changes == [.yes]

	demuxer.add_coded_frame(scan_state_test_frame(0))
	assert demuxer.next_frame()!.timestamp == 0
	assert track_buffer_read_blocked_changes == [.yes, .no]

	demuxer.set_blocking_reads_aborted_for_track()
	demuxer.next_frame() or { assert err.msg() == 'Aborted: Read aborted' }
	demuxer.reset_blocking_reads_aborted_for_track()
}
