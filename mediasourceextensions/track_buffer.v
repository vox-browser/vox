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

pub struct RemovedCodedFrame {
pub:
	byte_size        int
	decode_timestamp f64
}

pub enum TrackBufferSeekMode {
	fast_before
	fast_after
}

pub enum TrackBufferReadBlocked {
	no
	yes
}

pub struct TrackBufferTrackScanState {
pub:
	track                 WebMTrackInfo
	buffered_ranges       []MediaSourceTimeRange
	reached_end_of_stream bool
}

pub struct TrackBufferScanState {
pub:
	tracks   []TrackBufferTrackScanState
	duration f64
}

pub type TrackBufferScanStateChangeHandler = fn ()

pub type TrackBufferReadBlockedChangeHandler = fn (TrackBufferReadBlocked)

struct FrameRun {
mut:
	frames             []DemuxedCodedFrame
	presentation_start f64
	presentation_end   f64
}

fn (mut run FrameRun) recalculate_bounds() {
	if run.frames.len == 0 {
		run.presentation_start = 0
		run.presentation_end = 0
		return
	}
	run.presentation_start = run.frames[0].timestamp
	run.presentation_end = run.frames[0].timestamp + run.frames[0].duration
	for frame in run.frames[1..] {
		if frame.timestamp < run.presentation_start {
			run.presentation_start = frame.timestamp
		}
		if frame.timestamp + frame.duration > run.presentation_end {
			run.presentation_end = frame.timestamp + frame.duration
		}
	}
}

@[heap]
pub struct TrackBufferDemuxer {
pub:
	track WebMTrackInfo
mut:
	runs_                           []FrameRun
	current_run_                    int
	current_frame_                  int
	cursor_presentation_timestamp_ ?f64
	needs_reanchoring_              bool
	reached_end_of_stream_          bool
	aborted_                        bool
	last_appended_decode_timestamp_ ?f64
	last_appended_codec_configuration_ ?[]u8
	last_delivered_codec_configuration_ ?[]u8
	cursor_jumped_                  bool
	maximum_frame_duration_         f64
	total_bytes_                    int
	scan_state_                     TrackBufferScanState
	scan_state_change_handler_      ?TrackBufferScanStateChangeHandler
	read_blocked_                   TrackBufferReadBlocked
	read_blocked_change_handler_    ?TrackBufferReadBlockedChangeHandler
}

pub fn TrackBufferDemuxer.create(track WebMTrackInfo) &TrackBufferDemuxer {
	return &TrackBufferDemuxer{
		track: track
	}
}

pub fn (demuxer &TrackBufferDemuxer) run_count() int {
	return demuxer.runs_.len
}

pub fn (demuxer &TrackBufferDemuxer) coded_frame_count() int {
	mut count := 0
	for run in demuxer.runs_ {
		count += run.frames.len
	}
	return count
}

pub fn (demuxer &TrackBufferDemuxer) coded_frames() []DemuxedCodedFrame {
	mut frames := []DemuxedCodedFrame{cap: demuxer.coded_frame_count()}
	for run in demuxer.runs_ {
		frames << run.frames
	}
	frames.sort_with_compare(fn (a &DemuxedCodedFrame, b &DemuxedCodedFrame) int {
		return if a.timestamp < b.timestamp { -1 } else if a.timestamp > b.timestamp { 1 } else { 0 }
	})
	return frames
}

pub fn (demuxer &TrackBufferDemuxer) create_context_for_track(_ WebMTrackInfo) ! {
}

pub fn (demuxer &TrackBufferDemuxer) get_tracks_for_type(type_ MediaSourceTrackType) []WebMTrackInfo {
	if demuxer.track.type_ == type_ {
		return [demuxer.track]
	}
	return []
}

pub fn (demuxer &TrackBufferDemuxer) get_preferred_track_for_type(type_ MediaSourceTrackType) ?WebMTrackInfo {
	if demuxer.track.type_ == type_ {
		return demuxer.track
	}
	return none
}

pub fn (demuxer &TrackBufferDemuxer) duration_of_track(_ WebMTrackInfo) f64 {
	return 0
}

pub fn (demuxer &TrackBufferDemuxer) highest_end_time() f64 {
	mut highest := f64(0)
	for run in demuxer.runs_ {
		if run.presentation_end > highest { highest = run.presentation_end }
	}
	return highest
}

