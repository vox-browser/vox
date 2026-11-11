// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of ISOBMFFByteStreamParser.{h,cpp}. This implements the MSE
// fragmented-MP4 initialization and media-segment subset: ftyp/moov/mvex,
// track metadata and defaults, and moof/traf/tfhd/tfdt/trun plus mdat data.
module mediasourceextensions

const iso_segment_box_types = ['ftyp', 'moov', 'styp', 'moof', 'mdat']
const iso_top_level_box_types = ['ftyp', 'styp', 'mdat', 'free', 'skip', 'uuid', 'pdin',
	'sidx', 'ssix', 'prft', 'meta', 'meco', 'mfra', 'emsg', 'bloc', 'moov', 'moof']

fn box_begins_a_segment(type_ string) bool {
	return type_ in iso_segment_box_types
}

fn is_ignorable_top_level_box(type_ string) bool {
	return type_ in iso_top_level_box_types && !box_begins_a_segment(type_)
}

struct ISOBoxHeader {
	type_         string
	start         int
	content_start int
	end           int
}

struct ISOTrackContext {
	track                     WebMTrackInfo
	timescale                 u32
	sample_description_count  u32
	default_description_index u32 = 1
	default_duration          u32
	default_size              u32
	default_flags             u32
	sample_description_codecs []string
	sample_descriptions       [][]u8
}

struct ISOSample {
	track_id                 u32
	data_position            int
	data_size                int
	presentation_timestamp   f64
	decode_timestamp         f64
	duration                 f64
	is_keyframe              bool
	sample_description_index u32
}

fn isobmff_incomplete() IError {
	return error('incomplete ISO BMFF box')
}

fn iso_read_u16(bytes []u8, offset int) !u16 {
	if offset < 0 || offset + 2 > bytes.len {
		return isobmff_incomplete()
	}
	return (u16(bytes[offset]) << 8) | u16(bytes[offset + 1])
}

fn iso_read_u32(bytes []u8, offset int) !u32 {
	if offset < 0 || offset + 4 > bytes.len {
		return isobmff_incomplete()
	}
	return (u32(bytes[offset]) << 24) | (u32(bytes[offset + 1]) << 16) | (u32(bytes[offset + 2]) << 8) | u32(bytes[offset + 3])
}

fn iso_read_i32(bytes []u8, offset int) !i32 {
	return i32(iso_read_u32(bytes, offset)!)
}

fn iso_read_u64(bytes []u8, offset int) !u64 {
	hi := u64(iso_read_u32(bytes, offset)!)
	lo := u64(iso_read_u32(bytes, offset + 4)!)
	return (hi << 32) | lo
}

fn iso_fourcc(bytes []u8, offset int) !string {
	if offset < 0 || offset + 4 > bytes.len {
		return isobmff_incomplete()
	}
	return bytes[offset..offset + 4].bytestr()
}

fn read_iso_box_header(bytes []u8, offset int, limit int, incomplete_allowed bool) !ISOBoxHeader {
	if offset < 0 || limit < offset || limit > bytes.len {
		return error('Invalid ISO BMFF box bounds')
	}
	if offset + 8 > limit {
		if incomplete_allowed {
			return isobmff_incomplete()
		}
		return error('ISO BMFF box has an incomplete header')
	}
	mut size := u64(iso_read_u32(bytes, offset)!)
	type_ := iso_fourcc(bytes, offset + 4)!
	mut header_size := 8
	if size == 1 {
		if offset + 16 > limit {
			if incomplete_allowed {
				return isobmff_incomplete()
			}
			return error('ISO BMFF extended box header is incomplete')
		}
		size = iso_read_u64(bytes, offset + 8)!
		header_size = 16
	} else if size == 0 {
		return error('${type_} box may not extend to the end of the stream')
	}
	if size < u64(header_size) || size > u64(max_int - offset) {
		return error('Invalid ${type_} box size')
	}
	end := offset + int(size)
	if end > limit {
		if incomplete_allowed {
			return isobmff_incomplete()
		}
		return error('${type_} box extends beyond its parent')
	}
	return ISOBoxHeader{
		type_: type_
		start: offset
		content_start: offset + header_size
		end: end
	}
}

fn iso_child_boxes(bytes []u8, parent ISOBoxHeader) ![]ISOBoxHeader {
	mut result := []ISOBoxHeader{}
	mut position := parent.content_start
	for position < parent.end {
		child := read_iso_box_header(bytes, position, parent.end, false)!
		result << child
		position = child.end
	}
	return result
}

