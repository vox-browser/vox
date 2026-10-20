module css

import math

fn idle_layout_snapshot_is_shareable(cache &ComputedLayoutCache) bool {
	if cache.writable_owner_identity != 0 || voidptr(cache.rare_data_) != unsafe { nil }
		|| cache.computed_values_background_layers_.len != 0 { return false }
	// A projection can retain an element-specific source style. Keep it local.
	$for field in ComputedLayoutCache.fields {
		$if field.name == 'device_layout_projection_' {
			if voidptr(cache.$(field.name)) != unsafe { nil } { return false }
		}
	}
	return true
}

fn idle_layout_snapshots_equal(first &ComputedLayoutCache, second &ComputedLayoutCache) bool {
	// Compare every resolved field, including future additions. Only write
	// ownership and raw-graph resolution provenance are not rendered values.
	// Eligibility already requires absent rare data and empty background layers.
	$for field in ComputedLayoutCache.fields {
		$if field.name != 'resolution_provenance' && field.name != 'document_resolution_owner'
			&& field.name != 'writable_owner_identity' && field.name != 'owner_identity'
			&& field.name != 'owner_serial' && field.name != 'rare_data_writable_'
			&& field.name != 'rare_data_' && field.name != 'computed_values_background_layers_'
			&& field.name != 'device_layout_projection_' {
			if first.$(field.name) != second.$(field.name) { return false }
		}
	}
	return true
}

// Equal ordinary geometry snapshots can share storage at static idle. The
// temporary index disappears on return; it never roots a previous document.
// Raw property graphs, fonts and element contexts stay on their own styles.
pub fn share_idle_layout_snapshots(styles []&ComputedProperties) int {
	mut buckets := map[u64][]&ComputedLayoutCache{}
	mut visited := map[u64]bool{}
	mut merged_count := 0
	for style in styles {
		identity := u64(voidptr(style))
		if visited[identity] { continue }
		visited[identity] = true
		cache := style.computed_layout_cache_
		if voidptr(cache) == unsafe { nil } || !idle_layout_snapshot_is_shareable(cache) { continue }
		color := cache.computed_values_color_
		key := math.f64_bits(cache.computed_values_font_size_.to_double())
			^ (u64(color.r) << 24 | u64(color.g) << 16 | u64(color.b) << 8 | u64(color.a))
		mut found := false
		for previous in buckets[key] {
			if voidptr(previous) == voidptr(cache) { found = true; break }
			if !idle_layout_snapshots_equal(previous, cache) { continue }
			// A later write must copy. Without per-graph provenance, a later
			// resolve follows the complete context-aware path before publishing.
			mut snapshot := unsafe { &ComputedLayoutCache(previous) }
			snapshot.owner_serial = 0
			snapshot.owner_identity = 0
			snapshot.resolution_provenance = unsafe { nil }
			snapshot.document_resolution_owner = unsafe { nil }
			snapshot.rare_data_writable_ = false
			mut target := unsafe { &ComputedProperties(style) }
			target.computed_layout_cache_ = previous
			merged_count++
			found = true
			break
		}
		// Bound work on documents with many unique values in one coarse bucket.
		if !found && buckets[key].len < 256 { buckets[key] << cache }
	}
	return merged_count
}
