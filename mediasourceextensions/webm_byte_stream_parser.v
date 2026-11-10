// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ByteStreamParser.h and WebMByteStreamParser.{h,cpp}. This is
// an incremental EBML parser for the initialization-segment and Cluster subset
// required by the MSE WebM byte-stream format.
module mediasourceextensions

import math

const ebml_header_id = u64(0x1a45dfa3)
const segment_id = u64(0x18538067)
const segment_information_id = u64(0x1549a966)
const tracks_id = u64(0x1654ae6b)
const track_entry_id = u64(0xae)
const cluster_id = u64(0x1f43b675)
const timestamp_id = u64(0xe7)
const simple_block_id = u64(0xa3)
const block_group_id = u64(0xa0)
const block_id = u64(0xa1)
const block_duration_id = u64(0x9b)
const reference_block_id = u64(0xfb)
const cues_id = u64(0x1c53bb6b)
const chapters_id = u64(0x1043a770)
const timestamp_scale_id = u64(0x2ad7b1)
const duration_id = u64(0x4489)
const track_number_id = u64(0xd7)
const track_type_id = u64(0x83)
const codec_id_id = u64(0x86)
const codec_private_id = u64(0x63a2)
const track_language_id = u64(0x22b59c)
const track_language_bcp47_id = u64(0x22b59d)
const track_name_id = u64(0x536e)
const default_duration_id = u64(0x23e383)
const track_flag_default_id = u64(0x88)

pub enum SegmentType {
	incomplete
	unknown
	initialization_segment
	media_segment
}

pub enum MediaSourceTrackType {
	audio
	video
	text
}

pub enum MediaSourceTrackKind {
	none
	alternative
	captions
	descriptions
	main
	main_desc
	metadata
	sign
	subtitles
	translation
	commentary
}

pub fn (kind MediaSourceTrackKind) name() string {
	return match kind {
		.none { '' }
		.alternative { 'alternative' }
		.captions { 'captions' }
		.descriptions { 'descriptions' }
		.main { 'main' }
		.main_desc { 'maindesc' }
		.metadata { 'metadata' }
		.sign { 'sign' }
		.subtitles { 'subtitles' }
		.translation { 'translation' }
		.commentary { 'commentary' }
	}
}

pub struct WebMTrackInfo {
pub:
	number           u64
	type_            MediaSourceTrackType
	codec_id         string
	codec_private    []u8
	language         string
	label            string
	default_duration f64
	kind             MediaSourceTrackKind
	is_default       bool = true
}

fn webm_track_codec_is_supported(track WebMTrackInfo) bool {
	return match track.codec_id {
		'V_VP8', 'V_VP9', 'V_AV1' { track.type_ == .video }
		'A_VORBIS', 'A_OPUS' { track.type_ == .audio }
		else { track.type_ == .text }
	}
}

pub struct DemuxedCodedFrame {
pub:
	track_number u64
	is_keyframe  bool
	data         []u8
pub mut:
	codec_id               string
	new_codec_configuration ?[]u8
	timestamp        f64
	decode_timestamp ?f64
	duration         f64
}

pub fn (frame &DemuxedCodedFrame) decoding_timestamp() f64 {
	return frame.decode_timestamp or { frame.timestamp }
}

pub struct WebMInitializationSegmentResult {
pub:
	consumed int
	duration ?f64
	tracks   []WebMTrackInfo
}

pub struct WebMMediaSegmentResult {
pub:
	consumed          int
	completed_segment bool
	coded_frames      []DemuxedCodedFrame
}

struct EBMLElementHeader {
	id         u64
	data_start int
	data_end   int
	size_known bool
}

fn webm_incomplete() IError {
	return error('incomplete WebM element')
}

fn ebml_vint_length(first u8) !int {
	mut mask := u8(0x80)
	for length in 1 .. 9 {
		if first & mask != 0 {
			return length
		}
		mask >>= 1
	}
	return error('Invalid zero EBML variable-length integer')
}