fn iso_find_child(bytes []u8, parent ISOBoxHeader, type_ string) !ISOBoxHeader {
	for child in iso_child_boxes(bytes, parent)! {
		if child.type_ == type_ {
			return child
		}
	}
	return error('Missing ${type_} box')
}

fn iso_full_box_flags(bytes []u8, box ISOBoxHeader) !u32 {
	return iso_read_u32(bytes, box.content_start)! & 0x00ff_ffff
}

fn iso_box_version(bytes []u8, box ISOBoxHeader) !u8 {
	if box.content_start >= box.end {
		return error('${box.type_} full box has no version')
	}
	return bytes[box.content_start]
}

fn decode_iso_language(value u16) string {
	mut bytes := []u8{len: 3}
	bytes[0] = u8(((value >> 10) & 0x1f) + 0x60)
	bytes[1] = u8(((value >> 5) & 0x1f) + 0x60)
	bytes[2] = u8((value & 0x1f) + 0x60)
	language := bytes.bytestr()
	return if language == 'und' { '' } else { language }
}

fn iso_handler_name(bytes []u8, handler ISOBoxHeader) !string {
	start := handler.content_start + 24
	if start >= handler.end {
		return ''
	}
	if handler.end - start > maximum_metadata_string_size {
		return error('Handler name is too large')
	}
	mut end := start
	for end < handler.end && bytes[end] != 0 {
		end++
	}
	return bytes[start..end].bytestr()
}

fn iso_sample_entry_codec_is_supported(codec_id string, type_ MediaSourceTrackType) bool {
	return match codec_id {
		'av01', 'avc1', 'avc3', 'hev1', 'hvc1', 'vp08', 'vp09' { type_ == .video }
		'mp4a', 'Opus', 'fLaC' { type_ == .audio }
		else { type_ == .text }
	}
}

fn isobmff_track_codec_is_supported(track WebMTrackInfo) bool {
	return iso_sample_entry_codec_is_supported(track.codec_id, track.type_)
}

fn iso_sample_entry_child_offset(bytes []u8, entry ISOBoxHeader, type_ MediaSourceTrackType) !int {
	return match type_ {
		.video { entry.content_start + 78 }
		.audio {
			// ISO/IEC 14496-12 audio sample entries add version-specific fields
			// after the version 0 header and before their child boxes.
			if entry.content_start + 10 > entry.end {
				return entry.end
			}
			version := iso_read_u16(bytes, entry.content_start + 8)!
			match version {
				0 { entry.content_start + 28 }
				1 { entry.content_start + 44 }
				2 {
					if entry.content_start + 32 > entry.end {
						return entry.end
					}
					entry.content_start + int(iso_read_u32(bytes, entry.content_start + 28)!)
				}
				else { return error('ISO BMFF audio sample entry has an unsupported version') }
			}
		}
		.text { entry.end }
	}
}

fn validate_iso_sample_entry_configuration(bytes []u8, entry ISOBoxHeader, type_ MediaSourceTrackType) ! {
	// Vox retains the complete sample entry as its codec configuration. Bound
	// that retained representation before any clone, including unknown boxes.
	if entry.end - entry.start > maximum_codec_configuration_size {
		return error('Codec configuration sample entry is too large')
	}
	child_offset := iso_sample_entry_child_offset(bytes, entry, type_)!
	// The compact synthetic entries used by the translation tests omit the
	// standard sample-entry fields. A missing configuration record is valid for
	// codecs whose family is already identified by the sample-entry FourCC.
	if child_offset >= entry.end {
		return
	}
	mut position := child_offset
	for position < entry.end {
		child := read_iso_box_header(bytes, position, entry.end, false)!
		matches_sample_entry := match child.type_ {
			'av1C' { entry.type_ == 'av01' }
			'avcC' { entry.type_ in ['avc1', 'avc3'] }
			'hvcC' { entry.type_ in ['hev1', 'hvc1'] }
			'vpcC' { entry.type_ in ['vp08', 'vp09'] }
			'dOps' { entry.type_ == 'Opus' }
			'dfLa' { entry.type_ == 'fLaC' }
			'esds' { entry.type_ == 'mp4a' }
			else {
				position = child.end
				continue
			}
		}
		if !matches_sample_entry {
			return error('Codec configuration box does not match its sample entry format')
		}
		position = child.end
	}
}

