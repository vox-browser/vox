// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of LibGfx/Rust/src/text_layout.rs's shared shaping cache.
@[has_globals]
module platform

import math

const single_ascii_shape_cache_size = 128
const max_shape_cache_fonts = 64
const max_shaping_font_keys = 32
const max_shape_cache_texts_per_font = 16_384

struct ShapeParams {
	text_type           GlyphRunTextType
	letter_spacing_bits u32
	word_spacing_bits   u32
}

fn ShapeParams.new(text_type GlyphRunTextType, letter_spacing f32, word_spacing f32) ShapeParams {
	return ShapeParams{
		text_type: text_type
		letter_spacing_bits: math.f32_bits(letter_spacing)
		word_spacing_bits: math.f32_bits(word_spacing)
	}
}

fn (params ShapeParams) matches(other ShapeParams) bool {
	return params.text_type == other.text_type
		&& params.letter_spacing_bits == other.letter_spacing_bits
		&& params.word_spacing_bits == other.word_spacing_bits
}

// Glyphs in the cache are always relative to a zero baseline. The caller's
// Font supplies the retained lifetime and the requested baseline is applied to
// a fresh glyph vector after every lookup.
struct CachedShape {
	glyphs              []Glyph
	face                GlyphRunFace
	trailing_whitespace TrailingWhitespace
}

struct ShapeForParams {
	params ShapeParams
	shape  CachedShape
}

struct ShapesForText {
	text string
mut:
	last_used_tick u64
	shapes         []ShapeForParams
}

struct FontShapeCache {
	font_key string
mut:
	last_used_tick             u64
	single_ascii_common_shapes []CachedShape
	single_ascii_present       []bool
	shapes_by_text             []ShapesForText
	text_indices               map[string]int
}

fn new_font_shape_cache(font_key string, tick u64) FontShapeCache {
	return FontShapeCache{
		font_key: font_key
		last_used_tick: tick
		single_ascii_common_shapes: []CachedShape{len: single_ascii_shape_cache_size}
		single_ascii_present: []bool{len: single_ascii_shape_cache_size}
	}
}

struct ShapingCache {
mut:
	fonts []FontShapeCache
	tick  u64
}

fn (cache &ShapingCache) font_index(font_key string) int {
	for index, font_cache in cache.fonts {
		if font_cache.font_key == font_key {
			return index
		}
	}
	return -1
}

fn (cache &ShapingCache) text_index(font_index int, text string) int {
	if index := cache.fonts[font_index].text_indices[text] {
		return index
	}
	return -1
}

fn single_ascii_cache_index(text string, params ShapeParams) int {
	if text.len == 1 && int(text[0]) < single_ascii_shape_cache_size
		&& params.text_type == .common && params.letter_spacing_bits & u32(0x7fff_ffff) == 0
		&& params.word_spacing_bits & u32(0x7fff_ffff) == 0 {
		return int(text[0])
	}
	return -1
}

// A cache lookup advances the global recency clock even on a miss, matching
// the Rust cache. CachedShape is returned by value but its glyph storage is
// never exposed for mutation; shaped_text_with_baseline() clones it.
fn (mut cache ShapingCache) lookup(font_key string, text string, params ShapeParams) ?CachedShape {
	cache.tick++
	font_index := cache.font_index(font_key)
	if font_index < 0 {
		return none
	}
	cache.fonts[font_index].last_used_tick = cache.tick

	ascii_index := single_ascii_cache_index(text, params)
	if ascii_index >= 0 {
		if cache.fonts[font_index].single_ascii_present[ascii_index] {
			return cache.fonts[font_index].single_ascii_common_shapes[ascii_index]
		}
		return none
	}

	text_index := cache.text_index(font_index, text)
	if text_index < 0 {
		return none
	}
	cache.fonts[font_index].shapes_by_text[text_index].last_used_tick = cache.tick
	for entry in cache.fonts[font_index].shapes_by_text[text_index].shapes {
		if entry.params.matches(params) {
			return entry.shape
		}
	}
	return none
}

fn (mut cache ShapingCache) evict_least_recently_used_font() {
	if cache.fonts.len == 0 {
		return
	}
	mut least_recent_index := 0
	mut least_recent_tick := cache.fonts[0].last_used_tick
	for index in 1 .. cache.fonts.len {
		if cache.fonts[index].last_used_tick < least_recent_tick {
			least_recent_index = index
			least_recent_tick = cache.fonts[index].last_used_tick
		}
	}
	cache.fonts.delete(least_recent_index)
}