fn read_ebml_id(bytes []u8, offset int) !(u64, int) {
	if offset >= bytes.len {
		return webm_incomplete()
	}
	length := ebml_vint_length(bytes[offset])!
	if offset + length > bytes.len {
		return webm_incomplete()
	}
	mut value := u64(0)
	for byte in bytes[offset..offset + length] {
		value = (value << 8) | u64(byte)
	}
	return value, offset + length
}

fn read_ebml_size(bytes []u8, offset int) !(?u64, int) {
	if offset >= bytes.len {
		return webm_incomplete()
	}
	length := ebml_vint_length(bytes[offset])!
	if offset + length > bytes.len {
		return webm_incomplete()
	}
	marker := u8(0x80) >> (length - 1)
	mut value := u64(bytes[offset] & (marker - 1))
	for byte in bytes[offset + 1..offset + length] {
		value = (value << 8) | u64(byte)
	}
	unknown_value := (u64(1) << (7 * length)) - 1
	if value == unknown_value {
		return ?u64(none), offset + length
	}
	return value, offset + length
}

fn read_ebml_element_header(bytes []u8, offset int) !EBMLElementHeader {
	id, after_id := read_ebml_id(bytes, offset)!
	size, data_start := read_ebml_size(bytes, after_id)!
	if value := size {
		if value > u64(max_int - data_start) {
			return error('EBML element size is too large')
		}
		return EBMLElementHeader{
			id: id
			data_start: data_start
			data_end: data_start + int(value)
			size_known: true
		}
	}
	return EBMLElementHeader{
		id: id
		data_start: data_start
		data_end: bytes.len
	}
}

fn require_complete_element(bytes []u8, element EBMLElementHeader) ! {
	if !element.size_known || element.data_end > bytes.len {
		return webm_incomplete()
	}
}

fn read_ebml_uint(bytes []u8, element EBMLElementHeader) !u64 {
	require_complete_element(bytes, element)!
	length := element.data_end - element.data_start
	if length < 1 || length > 8 {
		return error('Invalid EBML unsigned integer width')
	}
	mut value := u64(0)
	for byte in bytes[element.data_start..element.data_end] {
		value = (value << 8) | u64(byte)
	}
	return value
}

fn read_ebml_float(bytes []u8, element EBMLElementHeader) !f64 {
	require_complete_element(bytes, element)!
	length := element.data_end - element.data_start
	if length == 4 {
		return f64(math.f32_from_bits(u32(read_ebml_uint(bytes, element)!)))
	}
	if length == 8 {
		return math.f64_from_bits(read_ebml_uint(bytes, element)!)
	}
	return error('Invalid EBML floating-point width')
}

fn read_ebml_string(bytes []u8, element EBMLElementHeader) !string {
	if element.data_end - element.data_start > maximum_metadata_string_size {
		return error('String element is too large')
	}
	require_complete_element(bytes, element)!
	return bytes[element.data_start..element.data_end].bytestr()
}

fn parse_webm_track_entry(bytes []u8, entry EBMLElementHeader) !WebMTrackInfo {
	require_complete_element(bytes, entry)!
	mut position := entry.data_start
	mut number := u64(0)
	mut track_type := u64(0)
	mut codec_id := ''
	mut codec_private := []u8{}
	mut language := ''
	mut language_bcp47 := ?string(none)
	mut label := ''
	mut default_duration := f64(0)
	mut is_default := true
	for position < entry.data_end {
		child := read_ebml_element_header(bytes, position)!
		require_complete_element(bytes, child)!
		match child.id {
			track_number_id {
				number = read_ebml_uint(bytes, child)!
			}
			track_type_id {
				track_type = read_ebml_uint(bytes, child)!
			}
			codec_id_id {
				codec_id = read_ebml_string(bytes, child)!
			}
			codec_private_id {
				if child.data_end - child.data_start > maximum_codec_configuration_size {
					return error("Track's CodecPrivate element is too large")
				}
				codec_private = bytes[child.data_start..child.data_end].clone()
			}
			track_language_id {
				language = read_ebml_string(bytes, child)!
			}
			track_language_bcp47_id {
				language_bcp47 = read_ebml_string(bytes, child)!
			}
			track_name_id {
				label = read_ebml_string(bytes, child)!
			}
			default_duration_id {
				default_duration = f64(read_ebml_uint(bytes, child)!) / 1_000_000_000.0
			}
			track_flag_default_id {
				is_default = read_ebml_uint(bytes, child)! != 0
			}
			else {}
		}
		position = child.data_end
	}
	if number == 0 || codec_id == '' {
		return error('WebM TrackEntry is missing its number or codec')
	}
	type_ := match track_type {
		1 { MediaSourceTrackType.video }
		2 { MediaSourceTrackType.audio }
		17, 33 { MediaSourceTrackType.text }
		else {
			return error('Unsupported WebM track type ${track_type}')
		}
	}
	return WebMTrackInfo{
		number: number
		type_: type_
		codec_id: codec_id
		codec_private: codec_private
		language: if preferred := language_bcp47 {
			if preferred == 'und' { '' } else { preferred }
		} else if language == 'und' { '' } else { language }
		label: label
		default_duration: default_duration
		is_default: is_default
	}
}

