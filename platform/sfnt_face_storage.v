module platform

import os

struct SFNTFaceTableRegion {
	source_offset u64
	length        int
	storage_offset int
	read_length   int
}

fn read_sfnt_bytes_at(file &os.File, offset u64, mut bytes []u8) bool {
	if bytes.len == 0 { return true }
	return (file.read_bytes_into(offset, mut bytes) or { return false }) == bytes.len
}

fn write_sfnt_u32(mut bytes []u8, offset int, value u32) {
	bytes[offset] = u8(value >> 24)
	bytes[offset + 1] = u8(value >> 16)
	bytes[offset + 2] = u8(value >> 8)
	bytes[offset + 3] = u8(value)
}

// x.ttf needs a standalone sfnt directory with absolute offsets into its own
// buffer. Read only the selected face's tables from a collection, then relocate
// their offsets into one owned buffer. Unrelated collection faces are never read
// or retained. Every selected table, including unknown tables, stays intact.
fn read_outline_face_bytes(path string, face_index int) ?[]u8 {
	if face_index < 0 { return none }
	mut file := os.open(path) or { return none }
	defer { file.close() }
	file.seek(0, .end) or { return none }
	file_size := file.tell() or { return none }
	if file_size < 12 || file_size > i64(0x7fffffff) { return none }
	mut header := []u8{len: 12}
	if !read_sfnt_bytes_at(&file, 0, mut header) { return none }
	is_collection := font_u32_at(header, 0)? == u32(0x74746366)
	mut directory_offset := u64(0)
	if is_collection {
		version := font_u32_at(header, 4)?
		if version != 0x00010000 && version != 0x00020000 { return none }
		count := u64(font_u32_at(header, 8)?)
		if count == 0 || count > u64((file_size - 12) / 4) || u64(face_index) >= count {
			return none
		}
		collection_header_length := u64(12) + count * 4 + if version == 0x00020000 { u64(12) } else { u64(0) }
		if collection_header_length > u64(file_size) { return none }
		mut selected_offset := []u8{len: 4}
		if !read_sfnt_bytes_at(&file, 12 + u64(face_index) * 4, mut selected_offset) { return none }
		directory_offset = u64(font_u32_at(selected_offset, 0)?)
		if directory_offset < collection_header_length || directory_offset > u64(file_size - 12)
			|| !read_sfnt_bytes_at(&file, directory_offset, mut header) { return none }
	} else if face_index != 0 {
		return none
	}
	signature := font_u32_at(header, 0)?
	if signature != 0x00010000 && signature != 0x4f54544f
		&& signature != 0x74727565 && signature != 0x74797031 { return none }
	table_count := int(font_u16_at(header, 4)?)
	if table_count == 0 { return none }
	directory_length := 12 + table_count * 16
	if u64(directory_length) > u64(file_size) - directory_offset { return none }
	mut directory := []u8{len: directory_length}
	if !read_sfnt_bytes_at(&file, directory_offset, mut directory) { return none }
	mut regions := []SFNTFaceTableRegion{cap: table_count}
	mut region_by_source := map[u64]int{}
	mut record_regions := []int{len: table_count}
	mut storage_length := i64(directory_length)
	for index in 0 .. table_count {
		record := 12 + index * 16
		offset := u64(font_u32_at(directory, record + 8)?)
		length := u64(font_u32_at(directory, record + 12)?)
		if offset > u64(file_size) || length > u64(file_size) - offset { return none }
		// Identical ranges can be shared by two tags. Preserve that sharing
		// instead of expanding their storage once per directory entry.
		key := (offset << 32) | length
		if previous := region_by_source[key] {
			record_regions[index] = previous
			continue
		}
		padded_length := (length + 3) & ~u64(3)
		if padded_length > u64(i64(0x7fffffff) - storage_length) { return none }
		// Preserve existing source padding when present; a final unpadded
		// table gets zero padding in the private standalone sfnt buffer.
		available := u64(file_size) - offset
		read_length := if padded_length < available { padded_length } else { available }
		record_regions[index] = regions.len
		region_by_source[key] = regions.len
		regions << SFNTFaceTableRegion{
			source_offset: offset
			length: int(length)
			storage_offset: int(storage_length)
			read_length: int(read_length)
		}
		storage_length += i64(padded_length)
	}
	mut bytes := []u8{len: int(storage_length)}
	copy(mut bytes[..directory_length], directory)
	for region in regions {
		mut destination := unsafe { bytes[region.storage_offset..region.storage_offset + region.read_length] }
		if !read_sfnt_bytes_at(&file, region.source_offset, mut destination) { return none }
	}
	for index in 0 .. table_count {
		record := 12 + index * 16
		region := regions[record_regions[index]]
		write_sfnt_u32(mut bytes, record + 8, u32(region.storage_offset))
		// Preserve the collection adapter's existing unsupported-kern rule.
		// HarfBuzz remains authoritative for shaping and kerning.
		if is_collection && bytes[record] == `k` && bytes[record + 1] == `e`
			&& bytes[record + 2] == `r` && bytes[record + 3] == `n` {
			if region.length < 2 { return none }
			if font_u16_at(bytes, region.storage_offset)? != 0 { bytes[record] = `K` }
		}
	}
	return bytes
}
