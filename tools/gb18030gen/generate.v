// SPDX-License-Identifier: BSD-2-Clause
module gb18030gen

import crypto.sha256
import os

pub struct IndexEntry {
pub:
	pointer u32
	point   u32
}

pub fn parse_index(source string) ![]IndexEntry {
	mut entries := []IndexEntry{}
	for line in source.split_into_lines() {
		text := line.trim_space()
		if text.len == 0 || text.starts_with('#') { continue }
		fields := text.split_any(' \t').filter(it.len > 0)
		if fields.len < 2 || !fields[1].starts_with('0x') {
			return error('Invalid encoding index row: ${line}')
		}
		pointer := u32(fields[0].parse_uint(10, 32)!)
		point := u32(fields[1][2..].parse_uint(16, 32)!)
		if point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff) {
			return error('Invalid Unicode scalar in encoding index')
		}
		if entries.len > 0 && pointer <= entries.last().pointer {
			return error('Encoding index pointers must increase')
		}
		entries << IndexEntry{ pointer: pointer, point: point }
	}
	return entries
}

fn rows(values []string) string {
	mut lines := []string{}
	for index := 0; index < values.len; index += 12 {
		end := if index + 12 < values.len { index + 12 } else { values.len }
		lines << '\t' + values[index..end].join(', ') + ','
	}
	return lines.join('\n')
}

fn hex_values(values []u32, kind string) []string {
	mut result := []string{cap: values.len}
	for index, value in values {
		text := '0x${value:04X}'
		result << if index == 0 { '${kind}(${text})' } else { text }
	}
	return result
}

fn decimal_values(values []u32, kind string) []string {
	mut result := values.map(it.str())
	if result.len > 0 { result[0] = '${kind}(${result[0]})' }
	return result
}

pub fn generate(index []IndexEntry, ranges []IndexEntry) !string {
	if index.len != 23940 || ranges.len == 0 || ranges[0].pointer != 0 {
		return error('GB18030 indexes are incomplete')
	}
	mut two := []u32{cap: index.len}
	mut first_pointer := map[u32]u32{}
	for pointer, entry in index {
		if entry.pointer != u32(pointer) || entry.point == 0 || entry.point > 0xffff {
			return error('Invalid GB18030 two-byte pointer')
		}
		two << entry.point
		if entry.point !in first_pointer { first_pointer[entry.point] = entry.pointer }
	}
	// The decoder handles the astral range and pointer 7457 separately. Keep
	// only the BMP linear starts used by its existing binary search.
	mut pointers := []u32{}
	mut points := []u32{}
	for entry in ranges {
		if entry.pointer >= 39420 { break }
		if entry.pointer == 7457 { continue }
		pointers << entry.pointer
		points << entry.point
	}
	mut encode := first_pointer.keys()
	encode.sort()
	encoded_pointers := encode.map(first_pointer[it])
	return $embed_file('header.txt').to_string() + '// index-gb18030: the code point of each two-byte pointer.\n' +
		'const gb18030_index = [\n${rows(hex_values(two, 'u16'))}\n]\n\n' +
		'// index-gb18030-ranges, without pointer 7457: the pointer and code point at\n' +
		'// which each linear four-byte range starts.\n' +
		'const gb18030_range_pointers = [\n${rows(decimal_values(pointers, 'u32'))}\n]\n\n' +
		'const gb18030_range_code_points = [\n${rows(hex_values(points, 'u32'))}\n]\n\n' +
		"// The encoder's index pointer for each code point in index-gb18030 (its first\n" +
		'// pointer), sorted by code point.\n' +
		'const gb18030_encode_code_points = [\n${rows(hex_values(encode, 'u16'))}\n]\n\n' +
		'const gb18030_encode_pointers = [\n${rows(decimal_values(encoded_pointers, 'u16'))}\n]\n'
}

pub fn read_pinned_indexes(directory string) !([]IndexEntry, []IndexEntry) {
	index := os.read_file(os.join_path(directory, 'index-gb18030.txt'))!
	ranges := os.read_file(os.join_path(directory, 'index-gb18030-ranges.txt'))!
	if sha256.hexhash(index) != '746b3c55f1a8ec4b90b451f384437a17fd37cd51cd668456a28071a758d10784'
		|| sha256.hexhash(ranges) != '874c6b6f6f74cf7d427ad228d5b41ddd9354fffd92a2259bf429f86e6baa7a1e' {
		return error('Pinned WHATWG encoding index hash mismatch')
	}
	return parse_index(index)!, parse_index(ranges)!
}
