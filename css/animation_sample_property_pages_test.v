module css

import dom
import platform

fn test_animation_retirement_keeps_sample_owned_property_pages_with_persistent_values() {
	$if prealloc {
		mut style := ComputedProperties.new()
		first := &dom.StyleValue{ css_text: 'red' }
		second := &dom.StyleValue{ css_text: 'blue' }
		style.set_property_without_modifying_flags(.fill, first)
		// Freeze the published page. The next write allocates a copy in the
		// sampling arena while the store and both values remain outside it.
		_ = style.clone_raw_property_store()
		mut arena := platform.new_arena('animation property page lifetime test')
		defer { arena.release() }
		entry := arena.enter()
		style.set_property_without_modifying_flags(.fill, second)
		arena.leave(entry)
		page_index := (int(PropertyID.fill) - int(first_longhand_property_id())) / computed_property_page_size
		assert arena.contains(voidptr(style.property_store_.pages[page_index]))
		assert !arena.contains(voidptr(style))
		assert !arena.contains(voidptr(style.property_store_))
		assert !arena.contains(voidptr(second))
		assert !arena.contains(voidptr(second.css_text.str))
		retiring := RetiringAnimationSamples{ arena: arena }
		assert retiring.computed_references_arena(style)
	}
}

fn test_animation_retirement_releases_a_property_page_after_its_installed_style_replaces_it() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.oldest_live_paint_scene_generation = 2
		element := document.create_element('div') or { panic(err) }
		mut target := dom.AbstractElement.new(element, none)
		mut style := ComputedProperties.new()
		first := &dom.StyleValue{ css_text: 'red' }
		second := &dom.StyleValue{ css_text: 'blue' }
		style.set_property_without_modifying_flags(.fill, first)
		_ = style.clone_raw_property_store()
		mut arena := platform.new_arena('installed animation property page test')
		entry := arena.enter()
		style.set_property_without_modifying_flags(.fill, second)
		arena.leave(entry)
		target.set_computed_properties(&dom.CSSComputedProperties_{ css_handle: voidptr(style) })
		mut storage := AnimationSampleStorage{
			retiring: [RetiringAnimationSamples{
				arena:   arena
				targets: [AnimationSampleTarget{ element: target }]
			}]
		}
		defer { storage.dispose() }
		storage.retire_unreachable(document)
		assert storage.retiring.len == 1
		assert !storage.retiring[0].holders_cleared
		assert storage.spare.len == 0
		assert style.property(.fill, .no)?.css_text == 'blue'
		// A replacement page outside the sample arena removes the last reader.
		_ = style.clone_raw_property_store()
		style.set_property_without_modifying_flags(.fill, first)
		for _ in 0 .. animation_sample_inspection_interval {
			storage.retire_unreachable(document)
		}
		assert storage.retiring.len == 0
		assert storage.spare.len == 1
		assert style.property(.fill, .no)?.css_text == 'red'
	}
}
