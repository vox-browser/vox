module css

import dom

// Identical immutable pages cannot invalidate a property. Diff the remaining
// slots directly, preserving the ordinary value comparison for distinct values.
fn compute_raw_property_invalidation(old_style &ComputedProperties,
	new_style &ComputedProperties) RequiredInvalidationAfterStyleChange {
	mut invalidation := RequiredInvalidationAfterStyleChange{}
	old_store := old_style.property_store_
	new_store := new_style.property_store_
	if old_store == unsafe { nil } || new_store == unsafe { nil } {
		for property_id in computed_interpolation_longhand_property_ids() {
			invalidation = required_invalidation_after_style_change_or(invalidation, compute_property_invalidation(property_id,
				old_style.property(property_id, .no), new_style.property(property_id, .no)))
		}
		return invalidation
	}
	for page_index in 0 .. computed_property_page_count {
		old_page := old_store.pages[page_index]
		new_page := new_store.pages[page_index]
		if computed_property_pages_equal(old_page, new_page) { continue
		 }
		for slot in 0 .. computed_property_page_size {
			index := page_index * computed_property_page_size + slot
			if index >= number_of_longhand_properties { break
			 }
			old_value := old_page.values[slot]
			new_value := new_page.values[slot]
			if voidptr(old_value) == voidptr(new_value) { continue
			 }
			property_id := property_id_from_longhand_index(index) or { continue }
			previous := if old_value == unsafe { nil } {
				?&dom.StyleValue(none)
			} else {
				?&dom.StyleValue(old_value)
			}
			current := if new_value == unsafe { nil } {
				?&dom.StyleValue(none)
			} else {
				?&dom.StyleValue(new_value)
			}
			invalidation = required_invalidation_after_style_change_or(invalidation, compute_property_invalidation(property_id,
				previous, current))
		}
	}
	return invalidation
}
