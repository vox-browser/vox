// Copyright (c) 2023, Kenneth Myhra <kennethmyhra@serenityos.org>
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the content-sniffing core of Libraries/LibWeb/MimeSniff/Resource.cpp — the
// WHATWG MIME Sniffing standard's byte pattern-matching algorithms (image/audio-or-video/font/
// archive) and the "rules for identifying an unknown MIME type". These are pure byte→MimeType
// functions over the MimeType record in mime_type.v; the Resource state-machine wrapper (supplied
// type, scheme handling, context-specific sniffing) is Fetch/config plumbing and is out of scope,
// so rules_for_identifying_an_unknown_mime_type takes the resource header directly.
// https://mimesniff.spec.whatwg.org/#reading-the-resource-header
module mimesniff

// https://mimesniff.spec.whatwg.org/#tag-terminating-byte
fn is_tag_terminating_byte(byte u8) bool {
	// 0x20 (SP) or 0x3E (">").
	return byte == 0x20 || byte == 0x3E
}

// https://mimesniff.spec.whatwg.org/#binary-data-byte
pub fn is_binary_data_byte(byte u8) bool {
	// 0x00..0x08, 0x0B, 0x0E..0x1A, or 0x1C..0x1F.
	return byte <= 0x08 || byte == 0x0B || (byte >= 0x0E && byte <= 0x1A)
		|| (byte >= 0x1C && byte <= 0x1F)
}

struct BytePatternTableRow {
	byte_pattern          []u8
	pattern_mask          []u8
	ignored_leading_bytes []u8
	mime_type             string
	is_tag_terminated     bool
}

fn row(byte_pattern string, pattern_mask string, ignored []u8, mime_type string) BytePatternTableRow {
	return BytePatternTableRow{
		byte_pattern:          byte_pattern.bytes()
		pattern_mask:          pattern_mask.bytes()
		ignored_leading_bytes: ignored
		mime_type:             mime_type
	}
}

fn tag_row(byte_pattern string, pattern_mask string, ignored []u8, mime_type string) BytePatternTableRow {
	return BytePatternTableRow{
		byte_pattern:          byte_pattern.bytes()
		pattern_mask:          pattern_mask.bytes()
		ignored_leading_bytes: ignored
		mime_type:             mime_type
		is_tag_terminated:     true
	}
}

const no_ignored_bytes = []u8{}

// https://mimesniff.spec.whatwg.org/#whitespace-byte
const ignored_whitespace_bytes = [u8(0x09), 0x0A, 0x0C, 0x0D, 0x20]

// https://mimesniff.spec.whatwg.org/#pattern-matching-algorithm
pub fn pattern_matching_algorithm(input []u8, pattern []u8, mask []u8, ignored []u8, is_tag_terminated bool) bool {
	// 1. Assert: pattern's length equals mask's length.
	// 2. If input's length is less than pattern's length, return false.
	if input.len < pattern.len {
		return false
	}
	// 3-4. Skip leading ignored bytes.
	mut s := 0
	for s < input.len {
		if input[s] !in ignored {
			break
		}
		s++
	}
	// 5-6. Compare pattern against the (masked) input.
	mut p := 0
	for p < pattern.len {
		// Guard against reading past the input after skipping ignored bytes (UB in C++).
		if s >= input.len {
			return false
		}
		masked_data := input[s] & mask[p]
		// Non-standard: a tag-terminating final byte.
		if is_tag_terminated && p + 1 == pattern.len {
			return is_tag_terminating_byte(masked_data)
		}
		if masked_data != pattern[p] {
			return false
		}
		s++
		p++
	}
	// 7. Return true.
	return true
}

fn match_pattern_table(input []u8, table []BytePatternTableRow) ?MimeType {
	for table_row in table {
		if pattern_matching_algorithm(input, table_row.byte_pattern, table_row.pattern_mask,
			table_row.ignored_leading_bytes, table_row.is_tag_terminated)
		{
			if mime := MimeType.parse(table_row.mime_type) {
				return mime
			}
		}
	}
	return none
}

