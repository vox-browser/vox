// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of TrackBuffer.{h,cpp} and TrackBufferDemuxer.{h,cpp}. The host
// decoder boundary reads coded frames from this timestamp-ordered store.
module mediasourceextensions

pub struct MediaSourceTimeRange {
pub:
	start f64
	end   f64
}

@[heap]
pub struct TrackBufferDemuxer {
pub:
	track WebMTrackInfo
mut:
	coded_frames_            []DemuxedCodedFrame
	read_position_           int
	reached_end_of_stream_   bool
	aborted_                 bool
	last_returned_timestamp_ ?f64
	last_frame_duration_     f64
}

pub fn TrackBufferDemuxer.create(track WebMTrackInfo) &TrackBufferDemuxer {
	return &TrackBufferDemuxer{
		track: track
	}
}

pub fn (demuxer &TrackBufferDemuxer) coded_frame_count() int {
	return demuxer.coded_frames_.len
}

pub fn (demuxer &TrackBufferDemuxer) coded_frames() []DemuxedCodedFrame {
	return demuxer.coded_frames_.clone()
}

pub fn (mut demuxer TrackBufferDemuxer) add_coded_frame(frame DemuxedCodedFrame) {
	mut insertion_index := 0
	for insertion_index < demuxer.coded_frames_.len
		&& demuxer.coded_frames_[insertion_index].timestamp < frame.timestamp {
		insertion_index++
	}
	if insertion_index < demuxer.coded_frames_.len
		&& demuxer.coded_frames_[insertion_index].timestamp == frame.timestamp {
		demuxer.coded_frames_[insertion_index] = frame
		return
	}
	if insertion_index > 0 && demuxer.coded_frames_[insertion_index - 1].duration <= 0 {
		mut previous := demuxer.coded_frames_[insertion_index - 1]
		previous.duration = frame.timestamp - previous.timestamp
		demuxer.coded_frames_[insertion_index - 1] = previous
		if previous.duration > 0 {
			demuxer.last_frame_duration_ = previous.duration
		}
	}
	demuxer.coded_frames_.insert(insertion_index, frame)
	if frame.duration > 0 {
		demuxer.last_frame_duration_ = frame.duration
	}
	if insertion_index <= demuxer.read_position_ {
		if last := demuxer.last_returned_timestamp_ {
			if last > frame.timestamp {
				demuxer.read_position_++
			}
		}
	}
}

pub fn (mut demuxer TrackBufferDemuxer) remove_coded_frames_and_dependants_in_range(start f64, end f64) {
	mut remove_start := 0
	for remove_start < demuxer.coded_frames_.len
		&& demuxer.coded_frames_[remove_start].timestamp < start {
		remove_start++
	}
	mut remove_end := remove_start
	for remove_end < demuxer.coded_frames_.len
		&& demuxer.coded_frames_[remove_end].timestamp < end {
		remove_end++
	}
	if remove_end <= remove_start {
		return
	}
	for remove_end < demuxer.coded_frames_.len && !demuxer.coded_frames_[remove_end].is_keyframe {
		remove_end++
	}
	demuxer.coded_frames_.delete_many(remove_start, remove_end - remove_start)
	if demuxer.read_position_ >= remove_end {
		demuxer.read_position_ -= remove_end - remove_start
	} else if demuxer.read_position_ > remove_start {
		demuxer.read_position_ = if remove_start > 0 { remove_start - 1 } else { 0 }
		for demuxer.read_position_ > 0
			&& !demuxer.coded_frames_[demuxer.read_position_].is_keyframe {
			demuxer.read_position_--
		}
		demuxer.last_returned_timestamp_ = none
	}
}

pub fn (demuxer &TrackBufferDemuxer) buffered_time_ranges() []MediaSourceTimeRange {
	mut ranges := []MediaSourceTimeRange{}
	for index, frame in demuxer.coded_frames_ {
		start := frame.timestamp
		duration := if frame.duration > 0 {
			frame.duration
		} else if index + 1 < demuxer.coded_frames_.len {
			demuxer.coded_frames_[index + 1].timestamp - frame.timestamp
		} else {
			demuxer.last_frame_duration_
		}
		end := frame.timestamp + duration
		if ranges.len == 0 || start > ranges.last().end + demuxer.maximum_time_range_gap() {
			ranges << MediaSourceTimeRange{ start: start, end: end }
		} else if end > ranges.last().end {
			last := ranges.len - 1
			ranges[last] = MediaSourceTimeRange{ start: ranges[last].start, end: end }
		}
	}
	return ranges
}

fn (demuxer &TrackBufferDemuxer) maximum_time_range_gap() f64 {
	return demuxer.last_frame_duration_ * 2
}

pub fn (mut demuxer TrackBufferDemuxer) next_frame() !DemuxedCodedFrame {
	if demuxer.aborted_ {
		return error('Aborted: Read aborted')
	}
	if demuxer.read_position_ >= demuxer.coded_frames_.len {
		if demuxer.reached_end_of_stream_ {
			return error('EndOfStream')
		}
		return error('NeedMoreData')
	}
	frame := demuxer.coded_frames_[demuxer.read_position_]
	if last := demuxer.last_returned_timestamp_ {
		if frame.timestamp - last > demuxer.maximum_time_range_gap() {
			return error('NeedMoreData: next frame is in a gap')
		}
	}
	demuxer.read_position_++
	demuxer.last_returned_timestamp_ = frame.timestamp
	demuxer.last_frame_duration_ = frame.duration
	return frame
}

pub fn (mut demuxer TrackBufferDemuxer) set_reached_end_of_stream() {
	demuxer.reached_end_of_stream_ = true
}

pub fn (mut demuxer TrackBufferDemuxer) clear_reached_end_of_stream() {
	demuxer.reached_end_of_stream_ = false
}

pub fn (mut demuxer TrackBufferDemuxer) set_blocking_reads_aborted(value bool) {
	demuxer.aborted_ = value
}

@[heap]
pub struct TrackBuffer {
pub:
	demuxer &TrackBufferDemuxer
mut:
	last_decode_timestamp_         ?f64
	last_frame_duration_           ?f64
	highest_end_timestamp_         ?f64
	need_random_access_point_flag_ bool = true
}

pub fn TrackBuffer.create(track WebMTrackInfo) &TrackBuffer {
	return &TrackBuffer{
		demuxer: TrackBufferDemuxer.create(track)
	}
}

pub fn (mut buffer TrackBuffer) unset_timestamps() {
	buffer.last_decode_timestamp_ = none
	buffer.last_frame_duration_ = none
	buffer.highest_end_timestamp_ = none
}

pub fn (mut buffer TrackBuffer) set_need_random_access_point_flag(value bool) {
	buffer.need_random_access_point_flag_ = value
}
