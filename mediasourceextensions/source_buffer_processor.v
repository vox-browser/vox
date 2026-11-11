// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of SourceBufferProcessor.{h,cpp}. The processor owns the
// incremental byte-stream parser and coded track buffers while SourceBuffer
// owns the observable DOM-facing state transitions.
module mediasourceextensions

const audio_track_byte_capacity = 12 * 1024 * 1024
const video_track_byte_capacity = 150 * 1024 * 1024
const text_track_byte_capacity = 1 * 1024 * 1024

pub enum AppendState {
	waiting_for_segment
	parsing_init_segment
	parsing_media_segment
}

pub struct ProcessorAppendResult {
pub:
	succeeded                    bool
	first_initialization_segment bool
	processed_coded_frames       bool
	duration                     ?f64
	tracks                       []WebMTrackInfo
}

@[heap]
pub struct SourceBufferProcessor {
mut:
	updating_                                       bool
	input_buffer_                                   []u8
	append_state_                                   AppendState
	mode_                                           AppendMode
	buffer_full_flag_                               bool
	parser_                                         &ByteStreamParser = unsafe { nil }
	track_buffers_                                  map[u64]&TrackBuffer
	generate_timestamps_flag_                       bool
	group_start_timestamp_                          ?f64
	group_end_timestamp_                            f64
	timestamp_offset_                               f64
	first_initialization_segment_received_          bool
	pending_initialization_segment_for_change_type_ bool
}

pub fn SourceBufferProcessor.create() &SourceBufferProcessor {
	return &SourceBufferProcessor{}
}

pub fn (mut processor SourceBufferProcessor) set_webm_parser() {
	processor.parser_ = ByteStreamParser.create_webm()
}

pub fn (mut processor SourceBufferProcessor) set_isobmff_parser() {
	processor.parser_ = ByteStreamParser.create_isobmff()
}

pub fn (processor &SourceBufferProcessor) updating() bool {
	return processor.updating_
}

pub fn (mut processor SourceBufferProcessor) set_updating(value bool) {
	processor.updating_ = value
}

pub fn (processor &SourceBufferProcessor) mode() AppendMode {
	return processor.mode_
}

pub fn (mut processor SourceBufferProcessor) set_mode(mode AppendMode) {
	processor.mode_ = mode
}

pub fn (processor &SourceBufferProcessor) is_parsing_media_segment() bool {
	return processor.append_state_ == .parsing_media_segment
}

pub fn (processor &SourceBufferProcessor) generate_timestamps_flag() bool {
	return processor.generate_timestamps_flag_
}

pub fn (mut processor SourceBufferProcessor) set_generate_timestamps_flag(value bool) {
	processor.generate_timestamps_flag_ = value
}

pub fn (processor &SourceBufferProcessor) group_end_timestamp() f64 {
	return processor.group_end_timestamp_
}

pub fn (processor &SourceBufferProcessor) timestamp_offset() f64 {
	return processor.timestamp_offset_
}

pub fn (mut processor SourceBufferProcessor) set_timestamp_offset(value f64) {
	processor.timestamp_offset_ = value
}

pub fn (mut processor SourceBufferProcessor) set_group_start_timestamp(value ?f64) {
	processor.group_start_timestamp_ = value
}

pub fn (mut processor SourceBufferProcessor) set_pending_initialization_segment_for_change_type_flag(value bool) {
	processor.pending_initialization_segment_for_change_type_ = value
}

pub fn (processor &SourceBufferProcessor) first_initialization_segment_received_flag() bool {
	return processor.first_initialization_segment_received_
}

pub fn (mut processor SourceBufferProcessor) set_first_initialization_segment_received_flag(value bool) {
	processor.first_initialization_segment_received_ = value
}

pub fn (processor &SourceBufferProcessor) is_buffer_full() bool {
	return processor.buffer_full_flag_
}

pub fn (processor &SourceBufferProcessor) total_buffered_bytes() int {
	mut total := 0
	for _, track_buffer in processor.track_buffers_ {
		total += track_buffer.demuxer.total_bytes()
	}
	return total
}

pub fn (processor &SourceBufferProcessor) capacity_in_bytes() int {
	mut total := 0
	for _, track_buffer in processor.track_buffers_ {
		total += match track_buffer.demuxer.track.type_ {
			.audio { audio_track_byte_capacity }
			.video { video_track_byte_capacity }
			.text { text_track_byte_capacity }
		}
	}
	return total
}

pub fn (mut processor SourceBufferProcessor) append_to_input_buffer(bytes []u8) {
	processor.input_buffer_ << bytes
}

pub fn (processor &SourceBufferProcessor) input_buffer_length() int {
	return processor.input_buffer_.len
}