fn webm_track_kind(track WebMTrackInfo, is_first_of_type bool) MediaSourceTrackKind {
	if track.type_ == .text {
		return match track.codec_id {
			'D_WEBVTT/captions' { .captions }
			'D_WEBVTT/subtitles' { .subtitles }
			'D_WEBVTT/descriptions' { .descriptions }
			else {
				if track.codec_id.starts_with('D_WEBVTT/') {
					MediaSourceTrackKind.metadata
				} else {
					MediaSourceTrackKind.subtitles
				}
			}
		}
	}
	if track.is_default {
		return .main
	}
	if !is_first_of_type {
		return .translation
	}
	return .none
}

@[heap]
pub struct WebMByteStreamParser {
mut:
	timestamp_scale u64 = 1_000_000
	duration_       ?f64
	tracks_         map[u64]WebMTrackInfo
	active_codec_configurations map[u64][]u8
	cluster_has_been_read bool
}

pub fn WebMByteStreamParser.create() &WebMByteStreamParser {
	return &WebMByteStreamParser{}
}

pub fn (parser &WebMByteStreamParser) sniff_segment_type(bytes []u8) SegmentType {
	id, _ := read_ebml_id(bytes, 0) or { return .incomplete }
	return match id {
		ebml_header_id { .initialization_segment }
		cluster_id { .media_segment }
		else { .unknown }
	}
}

pub fn (parser &WebMByteStreamParser) ignored_element_length(bytes []u8) !int {
	header := read_ebml_element_header(bytes, 0)!
	if header.id in [ebml_header_id, cluster_id] {
		return 0
	}
	if parser.cluster_has_been_read && header.id !in [cues_id, chapters_id] {
		return 0
	}
	require_complete_element(bytes, header)!
	return header.data_end
}

