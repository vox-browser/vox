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

// Unicode punctuation is shaped with a guessed script. Require an ASCII
// Latin letter in the piece as well as in the cached paragraph, so both
// independent and contextual shaping select Latin. Offsets remain UTF-16.
fn cached_shape_safe_latin_punctuation_width(shape CachedShape, start int, length int) ?f32 {
	if shape.safe_break_boundaries.len == 0 { return none }
	text_length := shape.safe_break_boundaries.len - 1
	width := cached_shape_safe_break_width(shape, start, length, text_length) or { return none }
	first := shape.safe_break_boundaries[start]
	end := shape.safe_break_boundaries[start + length]
	for index in first .. end {
		code_point := shape.glyphs[index].code_point
		if (code_point >= `A` && code_point <= `Z`) || (code_point >= `a` && code_point <= `z`) {
			return width
		}
	}
	return none
}

pub fn shaped_text_safe_break_width(letter_spacing f32, word_spacing f32, text string,
	start int, length int, font &Font) ?f32 {
	if font.font_rendering_policy != .chromium || start < 0 || length <= 0 {
		return none
	}
	is_ascii := text.is_ascii()
	if is_ascii && (start > text.len || length > text.len - start) { return none }
	font_key := shaping_cache_font_key(font)
	params := ShapeParams.new(.ltr, letter_spacing, word_spacing)
	mut cache := shared_shaping_cache()
	shape := cache.lookup(font_key, text, params) or { return none }
	if !is_ascii { return cached_shape_safe_latin_punctuation_width(shape, start, length) }
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

// A caller may retain this handle across layouts. Keys own their bytes; the
// immutable glyph view is used only in the shared cache generation that owns
// it. Evictions also change the generation, protecting the recency indices.
@[heap]
pub struct SafeBreakWidthCache {
mut:
	generation u64
	font_key string
	text string
	params ShapeParams
	shape CachedShape
	font_index int
	text_index int
	is_ascii bool
	has_repeated_spaces bool
}

pub fn shaped_text_safe_break_width_cached(mut local SafeBreakWidthCache,
	letter_spacing f32, word_spacing f32, text string, start int, length int,
	font &Font, collapses_spaces bool) ?f32 {
	if font.font_rendering_policy != .chromium || start < 0 || length <= 0 { return none }
	font_key := shaping_cache_font_key(font)
	params := ShapeParams.new(.ltr, letter_spacing, word_spacing)
	mut cache := shared_shaping_cache()
	if local.generation != platform_safe_break_cache_generation || local.font_key != font_key
		|| !local.params.matches(params) || local.text != text {
		shape := cache.lookup(font_key, text, params) or { return none }
		// Text may originate in a scratch scope. Retain independent key bytes.
		persistent := enter_persistent()
		if local.text != text { local.text = text.clone() }
		if local.font_key != font_key { local.font_key = font_key.clone() }
		leave_persistent(persistent)
		local.is_ascii = text.is_ascii()
		local.has_repeated_spaces = text.contains('  ')
		local.params = params
		local.shape = shape
		local.font_index = cache.font_index(font_key)
		local.text_index = cache.text_index(local.font_index, text)
		local.generation = platform_safe_break_cache_generation
	} else {
		// Preserve lookup recency even when the immutable shape is already local.
		cache.tick++
		cache.fonts[local.font_index].last_used_tick = cache.tick
		if local.text_index >= 0 {
			cache.fonts[local.font_index].shapes_by_text[local.text_index].last_used_tick = cache.tick
		}
	}
	if collapses_spaces && local.has_repeated_spaces { return none }
	if local.is_ascii { return cached_shape_safe_break_width(local.shape, start, length, text.len) }
	return cached_shape_safe_latin_punctuation_width(local.shape, start, length)
}