pub fn (demuxer &TrackBufferDemuxer) total_duration() f64 {
	return demuxer.highest_end_time()
}

fn (mut demuxer TrackBufferDemuxer) dispatch_scan_state_change() {
	demuxer.scan_state_ = TrackBufferScanState{
		duration: demuxer.highest_end_time()
		tracks: [TrackBufferTrackScanState{
			track: demuxer.track
			buffered_ranges: demuxer.buffered_time_ranges()
			reached_end_of_stream: demuxer.reached_end_of_stream_
		}]
	}
	if handler := demuxer.scan_state_change_handler_ {
		handler()
	}
}

fn (mut demuxer TrackBufferDemuxer) update_read_blocked(value TrackBufferReadBlocked) {
	if value == demuxer.read_blocked_ {
		return
	}
	demuxer.read_blocked_ = value
	if handler := demuxer.read_blocked_change_handler_ {
		handler(value)
	}
}

fn buffered_coded_frame_bytes(frame DemuxedCodedFrame) int {
	configuration_bytes := if configuration := frame.new_codec_configuration { configuration.len } else { 0 }
	return frame.data.len + configuration_bytes
}

pub fn (mut demuxer TrackBufferDemuxer) add_coded_frame(input_frame DemuxedCodedFrame) {
	mut frame := input_frame
	if configuration := frame.new_codec_configuration {
		demuxer.last_appended_codec_configuration_ = configuration.clone()
	}
	// Coded-frame processing replaces an existing frame at the same
	// presentation timestamp. Keep the run representation free of duplicate
	// presentation samples while preserving decode order for every other frame.
	for run_index := demuxer.runs_.len - 1; run_index >= 0; run_index-- {
		mut run := demuxer.runs_[run_index]
		for frame_index := run.frames.len - 1; frame_index >= 0; frame_index-- {
			if run.frames[frame_index].timestamp != frame.timestamp {
				continue
			}
			demuxer.total_bytes_ -= buffered_coded_frame_bytes(run.frames[frame_index])
			run.frames.delete(frame_index)
			if run.frames.len == 0 {
				demuxer.runs_.delete(run_index)
				if demuxer.current_run_ > run_index {
					demuxer.current_run_--
				}
			} else {
				run.recalculate_bounds()
				demuxer.runs_[run_index] = run
			}
			break
		}
	}
	mut run_to_continue := -1
	for index := demuxer.runs_.len - 1; index >= 0; index-- {
		last_decode := demuxer.runs_[index].frames.last().decoding_timestamp()
		delta := frame.decoding_timestamp() - last_decode
		if delta > 0 && delta <= demuxer.maximum_time_range_gap() {
			run_to_continue = index
			break
		}
	}
	if run_to_continue < 0 && !frame.is_keyframe {
		return
	}
	demuxer.last_appended_decode_timestamp_ = frame.decoding_timestamp()
	if frame.duration > demuxer.maximum_frame_duration_ {
		demuxer.maximum_frame_duration_ = frame.duration
	}
	if run_to_continue >= 0 {
		demuxer.total_bytes_ += buffered_coded_frame_bytes(frame)
		demuxer.runs_[run_to_continue].frames << frame
		demuxer.runs_[run_to_continue].recalculate_bounds()
		demuxer.dispatch_scan_state_change()
		return
	}
	if frame.new_codec_configuration == none {
		if configuration := demuxer.last_appended_codec_configuration_ {
			frame.new_codec_configuration = configuration.clone()
		}
	}
	demuxer.total_bytes_ += buffered_coded_frame_bytes(frame)
	mut run := FrameRun{
		frames: [frame]
	}
	run.recalculate_bounds()
	mut insertion_index := 0
	for insertion_index < demuxer.runs_.len
		&& demuxer.runs_[insertion_index].presentation_start < run.presentation_start {
		insertion_index++
	}
	demuxer.runs_.insert(insertion_index, run)
	if demuxer.runs_.len > 1 && insertion_index <= demuxer.current_run_ {
		demuxer.current_run_++
		if demuxer.current_run_ >= demuxer.runs_.len {
			demuxer.current_run_ = demuxer.runs_.len - 1
		}
	}
	demuxer.dispatch_scan_state_change()
}

