// Copyright 2014 Google Inc. All Rights Reserved.
// Copyright (c) 2024, Andreas Kling <andreas@ladybird.org>
// SPDX-License-Identifier: MIT AND BSD-2-Clause
//
// LibGfx/Font/WOFF2/Loader.cpp delegates to Google's woff2 library. This is a
// pure V port of its decoder (woff2 v1.0.2 src/woff2_dec.cc, variable_length.cc,
// table_tags.cc and woff2_common.cc), using vlib's V Brotli decoder.
module gfxfont

import encoding.binary
import x.compress.brotli

const woff2_signature = u32(0x774f4632) // "wOF2"
const woff2_ttc_flavor = u32(0x74746366) // "ttcf"
const woff2_flags_transform = u32(1) << 8
const woff2_sfnt_header_size = 12
const woff2_sfnt_entry_size = 16
// Over 14k test fonts the max compression ratio seen was ~20.
const woff2_max_plausible_compression_ratio = f32(100.0)
const woff2_end_pts_of_contours_offset = 10

const woff2_tag_glyf = u32(0x676c7966)
const woff2_tag_loca = u32(0x6c6f6361)
const woff2_tag_head = u32(0x68656164)
const woff2_tag_hhea = u32(0x68686561)
const woff2_tag_hmtx = u32(0x686d7478)

// Simple glyph flags.
const woff2_glyf_on_curve = 1 << 0
const woff2_glyf_x_short = 1 << 1
const woff2_glyf_y_short = 1 << 2
const woff2_glyf_repeat = 1 << 3
const woff2_glyf_this_x_is_same = 1 << 4
const woff2_glyf_this_y_is_same = 1 << 5

// Composite glyph flags.
const woff2_flag_arg_1_and_2_are_words = 1 << 0
const woff2_flag_we_have_a_scale = 1 << 3
const woff2_flag_more_components = 1 << 5
const woff2_flag_we_have_an_x_and_y_scale = 1 << 6
const woff2_flag_we_have_a_two_by_two = 1 << 7
const woff2_flag_we_have_instructions = 1 << 8

const woff2_known_tags = [u32(0x636d6170), 0x68656164, 0x68686561, 0x686d7478, 0x6d617870, 0x6e616d65,
	0x4f532f32, 0x706f7374, 0x63767420, 0x6670676d, 0x676c7966, 0x6c6f6361, 0x70726570, 0x43464620,
	0x564f5247, 0x45424454, 0x45424c43, 0x67617370, 0x68646d78, 0x6b65726e, 0x4c545348, 0x50434c54,
	0x56444d58, 0x76686561, 0x766d7478, 0x42415345, 0x47444546, 0x47504f53, 0x47535542, 0x45425343,
	0x4a535446, 0x4d415448, 0x43424454, 0x43424c43, 0x434f4c52, 0x4350414c, 0x53564720, 0x73626978,
	0x61636e74, 0x61766172, 0x62646174, 0x626c6f63, 0x62736c6e, 0x63766172, 0x66647363, 0x66656174,
	0x666d7478, 0x66766172, 0x67766172, 0x68737479, 0x6a757374, 0x6c636172, 0x6d6f7274, 0x6d6f7278,
	0x6f706264, 0x70726f70, 0x7472616b, 0x5a617066, 0x53696c66, 0x476c6174, 0x476c6f63, 0x46656174,
	0x53696c6c]

struct Woff2Table {
mut:
	tag              u32
	flags            u32
	src_offset       u32
	src_length       u32
	transform_length u32
	dst_offset       u32
	dst_length       u32
}

struct Woff2TtcFont {
mut:
	flavor          u32
	dst_offset      u32
	header_checksum u32
	table_indices   []int
}

struct Woff2Header {
mut:
	flavor            u32
	header_version    u32
	num_tables        u16
	compressed_offset u64
	compressed_length u32
	uncompressed_size u32
	tables            []Woff2Table
	ttc_fonts         []Woff2TtcFont
}

struct Woff2FontInfo {
mut:
	num_glyphs         u16
	index_format       u16
	num_hmetrics       u16
	x_mins             []i16
	table_entry_by_tag map[u32]int
}

struct Woff2ChecksumKey {
	tag        u32
	src_offset u32
}

struct Woff2RebuildMetadata {
mut:
	header_checksum u32
	font_infos      []Woff2FontInfo
	checksums       map[string]u32
}

struct Woff2Point {
	x        int
	y        int
	on_curve bool
}

// Woff2Buffer mirrors woff2's bounds-checked big-endian Buffer reader.
struct Woff2Buffer {
	data []u8
mut:
	offset int
}

fn (mut b Woff2Buffer) skip(n int) bool {
	if n < 0 || b.offset + n > b.data.len || b.offset + n < b.offset {
		return false
	}
	b.offset += n
	return true
}

fn (mut b Woff2Buffer) read_u8() ?u8 {
	if b.offset + 1 > b.data.len {
		return none
	}
	value := b.data[b.offset]
	b.offset++
	return value
}

fn (mut b Woff2Buffer) read_u16() ?u16 {
	if b.offset + 2 > b.data.len {
		return none
	}
	value := binary.big_endian_u16_at(b.data, b.offset)
	b.offset += 2
	return value
}

fn (mut b Woff2Buffer) read_u32() ?u32 {
	if b.offset + 4 > b.data.len {
		return none
	}
	value := binary.big_endian_u32_at(b.data, b.offset)
	b.offset += 4
	return value
}

