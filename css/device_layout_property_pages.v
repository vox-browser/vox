module css

import sync.stdatomic

fn (mut page ComputedPropertyPage) invalidate_device_layout_candidates() {
	stdatomic.store_u64(&page.device_layout_candidates_, 0)
}

// A page can be interned at different property positions. Include width
// keywords regardless of position; the normal property-specific check still
// decides whether they require scaling. Untyped values always retain parsing.
fn (page &ComputedPropertyPage) device_layout_candidates() u16 {
	cached := stdatomic.load_u64(&page.device_layout_candidates_)
	if cached & 0x10000 != 0 { return u16(cached) }
	mut mask := u16(0)
	for slot, value in page.values {
		if value == unsafe { nil } { continue }
		if value.css_value_handle != unsafe { nil } {
			box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
			if !device_layout_value_contains_lengths(&box.value) {
				if box.value is KeywordStyleValue {
					if box.value.keyword() !in [.thin, .medium, .thick] { continue }
				} else {
					continue
				}
			} else if device_layout_value_is_projection_invariant(&box.value) {
				continue
			}
		}
		mask |= u16(1) << slot
	}
	// Initial pages are shared by documents. Publish atomically even when two
	// independent projections compute the same mask concurrently.
	stdatomic.store_u64(&page.device_layout_candidates_, u64(mask) | 0x10000)
	return mask
}