pub fn (mut demuxer TrackBufferDemuxer) remove_coded_frames_and_dependants_in_range(start f64, end f64) {
	_ = demuxer.remove_coded_frames_and_dependants_in_range_returning_timestamp(start,
		end, none)
}

fn (mut demuxer TrackBufferDemuxer) erase_frames_and_dependants(run_index int, first_frame int, minimum_count int) int {
	total_bytes_before := demuxer.total_bytes_
	mut run := demuxer.runs_[run_index]
	mut count := minimum_count
	for first_frame + count < run.frames.len && !run.frames[first_frame + count].is_keyframe {
		count++
	}
	mut bytes := 0
	for frame in run.frames[first_frame..first_frame + count] {
		bytes += buffered_coded_frame_bytes(frame)
	}
	mut configuration_before_remaining := ?[]u8(none)
	if first_frame + count < run.frames.len {
		configuration_before_remaining = codec_configuration_after_frame_prefix(run,
			first_frame + count)
	}
	demuxer.total_bytes_ -= bytes
	run.frames.delete_many(first_frame, count)
	if demuxer.current_run_ == run_index {
		if demuxer.current_frame_ >= first_frame + count {
			demuxer.current_frame_ -= count
		} else if demuxer.current_frame_ >= first_frame {
			demuxer.current_frame_ = first_frame
			demuxer.note_cursor_jumped()
		}
	}
	if run.frames.len == 0 {
		demuxer.runs_.delete(run_index)
		if demuxer.current_run_ > run_index {
			demuxer.current_run_--
		} else if demuxer.current_run_ == run_index {
			demuxer.needs_reanchoring_ = true
		}
	} else if first_frame > 0 && first_frame < run.frames.len {
		mut tail := FrameRun{
			frames: run.frames[first_frame..].clone()
		}
		if tail.frames[0].new_codec_configuration == none {
			if configuration := configuration_before_remaining {
				tail.frames[0].new_codec_configuration = configuration.clone()
				demuxer.total_bytes_ += configuration.len
			}
		}
		run.frames = run.frames[..first_frame].clone()
		run.recalculate_bounds()
		tail.recalculate_bounds()
		demuxer.runs_[run_index] = run
		mut insertion_index := run_index + 1
		for insertion_index < demuxer.runs_.len
			&& demuxer.runs_[insertion_index].presentation_start < tail.presentation_start {
			insertion_index++
		}
		demuxer.runs_.insert(insertion_index, tail)
		if demuxer.current_run_ == run_index && demuxer.current_frame_ >= first_frame {
			demuxer.current_run_ = insertion_index
			demuxer.current_frame_ -= first_frame
		} else if demuxer.current_run_ >= insertion_index {
			demuxer.current_run_++
		}
	} else {
		if first_frame == 0 && run.frames[0].new_codec_configuration == none {
			if configuration := configuration_before_remaining {
				run.frames[0].new_codec_configuration = configuration.clone()
				demuxer.total_bytes_ += configuration.len
			}
		}
		run.recalculate_bounds()
		demuxer.runs_[run_index] = run
	}
	demuxer.recalculate_maximum_frame_duration()
	// A surviving run head may now own a cloned configuration. Report only
	// bytes actually freed, so eviction cannot spend that retained memory twice.
	return if total_bytes_before > demuxer.total_bytes_ { total_bytes_before - demuxer.total_bytes_ } else { 0 }
}

pub fn (mut demuxer TrackBufferDemuxer) remove_coded_frames_and_dependants_in_range_returning_timestamp(start f64, end f64, last_decode_timestamp ?f64) ?f64 {
	mut removed_presentation_timestamp := ?f64(none)
	for run_index := demuxer.runs_.len - 1; run_index >= 0; run_index-- {
		run := demuxer.runs_[run_index]
		if run.presentation_end <= start || run.presentation_start >= end {
			continue
		}
		mut first := -1
		mut last := -1
		for index, frame in run.frames {
			if frame.timestamp >= start && frame.timestamp < end {
				if first < 0 {
					first = index
				}
				last = index
			}
		}
		if first < 0 {
			continue
		}
		mut removal_end := last + 1
		for removal_end < run.frames.len && !run.frames[removal_end].is_keyframe {
			removal_end++
		}
		for frame in run.frames[first..removal_end] {
			if expected := last_decode_timestamp {
				if frame.decoding_timestamp() == expected {
					removed_presentation_timestamp = frame.timestamp
				}
			}
			if appended := demuxer.last_appended_decode_timestamp_ {
				if frame.decoding_timestamp() == appended {
					demuxer.last_appended_decode_timestamp_ = none
				}
			}
		}
		demuxer.erase_frames_and_dependants(run_index, first, removal_end - first)
	}
	demuxer.dispatch_scan_state_change()
	return removed_presentation_timestamp
}