fn (mut b Woff2Buffer) read_bytes(n int) ?[]u8 {
	if n < 0 || b.offset + n > b.data.len {
		return none
	}
	value := unsafe { b.data[b.offset..b.offset + n] }
	b.offset += n
	return value
}

// Read255UShort, section 6.1.1 of the MicroType Express draft.
fn (mut b Woff2Buffer) read_255_ushort() ?u32 {
	code := b.read_u8()?
	return match code {
		253 { u32(b.read_u16()?) }
		254 { u32(b.read_u8()?) + 253 * 2 }
		255 { u32(b.read_u8()?) + 253 }
		else { u32(code) }
	}
}

fn (mut b Woff2Buffer) read_base128() ?u32 {
	mut result := u32(0)
	for i in 0 .. 5 {
		code := b.read_u8()?
		// Leading zeros are invalid.
		if i == 0 && code == 0x80 {
			return none
		}
		// If any of the top seven bits are set then we're about to overflow.
		if result & 0xfe000000 != 0 {
			return none
		}
		result = (result << 7) | u32(code & 0x7f)
		if code & 0x80 == 0 {
			return result
		}
	}
	return none
}

// Woff2Out is the growable WOFF2Out implementation used by Loader.cpp.
struct Woff2Out {
mut:
	data []u8
}

fn (mut out Woff2Out) write(bytes []u8) ? {
	if u64(out.data.len) + u64(bytes.len) > woff2_max_output_size { return none }
	out.data << bytes
}

fn (mut out Woff2Out) write_at(bytes []u8, offset int) ? {
	if offset < 0 || u64(offset) + u64(bytes.len) > woff2_max_output_size { return none }
	if offset + bytes.len > out.data.len {
		out.data << []u8{len: offset + bytes.len - out.data.len}
	}
	copy(mut out.data[offset..offset + bytes.len], bytes)
}

fn (mut out Woff2Out) pad4() ? {
	if woff2_round4(u64(out.data.len)) > woff2_max_output_size { return none }
	pad := woff2_round4(u64(out.data.len)) - u64(out.data.len)
	for _ in 0 .. int(pad) {
		out.data << 0
	}
}

fn woff2_round4(value u64) u64 {
	return (value + 3) & ~u64(3)
}

fn woff2_round4_u32(value u32) u32 {
	if u32(0xffffffff) - value < 3 {
		return value
	}
	return (value + 3) & ~u32(3)
}

fn woff2_compute_ulong_sum(buf []u8) u32 {
	mut checksum := u32(0)
	aligned_size := buf.len & ~3
	for i := 0; i < aligned_size; i += 4 {
		checksum += binary.big_endian_u32_at(buf, i)
	}
	// Treat a size not aligned on 4 as if it were padded with zeros.
	if buf.len != aligned_size {
		mut v := u32(0)
		for i in aligned_size .. buf.len {
			v |= u32(buf[i]) << (24 - 8 * (i & 3))
		}
		checksum += v
	}
	return checksum
}

fn woff2_collection_header_size(header_version u32, num_fonts int) u64 {
	mut size := u64(0)
	if header_version == 0x00020000 {
		size += 12
	}
	if header_version == 0x00010000 || header_version == 0x00020000 {
		size += 12 + 4 * u64(num_fonts)
	}
	return size
}

fn woff2_store_u32(mut dst []u8, offset int, value u32) int {
	binary.big_endian_put_u32_at(mut dst, value, offset)
	return offset + 4
}

fn woff2_store_16(mut dst []u8, offset int, value int) int {
	dst[offset] = u8(value >> 8)
	dst[offset + 1] = u8(value)
	return offset + 2
}

fn woff2_with_sign(flag int, baseval int) int {
	return if flag & 1 != 0 { baseval } else { -baseval }
}

fn woff2_triplet_decode(flags_in []u8, input []u8, n_points int, mut result []Woff2Point) ?int {
	if n_points > input.len {
		return none
	}
	mut x := 0
	mut y := 0
	mut triplet_index := 0
	for i in 0 .. n_points {
		mut flag := int(flags_in[i])
		on_curve := flag >> 7 == 0
		flag &= 0x7f
		n_data_bytes := if flag < 84 {
			1
		} else if flag < 120 {
			2
		} else if flag < 124 {
			3
		} else {
			4
		}
		if triplet_index + n_data_bytes > input.len {
			return none
		}
		mut dx := 0
		mut dy := 0
		if flag < 10 {
			dy = woff2_with_sign(flag, ((flag & 14) << 7) + int(input[triplet_index]))
		} else if flag < 20 {
			dx = woff2_with_sign(flag, (((flag - 10) & 14) << 7) + int(input[triplet_index]))
		} else if flag < 84 {
			b0 := flag - 20
			b1 := int(input[triplet_index])
			dx = woff2_with_sign(flag, 1 + (b0 & 0x30) + (b1 >> 4))
			dy = woff2_with_sign(flag >> 1, 1 + ((b0 & 0x0c) << 2) + (b1 & 0x0f))
		} else if flag < 120 {
			b0 := flag - 84
			dx = woff2_with_sign(flag, 1 + ((b0 / 12) << 8) + int(input[triplet_index]))
			dy = woff2_with_sign(flag >> 1, 1 + (((b0 % 12) >> 2) << 8) + int(input[triplet_index + 1]))
		} else if flag < 124 {
			b2 := int(input[triplet_index + 1])
			dx = woff2_with_sign(flag, (int(input[triplet_index]) << 4) + (b2 >> 4))
			dy = woff2_with_sign(flag >> 1, ((b2 & 0x0f) << 8) + int(input[triplet_index + 2]))
		} else {
			dx = woff2_with_sign(flag, (int(input[triplet_index]) << 8) + int(input[triplet_index + 1]))
			dy = woff2_with_sign(flag >> 1, (int(input[triplet_index + 2]) << 8) +
				int(input[triplet_index + 3]))
		}
		triplet_index += n_data_bytes
		// Coordinate overflow is not security sensitive; C int arithmetic wraps.
		x = int(i32(x) + i32(dx))
		y = int(i32(y) + i32(dy))
		result << Woff2Point{x, y, on_curve}
	}
	return triplet_index
}

