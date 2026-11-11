module cpuraster

import math

// GlyphCache keeps a canvas's glyph masks across fillText() draws, as
// SkStrikeCache keeps Skia's strikes: the typeface facts a draw consults
// before it rasterizes anything, and each strike's glyph images under a key
// of every input that selects them. It holds no native fonts: a draw opens
// its face and strike font only for glyphs the cache lacks and releases
// them when it returns, so dropping the cache, or purging a strike, costs
// nothing but rasterizing those glyphs again. The cache allocates in its
// caller's arena, as the canvas does.
@[heap]
pub struct GlyphCache {
mut:
	faces   map[string]&GlyphFaceInfo
	strikes map[string]&CachedGlyphStrike
	order   []string
}

// SkStrikeCache's default budget, and a bound on the strikes it keeps.
const glyph_cache_max_bytes = 2 * 1024 * 1024
const glyph_cache_max_strikes = 64
const glyph_cache_max_bounds = 256

pub fn new_glyph_cache() &GlyphCache {
	return &GlyphCache{}
}

@[heap]
struct GlyphFaceInfo {
	color_glyphs bool
	variable     bool
mut:
	// font_bounds() by the f32 bits of the size.
	bounds map[u32]GlyphFaceBounds
}

struct GlyphFaceBounds {
	valid bool
	rect  Rect
}

// A strike's glyphs by glyph id and packed subpixel position, and whether
// its font could not be made.
@[heap]
struct CachedGlyphStrike {
mut:
	glyphs map[u32]StrikeGlyph
	bytes  int
	empty  bool
}

// LazyGlyphFace opens a run's face on first use and releases it with the
// draw.
struct LazyGlyphFace {
	path  string
	index int
mut:
	face   GlyphFace
	opened bool
	failed bool
}

fn (mut l LazyGlyphFace) get() ?GlyphFace {
	if l.opened {
		return l.face
	}
	if l.failed {
		return none
	}
	face := $if linux || cpuraster_freetype ? {
		open_freetype_face(l.path, l.index) or {
			l.failed = true
			return none
		}
	} $else {
		open_glyph_face(l.path) or {
			l.failed = true
			return none
		}
	}
	l.face = face
	l.opened = true
	return face
}

fn (mut l LazyGlyphFace) release() {
	if l.opened {
		l.face.release()
		l.opened = false
	}
}

fn glyph_face_key(path string, index int) string {
	return '${path}\x00${index}'
}

// The face's typeface facts, from the cache when it has them.
fn glyph_face_info(cache &GlyphCache, key string, mut lazy LazyGlyphFace) ?&GlyphFaceInfo {
	if cache != unsafe { nil } {
		if info := cache.faces[key] {
			return info
		}
	}
	face := lazy.get()?
	info := &GlyphFaceInfo{
		color_glyphs: face.color_glyphs
		variable:     face.variable
	}
	if cache != unsafe { nil } {
		mut c := unsafe { &GlyphCache(cache) }
		c.faces[key] = info
	}
	return info
}

// face.font_bounds(size), remembered per size.
fn glyph_face_bounds(mut info GlyphFaceInfo, mut lazy LazyGlyphFace, size f32) ?Rect {
	key := math.f32_bits(size)
	if known := info.bounds[key] {
		return if known.valid { known.rect } else { none }
	}
	face := lazy.get()?
	mut known := GlyphFaceBounds{}
	if rect := face.font_bounds(size) {
		known = GlyphFaceBounds{true, rect}
	}
	if info.bounds.len >= glyph_cache_max_bounds {
		info.bounds.clear()
	}
	info.bounds[key] = known
	return if known.valid { known.rect } else { none }
}

// The cached glyphs for a strike key, a new entry when there are none, or
// a draw-local entry without a cache. A new entry first purges the oldest
// strikes past the budget.
fn glyph_cache_strike(cache &GlyphCache, key string) &CachedGlyphStrike {
	if cache == unsafe { nil } {
		return &CachedGlyphStrike{}
	}
	mut c := unsafe { &GlyphCache(cache) }
	if entry := c.strikes[key] {
		return entry
	}
	mut bytes := 0
	for _, entry in c.strikes {
		bytes += entry.bytes
	}
	for c.order.len > 0 && (c.order.len >= glyph_cache_max_strikes || bytes > glyph_cache_max_bytes) {
		oldest := c.order[0]
		c.order.delete(0)
		if entry := c.strikes[oldest] {
			bytes -= entry.bytes
		}
		c.strikes.delete(oldest)
	}
	entry := &CachedGlyphStrike{}
	c.strikes[key] = entry
	c.order << key
	return entry
}

// The strike key: the face, size and the device matrix's 2x2 (strikes
// exclude translation), the mask gamma table, smoothing, baseline snapping
// and the color strike's foreground.
fn glyph_strike_key(face_key string, size f32, device SkAffine, strike &GlyphStrike, smooth_luminance int, luminance int) string {
	return '${face_key}\x00${math.f32_bits(size)},${math.f32_bits(device.sx)},${math.f32_bits(device.kx)},${math.f32_bits(device.ky)},${math.f32_bits(device.sy)},${luminance},${smooth_luminance},${strike.smoothing},${int(strike.snap_x)},${int(strike.snap_y)},${int(strike.color)},${strike.foreground}'
}

// strike.glyph() through the cache entry: rasterizes a missing glyph with
// the strike's font, made from the face on first need. None when that font
// cannot be made, which empties every mask of the strike.
fn (mut e CachedGlyphStrike) glyph(mut strike GlyphStrike, mut lazy LazyGlyphFace, id u16, sub_x int, sub_y int) ?StrikeGlyph {
	key := u32(id) << 4 | u32(sub_x) << 2 | u32(sub_y)
	if g := e.glyphs[key] {
		return g
	}
	if e.empty || !strike.ensure_font(mut lazy) {
		e.empty = true
		return none
	}
	g := strike.make_glyph(id, sub_x, sub_y)
	e.glyphs[key] = g
	e.bytes += g.image.len
	return g
}