pub fn (demuxer &TrackBufferDemuxer) total_bytes() int {
	return demuxer.total_bytes_
}

fn (demuxer &TrackBufferDemuxer) frame_is_evictable(frame DemuxedCodedFrame, current_time f64) bool {
	mut protected_start := current_time
	mut protected_end := current_time
	if cursor_time := demuxer.cursor_presentation_timestamp_ {
		if cursor_time < protected_start {
			protected_start = cursor_time
		}
		if cursor_time > protected_end {
			protected_end = cursor_time
		}
	}
	return frame.timestamp < protected_start || frame.timestamp > protected_end
}

fn (demuxer &TrackBufferDemuxer) run_ends_at_last_appended_frame(run FrameRun) bool {
	last_appended := demuxer.last_appended_decode_timestamp_ or { return false }
	return run.frames.last().decoding_timestamp() == last_appended
}

pub fn (demuxer &TrackBufferDemuxer) earliest_evictable_frame_timestamp(current_time f64) ?f64 {
	if demuxer.runs_.len == 0 {
		return none
	}
	run := demuxer.runs_[0]
	mut frame_count := 0
	for frame in run.frames {
		if frame_count > 0 && frame.is_keyframe {
			break
		}
		if !demuxer.frame_is_evictable(frame, current_time) {
			return none
		}
		frame_count++
	}
	if frame_count == run.frames.len && demuxer.run_ends_at_last_appended_frame(run) {
		return none
	}
	return run.frames[0].timestamp
}

pub fn (mut demuxer TrackBufferDemuxer) take_earliest_frame_and_dependants() int {
	if demuxer.runs_.len == 0 || demuxer.reached_end_of_stream_ {
		return 0
	}
	bytes := demuxer.erase_frames_and_dependants(0, 0, 1)
	demuxer.dispatch_scan_state_change()
	return bytes
}

pub fn (demuxer &TrackBufferDemuxer) latest_evictable_frame_timestamp(current_time f64) ?f64 {
	if demuxer.runs_.len == 0 {
		return none
	}
	run := demuxer.runs_.last()
	if demuxer.run_ends_at_last_appended_frame(run) {
		return none
	}
	frame := run.frames.last()
	if !demuxer.frame_is_evictable(frame, current_time) {
		return none
	}
	return frame.timestamp
}

pub fn (mut demuxer TrackBufferDemuxer) take_latest_frame() RemovedCodedFrame {
	if demuxer.runs_.len == 0 || demuxer.reached_end_of_stream_ {
		return RemovedCodedFrame{}
	}
	run_index := demuxer.runs_.len - 1
	frame_index := demuxer.runs_[run_index].frames.len - 1
	frame := demuxer.runs_[run_index].frames[frame_index]
	removed := RemovedCodedFrame{
		byte_size: buffered_coded_frame_bytes(frame)
		decode_timestamp: frame.decoding_timestamp()
	}
	demuxer.erase_frames_and_dependants(run_index, frame_index, 1)
	demuxer.dispatch_scan_state_change()
	return removed
}