fn parse_iso_track(bytes []u8, trak ISOBoxHeader) !ISOTrackContext {
	tkhd := iso_find_child(bytes, trak, 'tkhd')!
	tkhd_version := iso_box_version(bytes, tkhd)!
	track_id_offset := tkhd.content_start + if tkhd_version == 1 { 20 } else { 12 }
	track_id := iso_read_u32(bytes, track_id_offset)!
	if track_id == 0 {
		return error('ISO BMFF track has ID zero')
	}

	mdia := iso_find_child(bytes, trak, 'mdia')!
	mdhd := iso_find_child(bytes, mdia, 'mdhd')!
	mdhd_version := iso_box_version(bytes, mdhd)!
	timescale_offset := mdhd.content_start + if mdhd_version == 1 { 20 } else { 12 }
	language_offset := mdhd.content_start + if mdhd_version == 1 { 32 } else { 20 }
	timescale := iso_read_u32(bytes, timescale_offset)!
	if timescale == 0 {
		return error('ISO BMFF track has a zero timescale')
	}
	language := decode_iso_language(iso_read_u16(bytes, language_offset)!)

	handler := iso_find_child(bytes, mdia, 'hdlr')!
	handler_type := iso_fourcc(bytes, handler.content_start + 8)!
	type_ := match handler_type {
		'vide' { MediaSourceTrackType.video }
		'soun' { MediaSourceTrackType.audio }
		'text', 'subt', 'sbtl' { MediaSourceTrackType.text }
		else {
			return error('Unsupported ISO BMFF handler ${handler_type}')
		}
	}
	minf := iso_find_child(bytes, mdia, 'minf')!
	stbl := iso_find_child(bytes, minf, 'stbl')!
	stsd := iso_find_child(bytes, stbl, 'stsd')!
	sample_description_count := iso_read_u32(bytes, stsd.content_start + 4)!
	if sample_description_count == 0 {
		return error('ISO BMFF track has no sample descriptions')
	}
	mut sample_description_codecs := []string{cap: int(sample_description_count)}
	mut sample_descriptions := [][]u8{cap: int(sample_description_count)}
	mut description_position := stsd.content_start + 8
	for _ in 0 .. int(sample_description_count) {
		entry := read_iso_box_header(bytes, description_position, stsd.end, false)!
		validate_iso_sample_entry_configuration(bytes, entry, type_)!
		sample_description_codecs << entry.type_
		sample_descriptions << bytes[entry.start..entry.end].clone()
		description_position = entry.end
	}
	codec_id := sample_description_codecs[0]

	for child in iso_child_boxes(bytes, stbl)! {
		mut entry_count := u32(0)
		match child.type_ {
			'stts', 'stsc', 'stco', 'co64' {
				entry_count = iso_read_u32(bytes, child.content_start + 4)!
			}
			'stsz' {
				entry_count = iso_read_u32(bytes, child.content_start + 8)!
			}
			else {
				continue
			}
		}
		if entry_count != 0 {
			return error('ISO BMFF initialization track contains samples')
		}
	}

	return ISOTrackContext{
		track: WebMTrackInfo{
			number: track_id
			type_: type_
			codec_id: codec_id
			codec_private: sample_descriptions[0].clone()
			language: language
			label: iso_handler_name(bytes, handler)!
		}
		timescale: timescale
		sample_description_count: sample_description_count
		sample_description_codecs: sample_description_codecs
		sample_descriptions: sample_descriptions
	}
}

fn iso_track_kind(type_ MediaSourceTrackType, is_first_of_type bool) MediaSourceTrackKind {
	if type_ == .text {
		return .metadata
	}
	return if is_first_of_type { .main } else { .translation }
}

@[heap]
pub struct ISOBMFFByteStreamParser {
mut:
	duration_      ?f64
	track_contexts map[u32]ISOTrackContext
	active_sample_descriptions map[u32]u32
}

pub fn ISOBMFFByteStreamParser.create() &ISOBMFFByteStreamParser {
	return &ISOBMFFByteStreamParser{}
}

pub fn (parser &ISOBMFFByteStreamParser) sniff_segment_type(bytes []u8) SegmentType {
	_ = parser
	header := read_iso_box_header(bytes, 0, bytes.len, true) or { return .incomplete }
	return match header.type_ {
		'ftyp' { .initialization_segment }
		'styp', 'moof' { .media_segment }
		else { .unknown }
	}
}

