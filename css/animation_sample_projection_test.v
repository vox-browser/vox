module css

import dom
import platform

fn test_animation_retirement_keeps_values_read_by_a_retained_density_projection() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.oldest_live_paint_scene_generation = 2
		element := document.create_element('div') or { panic(err) }
		mut target := dom.AbstractElement.new(element, none)
		mut source := ComputedProperties.new()
		mut projected := ComputedProperties.new()
		mut arena := platform.new_arena('animation density projection lifetime test')
		entry := arena.enter()
		sample := &dom.StyleValue{ css_text: 'rgb(12.5, 30.25, 90.75)' }
		projected.set_property_without_modifying_flags(.fill, sample)
		arena.leave(entry)
		source.device_layout_projection_ = &DeviceLayoutStyleProjection{
			scale:      2
			provenance: unsafe { nil }
			style:      projected
		}
		assert !arena.contains(voidptr(source))
		assert !arena.contains(voidptr(source.device_layout_projection_))
		assert !arena.contains(voidptr(projected))
		assert arena.contains(voidptr(sample))
		target.set_computed_properties(&dom.CSSComputedProperties_{ css_handle: voidptr(source) })
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
		assert projected.property(.fill, .no)?.css_text == 'rgb(12.5, 30.25, 90.75)'
		// Once the source replaces its cached projection and layout's old
		// generation is gone, the arena can be reused normally.
		source.device_layout_projection_ = unsafe { nil }
		for _ in 0 .. animation_sample_inspection_interval {
			storage.retire_unreachable(document)
		}
		assert storage.retiring.len == 0
		assert storage.spare.len == 1
	}
}
