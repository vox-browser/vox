module platform

// Measure only ranges whose two boundaries HarfBuzz proved independent of
// their surrounding text. A missing cache entry or unknown cluster keeps the
// caller on its ordinary independent-shaping path.
fn cached_shape_safe_break_width(shape CachedShape, start int, length int,
	text_length int) ?f32 {
	if shape.face != .document || start < 0 || length <= 0 || start > text_length
		|| length > text_length - start {
		return none
	}
	mut offset := 0
	mut first := -1
	mut end := -1
	for index, glyph in shape.glyphs {
		if glyph.length_in_code_units <= 0 || glyph.shaping_break_safety !in [u8(1), 2] {
			return none
		}
		if offset == start { first = index }
		if offset == start + length { end = index }
		offset += glyph.length_in_code_units
		if offset > text_length { return none }
	}
	if offset != text_length { return none }
	if offset == start + length { end = shape.glyphs.len }
	if first < 0 || end <= first || shape.glyphs[first].shaping_break_safety != 1
		|| (end < shape.glyphs.len && shape.glyphs[end].shaping_break_safety != 1) {
		return none
	}
	mut advance := f64(0)
	for index in first .. end { advance += f64(shape.glyphs[index].advance) }
	// An independently shaped piece has no following glyph placement. Unlike
	// a context slice, its endpoint must not include the next glyph's offset.
	return f32(advance - f64(shape.glyphs[first].offset_x))
}

pub fn shaped_text_safe_break_width(letter_spacing f32, word_spacing f32, text string,
	start int, length int, font &Font) ?f32 {
	if font.font_rendering_policy != .chromium || !text.is_ascii() || start < 0
		|| length <= 0 || start > text.len || length > text.len - start {
		return none
	}
	font_key := shaping_cache_font_key(font)
	params := ShapeParams.new(.ltr, letter_spacing, word_spacing)
	mut cache := shared_shaping_cache()
	shape := cache.lookup(font_key, text, params) or { return none }
	return cached_shape_safe_break_width(shape, start, length, text.len)
}