pub fn (demuxer &TrackBufferDemuxer) buffered_time_ranges() []MediaSourceTimeRange {
	frames := demuxer.coded_frames()
	mut ranges := []MediaSourceTimeRange{}
	for frame in frames {
		start := frame.timestamp
		end := frame.timestamp + frame.duration
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
	return demuxer.maximum_frame_duration_ * 2
}

fn codec_configuration_after_frame_prefix(run FrameRun, frame_count int) ?[]u8 {
	mut index := frame_count
	for index > 0 {
		index--
		if configuration := run.frames[index].new_codec_configuration {
			return configuration.clone()
		}
	}
	return none
}

fn (mut demuxer TrackBufferDemuxer) note_cursor_jumped() {
	if !demuxer.needs_reanchoring_ {
		demuxer.cursor_jumped_ = true
	}
}

fn (mut demuxer TrackBufferDemuxer) recalculate_maximum_frame_duration() {
	demuxer.maximum_frame_duration_ = 0
	for run in demuxer.runs_ {
		for frame in run.frames {
			if frame.duration > demuxer.maximum_frame_duration_ {
				demuxer.maximum_frame_duration_ = frame.duration
			}
		}
	}
}

fn (demuxer &TrackBufferDemuxer) find_run_to_play_from(timestamp f64) ?int {
	if demuxer.runs_.len == 0 {
		return none
	}
	for index, run in demuxer.runs_ {
		if run.presentation_start > timestamp {
			if index > 0
				&& run.presentation_start - demuxer.runs_[index - 1].presentation_end <= demuxer.maximum_time_range_gap() {
				return index - 1
			}
			if run.presentation_start - timestamp <= demuxer.maximum_time_range_gap() {
				return index
			}
			return none
		}
		if timestamp < run.presentation_end {
			return index
		}
	}
	if demuxer.reached_end_of_stream_ {
		return demuxer.runs_.len - 1
	}
	return none
}

pub fn (demuxer &TrackBufferDemuxer) select_fast_seek_target_for_track(target f64, mode TrackBufferSeekMode) f64 {
	mut best_timestamp := ?f64(none)
	for run in demuxer.runs_ {
		for frame in run.frames {
			if !frame.is_keyframe {
				continue
			}
			if mode == .fast_before {
				if frame.timestamp <= target {
					if best := best_timestamp {
						if frame.timestamp > best {
							best_timestamp = frame.timestamp
						}
					} else {
						best_timestamp = frame.timestamp
					}
				}
			} else if frame.timestamp >= target {
				if best := best_timestamp {
					if frame.timestamp < best {
						best_timestamp = frame.timestamp
					}
				} else {
					best_timestamp = frame.timestamp
				}
			}
		}
	}
	return best_timestamp or { target }
}

pub fn (mut demuxer TrackBufferDemuxer) seek_to_most_recent_keyframe(timestamp f64) ! {
	run_index := demuxer.find_run_to_play_from(timestamp) or { return error('NeedMoreData') }
	run := demuxer.runs_[run_index]
	mut keyframe_index := 0
	for index in 1 .. run.frames.len {
		frame := run.frames[index]
		if frame.is_keyframe && frame.timestamp <= timestamp
			&& frame.timestamp >= run.frames[keyframe_index].timestamp {
			keyframe_index = index
		}
	}
	demuxer.current_run_ = run_index
	demuxer.current_frame_ = keyframe_index
	demuxer.cursor_presentation_timestamp_ = run.frames[keyframe_index].timestamp
	demuxer.needs_reanchoring_ = false
	demuxer.cursor_jumped_ = true
}

pub fn (mut demuxer TrackBufferDemuxer) next_frame() !DemuxedCodedFrame {
	if demuxer.aborted_ {
		return error('Aborted: Read aborted')
	}
	if demuxer.needs_reanchoring_ {
		anchor := demuxer.cursor_presentation_timestamp_ or { f64(0) }
		demuxer.seek_to_most_recent_keyframe(anchor) or {
			if demuxer.reached_end_of_stream_ { return error('EndOfStream') }
			return error('NeedMoreData')
		}
	}
	for demuxer.current_run_ < demuxer.runs_.len
		&& demuxer.current_frame_ >= demuxer.runs_[demuxer.current_run_].frames.len {
		if demuxer.current_run_ + 1 >= demuxer.runs_.len {
			break
		}
		current := demuxer.runs_[demuxer.current_run_]
		next := demuxer.runs_[demuxer.current_run_ + 1]
		if next.presentation_start - current.presentation_end > demuxer.maximum_time_range_gap() {
			break
		}
		demuxer.current_run_++
		demuxer.current_frame_ = 0
		demuxer.cursor_jumped_ = true
	}
	if demuxer.current_run_ >= demuxer.runs_.len
		|| demuxer.current_frame_ >= demuxer.runs_[demuxer.current_run_].frames.len {
		if demuxer.reached_end_of_stream_ {
			demuxer.update_read_blocked(.no)
			return error('EndOfStream')
		}
		demuxer.update_read_blocked(.yes)
		return error('NeedMoreData')
	}
	demuxer.update_read_blocked(.no)
	mut frame := demuxer.runs_[demuxer.current_run_].frames[demuxer.current_frame_]
	if demuxer.cursor_jumped_ {
		configuration := codec_configuration_after_frame_prefix(demuxer.runs_[demuxer.current_run_],
			demuxer.current_frame_ + 1)
		mut configuration_is_new := false
		if value := configuration {
			if delivered := demuxer.last_delivered_codec_configuration_ {
				configuration_is_new = value != delivered
			} else {
				configuration_is_new = true
			}
			if configuration_is_new {
				frame.new_codec_configuration = value.clone()
				demuxer.last_delivered_codec_configuration_ = value.clone()
			} else {
				frame.new_codec_configuration = none
			}
		}
		demuxer.cursor_jumped_ = false
	} else if configuration := frame.new_codec_configuration {
		demuxer.last_delivered_codec_configuration_ = configuration.clone()
	}
	demuxer.current_frame_++
	demuxer.cursor_presentation_timestamp_ = frame.timestamp
	return frame
}

pub fn (mut demuxer TrackBufferDemuxer) set_reached_end_of_stream() {
	demuxer.reached_end_of_stream_ = true
	demuxer.dispatch_scan_state_change()
}

pub fn (mut demuxer TrackBufferDemuxer) clear_reached_end_of_stream() {
	demuxer.reached_end_of_stream_ = false
	demuxer.dispatch_scan_state_change()
}

pub fn (mut demuxer TrackBufferDemuxer) set_blocking_reads_aborted(value bool) {
	demuxer.aborted_ = value
}

pub fn (demuxer &TrackBufferDemuxer) scan_state() TrackBufferScanState {
	return demuxer.scan_state_
}

pub fn (mut demuxer TrackBufferDemuxer) set_scan_state_change_handler(handler TrackBufferScanStateChangeHandler) {
	demuxer.scan_state_change_handler_ = handler
	demuxer.dispatch_scan_state_change()
}

pub fn (mut demuxer TrackBufferDemuxer) set_blocking_reads_aborted_for_track() {
	demuxer.aborted_ = true
}

pub fn (mut demuxer TrackBufferDemuxer) reset_blocking_reads_aborted_for_track() {
	demuxer.aborted_ = false
}

pub fn (mut demuxer TrackBufferDemuxer) set_read_blocked_change_handler_for_track(handler TrackBufferReadBlockedChangeHandler) {
	demuxer.read_blocked_change_handler_ = handler
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

pub fn (buffer &TrackBuffer) last_decode_timestamp() ?f64 {
	return buffer.last_decode_timestamp_
}

pub fn (mut buffer TrackBuffer) set_last_decode_timestamp(timestamp f64) {
	buffer.last_decode_timestamp_ = timestamp
}

pub fn (mut buffer TrackBuffer) unset_last_decode_timestamp() {
	buffer.last_decode_timestamp_ = none
}

pub fn (buffer &TrackBuffer) last_frame_duration() ?f64 {
	return buffer.last_frame_duration_
}

pub fn (mut buffer TrackBuffer) set_last_frame_duration(duration f64) {
	buffer.last_frame_duration_ = duration
}

pub fn (mut buffer TrackBuffer) unset_last_frame_duration() {
	buffer.last_frame_duration_ = none
}

pub fn (buffer &TrackBuffer) highest_end_timestamp() ?f64 {
	return buffer.highest_end_timestamp_
}

pub fn (mut buffer TrackBuffer) set_highest_end_timestamp(timestamp f64) {
	buffer.highest_end_timestamp_ = timestamp
}

pub fn (mut buffer TrackBuffer) unset_highest_end_timestamp() {
	buffer.highest_end_timestamp_ = none
}

pub fn (mut buffer TrackBuffer) unset_timestamps() {
	buffer.unset_last_decode_timestamp()
	buffer.unset_last_frame_duration()
	buffer.unset_highest_end_timestamp()
}

pub fn (mut buffer TrackBuffer) set_need_random_access_point_flag(value bool) {
	buffer.need_random_access_point_flag_ = value
}