// Stores the point data; dst holds the beginning of a simple glyph.
fn woff2_store_points(points []Woff2Point, n_contours int, instruction_length int, mut dst []u8) ?int {
	mut flag_offset := woff2_end_pts_of_contours_offset + 2 * n_contours + 2 + instruction_length
	mut last_flag := -1
	mut repeat_count := 0
	mut last_x := 0
	mut last_y := 0
	mut x_bytes := 0
	mut y_bytes := 0
	for point in points {
		mut flag := if point.on_curve { woff2_glyf_on_curve } else { 0 }
		dx := point.x - last_x
		dy := point.y - last_y
		if dx == 0 {
			flag |= woff2_glyf_this_x_is_same
		} else if dx > -256 && dx < 256 {
			flag |= woff2_glyf_x_short | (if dx > 0 { woff2_glyf_this_x_is_same } else { 0 })
			x_bytes++
		} else {
			x_bytes += 2
		}
		if dy == 0 {
			flag |= woff2_glyf_this_y_is_same
		} else if dy > -256 && dy < 256 {
			flag |= woff2_glyf_y_short | (if dy > 0 { woff2_glyf_this_y_is_same } else { 0 })
			y_bytes++
		} else {
			y_bytes += 2
		}
		if flag == last_flag && repeat_count != 255 {
			dst[flag_offset - 1] |= u8(woff2_glyf_repeat)
			repeat_count++
		} else {
			if repeat_count != 0 {
				if flag_offset >= dst.len {
					return none
				}
				dst[flag_offset] = u8(repeat_count)
				flag_offset++
			}
			if flag_offset >= dst.len {
				return none
			}
			dst[flag_offset] = u8(flag)
			flag_offset++
			repeat_count = 0
		}
		last_x = point.x
		last_y = point.y
		last_flag = flag
	}
	if repeat_count != 0 {
		if flag_offset >= dst.len {
			return none
		}
		dst[flag_offset] = u8(repeat_count)
		flag_offset++
	}
	if flag_offset + x_bytes + y_bytes > dst.len {
		return none
	}
	mut x_offset := flag_offset
	mut y_offset := flag_offset + x_bytes
	last_x = 0
	last_y = 0
	for point in points {
		dx := point.x - last_x
		if dx != 0 {
			if dx > -256 && dx < 256 {
				dst[x_offset] = u8(if dx < 0 { -dx } else { dx })
				x_offset++
			} else {
				x_offset = woff2_store_16(mut dst, x_offset, dx)
			}
		}
		last_x += dx
		dy := point.y - last_y
		if dy != 0 {
			if dy > -256 && dy < 256 {
				dst[y_offset] = u8(if dy < 0 { -dy } else { dy })
				y_offset++
			} else {
				y_offset = woff2_store_16(mut dst, y_offset, dy)
			}
		}
		last_y += dy
	}
	return y_offset
}

// Stores the coordinates' bounding box into a glyf record.
fn woff2_compute_bbox(points []Woff2Point, mut dst []u8) {
	mut x_min := 0
	mut y_min := 0
	mut x_max := 0
	mut y_max := 0
	if points.len > 0 {
		x_min = points[0].x
		x_max = points[0].x
		y_min = points[0].y
		y_max = points[0].y
	}
	for point in points[1..] {
		if point.x < x_min {
			x_min = point.x
		}
		if point.x > x_max {
			x_max = point.x
		}
		if point.y < y_min {
			y_min = point.y
		}
		if point.y > y_max {
			y_max = point.y
		}
	}
	mut offset := 2
	offset = woff2_store_16(mut dst, offset, x_min)
	offset = woff2_store_16(mut dst, offset, y_min)
	offset = woff2_store_16(mut dst, offset, x_max)
	woff2_store_16(mut dst, offset, y_max)
}

struct Woff2CompositeSize {
	size              int
	have_instructions bool
}

// Measures the next composite glyph without consuming the stream.
fn woff2_size_of_composite(stream Woff2Buffer) ?Woff2CompositeSize {
	mut composite := stream
	start_offset := composite.offset
	mut have_instructions := false
	mut flags := u16(woff2_flag_more_components)
	for flags & woff2_flag_more_components != 0 {
		flags = composite.read_u16()?
		have_instructions = have_instructions || flags & woff2_flag_we_have_instructions != 0
		mut arg_size := 2 // glyph index
		arg_size += if flags & woff2_flag_arg_1_and_2_are_words != 0 { 4 } else { 2 }
		if flags & woff2_flag_we_have_a_scale != 0 {
			arg_size += 2
		} else if flags & woff2_flag_we_have_an_x_and_y_scale != 0 {
			arg_size += 4
		} else if flags & woff2_flag_we_have_a_two_by_two != 0 {
			arg_size += 8
		}
		if !composite.skip(arg_size) {
			return none
		}
	}
	return Woff2CompositeSize{composite.offset - start_offset, have_instructions}
}

