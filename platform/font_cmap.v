module platform

// Match the formats and encoding selection supported by x.ttf. Vox already
// memoizes glyph indices together with advances in platform_glyph_units_cache;
// a second 65,536-entry integer vector per cmap is redundant.
fn font_cmap_glyph(bytes []u8, code_point u32) u16 {
	if code_point > 0xffff { return 0 }
	base := font_table_offset(bytes, 'cmap') or { return 0 }
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
			glyph = if code_point < 256 && length >= 262 { u16(bytes[subtable + 6 + int(code_point)]) } else { u16(0) }
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
