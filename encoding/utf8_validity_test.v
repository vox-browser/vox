module encoding

import encoding.hex
import json2
import os

pub struct Utf8ValiditySourceEdge {
pub:
	input_hex   string
	valid_up_to int
}

fn test_source_utf8_scalar_validity_matches_actual_helper_for_all_two_byte_inputs() {
	gold := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/utf8_validity_pairs.bin')!
	assert gold.len == 65536 && utf8_validity_masks.len == 384
	for first in 0 .. 256 {
		for second in 0 .. 256 {
			assert source_utf8_valid_up_to([u8(first), u8(second)]) == gold[first * 256 + second]
		}
	}
}

fn test_source_utf8_scalar_three_byte_mask_matches_every_actual_native_triple() {
	gold := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/utf8_validity_triples.bin')!
	assert gold.len == 1048576
	mut index := 0
	for first in 0xe0 .. 0xf0 {
		for second in 0 .. 256 {
			for third in 0 .. 256 {
				assert source_utf8_valid_up_to([u8(first), u8(second), u8(third)]) == gold[index]
				index++
			}
		}
	}
}

fn test_source_utf8_scalar_four_byte_mask_matches_actual_native_boundary_classes() {
	gold := os.read_bytes('${os.dir(@DIR)}/encoding/fixtures/utf8_validity_quads.bin')!
	assert gold.len == 81920
	mut index := 0
	edges := [u8(0), 0x7f, 0x80, 0x9f, 0xa0, 0xbf, 0xc0, 0xff]
	for first in 0xf0 .. 0xf5 {
		for second in 0 .. 256 {
			for third in edges {
				for fourth in edges {
					assert source_utf8_valid_up_to([u8(first), u8(second), third, fourth]) == gold[index]
					index++
				}
			}
		}
	}
}

fn test_source_utf8_validity_ascii_prefix_tail_and_native_simd_threshold_match() {
	cases := json2.decode[[]Utf8ValiditySourceEdge](os.read_file('${os.dir(@DIR)}/encoding/fixtures/utf8_validity_edges.json')!)!
	assert cases.len == 454
	for item in cases {
		assert source_utf8_valid_up_to(hex.decode(item.input_hex)!) == item.valid_up_to
	}
	assert source_utf8_valid_up_to([]) == 0
	assert source_utf8_valid_up_to([u8(0), 0, 0]) == 3
	assert source_utf8_valid_up_to([u8(0xe1), 0x80, 0x41]) == 0
	assert source_utf8_valid_up_to([u8(0x41), 0xe1, 0x80]) == 1
	assert source_utf8_valid_up_to('A😀Z'.bytes()) == 'A😀Z'.len
}