pub fn (processor &SourceBufferProcessor) track_buffers() map[u64]&TrackBuffer {
	return processor.track_buffers_.clone()
}

pub fn (processor &SourceBufferProcessor) highest_end_time() f64 {
	mut highest := f64(0)
	for _, track_buffer in processor.track_buffers_ {
		end := track_buffer.demuxer.highest_end_time()
		if end > highest { highest = end }
	}
	return highest
}

pub fn (processor &SourceBufferProcessor) buffered_time_ranges() []MediaSourceTimeRange {
	mut combined := []MediaSourceTimeRange{}
	mut first := true
	for _, track_buffer in processor.track_buffers_ {
		ranges := track_buffer.demuxer.buffered_time_ranges()
		if first {
			combined = ranges.clone()
			first = false
			continue
		}
		mut intersection := []MediaSourceTimeRange{}
		mut left_index := 0
		mut right_index := 0
		for left_index < combined.len && right_index < ranges.len {
			left := combined[left_index]
			right := ranges[right_index]
			start := if left.start > right.start { left.start } else { right.start }
			end := if left.end < right.end { left.end } else { right.end }
			if start < end {
				intersection << MediaSourceTimeRange{ start: start, end: end }
			}
			if left.end < right.end {
				left_index++
			} else {
				right_index++
			}
		}
		combined = intersection.clone()
	}
	return combined
}

fn (mut processor SourceBufferProcessor) drop_input_prefix(length int) {
	if length <= 0 {
		return
	}
	if length >= processor.input_buffer_.len {
		processor.input_buffer_.clear()
		return
	}
	processor.input_buffer_ = processor.input_buffer_[length..].clone()
}

fn is_incomplete_byte_stream_error(err IError) bool {
	return err.msg() in ['incomplete WebM element', 'incomplete ISO BMFF box']
}

fn completed_processor_append(first_initialization bool, processed_frames bool, duration ?f64, tracks []WebMTrackInfo) ProcessorAppendResult {
	return ProcessorAppendResult{
		succeeded: true
		first_initialization_segment: first_initialization
		processed_coded_frames: processed_frames
		duration: duration
		tracks: tracks
	}
}

fn (processor &SourceBufferProcessor) initialization_codecs_are_supported(tracks []WebMTrackInfo) bool {
	for track in tracks {
		if !processor.parser_.supports_track_codec(track) {
			return false
		}
	}
	return true
}

fn (processor &SourceBufferProcessor) repeated_initialization_tracks_match(tracks []WebMTrackInfo) bool {
	if tracks.len != processor.track_buffers_.len {
		return false
	}
	for track in tracks {
		track_buffer := processor.track_buffers_[track.number] or { return false }
		if track_buffer.demuxer.track.type_ != track.type_ {
			return false
		}
	}
	return true
}

// https://w3c.github.io/media-source/#sourcebuffer-segment-parser-loop
pub fn (mut processor SourceBufferProcessor) run_segment_parser_loop() ProcessorAppendResult {
	if processor.parser_ == unsafe { nil } {
		return ProcessorAppendResult{}
	}
	mut first_initialization := false
	mut processed_frames := false
	mut initialization_tracks := []WebMTrackInfo{}
	mut parsed_duration := ?f64(none)
	for {
		if processor.input_buffer_.len == 0 {
			return completed_processor_append(first_initialization, processed_frames, parsed_duration, initialization_tracks)
		}
		if processor.append_state_ == .waiting_for_segment {
			segment_type := processor.parser_.sniff_segment_type(processor.input_buffer_)
			match segment_type {
				.initialization_segment {
					processor.append_state_ = .parsing_init_segment
				}
				.media_segment {
					processor.append_state_ = .parsing_media_segment
				}
				.incomplete {
					return completed_processor_append(first_initialization, processed_frames, parsed_duration, initialization_tracks)
				}
				.unknown {
					ignored := processor.parser_.ignored_element_length(processor.input_buffer_) or {
						if is_incomplete_byte_stream_error(err) {
							return completed_processor_append(first_initialization, processed_frames, parsed_duration, initialization_tracks)
						}
						return ProcessorAppendResult{}
					}
					if ignored == 0 {
						return ProcessorAppendResult{}
					}
					processor.drop_input_prefix(ignored)
					continue
				}
			}
		}
		if processor.append_state_ == .parsing_init_segment {
			result := processor.parser_.parse_initialization_segment(processor.input_buffer_) or {
				if is_incomplete_byte_stream_error(err) {
					return completed_processor_append(first_initialization, processed_frames, parsed_duration, initialization_tracks)
				}
				return ProcessorAppendResult{}
			}
			if result.tracks.len == 0 {
				return ProcessorAppendResult{}
			}
			if !processor.initialization_codecs_are_supported(result.tracks) {
				return ProcessorAppendResult{}
			}
			parsed_duration = result.duration
			if !processor.first_initialization_segment_received_flag() {
				for track in result.tracks {
					processor.track_buffers_[track.number] = TrackBuffer.create(track)
				}
				initialization_tracks = result.tracks.clone()
				processor.set_first_initialization_segment_received_flag(true)
				first_initialization = true
			} else {
				if !processor.repeated_initialization_tracks_match(result.tracks) {
					return ProcessorAppendResult{}
				}
				processor.set_need_random_access_point_on_all_track_buffers(true)
			}
			processor.pending_initialization_segment_for_change_type_ = false
			processor.drop_input_prefix(result.consumed)
			processor.append_state_ = .waiting_for_segment
			continue
		}
		if processor.append_state_ == .parsing_media_segment {
			if !processor.first_initialization_segment_received_flag()
				|| processor.pending_initialization_segment_for_change_type_ {
				return ProcessorAppendResult{}
			}
			result := processor.parser_.parse_media_segment(processor.input_buffer_) or {
				if is_incomplete_byte_stream_error(err) {
					return completed_processor_append(first_initialization, processed_frames, parsed_duration, initialization_tracks)
				}
				return ProcessorAppendResult{}
			}
			processor.run_coded_frame_processing(result.coded_frames)
			processed_frames = processed_frames || result.coded_frames.len > 0
			if !result.completed_segment {
				return completed_processor_append(first_initialization, processed_frames, parsed_duration, initialization_tracks)
			}
			processor.drop_input_prefix(result.consumed)
			processor.append_state_ = .waiting_for_segment
		}
	}
	return ProcessorAppendResult{}
}

