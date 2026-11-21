module ggshape

import hash
import os

#include "@DIR/leaf_cache.h"

fn C.vox_leaf_cache_fetch(hash u64, key &u8, key_bytes u32, pixels &u8, pixel_bytes u32) i32
fn C.vox_leaf_cache_store(hash u64, key &u8, key_bytes u32, pixels &u8, pixel_bytes u32)
fn C.vox_leaf_cache_clear()
fn C.vox_leaf_cache_counter(index i32) u64
fn C.vox_leaf_cache_size() u64

// VOX_DISABLE_LEAF_RASTER_CACHE=1 draws every leaf on the GPU again, for
// matched comparisons.
const disable_leaf_cache = os.getenv('VOX_DISABLE_LEAF_RASTER_CACHE') != ''
// VOX_LEAF_RASTER_CACHE_DIAGNOSTICS=1 reports the cache's counters after
// every 256 lookups.
const leaf_cache_diagnostics = os.getenv('VOX_LEAF_RASTER_CACHE_DIAGNOSTICS') != ''

const leaf_cache_path = u8(1)
const leaf_cache_shape = u8(2)
const leaf_cache_shapes = u8(3)
const leaf_cache_svg_image = u8(4)
const leaf_cache_whole_shape = u8(5)

// LeafCacheKey collects every input of one region draw. Two draws with equal
// bytes upload the same backdrop and record the same draws on surfaces of the
// same size and sample count, so they read back the same pixels.
struct LeafCacheKey {
	// False with the cache switched off: nothing is collected or looked up.
	enabled bool
mut:
	bytes []u8
	hash  u64
	// The pixel bytes of the region, without row padding.
	pixel_bytes int
}

fn (mut key LeafCacheKey) add(data voidptr, length int) {
	if !key.enabled || data == unsafe { nil } || length <= 0 { return }
	unsafe { key.bytes.push_many(data, length) }
}

fn (mut key LeafCacheKey) add_i32(value i32) {
	key.add(&value, int(sizeof(i32)))
}

// Starts a key with the draw's kind, flags, surface and region, and with the
// backdrop rows the draw blends with.
fn new_leaf_cache_key(kind u8, flags i32, pixels &u8, pitch i32, region SurfaceRegion, has_background bool) LeafCacheKey {
	if disable_leaf_cache { return LeafCacheKey{} }
	row_bytes := region.width * 4
	mut key := LeafCacheKey{
		enabled:     true
		bytes:       []u8{cap: 512 + if has_background { row_bytes * region.height } else { 0 }}
		pixel_bytes: row_bytes * region.height
	}
	key.bytes << kind
	key.bytes << u8(if has_background { 1 } else { 0 })
	for value in [flags, i32(region.surface_width), i32(region.surface_height), i32(region.x),
		i32(region.y), i32(region.width), i32(region.height)] {
		key.add_i32(value)
	}
	if has_background {
		for y in 0 .. region.height {
			key.add(unsafe { pixels + y * int(pitch) }, row_bytes)
		}
	}
	return key
}

fn (mut key LeafCacheKey) add_path(path &C.VoxGraphitePath) {
	if !key.enabled { return }
	// Pointers differ between frames; the data they address is the input.
	mut inline_fields := *path
	inline_fields.segments = unsafe { nil }
	inline_fields.stops = unsafe { nil }
	key.add(&inline_fields, int(sizeof(C.VoxGraphitePath)))
	key.add(path.segments, int(path.segment_count) * 12 * int(sizeof(f32)))
	if path.gradient != 0 {
		key.add(path.stops, int(path.stop_count) * 5 * int(sizeof(f32)))
	}
}

fn (mut key LeafCacheKey) add_shape(shape &C.VoxGraphiteShape) {
	if !key.enabled { return }
	mut inline_fields := *shape
	inline_fields.clip_outs = unsafe { nil }
	key.add(&inline_fields, int(sizeof(C.VoxGraphiteShape)))
	key.add(shape.clip_outs, int(shape.clip_out_count) * 4 * int(sizeof(f32)))
}

fn (mut key LeafCacheKey) add_floats(values &f32, count int) {
	key.add_i32(i32(if values == unsafe { nil } { 0 } else { count }))
	key.add(values, count * int(sizeof(f32)))
}

// Copies the result of an identical earlier draw into the region's rows.
fn (mut key LeafCacheKey) fetch(pixels &u8, pitch i32, region SurfaceRegion) bool {
	if !key.enabled { return false }
	key.hash = hash.sum64(key.bytes, 0)
	row_bytes := region.width * 4
	if int(pitch) == row_bytes {
		found := C.vox_leaf_cache_fetch(key.hash, key.bytes.data, u32(key.bytes.len), pixels,
			u32(key.pixel_bytes)) != 0
		report_leaf_cache()
		return found
	}
	mut packed := []u8{len: key.pixel_bytes}
	found := C.vox_leaf_cache_fetch(key.hash, key.bytes.data, u32(key.bytes.len), packed.data,
		u32(key.pixel_bytes)) != 0
	if found {
		for y in 0 .. region.height {
			unsafe { vmemcpy(pixels + y * int(pitch), &packed[y * row_bytes], row_bytes) }
		}
	}
	report_leaf_cache()
	return found
}

// Remembers the rows a completed draw read back.
fn (key &LeafCacheKey) store(pixels &u8, pitch i32, region SurfaceRegion) {
	if !key.enabled { return }
	row_bytes := region.width * 4
	if int(pitch) == row_bytes {
		C.vox_leaf_cache_store(key.hash, key.bytes.data, u32(key.bytes.len), pixels, u32(key.pixel_bytes))
		return
	}
	mut packed := []u8{len: key.pixel_bytes}
	for y in 0 .. region.height {
		unsafe { vmemcpy(&packed[y * row_bytes], pixels + y * int(pitch), row_bytes) }
	}
	C.vox_leaf_cache_store(key.hash, key.bytes.data, u32(key.bytes.len), packed.data, u32(key.pixel_bytes))
}

fn report_leaf_cache() {
	if !leaf_cache_diagnostics { return }
	lookups := C.vox_leaf_cache_counter(0) + C.vox_leaf_cache_counter(1)
	if lookups % 256 != 0 { return }
	eprintln('VOX_LEAF_RASTER_CACHE hits=${C.vox_leaf_cache_counter(0)} misses=${C.vox_leaf_cache_counter(1)} stores=${C.vox_leaf_cache_counter(2)} clears=${C.vox_leaf_cache_counter(3)} bytes=${C.vox_leaf_cache_size()}')
}