fn woff2_store_loca(loca_values []u32, index_format u16, mut out Woff2Out) ?u32 {
	offset_size := if index_format != 0 { 4 } else { 2 }
	mut loca_content := []u8{len: loca_values.len * offset_size}
	mut offset := 0
	for value in loca_values {
		if index_format != 0 {
			offset = woff2_store_u32(mut loca_content, offset, value)
		} else {
			offset = woff2_store_16(mut loca_content, offset, int(value >> 1))
		}
	}
	out.write(loca_content)?
	return woff2_compute_ulong_sum(loca_content)
}

struct Woff2GlyfResult {
	glyf_checksum u32
	loca_checksum u32
}

// Reconstructs the entire glyf and loca tables from the transformed glyf data.
fn woff2_reconstruct_glyf(data []u8, mut glyf_table Woff2Table, mut loca_table Woff2Table, mut info Woff2FontInfo, mut out Woff2Out) ?Woff2GlyfResult {
	num_sub_streams := 7
	mut file := Woff2Buffer{
		data: unsafe { data[..int(glyf_table.transform_length)] }
	}
	glyf_start := out.data.len
	file.read_u32()? // version
	info.num_glyphs = file.read_u16()?
	info.index_format = file.read_u16()?
	// https://dev.w3.org/webfonts/WOFF2/spec/#conform-mustRejectLoca
	expected_loca_dst_length := u32(if info.index_format != 0 { 4 } else { 2 }) * (u32(info.num_glyphs) +
		1)
	if loca_table.dst_length != expected_loca_dst_length {
		return none
	}
	mut offset := u32((2 + num_sub_streams) * 4)
	if offset > glyf_table.transform_length {
		return none
	}
	mut substreams := []Woff2Buffer{cap: num_sub_streams}
	for _ in 0 .. num_sub_streams {
		substream_size := file.read_u32()?
		if substream_size > glyf_table.transform_length - offset {
			return none
		}
		substreams << Woff2Buffer{
			data: unsafe { data[int(offset)..int(offset + substream_size)] }
		}
		offset += substream_size
	}
	mut n_contour_stream := substreams[0]
	mut n_points_stream := substreams[1]
	mut flag_stream := substreams[2]
	mut glyph_stream := substreams[3]
	mut composite_stream := substreams[4]
	mut bbox_stream := substreams[5]
	mut instruction_stream := substreams[6]

	mut loca_values := []u32{len: int(info.num_glyphs) + 1}
	bitmap_length := ((int(info.num_glyphs) + 31) >> 5) << 2
	if !bbox_stream.skip(bitmap_length) {
		return none
	}
	bbox_bitmap := unsafe { bbox_stream.data[..bitmap_length] }
	mut glyf_checksum := u32(0)
	mut points := []Woff2Point{}
	mut n_points_vec := []int{}
	info.x_mins = []i16{len: int(info.num_glyphs)}
	for i in 0 .. int(info.num_glyphs) {
		mut glyph_buf := []u8{}
		mut glyph_size := 0
		have_bbox := bbox_bitmap[i >> 3] & (0x80 >> (i & 7)) != 0
		n_contours := n_contour_stream.read_u16()?
		if n_contours == 0xffff {
			// Composite glyphs must have an explicit bbox.
			if !have_bbox {
				return none
			}
			composite := woff2_size_of_composite(composite_stream)?
			mut instruction_size := 0
			if composite.have_instructions {
				instruction_size = int(glyph_stream.read_255_ushort()?)
			}
			glyph_buf = []u8{len: 12 + composite.size + instruction_size}
			glyph_size = woff2_store_16(mut glyph_buf, glyph_size, n_contours)
			bbox := bbox_stream.read_bytes(8)?
			copy(mut glyph_buf[glyph_size..], bbox)
			glyph_size += 8
			composite_bytes := composite_stream.read_bytes(composite.size)?
			copy(mut glyph_buf[glyph_size..], composite_bytes)
			glyph_size += composite.size
			if composite.have_instructions {
				glyph_size = woff2_store_16(mut glyph_buf, glyph_size, instruction_size)
				instructions := instruction_stream.read_bytes(instruction_size)?
				copy(mut glyph_buf[glyph_size..], instructions)
				glyph_size += instruction_size
			}
		} else if n_contours > 0 {
			// Simple glyph.
			n_points_vec.clear()
			mut total_n_points := u32(0)
			for _ in 0 .. int(n_contours) {
				n_points_contour := n_points_stream.read_255_ushort()?
				n_points_vec << int(n_points_contour)
				total_n_points += n_points_contour
			}
			flag_size := int(total_n_points)
			if flag_size > flag_stream.data.len - flag_stream.offset {
				return none
			}
			flags_buf := unsafe { flag_stream.data[flag_stream.offset..] }
			triplet_buf := unsafe { glyph_stream.data[glyph_stream.offset..] }
			points.clear()
			triplet_bytes_consumed := woff2_triplet_decode(flags_buf, triplet_buf, flag_size, mut
				points)?
			if !flag_stream.skip(flag_size) || !glyph_stream.skip(triplet_bytes_consumed) {
				return none
			}
			instruction_size := glyph_stream.read_255_ushort()?
			if total_n_points >= (1 << 27) || instruction_size >= (1 << 30) {
				return none
			}
			glyph_buf = []u8{len: 12 + 2 * int(n_contours) + 5 * int(total_n_points) +
				int(instruction_size)}
			glyph_size = woff2_store_16(mut glyph_buf, glyph_size, n_contours)
			if have_bbox {
				bbox := bbox_stream.read_bytes(8)?
				copy(mut glyph_buf[glyph_size..], bbox)
			} else {
				woff2_compute_bbox(points, mut glyph_buf)
			}
			glyph_size = woff2_end_pts_of_contours_offset
			mut end_point := -1
			for n_points_contour in n_points_vec {
				end_point += n_points_contour
				if end_point >= 65536 {
					return none
				}
				glyph_size = woff2_store_16(mut glyph_buf, glyph_size, end_point)
			}
			glyph_size = woff2_store_16(mut glyph_buf, glyph_size, int(instruction_size))
			instructions := instruction_stream.read_bytes(int(instruction_size))?
			copy(mut glyph_buf[glyph_size..], instructions)
			glyph_size += int(instruction_size)
			glyph_size = woff2_store_points(points, int(n_contours), int(instruction_size), mut
				glyph_buf)?
		} else if have_bbox {
			// An empty glyph must not have a bbox.
			return none
		}
		loca_values[i] = u32(out.data.len - glyf_start)
		glyph := unsafe { glyph_buf[..glyph_size] }
		out.write(glyph)?
		out.pad4()?
		glyf_checksum += woff2_compute_ulong_sum(glyph)
		// x_min may be needed to reconstruct hmtx.
		if n_contours > 0 {
			info.x_mins[i] = i16(binary.big_endian_u16_at(glyph_buf, 2))
		}
	}
	glyf_table.dst_length = u32(out.data.len) - glyf_table.dst_offset
	loca_table.dst_offset = u32(out.data.len)
	// loca[n] is the length of the glyph data (glyf) table.
	loca_values[int(info.num_glyphs)] = glyf_table.dst_length
	loca_checksum := woff2_store_loca(loca_values, info.index_format, mut out)?
	loca_table.dst_length = u32(out.data.len) - loca_table.dst_offset
	return Woff2GlyfResult{glyf_checksum, loca_checksum}
}

