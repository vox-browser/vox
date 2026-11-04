module css

import dom
import platform

fn test_animation_page_scan_finds_samples_in_every_slot_after_shared_clean_pages() {
	$if prealloc {
		mut arena := platform.new_arena('animation shared page scan slots')
		defer { arena.release() }
		entry := arena.enter()
		sample := &dom.StyleValue{ css_text: 'sample' }
		arena.leave(entry)
		retiring := RetiringAnimationSamples{ arena: arena }
		mut original := ComputedProperties.new()
		for index in 0 .. number_of_longhand_properties {
			mut changed := ComputedProperties.new()
			changed.property_store_ = original.clone_raw_property_store()
			changed.set_raw_property_at_index(index, sample)
			mut scan := AnimationSampleReferenceScan{ retiring: &retiring, use_property_pages: true }
			mut scalar := AnimationSampleReferenceScan{ retiring: &retiring, use_property_pages: false }
			assert !scan.computed_references_arena_at_depth(original, 0)
			assert !scalar.computed_references_arena_at_depth(original, 0)
			assert scan.computed_references_arena_at_depth(changed, 0), '${index}'
			assert scalar.computed_references_arena_at_depth(changed, 0), '${index}'
		}
	}
}

fn test_animation_page_scan_rechecks_in_place_changes_between_inspections() {
	$if prealloc {
		mut arena := platform.new_arena('animation scan memo lifetime')
		defer { arena.release() }
		mut style := ComputedProperties.new()
		mut value := &dom.StyleValue{ css_text: 'persistent' }
		style.set_property_without_modifying_flags(.fill, value)
		index := int(PropertyID.fill) - int(first_longhand_property_id())
		page := style.property_store_.pages[index / computed_property_page_size]
		retiring := RetiringAnimationSamples{ arena: arena }
		assert !retiring.computed_references_arena(style)
		entry := arena.enter()
		borrowed := ['sample', 'text'].join(' ')
		arena.leave(entry)
		assert arena.contains(voidptr(borrowed.str))
		value.css_text = borrowed
		assert voidptr(style.property_store_.pages[index / computed_property_page_size]) == voidptr(page)
		assert retiring.computed_references_arena(style)
		value.css_text = 'persistent again'
		assert !retiring.computed_references_arena(style)
		entry2 := arena.enter()
		sample := &dom.StyleValue{ css_text: 'replacement' }
		arena.leave(entry2)
		style.set_property_without_modifying_flags(.fill, sample)
		assert voidptr(style.property_store_.pages[index / computed_property_page_size]) == voidptr(page)
		assert retiring.computed_references_arena(style)
		style.set_property_without_modifying_flags(.fill, value)
		assert !retiring.computed_references_arena(style)
	}
}

fn test_animation_page_scan_hash_collisions_and_partial_pages_remain_conservative() {
	$if prealloc {
		mut arena := platform.new_arena('animation scan collisions')
		defer { arena.release() }
		entry := arena.enter()
		sample := &dom.StyleValue{ css_text: 'sample' }
		arena.leave(entry)
		retiring := RetiringAnimationSamples{ arena: arena }
		mut pages := []&ComputedPropertyPage{}
		mut by_slot := map[int]&ComputedPropertyPage{}
		mut first := unsafe { &ComputedPropertyPage(nil) }
		mut second := unsafe { &ComputedPropertyPage(nil) }
		for _ in 0 .. 257 {
			page := &ComputedPropertyPage{}
			pages << page
			slot := animation_sample_page_scan_slot(page)
			if previous := by_slot[slot] {
				first = previous
				second = page
				break
			}
			by_slot[slot] = page
		}
		assert first != unsafe { nil } && second != unsafe { nil }
		second.values[computed_property_page_size - 1] = sample
		mut scan := AnimationSampleReferenceScan{ retiring: &retiring, use_property_pages: true }
		assert !scan.property_page_references_arena(first, computed_property_page_size)
		assert scan.property_page_references_arena(second, computed_property_page_size)
		assert !scan.property_page_references_arena(first, computed_property_page_size)
		// Inspecting a prefix cannot prove that the unvisited tail is clean.
		mut partial := AnimationSampleReferenceScan{ retiring: &retiring, use_property_pages: true }
		assert !partial.property_page_references_arena(second, 1)
		assert partial.property_page_references_arena(second, computed_property_page_size)
	}
}

fn test_animation_page_scan_keeps_projection_tail_after_a_shared_clean_source() {
	$if prealloc {
		mut arena := platform.new_arena('animation page scan projection')
		defer { arena.release() }
		entry := arena.enter()
		sample := &dom.StyleValue{ css_text: 'sample' }
		arena.leave(entry)
		mut source := ComputedProperties.new()
		mut projected := ComputedProperties.new()
		projected.property_store_ = source.clone_raw_property_store()
		projected.set_property_without_modifying_flags(.fill, sample)
		source.device_layout_projection_ = &DeviceLayoutStyleProjection{
			scale:      2
			provenance: unsafe { nil }
			style:      projected
		}
		retiring := RetiringAnimationSamples{ arena: arena }
		mut scan := AnimationSampleReferenceScan{ retiring: &retiring, use_property_pages: true }
		mut scalar := AnimationSampleReferenceScan{ retiring: &retiring, use_property_pages: false }
		assert scan.computed_references_arena_at_depth(source, 0)
		assert scalar.computed_references_arena_at_depth(source, 0)
	}
}

fn test_animation_page_inspection_does_not_grow_the_callers_arena() {
	$if prealloc {
		mut samples := platform.new_arena('retiring sample inspection ownership')
		defer { samples.release() }
		retiring := RetiringAnimationSamples{ arena: samples }
		style := ComputedProperties.new()
		mut owner := platform.new_arena('inspection caller')
		defer { owner.release() }
		entry := owner.enter()
		assert !retiring.computed_references_arena(style)
		before := owner.usage().used
		for _ in 0 .. 32 {
			assert !retiring.computed_references_arena(style)
		}
		assert owner.usage().used == before
		owner.leave(entry)
	}
}
