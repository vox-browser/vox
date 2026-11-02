module css

import dom
import platform

fn test_animation_retirement_keeps_sample_arrays_in_a_persistent_typed_color() {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.oldest_live_paint_scene_generation = 2
		element := document.create_element('svg') or { panic(err) }
		mut target := dom.AbstractElement.new(element, none)
		mut style := ComputedProperties.new()
		mut arena := platform.new_arena('typed color payload lifetime')
		entry := arena.enter()
		color := parse_css_value_logic(.fill, 'rgb(10.5 20.25 30.75 / .25)') or { panic('color') }
		arena.leave(entry)
		// The wrapper and its opaque box can outlive the arrays borrowed by the
		// typed color. Neither address alone proves the payload is persistent.
		value := dom_style_value_from_value_logic(color)
		assert !arena.contains(voidptr(value))
		assert !arena.contains(value.css_value_handle)
		style.set_property_without_modifying_flags(.fill, value)
		target.set_computed_properties(&dom.CSSComputedProperties_{ css_handle: voidptr(style) })
		mut storage := AnimationSampleStorage{
			retiring: [RetiringAnimationSamples{
				arena: arena
				targets: [AnimationSampleTarget{ element: target }]
			}]
		}
		defer { storage.dispose() }
		storage.retire_unreachable(document)
		assert storage.retiring.len == 1
		assert !storage.retiring[0].holders_cleared
		assert style.typed_property_value(.fill)?.srgb_paint_components()? == [10.5 / 255, 20.25 / 255, 30.75 / 255, .25]!
		style.set_property_without_modifying_flags(.fill, dom_style_value_from_value_logic(
			parse_css_value_logic(.fill, 'red') or { panic('replacement') }))
		for _ in 0 .. animation_sample_inspection_interval {
			storage.retire_unreachable(document)
		}
		assert storage.retiring.len == 0
		assert storage.spare.len == 1
	}
}