// http://dev.w3.org/webfonts/WOFF2/spec/Overview.html#hmtx_table_format
fn woff2_reconstruct_transformed_hmtx(transformed []u8, num_glyphs u16, num_hmetrics u16, x_mins []i16, mut out Woff2Out) ?u32 {
	mut input := Woff2Buffer{
		data: transformed
	}
	hmtx_flags := input.read_u8()?
	has_proportional_lsbs := hmtx_flags & 1 == 0
	has_monospace_lsbs := hmtx_flags & 2 == 0
	// Bits 2-7 are reserved and must be zero.
	if hmtx_flags & 0xfc != 0 {
		return none
	}
	// A transformed table must omit at least one lsb array.
	if has_proportional_lsbs && has_monospace_lsbs {
		return none
	}
	if x_mins.len != int(num_glyphs) || num_hmetrics > num_glyphs || num_hmetrics < 1 {
		return none
	}
	mut advance_widths := []u16{cap: int(num_hmetrics)}
	for _ in 0 .. int(num_hmetrics) {
		advance_widths << input.read_u16()?
	}
	mut lsbs := []i16{cap: int(num_glyphs)}
	for i in 0 .. int(num_hmetrics) {
		lsbs << if has_proportional_lsbs { i16(input.read_u16()?) } else { x_mins[i] }
	}
	for i in int(num_hmetrics) .. int(num_glyphs) {
		lsbs << if has_monospace_lsbs { i16(input.read_u16()?) } else { x_mins[i] }
	}
	mut hmtx_table := []u8{len: 2 * int(num_glyphs) + 2 * int(num_hmetrics)}
	mut dst_offset := 0
	for i in 0 .. int(num_glyphs) {
		if i < int(num_hmetrics) {
			dst_offset = woff2_store_16(mut hmtx_table, dst_offset, int(advance_widths[i]))
		}
		dst_offset = woff2_store_16(mut hmtx_table, dst_offset, int(lsbs[i]))
	}
	out.write(hmtx_table)?
	return woff2_compute_ulong_sum(hmtx_table)
}

fn woff2_read_table_directory(mut file Woff2Buffer, num_tables int) ?[]Woff2Table {
	mut tables := []Woff2Table{len: num_tables}
	mut src_offset := u32(0)
	for i in 0 .. num_tables {
		flag_byte := file.read_u8()?
		tag := if flag_byte & 0x3f == 0x3f {
			file.read_u32()?
		} else {
			woff2_known_tags[flag_byte & 0x3f]
		}
		mut flags := u32(0)
		xform_version := u32((flag_byte >> 6) & 0x03)
		// Version 0 transforms glyf/loca; nonzero versions transform the others.
		if tag == woff2_tag_glyf || tag == woff2_tag_loca {
			if xform_version == 0 {
				flags |= woff2_flags_transform
			}
		} else if xform_version != 0 {
			flags |= woff2_flags_transform
		}
		flags |= xform_version
		dst_length := file.read_base128()?
		mut transform_length := dst_length
		if flags & woff2_flags_transform != 0 {
			transform_length = file.read_base128()?
			if tag == woff2_tag_loca && transform_length != 0 {
				return none
			}
		}
		if src_offset + transform_length < src_offset {
			return none
		}
		tables[i] = Woff2Table{
			tag:              tag
			flags:            flags
			src_offset:       src_offset
			src_length:       transform_length
			transform_length: transform_length
			dst_length:       dst_length
		}
		src_offset += transform_length
	}
	return tables
}

