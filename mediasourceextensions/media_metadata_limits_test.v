// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
// Ladybird 52271d6b4666b47cead2aa296a1ffa7db38aca64.
module mediasourceextensions

fn test_metadata_string_limits_precede_copying_and_accept_the_boundary() {
	bytes := []u8{len: maximum_metadata_string_size, init: `a`}
	header := EBMLElementHeader{ data_start: 0, data_end: bytes.len, size_known: true }
	assert read_ebml_string(bytes, header)!.len == maximum_metadata_string_size
	if _ := read_ebml_string(bytes, EBMLElementHeader{ ...header, data_end: bytes.len + 1 }) {
		assert false
	} else {
		assert err.msg() == 'String element is too large'
	}
	mut handler_bytes := []u8{len: 24}
	handler_bytes << bytes
	assert iso_handler_name(handler_bytes, ISOBoxHeader{ content_start: 0, end: handler_bytes.len })!.len == maximum_metadata_string_size
	handler_bytes << u8(0)
	if _ := iso_handler_name(handler_bytes, ISOBoxHeader{ content_start: 0, end: handler_bytes.len }) {
		assert false
	} else {
		assert err.msg() == 'Handler name is too large'
	}
}

fn metadata_limit_track(private_length int) []u8 {
	mut bytes := [u8(0xd7), 0x81, 1, 0x83, 0x81, 1, 0x86, 0x85]
	bytes << 'V_VP9'.bytes()
	bytes << [u8(0x63), 0xa2, u8(0x10 | (private_length >> 24)), u8(private_length >> 16),
		u8(private_length >> 8), u8(private_length)]
	bytes << []u8{len: private_length, init: u8(1)}
	return bytes
}

fn test_webm_codec_private_is_bounded_before_retaining_the_track() {
	for length in [maximum_codec_configuration_size, maximum_codec_configuration_size + 1] {
		bytes := metadata_limit_track(length)
		header := EBMLElementHeader{ id: track_entry_id, data_start: 0, data_end: bytes.len, size_known: true }
		if track := parse_webm_track_entry(bytes, header) {
			assert length == maximum_codec_configuration_size
			assert track.codec_private.len == length
		} else {
			assert length > maximum_codec_configuration_size
			assert err.msg() == "Track's CodecPrivate element is too large"
		}
	}
}

fn test_isobmff_retained_configuration_budget_includes_unknown_boxes() {
	// An unknown child still consumes the retained sample-entry budget.
	mut bytes := []u8{len: maximum_codec_configuration_size}
	child_start := 8 + 78
	child_size := bytes.len - child_start
	for index in 0 .. 4 {
		bytes[child_start + index] = u8(child_size >> ((3 - index) * 8))
		bytes[child_start + 4 + index] = 'free'[index]
	}
	validate_iso_sample_entry_configuration(bytes,
		ISOBoxHeader{ start: 0, content_start: 8, end: bytes.len, type_: 'av01' }, .video)!
	// The limit is checked before child parsing or copying even when the bytes
	// have not arrived yet.
	entry := ISOBoxHeader{ start: 0, content_start: 8, end: maximum_codec_configuration_size + 1, type_: 'av01' }
	validate_iso_sample_entry_configuration([]u8{}, entry, .video) or {
		assert err.msg() == 'Codec configuration sample entry is too large'
		return
	}
	assert false
}