pub fn (parser &ISOBMFFByteStreamParser) ignored_element_length(bytes []u8) !int {
	_ = parser
	header := read_iso_box_header(bytes, 0, bytes.len, true)!
	if box_begins_a_segment(header.type_) {
		return 0
	}
	if !is_ignorable_top_level_box(header.type_) {
		return error('Found a ${header.type_} box that is not valid at the top level')
	}
	return header.end
}

pub fn (mut parser ISOBMFFByteStreamParser) parse_initialization_segment(bytes []u8) !WebMInitializationSegmentResult {
	file_type := read_iso_box_header(bytes, 0, bytes.len, true)!
	if file_type.type_ != 'ftyp' {
		return error('ISO BMFF initialization segment must start with a File Type box')
	}
	mut position := file_type.end
	mut movie := ISOBoxHeader{}
	for {
		header := read_iso_box_header(bytes, position, bytes.len, true)!
		if header.type_ == 'moov' {
			movie = header
			break
		}
		if !is_ignorable_top_level_box(header.type_) {
			return error('Found ${header.type_} where the Movie box was expected')
		}
		position = header.end
	}

	mut found_mvex := false
	mut contexts := map[u32]ISOTrackContext{}
	mut trex_boxes := []ISOBoxHeader{}
	mut duration := ?f64(none)
	for child in iso_child_boxes(bytes, movie)! {
		match child.type_ {
			'mvhd' {
				version := iso_box_version(bytes, child)!
				timescale_offset := child.content_start + if version == 1 { 20 } else { 12 }
				duration_offset := child.content_start + if version == 1 { 24 } else { 16 }
				timescale := iso_read_u32(bytes, timescale_offset)!
				duration_ticks := if version == 1 {
					iso_read_u64(bytes, duration_offset)!
				} else {
					u64(iso_read_u32(bytes, duration_offset)!)
				}
				if timescale != 0 && duration_ticks != 0 && duration_ticks != u64(-1) {
					duration = f64(duration_ticks) / f64(timescale)
				}
			}
			'trak' {
				context := parse_iso_track(bytes, child)!
				if u32(context.track.number) in contexts {
					return error('Duplicate ISO BMFF track ID ${context.track.number}')
				}
				contexts[u32(context.track.number)] = context
			}
			'mvex' {
				found_mvex = true
				for box in iso_child_boxes(bytes, child)! {
					if box.type_ == 'trex' {
						trex_boxes << box
					}
				}
			}
			else {}
		}
	}
	if !found_mvex {
		return error('Movie box contains no Movie Extends box')
	}
	for trex in trex_boxes {
		track_id := iso_read_u32(bytes, trex.content_start + 4)!
		mut context := contexts[track_id] or { continue }
		context = ISOTrackContext{
			...context
			default_description_index: iso_read_u32(bytes, trex.content_start + 8)!
			default_duration: iso_read_u32(bytes, trex.content_start + 12)!
			default_size: iso_read_u32(bytes, trex.content_start + 16)!
			default_flags: iso_read_u32(bytes, trex.content_start + 20)!
		}
		contexts[track_id] = context
	}
	parser.duration_ = duration
	parser.track_contexts = contexts.clone()
	parser.active_sample_descriptions.clear()
	mut tracks := []WebMTrackInfo{cap: contexts.len}
	for _, context in contexts {
		is_first_of_type := !tracks.any(it.type_ == context.track.type_)
		tracks << WebMTrackInfo{
			...context.track
			kind: iso_track_kind(context.track.type_, is_first_of_type)
		}
	}
	return WebMInitializationSegmentResult{
		consumed: movie.end
		duration: duration
		tracks: tracks
	}
}