fn woff2_store_offset_table(mut result []u8, offset int, flavor u32, num_tables int) int {
	mut pos := woff2_store_u32(mut result, offset, flavor)
	pos = woff2_store_16(mut result, pos, num_tables)
	mut max_pow2 := 0
	for (1 << (max_pow2 + 1)) <= num_tables {
		max_pow2++
	}
	output_search_range := u16((1 << max_pow2) << 4)
	pos = woff2_store_16(mut result, pos, int(output_search_range))
	pos = woff2_store_16(mut result, pos, max_pow2)
	return woff2_store_16(mut result, pos, int(u16(num_tables << 4) - output_search_range))
}

fn woff2_store_table_entry(mut result []u8, offset int, tag u32) int {
	mut pos := woff2_store_u32(mut result, offset, tag)
	pos = woff2_store_u32(mut result, pos, 0)
	pos = woff2_store_u32(mut result, pos, 0)
	return woff2_store_u32(mut result, pos, 0)
}

// The first table goes after all the headers and table directories.
fn woff2_offset_to_first_table(hdr Woff2Header) u64 {
	mut offset := u64(woff2_sfnt_header_size) + u64(woff2_sfnt_entry_size) * u64(hdr.num_tables)
	if hdr.header_version != 0 {
		offset = woff2_collection_header_size(hdr.header_version, hdr.ttc_fonts.len) +
			u64(woff2_sfnt_header_size) * u64(hdr.ttc_fonts.len)
		for ttc_font in hdr.ttc_fonts {
			offset += u64(woff2_sfnt_entry_size) * u64(ttc_font.table_indices.len)
		}
	}
	return offset
}

fn woff2_font_table_indices(hdr Woff2Header, font_index int) []int {
	if hdr.header_version != 0 {
		return hdr.ttc_fonts[font_index].table_indices
	}
	return []int{len: hdr.tables.len, init: index}
}

fn woff2_find_table(hdr Woff2Header, indices []int, tag u32) int {
	for index in indices {
		if hdr.tables[index].tag == tag {
			return index
		}
	}
	return -1
}

// Table directories were written with zeros; fill them while rebuilding the font.
fn woff2_reconstruct_font(mut transformed_buf []u8, mut metadata Woff2RebuildMetadata, mut hdr Woff2Header, font_index int, mut out Woff2Out) ? {
	mut dest_offset := u32(out.data.len)
	mut info := metadata.font_infos[font_index]
	indices := woff2_font_table_indices(hdr, font_index)
	// glyf without loca does not make sense.
	glyf_index := woff2_find_table(hdr, indices, woff2_tag_glyf)
	loca_index := woff2_find_table(hdr, indices, woff2_tag_loca)
	if (glyf_index >= 0) != (loca_index >= 0) {
		return none
	}
	if glyf_index >= 0 && hdr.tables[glyf_index].flags & woff2_flags_transform != hdr.tables[loca_index].flags & woff2_flags_transform {
		return none
	}
	mut font_checksum := metadata.header_checksum
	if hdr.header_version != 0 {
		font_checksum = hdr.ttc_fonts[font_index].header_checksum
	}
	mut loca_checksum := u32(0)
	for index in indices {
		mut table := hdr.tables[index]
		checksum_key := '${table.tag}:${table.src_offset}'
		reused := checksum_key in metadata.checksums
		if font_index == 0 && reused {
			return none
		}
		// A collection with optimized hmtx that reused glyf/loca would fail; the
		// source does not optimize hmtx for collections.
		if u64(table.src_offset) + u64(table.src_length) > u64(transformed_buf.len) {
			return none
		}
		if !reused && table.flags & woff2_flags_transform != woff2_flags_transform
			&& table.tag == woff2_tag_head {
			if table.src_length < 12 {
				return none
			}
			// checkSumAdjustment = 0
			woff2_store_u32(mut transformed_buf, int(table.src_offset) + 8, 0)
		}
		source := unsafe { transformed_buf[int(table.src_offset)..int(table.src_offset + table.src_length)] }
		if table.tag == woff2_tag_hhea {
			// numberOfHMetrics follows 34 bytes of hhea.
			if source.len < 36 {
				return none
			}
			info.num_hmetrics = binary.big_endian_u16_at(source, 34)
		}
		mut checksum := u32(0)
		if !reused {
			if table.flags & woff2_flags_transform != woff2_flags_transform {
				table.dst_offset = dest_offset
				checksum = woff2_compute_ulong_sum(source)
				out.write(source)?
			} else if table.tag == woff2_tag_glyf {
				table.dst_offset = dest_offset
				mut loca_table := hdr.tables[loca_index]
				result := woff2_reconstruct_glyf(source, mut table, mut loca_table, mut info, mut
					out)?
				hdr.tables[loca_index] = loca_table
				checksum = result.glyf_checksum
				loca_checksum = result.loca_checksum
			} else if table.tag == woff2_tag_loca {
				// ReconstructGlyf did all the work; reload its dst fields.
				table = hdr.tables[index]
				checksum = loca_checksum
			} else if table.tag == woff2_tag_hmtx {
				table.dst_offset = dest_offset
				// Tables are sorted so all the needed info has been gathered.
				checksum = woff2_reconstruct_transformed_hmtx(source, info.num_glyphs, info.num_hmetrics,
					info.x_mins, mut out)?
			} else {
				// Unknown transform.
				return none
			}
			metadata.checksums[checksum_key] = checksum
		} else {
			checksum = metadata.checksums[checksum_key]
		}
		hdr.tables[index] = table
		font_checksum += checksum
		// Update the table entry with real values.
		mut table_entry := []u8{len: 12}
		woff2_store_u32(mut table_entry, 0, checksum)
		woff2_store_u32(mut table_entry, 4, table.dst_offset)
		woff2_store_u32(mut table_entry, 8, table.dst_length)
		out.write_at(table_entry, info.table_entry_by_tag[table.tag] + 4)?
		// The zeros were replaced; update the overall checksum.
		font_checksum += woff2_compute_ulong_sum(table_entry)
		out.pad4()?
		if u64(table.dst_offset) + u64(table.dst_length) > u64(out.data.len) {
			return none
		}
		dest_offset = u32(out.data.len)
	}
	// Update head checkSumAdjustment; it was zeroed before summing the font.
	head_index := woff2_find_table(hdr, indices, woff2_tag_head)
	if head_index >= 0 {
		head_table := hdr.tables[head_index]
		if head_table.dst_length < 12 {
			return none
		}
		mut adjustment := []u8{len: 4}
		woff2_store_u32(mut adjustment, 0, u32(0xb1b0afba) - font_checksum)
		out.write_at(adjustment, int(head_table.dst_offset) + 8)?
	}
	metadata.font_infos[font_index] = info
}

