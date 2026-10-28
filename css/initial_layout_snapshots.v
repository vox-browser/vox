module css

import dom
import math
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

fn initial_layout_snapshot_key(cache &ComputedLayoutCache) u64 {
	color := cache.computed_values_color_
	return math.f64_bits(cache.computed_values_font_size_.to_double())
		^ (u64(color.r) << 24 | u64(color.g) << 16 | u64(color.b) << 8 | u64(color.a))
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
