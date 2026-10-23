module platform

// Match the formats and encoding selection supported by x.ttf. Vox already
// memoizes glyph indices together with advances in platform_glyph_units_cache;
// a second 65,536-entry integer vector per cmap is redundant.
fn font_cmap_glyph(bytes []u8, code_point u32) u16 {
	if code_point > 0xffff { return 0 }
	base := font_table_offset(bytes, 'cmap') or { return 0 }
	if base > bytes.len { return 0 }
	return font_cmap_table_glyph(bytes[base..], code_point)
}

// This view is borrowed for the duration of the query. Decoded sfnt callers
// retain their historical extent; native source callers supply a bounded cmap.
fn font_cmap_table_glyph(bytes []u8, code_point u32) u16 {
	if code_point > 0xffff { return 0 }
	base := 0
	count := int(font_u16_at(bytes, base + 2) or { return 0 })
	if count > (bytes.len - base - 4) / 8 { return 0 }
	mut glyph := u16(0)
	for index in 0 .. count {
		record := base + 4 + index * 8
		platform_id := font_u16_at(bytes, record) or { continue }
		encoding := font_u16_at(bytes, record + 2) or { continue }
		if platform_id != 3 || encoding > 1 { continue }
		offset := u64(font_u32_at(bytes, record + 4) or { continue }) + u64(base)
		if offset > u64(bytes.len) { continue }
		subtable := int(offset)
		format := font_u16_at(bytes, subtable) or { continue }
		length := int(font_u16_at(bytes, subtable + 2) or { continue })
		if length < 6 || length > bytes.len - subtable { continue }
		if format == 0 {
			glyph = if code_point < 256 && length >= 262 {
				u16(bytes[subtable + 6 + int(code_point)])
			} else {
				u16(0)
			}
		} else if format == 4 {
			glyph = font_cmap_format4_glyph(bytes[subtable..subtable + length], u16(code_point))
		}
	}
	return glyph
}

fn font_cmap_format4_glyph(bytes []u8, code_point u16) u16 {
	count := int(font_u16_at(bytes, 6) or { return 0 }) / 2
	if count == 0 || bytes.len < 16 || count > (bytes.len - 16) / 8 { return 0 }
	for index in 0 .. count {
		end := font_u16_at(bytes, 14 + index * 2) or { return 0 }
		start := font_u16_at(bytes, 16 + count * 2 + index * 2) or { return 0 }
		if code_point < start || code_point > end { continue }
		delta := font_u16_at(bytes, 16 + count * 4 + index * 2) or { return 0 }
		range_position := 16 + count * 6 + index * 2
		range_offset := int(font_u16_at(bytes, range_position) or { return 0 })
		if range_offset == 0 { return u16((u32(delta) + u32(code_point)) & 0xffff) }
		// Preserve x.ttf's existing range-offset mapping. Changing its delta
		// semantics belongs to a separate font compatibility change.
		return font_u16_at(bytes, range_position + range_offset + 2 * int(code_point - start)) or { 0 }
	}
	return 0
}

// Borrow the selected source face's cmap only when the standalone decoder
// would accept its container and all cmap reads stay inside that table. Any
// uncertain or malformed input keeps the existing outline-decoder fallback.
fn font_source_cmap_table(bytes []u8, face_index int) ?[]u8 {
	if face_index < 0 || bytes.len < 12 || bytes.len > 0x7fffffff { return none }
	is_collection := font_u32_at(bytes, 0)? == u32(0x74746366)
	mut directory := 0
	if is_collection {
		version := font_u32_at(bytes, 4)?
		if version != 0x00010000 && version != 0x00020000 { return none }
		count := u64(font_u32_at(bytes, 8)?)
		if count == 0 || count > u64((bytes.len - 12) / 4) || u64(face_index) >= count {
			return none
		}
		header_length := u64(12) + count * 4 + if version == 0x00020000 { u64(12) } else { u64(0) }
		offset := u64(font_u32_at(bytes, 12 + face_index * 4)?)
		if header_length > u64(bytes.len) || offset < header_length || offset > u64(bytes.len - 12) {
			return none
		}
		directory = int(offset)
	} else if face_index != 0 {
		return none
	}
	signature := font_u32_at(bytes, directory)?
	if signature != 0x00010000 && signature != 0x4f54544f
		&& signature != 0x74727565 && signature != 0x74797031 {
		return none
	}
	count := int(font_u16_at(bytes, directory + 4)?)
	directory_length := 12 + count * 16
	if count == 0 || directory_length > bytes.len - directory { return none }
	mut storage_length := u64(directory_length)
	mut cmap_offset := -1
	mut cmap_length := 0
	for index in 0 .. count {
		record := directory + 12 + index * 16
		tag := font_u32_at(bytes, record)?
		offset := u64(font_u32_at(bytes, record + 8)?)
		length := u64(font_u32_at(bytes, record + 12)?)
		if offset > u64(bytes.len) || length > u64(bytes.len) - offset { return none }
		// Counting duplicate ranges twice is deliberately conservative: an
		// unusually large shared table can still use the legacy decoder.
		storage_length += (length + 3) & ~u64(3)
		if storage_length > 0x7fffffff { return none }
		if is_collection && tag == 0x6b65726e && length < 2 { return none }
		if tag == 0x636d6170 && cmap_offset < 0 {
			cmap_offset = int(offset)
			cmap_length = int(length)
		}
	}
	if cmap_offset < 0 || cmap_length < 4 { return none }
	cmap := bytes[cmap_offset..cmap_offset + cmap_length]
	encoding_count := int(font_u16_at(cmap, 2)?)
	if encoding_count > (cmap.len - 4) / 8 { return none }
	for index in 0 .. encoding_count {
		record := 4 + index * 8
		if font_u16_at(cmap, record)? != 3 || font_u16_at(cmap, record + 2)? > 1 { continue }
		offset := u64(font_u32_at(cmap, record + 4)?)
		if offset > u64(cmap.len) || u64(cmap.len) - offset < 4 { return none }
		length := int(font_u16_at(cmap, int(offset) + 2)?)
		if length > cmap.len - int(offset) { return none }
	}
	return cmap
}