fn woff2_read_header(data []u8) ?Woff2Header {
	length := u64(data.len)
	mut file := Woff2Buffer{
		data: data
	}
	mut hdr := Woff2Header{}
	if file.read_u32()? != woff2_signature {
		return none
	}
	hdr.flavor = file.read_u32()?
	if u64(file.read_u32()?) != length {
		return none
	}
	hdr.num_tables = file.read_u16()?
	if hdr.num_tables == 0 {
		return none
	}
	// reserved and totalSfntSize are recomputed rather than trusted.
	if !file.skip(6) {
		return none
	}
	hdr.compressed_length = file.read_u32()?
	// majorVersion and minorVersion.
	if !file.skip(4) {
		return none
	}
	meta_offset := file.read_u32()?
	meta_length := file.read_u32()?
	file.read_u32()? // metaOrigLength
	if meta_offset != 0 && (u64(meta_offset) >= length || length - u64(meta_offset) < u64(meta_length)) {
		return none
	}
	priv_offset := file.read_u32()?
	priv_length := file.read_u32()?
	if priv_offset != 0 && (u64(priv_offset) >= length || length - u64(priv_offset) < u64(priv_length)) {
		return none
	}
	hdr.tables = woff2_read_table_directory(mut file, int(hdr.num_tables))?
	// Before output sorting, the last table end is the uncompressed size.
	last_table := hdr.tables.last()
	hdr.uncompressed_size = last_table.src_offset + last_table.src_length
	if hdr.uncompressed_size < last_table.src_offset {
		return none
	}
	if hdr.flavor == woff2_ttc_flavor {
		hdr.header_version = file.read_u32()?
		if hdr.header_version != 0x00010000 && hdr.header_version != 0x00020000 {
			return none
		}
		num_fonts := file.read_255_ushort()?
		if num_fonts == 0 {
			return none
		}
		hdr.ttc_fonts = []Woff2TtcFont{len: int(num_fonts)}
		for i in 0 .. int(num_fonts) {
			num_tables := file.read_255_ushort()?
			if num_tables == 0 {
				return none
			}
			mut ttc_font := Woff2TtcFont{
				flavor: file.read_u32()?
			}
			mut glyf_idx := 0
			mut loca_idx := 0
			for _ in 0 .. int(num_tables) {
				table_idx := int(file.read_255_ushort()?)
				if table_idx >= hdr.tables.len {
					return none
				}
				ttc_font.table_indices << table_idx
				if hdr.tables[table_idx].tag == woff2_tag_loca {
					loca_idx = table_idx
				}
				if hdr.tables[table_idx].tag == woff2_tag_glyf {
					glyf_idx = table_idx
				}
			}
			// glyf and loca must be consecutive; a lone table is rejected later.
			if (glyf_idx > 0 || loca_idx > 0) && (glyf_idx > loca_idx || loca_idx - glyf_idx != 1) {
				return none
			}
			hdr.ttc_fonts[i] = ttc_font
		}
	}
	hdr.compressed_offset = u64(file.offset)
	mut src_offset := woff2_round4(hdr.compressed_offset + u64(hdr.compressed_length))
	if src_offset > length {
		return none
	}
	if meta_offset != 0 {
		if src_offset != u64(meta_offset) {
			return none
		}
		// The source rounds the wrapping uint32 sum, saturating near the limit.
		src_offset = u64(woff2_round4_u32(meta_offset + meta_length))
	}
	if priv_offset != 0 {
		if src_offset != u64(priv_offset) {
			return none
		}
		src_offset = u64(woff2_round4_u32(priv_offset + priv_length))
	}
	if src_offset != woff2_round4(length) {
		return none
	}
	return hdr
}

