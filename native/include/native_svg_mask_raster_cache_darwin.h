#ifndef VOX_NATIVE_SVG_MASK_RASTER_CACHE_DARWIN_H
#define VOX_NATIVE_SVG_MASK_RASTER_CACHE_DARWIN_H

#include <CoreGraphics/CoreGraphics.h>
#include <stdint.h>

// At most sixteen 512 KiB RGBA images. An absolute-position entry can
// retain the same image without allocating another copy of its pixels.
#define NATIVE_SVG_MASK_RASTER_CACHE_SIZE 16

typedef struct {
	uint64_t key;
	CGImageRef image;
	uint64_t last_use;
	uint64_t frame;
} NativeSVGMaskRasterCacheEntry;

typedef struct {
	NativeSVGMaskRasterCacheEntry entries[NATIVE_SVG_MASK_RASTER_CACHE_SIZE];
	NativeSVGMaskRasterCacheEntry *replacement;
} NativeSVGMaskRasterCache;

static inline NativeSVGMaskRasterCacheEntry *native_svg_mask_raster_replacement(
	NativeSVGMaskRasterCache *cache)
{
	if (cache->replacement != NULL) {
		return cache->replacement;
	}
	NativeSVGMaskRasterCacheEntry *replacement = &cache->entries[0];
	for (int index = 1; index < NATIVE_SVG_MASK_RASTER_CACHE_SIZE; ++index) {
		NativeSVGMaskRasterCacheEntry *entry = &cache->entries[index];
		if (entry->image == NULL || entry->last_use < replacement->last_use) {
			replacement = entry;
		}
	}
	cache->replacement = replacement;
	return replacement;
}

static inline int32_t native_svg_mask_raster_can_admit(NativeSVGMaskRasterCache *cache,
	uint64_t frame)
{
	const NativeSVGMaskRasterCacheEntry *entry = native_svg_mask_raster_replacement(cache);
	// Keep rasters that the current or preceding frame used. A sequence
	// longer than the cache would otherwise evict them before each reuse.
	return entry->image == NULL || frame - entry->frame > 1;
}

static inline void native_svg_mask_raster_touch(NativeSVGMaskRasterCache *cache,
	NativeSVGMaskRasterCacheEntry *entry, uint64_t last_use, uint64_t frame)
{
	// A newer timestamp on another slot cannot change the oldest slot.
	// A wrapped clock can make the touched slot oldest again.
	if (last_use != entry->last_use
		&& (entry == cache->replacement || last_use < entry->last_use)) {
		cache->replacement = NULL;
	}
	entry->last_use = last_use;
	entry->frame = frame;
}

static inline CGImageRef native_svg_mask_raster_store(NativeSVGMaskRasterCache *cache,
	NativeSVGMaskRasterCacheEntry raster)
{
	NativeSVGMaskRasterCacheEntry *entry = native_svg_mask_raster_replacement(cache);
	CGImageRef previous = entry->image;
	*entry = raster;
	cache->replacement = NULL;
	return previous;
}

#endif
