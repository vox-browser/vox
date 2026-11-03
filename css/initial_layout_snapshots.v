module css

import dom
import math
import os
$if prealloc {
	import platform
}

// Pure resolved-cache updates are written into a short-lived record. Its nested
// values still allocate in the document. Once complete, share an equal frozen
// snapshot or allocate its sole permanent record. This avoids orphaning a
// duplicate cache in a bump arena after an idle-time deduplication pass.
@[heap]
struct InitialLayoutSnapshotPool {
mut:
	buckets map[u64][]&ComputedLayoutCache
	identical_inputs map[u64][]IdenticalLayoutInputs
	identical_pages map[u64]IdenticalLayoutPage
}

struct InitialLayoutSnapshot {
mut:
	cache &ComputedLayoutCache = unsafe { nil }
	pool &InitialLayoutSnapshotPool = unsafe { nil }
}

fn begin_initial_layout_snapshot(style &ComputedProperties, document &dom.Document) InitialLayoutSnapshot {
	$if prealloc {
		owner := document.native_storage()
		previous := style.computed_layout_cache()
		if previous.writable_owner_identity != 0
			|| style.reuses_computed_layout_cache(u64(voidptr(style)))
			// A final animation update can resolve ordinary values in the
			// sample arena. The interning pool outlives that target's samples.
			|| platform.transient_arena_entered()
			|| owner == unsafe { nil }
			|| voidptr(owner) != voidptr(platform.current_retained_arena())
			|| style.has_animated_properties() || style.has_animated_custom_properties() {
			return InitialLayoutSnapshot{}
		}
		// Untyped compatibility values can invoke a parser/checkpoint from a
		// getter. Keep their ordinary durable cache across possible reentry.
		for index in 0 .. style.raw_property_count() {
			value := style.raw_property_at_index(index)
			if value != unsafe { nil } && value.css_value_handle == unsafe { nil } {
				return InitialLayoutSnapshot{}
			}
		}
		mut computer := css_style_computer_for(document)
		if computer.initial_layout_snapshots_ == unsafe { nil } {
			computer.initial_layout_snapshots_ = &InitialLayoutSnapshotPool{}
		}
		// Scripting can be enabled: font/counter discovery already finished,
		// and typed getters below cannot invoke the parser or a checkpoint.
		// Only the outer record is temporary. Do not enter a temporary V arena:
		// setters can publish typed payloads which must remain document-owned.
		mut temporary := unsafe { &ComputedLayoutCache(C.malloc(sizeof(ComputedLayoutCache))) }
		if temporary == unsafe { nil } { panic('could not allocate initial layout snapshot') }
		// Preserve the previous non-inherited fields and copy rare data before
		// its first mutation. Existing snapshots can still have retained readers.
		unsafe { vmemcpy(temporary, previous, int(sizeof(ComputedLayoutCache))) }
		temporary.rare_data_writable_ = false
		temporary.writable_owner_identity = u64(voidptr(style))
		temporary.owner_identity = u64(voidptr(style))
		mut mutable_style := unsafe { &ComputedProperties(style) }
		temporary.owner_serial = mutable_style.layout_cache_owner_serial()
		mutable_style.computed_layout_cache_ = temporary
		return InitialLayoutSnapshot{cache: temporary, pool: computer.initial_layout_snapshots_}
	}
	return InitialLayoutSnapshot{}
}

fn begin_inherited_layout_snapshot(style &ComputedProperties, source &ComputedProperties) InitialLayoutSnapshot {
	$if prealloc {
		document := source.computed_layout_cache().document_resolution_owner
		if document != unsafe { nil } {
			return begin_initial_layout_snapshot(style, document)
		}
	}
	return InitialLayoutSnapshot{}
}

const disable_geometry_snapshot_keys = os.getenv('VOX_DISABLE_GEOMETRY_SNAPSHOT_KEYS') != ''

fn layout_snapshot_number_bits(number f64) u64 {
	// Equality treats both zero signs alike. Never split equal snapshots.
	return if number == 0 { u64(0) } else { math.f64_bits(number) }
}

fn layout_snapshot_mix(key u64, value u64) u64 {
	return (key ^ value) * 1099511628211
}

fn layout_snapshot_size_key(key u64, size &Size) u64 {
	mut result := layout_snapshot_mix(key, u64(size.type_))
	if value := size.length_percentage_ {
		result = layout_snapshot_mix(result, u64(i64(value.unit_code_)))
		// Calculations keep their ordinary deep comparison. Their pointer is
		// an ownership detail and must not distinguish equal resolved values.
		if !value.is_calculated() {
			result = layout_snapshot_mix(result, layout_snapshot_number_bits(unsafe { value.payload_.number }))
		}
	}
	return result
}

fn initial_layout_snapshot_key(cache &ComputedLayoutCache) u64 {
	color := cache.computed_values_color_
	mut key := layout_snapshot_number_bits(cache.computed_values_font_size_.to_double())
		^ (u64(color.r) << 24 | u64(color.g) << 16 | u64(color.b) << 8 | u64(color.a))
	if disable_geometry_snapshot_keys { return key }
	// Font and color alone put most of a page into one bounded bucket. Use
	// ordinary geometry to separate it before the complete field comparison.
	key = layout_snapshot_mix(key, layout_snapshot_number_bits(cache.computed_values_font_weight_))
	key = layout_snapshot_mix(key, u64(cache.computed_values_position_))
	key = layout_snapshot_size_key(key, &cache.computed_values_width_)
	return layout_snapshot_size_key(key, &cache.computed_values_height_)
}

fn (mut candidate InitialLayoutSnapshot) publish(mut style ComputedProperties) {
	if candidate.cache == unsafe { nil } { return }
	$if prealloc {
		mut cache := candidate.cache
		assert voidptr(style.computed_layout_cache_) == voidptr(cache)
		cache.writable_owner_identity = 0
		cache.rare_data_writable_ = false
		provenance := cache.resolution_provenance
		shareable := idle_layout_snapshot_is_shareable(cache)
		key := initial_layout_snapshot_key(cache)
		mut published := unsafe { &ComputedLayoutCache(nil) }
		if shareable {
			for previous in candidate.pool.buckets[key] {
				if idle_layout_snapshots_equal(previous, cache) { published = previous; break }
			}
		}
		if published == unsafe { nil } {
			published = &ComputedLayoutCache{...cache}
			// Bound collision work for pages with many different geometries.
			if shareable && candidate.pool.buckets[key].len < 256 {
				published.owner_identity = 0
				published.owner_serial = 0
				published.resolution_provenance = unsafe { nil }
				candidate.pool.buckets[key] << published
			}
		}
		style.computed_layout_cache_ = published
		// A frozen shared value must not retain another style's raw graph or
		// element context. Keep each style's proof beside its own raw properties.
		style.shared_geometry_provenance_ = provenance
		style.shared_geometry_cache_ = published
		unsafe { C.free(cache) }
		candidate.cache = unsafe { nil }
		candidate.pool = unsafe { nil }
	}
}