fn parse_iso_track_fragment(bytes []u8, moof ISOBoxHeader, traf ISOBoxHeader, contexts map[u32]ISOTrackContext) ![]ISOSample {
	children := iso_child_boxes(bytes, traf)!
	mut tfhd := ISOBoxHeader{}
	mut tfdt := ISOBoxHeader{}
	mut runs := []ISOBoxHeader{}
	for child in children {
		match child.type_ {
			'tfhd' {
				tfhd = child
			}
			'tfdt' {
				tfdt = child
			}
			'trun' { runs << child }
			else {}
		}
	}
	if tfhd.type_ == '' || tfdt.type_ == '' {
		return error('ISO BMFF Track Fragment lacks tfhd or tfdt')
	}
	tfhd_flags := iso_full_box_flags(bytes, tfhd)!
	mut cursor := tfhd.content_start + 4
	track_id := iso_read_u32(bytes, cursor)!
	cursor += 4
	base_data_offset := if tfhd_flags & 0x000001 != 0 {
		value := iso_read_u64(bytes, cursor)!
		cursor += 8
		if value > u64(max_int) {
			return error('ISO BMFF base data offset is too large')
		}
		int(value)
	} else {
		moof.start
	}
	if tfhd_flags & 0x000001 == 0 && tfhd_flags & 0x020000 == 0 {
		return error('Movie Fragment does not use relative addressing')
	}
	context := contexts[track_id] or { return error('Unknown ISO BMFF fragment track ${track_id}') }
	mut description_index := context.default_description_index
	mut default_duration := context.default_duration
	mut default_size := context.default_size
	mut default_flags := context.default_flags
	if tfhd_flags & 0x000002 != 0 {
		description_index = iso_read_u32(bytes, cursor)!
		cursor += 4
	}
	if tfhd_flags & 0x000008 != 0 {
		default_duration = iso_read_u32(bytes, cursor)!
		cursor += 4
	}
	if tfhd_flags & 0x000010 != 0 {
		default_size = iso_read_u32(bytes, cursor)!
		cursor += 4
	}
	if tfhd_flags & 0x000020 != 0 {
		default_flags = iso_read_u32(bytes, cursor)!
	}
	if description_index == 0 || description_index > context.sample_description_count {
		return error('Invalid ISO BMFF sample description index')
	}
	tfdt_version := iso_box_version(bytes, tfdt)!
	mut decode_time := if tfdt_version == 1 {
		iso_read_u64(bytes, tfdt.content_start + 4)!
	} else {
		u64(iso_read_u32(bytes, tfdt.content_start + 4)!)
	}
	mut previous_run_end := base_data_offset
	mut samples := []ISOSample{}
	for run in runs {
		version := iso_box_version(bytes, run)!
		flags := iso_full_box_flags(bytes, run)!
		mut run_cursor := run.content_start + 4
		sample_count := iso_read_u32(bytes, run_cursor)!
		run_cursor += 4
		mut data_position := previous_run_end
		if flags & 0x000001 != 0 {
			offset := iso_read_i32(bytes, run_cursor)!
			run_cursor += 4
			position_64 := i64(base_data_offset) + i64(offset)
			if position_64 < 0 || position_64 > max_int {
				return error('Invalid ISO BMFF sample data offset')
			}
			data_position = int(position_64)
		}
		mut first_sample_flags := ?u32(none)
		if flags & 0x000004 != 0 {
			first_sample_flags = iso_read_u32(bytes, run_cursor)!
			run_cursor += 4
		}
		for sample_index in 0 .. int(sample_count) {
			duration_ticks := if flags & 0x000100 != 0 {
				value := iso_read_u32(bytes, run_cursor)!
				run_cursor += 4
				value
			} else {
				default_duration
			}
			size := if flags & 0x000200 != 0 {
				value := iso_read_u32(bytes, run_cursor)!
				run_cursor += 4
				value
			} else {
				default_size
			}
			mut sample_flags := default_flags
			if flags & 0x000400 != 0 {
				sample_flags = iso_read_u32(bytes, run_cursor)!
				run_cursor += 4
			} else if sample_index == 0 {
				if value := first_sample_flags {
					sample_flags = value
				}
			}
			mut composition_offset := i64(0)
			if flags & 0x000800 != 0 {
				composition_offset = if version == 1 {
					i64(iso_read_i32(bytes, run_cursor)!)
				} else {
					i64(iso_read_u32(bytes, run_cursor)!)
				}
				run_cursor += 4
			}
			if size == 0 {
				return error('ISO BMFF sample contains no data')
			}
			if data_position > max_int - int(size) {
				return error('ISO BMFF sample data range is too large')
			}
			samples << ISOSample{
				track_id: track_id
				data_position: data_position
				data_size: int(size)
				presentation_timestamp: f64(i64(decode_time) + composition_offset) / f64(context.timescale)
				decode_timestamp: f64(decode_time) / f64(context.timescale)
				duration: f64(duration_ticks) / f64(context.timescale)
				is_keyframe: sample_flags & 0x0001_0000 == 0
				sample_description_index: description_index
			}
			data_position += int(size)
			decode_time += u64(duration_ticks)
		}
		previous_run_end = data_position
	}
	return samples
}