pub fn (mut parser WebMByteStreamParser) parse_initialization_segment(bytes []u8) !WebMInitializationSegmentResult {
	header := read_ebml_element_header(bytes, 0)!
	if header.id != ebml_header_id {
		return error('WebM initialization segment must start with an EBML header')
	}
	require_complete_element(bytes, header)!
	segment := read_ebml_element_header(bytes, header.data_end)!
	if segment.id != segment_id {
		return error('Expected a Segment after the EBML header')
	}
	mut position := segment.data_start
	mut found_info := false
	mut found_tracks := false
	mut timestamp_scale := u64(1_000_000)
	mut duration_ticks := ?f64(none)
	mut tracks := map[u64]WebMTrackInfo{}
	for !found_info || !found_tracks {
		child := read_ebml_element_header(bytes, position)!
		if child.id in [ebml_header_id, cluster_id] {
			break
		}
		require_complete_element(bytes, child)!
		if child.id == segment_information_id {
			if found_info {
				return error('Duplicate WebM Segment Information element')
			}
			mut info_position := child.data_start
			for info_position < child.data_end {
				field := read_ebml_element_header(bytes, info_position)!
				require_complete_element(bytes, field)!
				if field.id == timestamp_scale_id {
					timestamp_scale = read_ebml_uint(bytes, field)!
				} else if field.id == duration_id {
					duration_ticks = read_ebml_float(bytes, field)!
				}
				info_position = field.data_end
			}
			found_info = true
		} else if child.id == tracks_id {
			if !found_info {
				return error('WebM Tracks appeared before Segment Information')
			}
			if found_tracks {
				return error('Duplicate WebM Tracks element')
			}
			mut track_position := child.data_start
			for track_position < child.data_end {
				entry := read_ebml_element_header(bytes, track_position)!
				require_complete_element(bytes, entry)!
				if entry.id == track_entry_id {
					parsed_track := parse_webm_track_entry(bytes, entry)!
					is_first_of_type := !tracks.values().any(it.type_ == parsed_track.type_)
					track := WebMTrackInfo{
						...parsed_track
						kind: webm_track_kind(parsed_track, is_first_of_type)
					}
					if track.number in tracks {
						return error('Duplicate WebM track number ${track.number}')
					}
					tracks[track.number] = track
				}
				track_position = entry.data_end
			}
			found_tracks = true
		}
		position = child.data_end
	}
	if !found_info || !found_tracks {
		return webm_incomplete()
	}
	parser.timestamp_scale = timestamp_scale
	parser.duration_ = if ticks := duration_ticks {
		ticks * f64(timestamp_scale) / 1_000_000_000.0
	} else {
		none
	}
	parser.tracks_ = tracks.clone()
	parser.active_codec_configurations.clear()
	parser.cluster_has_been_read = false
	return WebMInitializationSegmentResult{
		consumed: position
		duration: parser.duration_
		tracks: tracks.values()
	}
}

fn (mut parser WebMByteStreamParser) configure_frame(mut frame DemuxedCodedFrame, track WebMTrackInfo) {
	frame.codec_id = track.codec_id
	if active := parser.active_codec_configurations[track.number] {
		if active == track.codec_private {
			return
		}
	}
	frame.new_codec_configuration = track.codec_private.clone()
	parser.active_codec_configurations[track.number] = track.codec_private.clone()
}

fn parse_webm_block(bytes []u8, element EBMLElementHeader, cluster_timecode i64, timestamp_scale u64, duration f64, keyframe bool) !DemuxedCodedFrame {
	require_complete_element(bytes, element)!
	track_number, after_track := read_ebml_size(bytes, element.data_start)!
	number := track_number or { return error('Unknown-size WebM track number') }
	if after_track + 3 > element.data_end {
		return webm_incomplete()
	}
	relative_raw := (u16(bytes[after_track]) << 8) | u16(bytes[after_track + 1])
	relative_timecode := i16(relative_raw)
	flags := bytes[after_track + 2]
	if flags & 0x06 != 0 {
		return error('WebM block lacing is not supported')
	}
	return DemuxedCodedFrame{
		track_number: number
		timestamp: f64(cluster_timecode + i64(relative_timecode)) * f64(timestamp_scale) / 1_000_000_000.0
		decode_timestamp: f64(cluster_timecode + i64(relative_timecode)) * f64(timestamp_scale) / 1_000_000_000.0
		duration: duration
		is_keyframe: keyframe || (flags & 0x80 != 0)
		data: bytes[after_track + 3..element.data_end].clone()
	}
}

