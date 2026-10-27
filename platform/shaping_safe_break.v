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
	if shape.safe_break_boundaries.len > 0 {
		if shape.safe_break_boundaries.len - 1 != text_length { return none }
		return cached_shape_safe_break_range_width(shape, shape.safe_break_boundaries[start],
			shape.safe_break_boundaries[start + length])
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
	return cached_shape_safe_break_range_width(shape, first, end)
}

fn cached_shape_safe_break_range_width(shape CachedShape, first int, end int) ?f32 {
	if first < 0 || first >= shape.glyphs.len || end <= first || end > shape.glyphs.len || shape.glyphs[first].shaping_break_safety != 1
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

// Build the immutable boundary lookup once, inside the cache's ownership
// scope. Width queries then visit only the requested glyph range. Large or
// unknown runs keep the checked scan without retaining an oversized index.
fn cached_shape_safe_break_boundaries(shape CachedShape) []int {
	max_units := 1_048_576
	if shape.face != .document || shape.glyphs.len == 0 { return []int{} }
	mut length := 0
	for glyph in shape.glyphs {
		if glyph.length_in_code_units <= 0 || glyph.length_in_code_units > max_units - length
			|| glyph.shaping_break_safety !in [u8(1), 2] {
			return []int{}
		}
		length += glyph.length_in_code_units
	}
	mut boundaries := []int{len: length + 1, init: -1}
	mut offset := 0
	for index, glyph in shape.glyphs {
		boundaries[offset] = index
		offset += glyph.length_in_code_units
	}
	boundaries[length] = shape.glyphs.len
	return boundaries
}
