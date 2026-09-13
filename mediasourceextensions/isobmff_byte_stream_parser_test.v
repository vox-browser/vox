module mediasourceextensions

import dom
import html
import math

fn iso_test_u32(value u32) []u8 {
	return [u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value)]
}

fn iso_test_u64(value u64) []u8 {
	mut result := iso_test_u32(u32(value >> 32))
	result << iso_test_u32(u32(value))
	return result
}

fn iso_test_box(type_ string, payload []u8) []u8 {
	assert type_.len == 4
	mut result := iso_test_u32(u32(payload.len + 8))
	result << type_.bytes()
	result << payload
	return result
}

fn iso_test_full_box(type_ string, version u8, flags u32, payload []u8) []u8 {
	mut full_payload := [version, u8(flags >> 16), u8(flags >> 8), u8(flags)]
	full_payload << payload
	return iso_test_box(type_, full_payload)
}

fn minimal_isobmff_initialization_segment() []u8 {
	mut file_type_payload := 'isom'.bytes()
	file_type_payload << iso_test_u32(0)
	file_type := iso_test_box('ftyp', file_type_payload)

	mut movie_header_payload := []u8{len: 8}
	movie_header_payload << iso_test_u32(1000)
	movie_header_payload << iso_test_u32(0)
	movie_header := iso_test_full_box('mvhd', 0, 0, movie_header_payload)

	mut track_header_payload := []u8{len: 8}
	track_header_payload << iso_test_u32(1)
	track_header := iso_test_full_box('tkhd', 0, 0, track_header_payload)

	mut media_header_payload := []u8{len: 8}
	media_header_payload << iso_test_u32(1000)
	media_header_payload << iso_test_u32(0)
	media_header_payload << [u8(0x55), 0xc4]
	media_header := iso_test_full_box('mdhd', 0, 0, media_header_payload)

	mut handler_payload := []u8{len: 4}
	handler_payload << 'vide'.bytes()
	handler_payload << []u8{len: 12}
	handler_payload << 'VideoHandler\x00'.bytes()
	handler := iso_test_full_box('hdlr', 0, 0, handler_payload)

	sample_entry := iso_test_box('av01', []u8{})
	mut sample_description_payload := iso_test_u32(1)
	sample_description_payload << sample_entry
	sample_description := iso_test_full_box('stsd', 0, 0, sample_description_payload)
	empty_table := iso_test_u32(0)
	decoding_time := iso_test_full_box('stts', 0, 0, empty_table)
	sample_to_chunk := iso_test_full_box('stsc', 0, 0, empty_table)
	mut sample_size_payload := iso_test_u32(0)
	sample_size_payload << iso_test_u32(0)
	sample_size := iso_test_full_box('stsz', 0, 0, sample_size_payload)
	chunk_offset := iso_test_full_box('stco', 0, 0, empty_table)
	mut sample_table_payload := sample_description.clone()
	sample_table_payload << decoding_time
	sample_table_payload << sample_to_chunk
	sample_table_payload << sample_size
	sample_table_payload << chunk_offset
	sample_table := iso_test_box('stbl', sample_table_payload)
	media_information := iso_test_box('minf', sample_table)
	mut media_payload := media_header.clone()
	media_payload << handler
	media_payload << media_information
	media := iso_test_box('mdia', media_payload)
	mut track_payload := track_header.clone()
	track_payload << media
	track := iso_test_box('trak', track_payload)

	mut track_extends_payload := iso_test_u32(1)
	track_extends_payload << iso_test_u32(1)
	track_extends_payload << iso_test_u32(0)
	track_extends_payload << iso_test_u32(0)
	track_extends_payload << iso_test_u32(0)
	track_extends := iso_test_full_box('trex', 0, 0, track_extends_payload)
	movie_extends := iso_test_box('mvex', track_extends)
	mut movie_payload := movie_header.clone()
	movie_payload << track
	movie_payload << movie_extends
	movie := iso_test_box('moov', movie_payload)

	mut result := file_type.clone()
	result << movie
	return result
}

fn minimal_isobmff_media_segment() []u8 {
	mut track_fragment_header_payload := iso_test_u32(1)
	track_fragment_header_payload << iso_test_u32(1000)
	track_fragment_header_payload << iso_test_u32(3)
	track_fragment_header_payload << iso_test_u32(0x0200_0000)
	track_fragment_header := iso_test_full_box('tfhd', 0, 0x020038, track_fragment_header_payload)
	decode_time := iso_test_full_box('tfdt', 1, 0, iso_test_u64(0))

	mut placeholder_run_payload := iso_test_u32(1)
	placeholder_run_payload << iso_test_u32(0)
	placeholder_run := iso_test_full_box('trun', 0, 1, placeholder_run_payload)
	mut placeholder_fragment_payload := track_fragment_header.clone()
	placeholder_fragment_payload << decode_time
	placeholder_fragment_payload << placeholder_run
	placeholder_track_fragment := iso_test_box('traf', placeholder_fragment_payload)
	placeholder_movie_fragment := iso_test_box('moof', placeholder_track_fragment)

	mut run_payload := iso_test_u32(1)
	run_payload << iso_test_u32(u32(placeholder_movie_fragment.len + 8))
	run := iso_test_full_box('trun', 0, 1, run_payload)
	mut fragment_payload := track_fragment_header.clone()
	fragment_payload << decode_time
	fragment_payload << run
	track_fragment := iso_test_box('traf', fragment_payload)
	movie_fragment := iso_test_box('moof', track_fragment)
	media_data := iso_test_box('mdat', [u8(1), 2, 3])
	mut result := movie_fragment.clone()
	result << media_data
	return result
}

fn test_isobmff_initialization_and_media_segments_create_tracks_and_frames() {
	initialization := minimal_isobmff_initialization_segment()
	mut parser := ISOBMFFByteStreamParser.create()
	parsed_initialization := parser.parse_initialization_segment(initialization)!
	assert parsed_initialization.consumed == initialization.len
	assert parsed_initialization.tracks.len == 1

	mut source := MediaSource.create()
	mut media := html.HTMLMediaElement.create(none, dom.URL{'https://example.test/'})
	media.set_src_object(source.as_media_provider())!
	mut buffer := source.add_source_buffer('video/mp4; codecs="av01.0.00M.08"')!

	buffer.append_buffer(initialization[..initialization.len / 2])!
	assert buffer.input_buffer_length() == initialization.len / 2
	buffer.append_buffer(initialization[initialization.len / 2..])!
	assert buffer.input_buffer_length() == 0
	assert source.duration() == math.inf(1)
	assert buffer.video_tracks().length() == 1

	buffer.append_buffer(minimal_isobmff_media_segment())!
	track_buffer := buffer.processor_.track_buffers()[1] or { panic('missing MP4 track buffer') }
	frames := track_buffer.demuxer.coded_frames()
	assert frames.len == 1
	assert frames[0].timestamp == 0
	assert frames[0].duration == 1
	assert frames[0].is_keyframe
	assert frames[0].data == [u8(1), 2, 3]
	buffered := buffer.buffered()!
	assert buffered.length() == 1
	assert buffered.start(0)! == 0
	assert buffered.end(0)! == 1
}

fn test_isobmff_ignores_complete_top_level_boxes_but_retains_split_ones() {
	mut parser := ISOBMFFByteStreamParser.create()
	event_message := iso_test_box('emsg', []u8{len: 16})
	assert parser.ignored_element_length(event_message[..10]) or {
		assert err.msg() == 'incomplete ISO BMFF box'
		0
	} == 0
	assert parser.ignored_element_length(event_message)! == event_message.len
}