pub fn (mut parser WebMByteStreamParser) parse_media_segment(bytes []u8) !WebMMediaSegmentResult {
	cluster := read_ebml_element_header(bytes, 0)!
	if cluster.id != cluster_id {
		return error('WebM media segment must begin with a Cluster')
	}
	require_complete_element(bytes, cluster)!
	mut position := cluster.data_start
	timecode_element := read_ebml_element_header(bytes, position)!
	if timecode_element.id != timestamp_id {
		return error('WebM Cluster must begin with a Timecode')
	}
	cluster_timecode := i64(read_ebml_uint(bytes, timecode_element)!)
	parser.cluster_has_been_read = true
	position = timecode_element.data_end
	mut frames := []DemuxedCodedFrame{}
	mut seen_tracks := map[u64]bool{}
	mut last_timestamp := -math.inf(1)
	for position < cluster.data_end {
		element := read_ebml_element_header(bytes, position)!
		require_complete_element(bytes, element)!
		if element.id == simple_block_id {
			probe_track, _ := read_ebml_size(bytes, element.data_start)!
			track_number := probe_track or { return error('Invalid WebM block track') }
			track := parser.tracks_[track_number] or { return error('Unknown WebM block track') }
			mut frame := parse_webm_block(bytes, element, cluster_timecode, parser.timestamp_scale, track.default_duration, false)!
			parser.configure_frame(mut frame, track)
			if frame.timestamp < last_timestamp {
				return error('WebM block timestamps are not increasing')
			}
			last_timestamp = frame.timestamp
			seen_tracks[frame.track_number] = true
			frames << frame
		} else if element.id == block_group_id {
			mut group_position := element.data_start
			mut block := ?EBMLElementHeader(none)
			mut duration := f64(0)
			mut has_reference := false
			for group_position < element.data_end {
				child := read_ebml_element_header(bytes, group_position)!
				require_complete_element(bytes, child)!
				if child.id == block_id {
					block = child
				} else if child.id == block_duration_id {
					duration = f64(read_ebml_uint(bytes, child)!) * f64(parser.timestamp_scale) / 1_000_000_000.0
				} else if child.id == reference_block_id {
					has_reference = true
				}
				group_position = child.data_end
			}
			block_element := block or { return error('WebM BlockGroup has no Block') }
			track_number, _ := read_ebml_size(bytes, block_element.data_start)!
			number := track_number or { return error('Invalid WebM block track') }
			track := parser.tracks_[number] or { return error('Unknown WebM block track') }
			mut frame := parse_webm_block(bytes, block_element, cluster_timecode, parser.timestamp_scale, duration, !has_reference)!
			parser.configure_frame(mut frame, track)
			if frame.timestamp < last_timestamp {
				return error('WebM block timestamps are not increasing')
			}
			last_timestamp = frame.timestamp
			seen_tracks[frame.track_number] = true
			frames << frame
		}
		position = element.data_end
	}
	for track_number, _ in parser.tracks_ {
		if track_number !in seen_tracks {
			return error('WebM Cluster has no block for track ${track_number}')
		}
	}
	return WebMMediaSegmentResult{
		consumed: cluster.data_end
		completed_segment: true
		coded_frames: frames
	}
}

pub fn (parser &WebMByteStreamParser) duration() ?f64 {
	return parser.duration_
}

pub fn (parser &WebMByteStreamParser) tracks() []WebMTrackInfo {
	return parser.tracks_.values()
}

pub fn (parser &WebMByteStreamParser) codec_id_for_track(track_number u64) string {
	track := parser.tracks_[track_number] or { return '' }
	return track.codec_id
}

pub fn (parser &WebMByteStreamParser) codec_initialization_data_for_track(track_number u64) []u8 {
	track := parser.tracks_[track_number] or { return [] }
	return track.codec_private.clone()
}

fn (parser &WebMByteStreamParser) tracks_for_type(type_ MediaSourceTrackType) []WebMTrackInfo {
	return parser.tracks().filter(it.type_ == type_)
}

pub fn (parser &WebMByteStreamParser) video_tracks() []WebMTrackInfo {
	return parser.tracks_for_type(.video)
}

pub fn (parser &WebMByteStreamParser) audio_tracks() []WebMTrackInfo {
	return parser.tracks_for_type(.audio)
}

pub fn (parser &WebMByteStreamParser) text_tracks() []WebMTrackInfo {
	return parser.tracks_for_type(.text)
}

pub fn (mut parser WebMByteStreamParser) reset_parser_state() {
	// Ladybird clears its retained partial media-segment reader here. This
	// parser reparses the retained input prefix on each call, so it has no
	// equivalent per-segment cursor to clear; initialization state is kept.
	_ = parser
}