// https://mimesniff.spec.whatwg.org/#matching-an-image-type-pattern
pub fn match_an_image_type_pattern(input []u8) ?MimeType {
	table := [
		row('\x00\x00\x01\x00', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'image/x-icon'),
		row('\x00\x00\x02\x00', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'image/x-icon'),
		row('\x42\x4D', '\xFF\xFF', no_ignored_bytes, 'image/bmp'),
		row('\x47\x49\x46\x38\x37\x61', '\xFF\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes, 'image/gif'),
		row('\x47\x49\x46\x38\x39\x61', '\xFF\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes, 'image/gif'),
		row('\x52\x49\x46\x46\x00\x00\x00\x00\x57\x45\x42\x50\x56\x50',
			'\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes,
			'image/webp'),
		row('\x89\x50\x4E\x47\x0D\x0A\x1A\x0A', '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
			no_ignored_bytes, 'image/png'),
		row('\xFF\xD8\xFF', '\xFF\xFF\xFF', no_ignored_bytes, 'image/jpeg'),
	]
	return match_pattern_table(input, table)
}

// https://mimesniff.spec.whatwg.org/#signature-for-mp4
pub fn matches_mp4_signature(sequence []u8) bool {
	length := sequence.len
	// 3. If length is less than 12, return false.
	if length < 12 {
		return false
	}
	// 4. box-size = big-endian u32 of sequence[0..3].
	box_size := (u32(sequence[0]) << 24) | (u32(sequence[1]) << 16) | (u32(sequence[2]) << 8) | u32(sequence[3])
	// 5. If length < box-size or box-size % 4 != 0, return false.
	if u32(length) < box_size || box_size % 4 != 0 {
		return false
	}
	// 6. If sequence[4..7] is not "ftyp", return false.
	if sequence[4..8] != '\x66\x74\x79\x70'.bytes() {
		return false
	}
	// 7. If sequence[8..10] is "mp4", return true.
	if sequence[8..11] == '\x6D\x70\x34'.bytes() {
		return true
	}
	// 8-9. Scan the compatible-brands list for "mp4".
	mut bytes_read := u32(16)
	for bytes_read < box_size {
		if int(bytes_read) + 3 > length {
			break
		}
		if sequence[bytes_read..bytes_read + 3] == '\x6D\x70\x34'.bytes() {
			return true
		}
		bytes_read += 4
	}
	// 10. Return false.
	return false
}

struct VintResult {
	value  u64
	length int
}

// https://mimesniff.spec.whatwg.org/#parse-a-vint
fn parse_a_vint(input []u8, iter int) VintResult {
	sequence := input[iter..]
	length := sequence.len
	// 1. mask = 128.
	mut mask := u8(128)
	// 2. max vint length = 8.
	max_vint_length := 8
	// 3. number size = 1.
	mut number_size := 1
	// 5. index = 0.
	mut index := 0
	// 4. Count the leading zero bits to find the vint length.
	for number_size < max_vint_length && number_size < length {
		if sequence[index] & mask != 0 {
			break
		}
		mask >>= 1
		number_size++
	}
	// 6. parsed number = sequence[index] & ~mask.
	mut parsed_number := u64(sequence[index] & ~mask)
	// 7. Increment index.
	index++
	// 8-9. Read the remaining bytes.
	mut bytes_remaining := number_size - 1
	for bytes_remaining != 0 {
		if index >= length {
			break
		}
		parsed_number <<= 8
		parsed_number |= u64(sequence[index])
		index++
		if index >= length {
			break
		}
		bytes_remaining--
	}
	return VintResult{
		value:  parsed_number
		length: number_size
	}
}

// https://mimesniff.spec.whatwg.org/#signature-for-webm
pub fn matches_webm_signature(sequence []u8) bool {
	length := sequence.len
	// 3. If length is less than 4, return false.
	if length < 4 {
		return false
	}
	// 4. If sequence[0..3] != 0x1A 0x45 0xDF 0xA3, return false.
	if sequence[0..4] != '\x1A\x45\xDF\xA3'.bytes() {
		return false
	}
	// 5-6. Scan for the "webm" DocType element.
	mut iter := 4
	for iter < length && iter < 38 {
		if iter + 1 >= length {
			break
		}
		if sequence[iter..iter + 2] == '\x42\x82'.bytes() {
			iter += 2
			if iter >= length {
				break
			}
			number_size := parse_a_vint(sequence, iter).length
			iter += number_size
			if iter >= length - 4 {
				break
			}
			if sequence[iter..iter + 4] == '\x77\x65\x62\x6D'.bytes() {
				return true
			}
		}
		iter += 1
	}
	// 7. Return false.
	return false
}

// https://mimesniff.spec.whatwg.org/#match-an-mp3-header
fn match_mp3_header(sequence []u8, s int) bool {
	length := sequence.len
	// 1. If length is less than 4, return false.
	if length - s < 4 {
		return false
	}
	// 2. If sequence[s] != 0xff or (sequence[s+1] & 0xe0) != 0xe0, return false.
	if sequence[s] != 0xff || (sequence[s + 1] & 0xe0) != 0xe0 {
		return false
	}
	// 3-4. layer must be non-zero.
	layer := (sequence[s + 1] & 0x06) >> 1
	if layer == 0 {
		return false
	}
	// 5-6. bit-rate must not be 15.
	bit_rate := (sequence[s + 2] & 0xf0) >> 4
	if bit_rate == 15 {
		return false
	}
	// 7-8. sample-rate must not be 3.
	sample_rate := (sequence[s + 2] & 0x0c) >> 2
	if sample_rate == 3 {
		return false
	}
	// FIXME: 9-11 (freq/final-layer checks) are not implemented upstream either.
	// 12. Return true.
	return true
}

// https://mimesniff.spec.whatwg.org/#matches-the-signature-for-mp3-without-id3
// FIXME: upstream only matches a single-frame mp3 header (whatwg/mimesniff#70).
fn matches_mp3_no_id3_signature(sequence []u8) bool {
	return match_mp3_header(sequence, 0)
}

// https://mimesniff.spec.whatwg.org/#matching-an-audio-or-video-type-pattern
pub fn match_an_audio_or_video_type_pattern(input []u8) ?MimeType {
	table := [
		row('\x46\x4F\x52\x4D\x00\x00\x00\x00\x41\x49\x46\x46',
			'\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF', no_ignored_bytes, 'audio/aiff'),
		row('\x49\x44\x33', '\xFF\xFF\xFF', no_ignored_bytes, 'audio/mpeg'),
		row('\x4F\x67\x67\x53\x00', '\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes, 'application/ogg'),
		row('\x4D\x54\x68\x64\x00\x00\x00\x06', '\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF',
			no_ignored_bytes, 'audio/midi'),
		row('\x52\x49\x46\x46\x00\x00\x00\x00\x41\x56\x49\x20',
			'\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF', no_ignored_bytes, 'video/avi'),
		row('\x52\x49\x46\x46\x00\x00\x00\x00\x57\x41\x56\x45',
			'\xFF\xFF\xFF\xFF\x00\x00\x00\x00\xFF\xFF\xFF\xFF', no_ignored_bytes, 'audio/wave'),
	]
	if mime := match_pattern_table(input, table) {
		return mime
	}
	// 2. MP4.
	if matches_mp4_signature(input) {
		return MimeType.create('video', 'mp4')
	}
	// 3. WebM.
	if matches_webm_signature(input) {
		return MimeType.create('video', 'webm')
	}
	// 4. MP3 without ID3.
	if matches_mp3_no_id3_signature(input) {
		return MimeType.create('audio', 'mpeg')
	}
	// 5. Return undefined.
	return none
}

// https://mimesniff.spec.whatwg.org/#matching-a-font-type-pattern
pub fn match_a_font_type_pattern(input []u8) ?MimeType {
	table := [
		row('\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x4C\x50',
			'\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xFF\xFF',
			no_ignored_bytes, 'application/vnd.ms-fontobject'),
		row('\x00\x01\x00\x00', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'font/ttf'),
		row('\x4F\x54\x54\x4F', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'font/otf'),
		row('\x74\x74\x63\x66', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'font/collection'),
		row('\x77\x4F\x46\x46', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'font/woff'),
		row('\x77\x4F\x46\x32', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'font/woff2'),
	]
	return match_pattern_table(input, table)
}

// https://mimesniff.spec.whatwg.org/#matching-an-archive-type-pattern
pub fn match_an_archive_type_pattern(input []u8) ?MimeType {
	table := [
		row('\x1F\x8B\x08', '\xFF\xFF\xFF', no_ignored_bytes, 'application/x-gzip'),
		row('\x50\x4B\x03\x04', '\xFF\xFF\xFF\xFF', no_ignored_bytes, 'application/zip'),
		row('\x52\x61\x72\x21\x1A\x07\x00', '\xFF\xFF\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes,
			'application/x-rar-compressed'),
	]
	return match_pattern_table(input, table)
}

// https://mimesniff.spec.whatwg.org/#rules-for-identifying-an-unknown-mime-type
pub fn rules_for_identifying_an_unknown_mime_type(resource_header []u8, sniff_scriptable bool) MimeType {
	// 1. If the sniff-scriptable flag is set, try the scriptable patterns.
	if sniff_scriptable {
		text_html := 'text/html'
		ws := ignored_whitespace_bytes
		scriptable_table := [
			tag_row('\x3C\x21\x44\x4F\x43\x54\x59\x50\x45\x20\x48\x54\x4D\x4C\x00',
				'\xFF\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xDF\xFF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x48\x54\x4D\x4C\x00', '\xFF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x48\x45\x41\x44\x00', '\xFF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x53\x43\x52\x49\x50\x54\x00', '\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xFF', ws,
				text_html),
			tag_row('\x3C\x49\x46\x52\x41\x4D\x45\x00', '\xFF\xDF\xDF\xDF\xDF\xDF\xDF\xFF', ws,
				text_html),
			tag_row('\x3C\x48\x31\x00', '\xFF\xDF\xFF\xFF', ws, text_html),
			tag_row('\x3C\x44\x49\x56\x00', '\xFF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x46\x4F\x4E\x54\x00', '\xFF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x54\x41\x42\x4C\x45\x00', '\xFF\xDF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x41\x00', '\xFF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x53\x54\x59\x4C\x45\x00', '\xFF\xDF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x54\x49\x54\x4C\x45\x00', '\xFF\xDF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x42\x00', '\xFF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x42\x4F\x44\x59\x00', '\xFF\xDF\xDF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x42\x52\x00', '\xFF\xDF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x50\x00', '\xFF\xDF\xFF', ws, text_html),
			tag_row('\x3C\x21\x2D\x2D\x00', '\xFF\xFF\xFF\xFF\xFF', ws, text_html),
			row('\x3C\x3F\x78\x6D\x6C', '\xFF\xFF\xFF\xFF\xFF', ws, 'text/xml'),
			row('\x25\x50\x44\x46\x2D', '\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes, 'application/pdf'),
		]
		if mime := match_pattern_table(resource_header, scriptable_table) {
			return mime
		}
	}
	// 2. Try the PostScript / BOM patterns.
	text_plain := 'text/plain'
	bom_table := [
		row('\x25\x21\x50\x53\x2D\x41\x64\x6F\x62\x65\x2D',
			'\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF', no_ignored_bytes,
			'application/postscript'),
		row('\xFE\xFF\x00\x00', '\xFF\xFF\x00\x00', no_ignored_bytes, text_plain),
		row('\xFF\xFE\x00\x00', '\xFF\xFF\x00\x00', no_ignored_bytes, text_plain),
		row('\xEF\xBB\xBF\x00', '\xFF\xFF\xFF\x00', no_ignored_bytes, text_plain),
	]
	if mime := match_pattern_table(resource_header, bom_table) {
		return mime
	}
	// 3-4. Image.
	if mime := match_an_image_type_pattern(resource_header) {
		return mime
	}
	// 5-6. Audio or video.
	if mime := match_an_audio_or_video_type_pattern(resource_header) {
		return mime
	}
	// 7-8. Archive.
	if mime := match_an_archive_type_pattern(resource_header) {
		return mime
	}
	// 9. If the header contains no binary data bytes, return "text/plain".
	if !resource_header.any(is_binary_data_byte(it)) {
		return MimeType.create('text', 'plain')
	}
	// 10. Return "application/octet-stream".
	return MimeType.create('application', 'octet-stream')
}
