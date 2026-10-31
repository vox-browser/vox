module css

import sync.stdatomic
$if prealloc {
	import platform
}

// This cache belongs to one document's style computer, never to globally
// shared initial pages. Entries retain their source page for GC ownership.
@[heap]
struct DeviceLayoutPropertyPages {
mut:
	pages map[u64]DeviceLayoutPropertyPage
}

struct DeviceLayoutPropertyPage {
	source     &ComputedPropertyPage
	generation u64
	index      int
	factor     f64
	projected  &ComputedPropertyPage
}

fn (computer &StyleComputer) can_retain_device_layout_page(page &ComputedPropertyPage) bool {
	$if prealloc {
		if computer.document_ == unsafe { nil } { return false }
		owner := computer.document_.native_storage()
		if owner == unsafe { nil }
			|| voidptr(owner) != voidptr(platform.current_retained_arena()) { return false }
		if owner.arena.contains(voidptr(page)) { return true }
		// Initial pages have persistent process ownership. Arbitrary pages
		// borrowed from another document or a scratch arena cannot be retained.
		if computed_initial_property_store != unsafe { nil } {
			for initial in computed_initial_property_store.pages {
				if voidptr(initial) == voidptr(page) { return true }
			}
		}
		return false
	}
	return true
}

fn (computer &StyleComputer) device_layout_page(page &ComputedPropertyPage, index int, factor f64) ?&ComputedPropertyPage {
	if computer.device_layout_property_pages_ != unsafe { nil } {
		if cached := computer.device_layout_property_pages_.pages[u64(voidptr(page))] {
			if cached.generation != 0 && cached.generation == page.device_layout_generation_
				&& cached.index == index && cached.factor == factor {
				return cached.projected
			}
		}
	}
	return none
}

// Only memoize pages whose scaled values cannot depend on the element, font,
// viewport or color scheme. The ordinary resolver produces the first result.
// Font-size has already been installed separately on the destination page.
fn (computer &StyleComputer) retain_device_layout_page(source &ComputedPropertyPage,
	mut target ComputedPropertyStore, index int, factor f64, mask u16) {
	if source.device_layout_generation_ == 0 || !computer.can_retain_device_layout_page(source) { return }
	font_page := (int(PropertyID.font_size) - int(first_longhand_property_id())) / computed_property_page_size
	if index == font_page { return }
	ids := computed_interpolation_longhand_property_ids()
	for slot in 0 .. computed_property_page_size {
		position := index * computed_property_page_size + slot
		if position >= ids.len { break }
		property := ids[position]
		if mask & (u16(1) << slot) == 0 { continue }
		value := source.values[slot]
		if value == unsafe { nil } { continue }
		if value.css_value_handle == unsafe { nil } { return }
		box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
		if !device_layout_value_needs_projection(property, &box.value) { continue }
		match box.value {
			LengthStyleValue { if !box.value.length_.is_px() { return } }
			KeywordStyleValue {} // Only border-width keywords need projection.
			else { return }
		}
	}
	mut owner := unsafe { &StyleComputer(computer) }
	if owner.device_layout_property_pages_ == unsafe { nil } {
		owner.device_layout_property_pages_ = &DeviceLayoutPropertyPages{}
	}
	mut cache := owner.device_layout_property_pages_
	key := u64(voidptr(source))
	if cache.pages.len >= computed_property_page_pool_limit && key !in cache.pages { return }
	// All future writes, including through a value-copy alias of the projected
	// style, must preserve the page retained by this cache.
	target.writable &= ~(u32(1) << index)
	cache.pages[key] = DeviceLayoutPropertyPage{
		source: source
		generation: source.device_layout_generation_
		index: index
		factor: factor
		projected: target.pages[index]
	}
}

fn (mut page ComputedPropertyPage) invalidate_device_layout_candidates() {
	stdatomic.store_u64(&page.device_layout_candidates_, 0)
	// Recycling can reuse a page's address. Saturation disables memoization
	// rather than making an old cached result eligible again.
	if page.device_layout_generation_ != 0 {
		page.device_layout_generation_++
	}
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
