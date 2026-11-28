#pragma once
// Results of document leaf draws, keyed by every input of the draw: the
// descriptor, its surface and region, and the backdrop pixels it blends with.
// A draw with an identical key produces identical pixels, so a later frame
// that repaints an unchanged leaf copies them instead of waiting for the GPU.
// The main thread owns the cache.
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "../platform/native_state.h"

#define VOX_LEAF_CACHE_SLOTS 4096u
#define VOX_LEAF_CACHE_PROBES 8u
// Icons and borders are a few kilobytes; a larger leaf is drawn every time.
#define VOX_LEAF_CACHE_MAX_ENTRY_BYTES (512u * 1024u)
#define VOX_LEAF_CACHE_MAX_BYTES (32u * 1024u * 1024u)

typedef struct {
	uint64_t hash;
	uint32_t key_bytes, pixel_bytes;
	// The key bytes, then the result pixels.
	uint8_t *data;
} VoxLeafCacheEntry;

VOX_NATIVE_STATE VoxLeafCacheEntry vox_leaf_cache_entries[VOX_LEAF_CACHE_SLOTS];
VOX_NATIVE_STATE size_t vox_leaf_cache_bytes;
// Hits, misses, stores and whole-cache clears.
VOX_NATIVE_STATE uint64_t vox_leaf_cache_counters[4];

static void vox_leaf_cache_clear(void) {
	for (unsigned index = 0; index < VOX_LEAF_CACHE_SLOTS; ++index) free(vox_leaf_cache_entries[index].data);
	memset(vox_leaf_cache_entries, 0, sizeof vox_leaf_cache_entries);
	vox_leaf_cache_bytes = 0;
	++vox_leaf_cache_counters[3];
}

// Copies the cached result of an identical draw into `pixels` and returns 1,
// or returns 0 and leaves `pixels` unchanged.
static int vox_leaf_cache_fetch(uint64_t hash, const uint8_t *key, uint32_t key_bytes,
	uint8_t *pixels, uint32_t pixel_bytes) {
	for (unsigned probe = 0; probe < VOX_LEAF_CACHE_PROBES; ++probe) {
		const VoxLeafCacheEntry *entry = &vox_leaf_cache_entries[(hash + probe) & (VOX_LEAF_CACHE_SLOTS - 1)];
		if (!entry->data) break;
		if (entry->hash == hash && entry->key_bytes == key_bytes && entry->pixel_bytes == pixel_bytes
			&& memcmp(entry->data, key, key_bytes) == 0) {
			memcpy(pixels, entry->data + key_bytes, pixel_bytes);
			++vox_leaf_cache_counters[0];
			return 1;
		}
	}
	++vox_leaf_cache_counters[1];
	return 0;
}

static void vox_leaf_cache_store(uint64_t hash, const uint8_t *key, uint32_t key_bytes,
	const uint8_t *pixels, uint32_t pixel_bytes) {
	size_t size = (size_t)key_bytes + pixel_bytes;
	if (!size || size > VOX_LEAF_CACHE_MAX_ENTRY_BYTES) return;
	// Entries have no order of use; a full cache starts over.
	if (vox_leaf_cache_bytes + size > VOX_LEAF_CACHE_MAX_BYTES) vox_leaf_cache_clear();
	VoxLeafCacheEntry *slot = &vox_leaf_cache_entries[hash & (VOX_LEAF_CACHE_SLOTS - 1)];
	for (unsigned probe = 0; probe < VOX_LEAF_CACHE_PROBES; ++probe) {
		VoxLeafCacheEntry *entry = &vox_leaf_cache_entries[(hash + probe) & (VOX_LEAF_CACHE_SLOTS - 1)];
		if (!entry->data || (entry->hash == hash && entry->key_bytes == key_bytes
			&& entry->pixel_bytes == pixel_bytes && memcmp(entry->data, key, key_bytes) == 0)) {
			slot = entry;
			break;
		}
	}
	uint8_t *data = malloc(size);
	if (!data) return;
	memcpy(data, key, key_bytes);
	memcpy(data + key_bytes, pixels, pixel_bytes);
	if (slot->data) {
		vox_leaf_cache_bytes -= (size_t)slot->key_bytes + slot->pixel_bytes;
		free(slot->data);
	}
	slot->hash = hash;
	slot->key_bytes = key_bytes;
	slot->pixel_bytes = pixel_bytes;
	slot->data = data;
	vox_leaf_cache_bytes += size;
	++vox_leaf_cache_counters[2];
}

static uint64_t vox_leaf_cache_counter(int index) {
	return index >= 0 && index < 4 ? vox_leaf_cache_counters[index] : 0;
}

static uint64_t vox_leaf_cache_size(void) { return (uint64_t)vox_leaf_cache_bytes; }