fn (mut cache ShapingCache) evict_least_recently_used_texts(font_index int) {
	mut ticks := []u64{cap: cache.fonts[font_index].shapes_by_text.len}
	for entry in cache.fonts[font_index].shapes_by_text {
		ticks << entry.last_used_tick
	}
	if ticks.len == 0 {
		return
	}
	ticks.sort(a < b)
	threshold := ticks[ticks.len / 2]
	mut retained := []ShapesForText{cap: ticks.len / 2}
	for entry in cache.fonts[font_index].shapes_by_text {
		if entry.last_used_tick > threshold {
			retained << entry
		}
	}
	cache.fonts[font_index].shapes_by_text = retained
	cache.fonts[font_index].text_indices.clear()
	for index, entry in cache.fonts[font_index].shapes_by_text {
		cache.fonts[font_index].text_indices[entry.text] = index
	}
}

fn clone_cached_shape(shape CachedShape) CachedShape {
	return CachedShape{
		glyphs: shape.glyphs.clone()
		face: shape.face
		trailing_whitespace: shape.trailing_whitespace
	}
}

fn (mut cache ShapingCache) store(font_key string, text string, params ShapeParams, shape CachedShape) {
	// The cache outlives any arena entered by the caller; store() copies the
	// shape and keys into it.
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	mut font_index := cache.font_index(font_key)
	if font_index < 0 {
		if cache.fonts.len >= max_shape_cache_fonts {
			cache.evict_least_recently_used_font()
		}
		cache.fonts << new_font_shape_cache(font_key.clone(), cache.tick)
		font_index = cache.fonts.len - 1
	}
	cache.fonts[font_index].last_used_tick = cache.tick

	ascii_index := single_ascii_cache_index(text, params)
	if ascii_index >= 0 {
		cache.fonts[font_index].single_ascii_common_shapes[ascii_index] = clone_cached_shape(shape)
		cache.fonts[font_index].single_ascii_present[ascii_index] = true
		return
	}

	mut text_index := cache.text_index(font_index, text)
	if text_index < 0 {
		if cache.fonts[font_index].shapes_by_text.len >= max_shape_cache_texts_per_font {
			cache.evict_least_recently_used_texts(font_index)
		}
		cache.fonts[font_index].shapes_by_text << ShapesForText{
			text: text.clone()
			last_used_tick: cache.tick
		}
		text_index = cache.fonts[font_index].shapes_by_text.len - 1
		cache.fonts[font_index].text_indices[text] = text_index
	}
	cache.fonts[font_index].shapes_by_text[text_index].last_used_tick = cache.tick
	for entry in cache.fonts[font_index].shapes_by_text[text_index].shapes {
		if entry.params.matches(params) {
			return
		}
	}
	cache.fonts[font_index].shapes_by_text[text_index].shapes << ShapeForParams{
		params: params
		shape: clone_cached_shape(shape)
	}
}

// Retain complete keys together with the immutable inputs that produced them.
// Keep values rather than a Font address, since equivalent handles can be new.
struct ShapingFontKey {
	family          string
	source_path     string
	resolved_path   string
	weight          int
	italic          bool
	point_size_bits u32
	is_invisible    bool
	font_rendering_policy FontRenderingPolicy
	synthesize_ascii_caps bool
	key             string
}

__global (
	platform_shaping_cache        &ShapingCache
	last_shaping_font_key         &ShapingFontKey
	recent_shaping_font_keys      [max_shaping_font_keys]&ShapingFontKey
	recent_shaping_font_key_count int
	next_shaping_font_key         int
)

fn shared_shaping_cache() &ShapingCache {
	if isnil(platform_shaping_cache) {
		persistent := enter_persistent()
		platform_shaping_cache = &ShapingCache{}
		leave_persistent(persistent)
	}
	return platform_shaping_cache
}

// Returned glyph runs own their glyph storage. Static idle pages can discard
// the lookup copies; a later measurement or shape request refills the cache.
pub fn release_unused_text_shaping() {
	platform_shaping_cache = unsafe { nil }
}

// Equivalent Font values select the same concrete face and may safely share
// a shape. Include the resolved face as well as the CSS identity so changes to
// font configuration cannot alias an older entry.
@[inline]
fn (entry &ShapingFontKey) matches(font &Font, point_size_bits u32) bool {
	return entry.weight == font.weight && entry.point_size_bits == point_size_bits
		&& entry.italic == font.italic
		&& entry.is_invisible == font.is_invisible && entry.family == font.family
		&& entry.font_rendering_policy == font.font_rendering_policy
		&& entry.synthesize_ascii_caps == font.synthesize_ascii_caps
		&& entry.source_path == font.source_path && entry.resolved_path == font.resolved_path_
}