// Writes everything before the actual table data.
fn woff2_write_headers(mut metadata Woff2RebuildMetadata, mut hdr Woff2Header, mut out Woff2Out) ? {
	mut output := []u8{len: int(woff2_offset_to_first_table(hdr))}
	mut offset := 0
	if hdr.header_version != 0 {
		// A collection sorts the table indices of each font by tag.
		for mut ttc_font in hdr.ttc_fonts {
			mut sorted_index_by_tag := map[u32]int{}
			for table_index in ttc_font.table_indices {
				sorted_index_by_tag[hdr.tables[table_index].tag] = table_index
			}
			mut tags := sorted_index_by_tag.keys()
			tags.sort(a < b)
			for i, tag in tags {
				ttc_font.table_indices[i] = sorted_index_by_tag[tag]
			}
			// std::map collapses duplicate tags; the source keeps the stale tail.
		}
		offset = woff2_store_u32(mut output, offset, hdr.flavor) // TTCTag
		offset = woff2_store_u32(mut output, offset, hdr.header_version)
		offset = woff2_store_u32(mut output, offset, u32(hdr.ttc_fonts.len))
		mut offset_table := offset
		for _ in 0 .. hdr.ttc_fonts.len {
			offset = woff2_store_u32(mut output, offset, 0)
		}
		if hdr.header_version == 0x00020000 {
			// ulDsigTag, ulDsigLength and ulDsigOffset.
			offset = woff2_store_u32(mut output, offset, 0)
			offset = woff2_store_u32(mut output, offset, 0)
			offset = woff2_store_u32(mut output, offset, 0)
		}
		metadata.font_infos = []Woff2FontInfo{len: hdr.ttc_fonts.len}
		for i in 0 .. hdr.ttc_fonts.len {
			offset_table = woff2_store_u32(mut output, offset_table, u32(offset))
			hdr.ttc_fonts[i].dst_offset = u32(offset)
			offset = woff2_store_offset_table(mut output, offset, hdr.ttc_fonts[i].flavor,
				hdr.ttc_fonts[i].table_indices.len)
			for table_index in hdr.ttc_fonts[i].table_indices {
				tag := hdr.tables[table_index].tag
				metadata.font_infos[i].table_entry_by_tag[tag] = offset
				offset = woff2_store_table_entry(mut output, offset, tag)
			}
			start := int(hdr.ttc_fonts[i].dst_offset)
			hdr.ttc_fonts[i].header_checksum = woff2_compute_ulong_sum(output[start..offset])
		}
	} else {
		// Re-order the table directory in OpenType (tag) order.
		mut sorted_tags := hdr.tables.map(it.tag)
		sorted_tags.sort(a < b)
		metadata.font_infos = []Woff2FontInfo{len: 1}
		offset = woff2_store_offset_table(mut output, offset, hdr.flavor, int(hdr.num_tables))
		for tag in sorted_tags {
			metadata.font_infos[0].table_entry_by_tag[tag] = offset
			offset = woff2_store_table_entry(mut output, offset, tag)
		}
	}
	out.write(output)?
	metadata.header_checksum = woff2_compute_ulong_sum(output)
}

// BrotliDecoderDecompress stops at the stream's last meta-block and ignores
// any remaining input. vlib's V decoder rejects bytes after the stream, so find
// its end by decoding prefixes: shorter ones are truncated, longer ones trail.
fn woff2_brotli_decompress(data []u8) ![]u8 {
	mut message := ''
	whole := brotli.decompress(data) or {
		message = err.msg()
		[]u8{}
	}
	if message == '' {
		return whole
	}
	if !message.contains('trailing data') {
		return error(message)
	}
	mut low := 1
	mut high := data.len - 1
	for low <= high {
		middle := low + (high - low) / 2
		message = ''
		decoded := brotli.decompress(unsafe { data[..middle] }) or {
			message = err.msg()
			[]u8{}
		}
		if message == '' {
			return decoded
		}
		if message.contains('trailing data') {
			high = middle - 1
		} else if message.contains('truncated') {
			low = middle + 1
		} else {
			return error(message)
		}
	}
	return error('brotli: stream end not found')
}

fn woff2_convert_to_ttf(data []u8) ?[]u8 {
	mut hdr := woff2_read_header(data)?
	mut metadata := Woff2RebuildMetadata{}
	mut out := Woff2Out{}
	woff2_write_headers(mut metadata, mut hdr, mut out)?
	compression_ratio := f32(hdr.uncompressed_size) / f32(data.len)
	if compression_ratio > woff2_max_plausible_compression_ratio || hdr.uncompressed_size < 1 {
		return none
	}
	compressed_end := hdr.compressed_offset + hdr.compressed_length
	if compressed_end > u64(data.len) {
		return none
	}
	mut uncompressed := woff2_brotli_decompress(data[int(hdr.compressed_offset)..int(compressed_end)]) or {
		return none
	}
	if uncompressed.len != int(hdr.uncompressed_size) {
		return none
	}
	for i in 0 .. metadata.font_infos.len {
		woff2_reconstruct_font(mut uncompressed, mut metadata, mut hdr, i, mut out)?
	}
	return out.data
}

// LibGfx/Font/WOFF2/Loader.cpp: convert_to_ttf.
pub fn convert_woff2_to_sfnt(data []u8) ![]u8 {
	if woff2_decompressed_table_data_size(data)! > woff2_max_output_size {
		return error('Decompressed WOFF2 table data is too big')
	}
	return woff2_convert_to_ttf(data) or {
		return error('Failed to convert the WOFF2 font to TTF')
	}
}