// https://w3c.github.io/media-source/#sourcebuffer-reset-parser-state
pub fn (mut processor SourceBufferProcessor) reset_parser_state() {
	if processor.parser_ != unsafe { nil } {
		processor.parser_.reset_parser_state()
	}
	processor.unset_all_track_buffer_timestamps()
	processor.set_need_random_access_point_on_all_track_buffers(true)
	if processor.mode_ == .sequence {
		processor.group_start_timestamp_ = processor.group_end_timestamp_
	}
	processor.input_buffer_.clear()
	processor.append_state_ = .waiting_for_segment
}

fn (mut processor SourceBufferProcessor) run_coded_frame_processing(frames []DemuxedCodedFrame) {
	for input_frame in frames {
		mut frame := input_frame
		decode_timestamp := frame.decoding_timestamp()
		frame.timestamp += processor.timestamp_offset_
		frame.decode_timestamp = decode_timestamp + processor.timestamp_offset_
		mut track_buffer := processor.track_buffers_[frame.track_number] or { continue }
		if last := track_buffer.last_decode_timestamp_ {
			last_duration := track_buffer.last_frame_duration_ or { f64(0) }
			if frame.duration <= 0 && frame.decoding_timestamp() > last {
				frame.duration = frame.decoding_timestamp() - last
			}
			if frame.decoding_timestamp() < last || (last_duration > 0
				&& frame.decoding_timestamp() - last > 2 * last_duration) {
				if processor.mode_ == .segments {
					processor.group_end_timestamp_ = frame.timestamp
				} else {
					processor.group_start_timestamp_ = processor.group_end_timestamp_
				}
				processor.unset_all_track_buffer_timestamps()
				processor.set_need_random_access_point_on_all_track_buffers(true)
				track_buffer = processor.track_buffers_[frame.track_number] or { continue }
			}
		}
		if track_buffer.need_random_access_point_flag_ {
			if !frame.is_keyframe {
				continue
			}
			track_buffer.need_random_access_point_flag_ = false
		}
		frame_end := frame.timestamp + frame.duration
		mut demuxer := track_buffer.demuxer
		if highest_end_timestamp := track_buffer.highest_end_timestamp_ {
			if highest_end_timestamp <= frame.timestamp {
				demuxer.remove_coded_frames_and_dependants_in_range(highest_end_timestamp,
					frame_end)
			}
		} else {
			demuxer.remove_coded_frames_and_dependants_in_range(frame.timestamp, frame_end)
		}
		demuxer.add_coded_frame(frame)
		track_buffer.last_decode_timestamp_ = frame.decoding_timestamp()
		track_buffer.last_frame_duration_ = frame.duration
		if highest := track_buffer.highest_end_timestamp_ {
			if frame_end > highest {
				track_buffer.highest_end_timestamp_ = frame_end
			}
		} else {
			track_buffer.highest_end_timestamp_ = frame_end
		}
		if frame_end > processor.group_end_timestamp_ {
			processor.group_end_timestamp_ = frame_end
		}
	}
}

