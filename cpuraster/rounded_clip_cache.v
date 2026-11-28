module cpuraster

pub struct RoundedClipGeometry {
pub:
	rect      Rect
	radii     [8]f32
	transform Matrix
}

pub fn (shape &RoundedClipGeometry) path() Path {
	return rounded_rect(shape.rect, shape.radii).clip_path(shape.transform)
}

struct RoundedClipCacheKey {
	shape  RoundedClipGeometry
	width  int
	height int
}

pub struct RoundedClipCoverage {
pub:
	clip   ?RasterClip
	reused bool
}

struct RoundedClipCacheEntry {
	key  RoundedClipCacheKey
	clip ?RasterClip
}

// Use this cache within the scope that owns the rasterized clip rows.
pub struct RoundedClipCache {
mut:
	entries [4]RoundedClipCacheEntry
	count   int
	next    int
}

pub fn (mut cache RoundedClipCache) raster_clip(shape RoundedClipGeometry, width int,
	height int) RoundedClipCoverage {
	key := RoundedClipCacheKey{shape, width, height}
	for index in 0 .. cache.count {
		entry := &cache.entries[index]
		if entry.key == key {
			return RoundedClipCoverage{entry.clip, true}
		}
	}
	raster := canvas_raster_clip(width, height, [shape.path()])
	clip := if raster.covers_surface(width, height) { ?RasterClip(none) } else { ?RasterClip(raster) }
	cache.entries[cache.next] = RoundedClipCacheEntry{key, clip}
	cache.next = (cache.next + 1) % cache.entries.len
	if cache.count < cache.entries.len { cache.count++ }
	return RoundedClipCoverage{clip, false}
}
