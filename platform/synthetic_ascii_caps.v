module platform

fn (font &Font) shaping_code_point(code_point u32) u32 {
	if font.synthesize_ascii_caps && code_point >= u32(`a`) && code_point <= u32(`z`) {
		return code_point - 32
	}
	return code_point
}

fn (font &Font) text_for_shaping(text string) string {
	if !font.synthesize_ascii_caps { return text }
	mut bytes := text.bytes()
	for index, value in bytes {
		if value >= `a` && value <= `z` { bytes[index] = value - 32 }
	}
	return bytes.bytestr()
}

// A face with native small-cap substitutions should use those glyphs instead
// of the ASCII synthesis fallback. Non-ASCII case mapping remains unchanged.
pub fn (font &Font) has_gsub_feature(tag string) bool {
	if tag.len != 4 { return false }
	face := font_face(font) or { return false }
	table := font_table_offset(face.buf, 'GSUB') or { return false }
	features_offset := font_u16_at(face.buf, table + 6) or { return false }
	features := table + int(features_offset)
	count := font_u16_at(face.buf, features) or { return false }
	for index in 0 .. int(count) {
		start := features + 2 + index * 6
		if start + 4 > face.buf.len { return false }
		if face.buf[start..start + 4].bytestr() == tag { return true }
	}
	return false
}