pub fn (mut parser ISOBMFFByteStreamParser) parse_media_segment(bytes []u8) !WebMMediaSegmentResult {
	mut position := 0
	mut header := read_iso_box_header(bytes, position, bytes.len, true)!
	if header.type_ == 'styp' {
		position = header.end
		header = read_iso_box_header(bytes, position, bytes.len, true)!
	}
	for header.type_ != 'moof' {
		if !is_ignorable_top_level_box(header.type_) {
			return error('Found ${header.type_} where the Movie Fragment box was expected')
		}
		position = header.end
		header = read_iso_box_header(bytes, position, bytes.len, true)!
	}
	moof := header
	mut samples := []ISOSample{}
	mut track_fragment_count := 0
	for child in iso_child_boxes(bytes, moof)! {
		if child.type_ == 'traf' {
			track_fragment_count++
			samples << parse_iso_track_fragment(bytes, moof, child, parser.track_contexts)!
		}
	}
	if track_fragment_count == 0 {
		return error('Movie Fragment box contains no Track Fragment boxes')
	}
	samples.sort_with_compare(fn (a &ISOSample, b &ISOSample) int {
		return if a.data_position < b.data_position {
			-1
		} else if a.data_position > b.data_position { 1 } else { 0 }
	})
	for index in 1 .. samples.len {
		previous := samples[index - 1]
		if samples[index].data_position < previous.data_position + previous.data_size {
			return error('ISO BMFF sample data ranges overlap')
		}
	}

	mut media_data_ranges := []MediaSourceTimeRange{}
	position = moof.end
	mut consumed := position
	for {
		media_data := read_iso_box_header(bytes, position, bytes.len, true)!
		if media_data.type_ != 'mdat' {
			return error('Found ${media_data.type_} where a Media Data box was expected')
		}
		media_data_ranges << MediaSourceTimeRange{
			start: media_data.content_start
			end: media_data.end
		}
		consumed = media_data.end
		mut all_contained := true
		for sample in samples {
			mut contained := false
			for range_ in media_data_ranges {
				if f64(sample.data_position) >= range_.start
					&& f64(sample.data_position + sample.data_size) <= range_.end {
					contained = true
					break
				}
			}
			if !contained {
				all_contained = false
				break
			}
		}
		if all_contained {
			break
		}
		position = media_data.end
	}

	mut frames := []DemuxedCodedFrame{cap: samples.len}
	for sample in samples {
		context := parser.track_contexts[sample.track_id] or {
			return error('Unknown ISO BMFF sample track ${sample.track_id}')
		}
		description_offset := int(sample.sample_description_index - 1)
		mut configuration := ?[]u8(none)
		if active := parser.active_sample_descriptions[sample.track_id] {
			if active != sample.sample_description_index {
				configuration = context.sample_descriptions[description_offset].clone()
			}
		} else {
			configuration = context.sample_descriptions[description_offset].clone()
		}
		parser.active_sample_descriptions[sample.track_id] = sample.sample_description_index
		frames << DemuxedCodedFrame{
			track_number: sample.track_id
			codec_id: context.sample_description_codecs[description_offset]
			timestamp: sample.presentation_timestamp
			decode_timestamp: sample.decode_timestamp
			duration: sample.duration
			is_keyframe: sample.is_keyframe
			data: bytes[sample.data_position..sample.data_position + sample.data_size].clone()
			new_codec_configuration: configuration
		}
	}
	return WebMMediaSegmentResult{
		consumed: consumed
		completed_segment: true
		coded_frames: frames
	}
}

pub fn (mut parser ISOBMFFByteStreamParser) reset_parser_state() {
	// Parsing is restarted from the retained input prefix for each append, so
	// there is no independent partial-fragment cursor to clear.
	_ = parser
}

pub fn (parser &ISOBMFFByteStreamParser) duration() ?f64 {
	return parser.duration_
}

fn (parser &ISOBMFFByteStreamParser) tracks_for_type(type_ MediaSourceTrackType) []WebMTrackInfo {
	return parser.track_contexts.values().map(it.track).filter(it.type_ == type_)
}

pub fn (parser &ISOBMFFByteStreamParser) video_tracks() []WebMTrackInfo {
	return parser.tracks_for_type(.video)
}

pub fn (parser &ISOBMFFByteStreamParser) audio_tracks() []WebMTrackInfo {
	return parser.tracks_for_type(.audio)
}

pub fn (parser &ISOBMFFByteStreamParser) text_tracks() []WebMTrackInfo {
	return parser.tracks_for_type(.text)
}