// https://w3c.github.io/media-source/#dfn-coded-frame-removal
pub fn (mut processor SourceBufferProcessor) run_coded_frame_removal(start f64, end f64) {
	for _, mut track_buffer in processor.track_buffers_ {
		mut demuxer := track_buffer.demuxer
		removed_timestamp := demuxer.remove_coded_frames_and_dependants_in_range_returning_timestamp(start,
			end, track_buffer.last_decode_timestamp_)
		if presentation_timestamp := removed_timestamp {
			if processor.mode_ == .segments {
				processor.group_end_timestamp_ = presentation_timestamp
			} else {
				processor.group_start_timestamp_ = processor.group_end_timestamp_
			}
			processor.unset_all_track_buffer_timestamps()
			processor.set_need_random_access_point_on_all_track_buffers(true)
		}
	}
	if processor.total_buffered_bytes() < processor.capacity_in_bytes() {
		processor.buffer_full_flag_ = false
	}
}

// https://w3c.github.io/media-source/#sourcebuffer-coded-frame-eviction
pub fn (mut processor SourceBufferProcessor) run_coded_frame_eviction(new_data_size int, current_time f64) {
	if processor.track_buffers_.len == 0 {
		return
	}
	current_capacity := processor.capacity_in_bytes()
	projected_bytes := processor.total_buffered_bytes() + new_data_size
	processor.buffer_full_flag_ = projected_bytes > current_capacity
	if !processor.buffer_full_flag_ {
		return
	}

	bytes_to_evict := projected_bytes - current_capacity
	mut bytes_evicted := 0
	for bytes_evicted < bytes_to_evict {
		mut oldest_track_id := ?u64(none)
		mut oldest_timestamp := f64(0)
		for track_id, track_buffer in processor.track_buffers_ {
			candidate := track_buffer.demuxer.earliest_evictable_frame_timestamp(current_time) or {
				continue
			}
			if oldest_track_id == none || candidate < oldest_timestamp {
				oldest_track_id = track_id
				oldest_timestamp = candidate
			}
		}
		track_id := oldest_track_id or { break }
		mut track_buffer := processor.track_buffers_[track_id] or { break }
		mut demuxer := track_buffer.demuxer
		bytes_evicted += demuxer.take_earliest_frame_and_dependants()
	}

	for bytes_evicted < bytes_to_evict {
		mut latest_track_id := ?u64(none)
		mut latest_timestamp := f64(0)
		for track_id, track_buffer in processor.track_buffers_ {
			candidate := track_buffer.demuxer.latest_evictable_frame_timestamp(current_time) or {
				continue
			}
			if latest_track_id == none || candidate > latest_timestamp {
				latest_track_id = track_id
				latest_timestamp = candidate
			}
		}
		track_id := latest_track_id or { break }
		mut track_buffer := processor.track_buffers_[track_id] or { break }
		last_decode_timestamp := track_buffer.last_decode_timestamp_
		mut demuxer := track_buffer.demuxer
		removed_frame := demuxer.take_latest_frame()
		bytes_evicted += removed_frame.byte_size
		if last_decode := last_decode_timestamp {
			if removed_frame.decode_timestamp == last_decode {
				if processor.mode_ == .segments {
					processor.group_end_timestamp_ = latest_timestamp
				} else {
					processor.group_start_timestamp_ = processor.group_end_timestamp_
				}
				processor.unset_all_track_buffer_timestamps()
				processor.set_need_random_access_point_on_all_track_buffers(true)
			}
		}
	}

	if processor.total_buffered_bytes() + new_data_size <= current_capacity {
		processor.buffer_full_flag_ = false
	}
}

fn (mut processor SourceBufferProcessor) unset_all_track_buffer_timestamps() {
	for _, mut track_buffer in processor.track_buffers_ {
		track_buffer.unset_timestamps()
	}
}

fn (mut processor SourceBufferProcessor) set_need_random_access_point_on_all_track_buffers(value bool) {
	for _, mut track_buffer in processor.track_buffers_ {
		track_buffer.set_need_random_access_point_flag(value)
	}
}

pub fn (mut processor SourceBufferProcessor) set_reached_end_of_stream() {
	for _, track_buffer in processor.track_buffers_ {
		mut demuxer := track_buffer.demuxer
		demuxer.set_reached_end_of_stream()
	}
}

pub fn (mut processor SourceBufferProcessor) clear_reached_end_of_stream() {
	for _, track_buffer in processor.track_buffers_ {
		mut demuxer := track_buffer.demuxer
		demuxer.clear_reached_end_of_stream()
	}
}