// Keep the last key as the common fast path, and retain a bounded ring for
// layouts that alternate between a few concrete fonts. Entries use values,
// rather than Font addresses, so newly created equivalent handles can share.
fn shaping_cache_font_key(font &Font) string {
	previous := last_shaping_font_key
	if font.resolved_path_ != '' && !isnil(previous) && previous.family == font.family
		&& previous.source_path == font.source_path && previous.resolved_path == font.resolved_path_
		&& previous.weight == font.weight
		&& previous.italic == font.italic
		&& previous.point_size_bits == math.f32_bits(font.point_size)
		&& previous.is_invisible == font.is_invisible
		&& previous.font_rendering_policy == font.font_rendering_policy
		&& previous.synthesize_ascii_caps == font.synthesize_ascii_caps {
		return previous.key
	}
	return shaping_font_key_after_last_miss(font)
}

fn shaping_font_key_after_last_miss(font &Font) string {
	point_size_bits := math.f32_bits(font.point_size)
	if font.resolved_path_ != '' {
		for index in 0 .. recent_shaping_font_key_count {
			mut entry := recent_shaping_font_keys[index]
			if entry.matches(font, point_size_bits) {
				last_shaping_font_key = entry
				return entry.key
			}
		}
	}
	// The key and its ring entry outlive any arena entered by the caller.
	persistent := enter_persistent()
	defer { leave_persistent(persistent) }
	resolved_path := font.font_path() or { '' }
	key := '${font.family.len}:${font.family}|${font.source_path.len}:${font.source_path}|${resolved_path.len}:${resolved_path}|${font.weight}|${font.face_index()}|${point_size_bits}|${font.is_invisible}|${font.font_rendering_policy}|${font.synthesize_ascii_caps}' + if font.italic { '|italic' } else { '' }
	// An unavailable explicit source can appear later. Its fallback path remains
	// unpinned, and must continue through the original resolution on each call.
	if font.resolved_path_ != '' {
		mut entry := &ShapingFontKey{
			family:          font.family.clone()
			source_path:     font.source_path.clone()
			resolved_path:   resolved_path.clone()
			weight:          font.weight
			italic:          font.italic
			point_size_bits: point_size_bits
			is_invisible:    font.is_invisible
			font_rendering_policy: font.font_rendering_policy
			synthesize_ascii_caps: font.synthesize_ascii_caps
			key:             key
		}
		last_shaping_font_key = entry
		recent_shaping_font_keys[next_shaping_font_key] = entry
		next_shaping_font_key = (next_shaping_font_key + 1) % max_shaping_font_keys
		if recent_shaping_font_key_count < max_shaping_font_keys {
			recent_shaping_font_key_count++
		}
	}
	return key
}

fn cached_shape_from(shaped ShapedText) CachedShape {
	return CachedShape{
		// store() owns the retained copy. This view stays local and read-only.
		glyphs: shaped.glyph_run.glyphs()
		face: shaped.glyph_run.face()
		trailing_whitespace: shaped.trailing_whitespace
	}
}

fn shaped_text_with_baseline(shape CachedShape, baseline_start_x f32, font &Font, text_type GlyphRunTextType) ShapedText {
	mut glyphs := shape.glyphs.clone()
	if baseline_start_x != 0 {
		for mut glyph in glyphs {
			glyph.position.x += baseline_start_x
		}
	}
	return ShapedText{
		glyph_run: glyph_run_with_owned_glyphs(font, text_type, glyphs, shape.face)
		trailing_whitespace: shape.trailing_whitespace
	}
}

fn shape_text_cached(baseline_start_x f32, letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) ShapedText {
	font_key := shaping_cache_font_key(font)
	params := ShapeParams.new(text_type, letter_spacing, word_spacing)
	mut cache := shared_shaping_cache()
	if shape := cache.lookup(font_key, text, params) {
		return shaped_text_with_baseline(shape, baseline_start_x, font, text_type)
	}
	shaped := shape_text_uncached(0, letter_spacing, word_spacing, text, font, text_type)
	shape := cached_shape_from(shaped)
	cache.store(font_key, text, params, shape)
	// The uncached run already owns its mutable glyph and playback storage.
	// store() cloned the cache's glyphs, so this run can go directly to its caller.
	if baseline_start_x == 0 {
		return shaped
	}
	return shaped_text_with_baseline(shape, baseline_start_x, font, text_type)
}

// Width-only callers share the exact cache used by full glyph-run callers.
pub fn shaped_text_width(letter_spacing f32, word_spacing f32, text string, font &Font, text_type GlyphRunTextType) f32 {
	font_key := shaping_cache_font_key(font)
	params := ShapeParams.new(text_type, letter_spacing, word_spacing)
	mut cache := shared_shaping_cache()
	if shape := cache.lookup(font_key, text, params) {
		mut width := f32(0)
		for glyph in shape.glyphs {
			width += glyph.advance
		}
		return width
	}
	shaped := shape_text_uncached(0, letter_spacing, word_spacing, text, font, text_type)
	cache.store(font_key, text, params, cached_shape_from(shaped))
	return shaped.glyph_run.width()
}
