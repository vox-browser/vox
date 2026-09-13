module mediasourceextensions

import dom
import html
import math

@[heap]
struct RemovalEventCounts {
mut:
	update_start int
	update       int
	update_end   int
}

fn removal_event_callback(counts &RemovalEventCounts, kind string) &dom.CallbackType {
	return &dom.CallbackType{
		handle_event: fn [counts, kind] (_ &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut mutable_counts := unsafe { &RemovalEventCounts(counts) }
			match kind {
				'updatestart' { mutable_counts.update_start++ }
				'update' { mutable_counts.update++ }
				'updateend' { mutable_counts.update_end++ }
				else {}
			}
			return dom.js_undefined()
		}
	}
}

fn removal_test_frame(timestamp f64, keyframe bool) DemuxedCodedFrame {
	return DemuxedCodedFrame{
		track_number: 1
		is_keyframe:  keyframe
		data:         [u8(1)]
		timestamp:    timestamp
		duration:     1
	}
}

fn test_source_buffer_remove_discards_the_range_and_decoding_dependants() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	source.set_duration(20)!
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!
	mut track_buffer := TrackBuffer.create(WebMTrackInfo{
		number: 1
		type_:  .text
	})
	buffer.processor_.track_buffers_[1] = track_buffer
	mut demuxer := track_buffer.demuxer
	for frame in [
		removal_test_frame(0, true),
		removal_test_frame(1, false),
		removal_test_frame(5, true),
		removal_test_frame(6, false),
		removal_test_frame(10, true),
	] {
		demuxer.add_coded_frame(frame)
	}
	track_buffer.last_decode_timestamp_ = 6
	track_buffer.last_frame_duration_ = 1
	track_buffer.highest_end_timestamp_ = 11
	track_buffer.need_random_access_point_flag_ = false
	buffer.processor_.buffer_full_flag_ = true

	counts := &RemovalEventCounts{}
	buffer.set_onupdatestart(removal_event_callback(counts, 'updatestart'))
	buffer.set_onupdate(removal_event_callback(counts, 'update'))
	buffer.set_onupdateend(removal_event_callback(counts, 'updateend'))
	buffer.remove(0.5, 5.5)!

	assert demuxer.coded_frames().map(it.timestamp) == [f64(0), 10]
	assert !buffer.updating()
	assert !buffer.range_removal_running_
	assert !buffer.processor_.is_buffer_full()
	assert buffer.processor_.group_end_timestamp() == 6
	assert track_buffer.last_decode_timestamp_ == none
	assert track_buffer.need_random_access_point_flag_
	assert counts.update_start == 1
	assert counts.update == 1
	assert counts.update_end == 1
}

fn test_source_buffer_remove_validates_the_requested_range_and_state() {
	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	mut buffer := source.add_source_buffer('video/webm; codecs="vp9"')!

	buffer.remove(0, 1) or { assert err.msg() == 'TypeError: MediaSource duration is NaN' }
	source.set_duration(10)!
	buffer.remove(-1, 1) or {
		assert err.msg() == 'TypeError: Removal range start is outside of the duration'
	}
	buffer.remove(11, 12) or {
		assert err.msg() == 'TypeError: Removal range start is outside of the duration'
	}
	buffer.remove(5, 5) or {
		assert err.msg() == 'TypeError: Removal range end does not follow its start'
	}
	buffer.remove(5, math.nan()) or {
		assert err.msg() == 'TypeError: Removal range end does not follow its start'
	}
	buffer.processor_.set_updating(true)
	buffer.remove(0, 1) or { assert err.msg() == 'InvalidStateError: SourceBuffer is updating' }
	buffer.processor_.set_updating(false)
	buffer.range_removal_running_ = true
	buffer.abort() or {
		assert err.msg() == 'InvalidStateError: SourceBuffer is removing a range'
	}
	buffer.range_removal_running_ = false

	source.run_end_of_stream_algorithm(none)
	buffer.remove(0, 1)!
	assert source.ready_state() == .open
}
