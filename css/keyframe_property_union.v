module css

import dom
import os
import platform
import sync.stdatomic

const retain_keyframe_id_union_map = os.getenv('VOX_RETAIN_KEYFRAME_ID_UNION_MAP') != ''
const keyframe_id_union_diagnostics = os.getenv('VOX_KEYFRAME_ID_UNION_DIAGNOSTICS') != ''

__global keyframe_id_union_reported stdatomic.AtomicVal[bool]

// Preserve the map union's insertion order: explicit properties first, then
// initial-value keys that were absent from that map. Presence, not the bool
// payload, decides whether an initial-value key participates.
fn keyframe_property_ids(keyframe ResolvedKeyFrame) []PropertyID {
	mut ids := []PropertyID{cap: keyframe.properties.len + keyframe.use_initial_properties.len}
	for property, _ in keyframe.properties { ids << property }
	for property, _ in keyframe.use_initial_properties {
		if property !in keyframe.properties { ids << property }
	}
	return ids
}

fn (s &StyleComputer) compute_keyframe_values(abstract_element dom.AbstractElement, keyframe ResolvedKeyFrame, computed_properties &ComputedProperties) map[PropertyID]&dom.StyleValue {
	if retain_keyframe_id_union_map {
		return s.compute_keyframe_values_with_id_map(abstract_element, keyframe, computed_properties)
	}
	if keyframe_id_union_diagnostics && (keyframe.properties.len > 0 || keyframe.use_initial_properties.len > 0)
		&& keyframe_id_union_reported.compare_and_swap(false, true) {
		eprintln('Vox keyframe property union: ordered vector')
	}
	mut result := map[PropertyID]&dom.StyleValue{}
	// Native recascades retain resolved values, but use the lookup tables only
	// synchronously. Animation-frame samples already have their bounded owner.
	retire_lookup := !s.sampling_animation_frame_ && s.document_.native_storage() != unsafe { nil }
		&& voidptr(platform.current_retained_arena()) == voidptr(s.document_.native_storage())
	workspace := if retire_lookup {
		platform.begin_thread_scratch('keyframe property lookup')
	} else {
		platform.ThreadScratchScope{}
	}
	defer { workspace.finish() }
	property_ids := keyframe_property_ids(keyframe)

	mapping_context := LogicalAliasMappingContext{
		writing_mode: computed_properties.writing_mode()
		direction:    computed_properties.direction()
	}
	mut specified_values := map[PropertyID]&dom.StyleValue{}
	for property_id in property_ids {
		mut value := keyframe.properties[property_id] or {
			computed_properties.property(property_id, .no) or { continue }
		}
		mut owned := if retire_lookup {
			platform.enter_retained_allocations()
		} else {
			platform.RetainedAllocationScope{}
		}
		if typed := typed_style_value_logic_from_dom(value) {
			if typed is UnresolvedStyleValue && typed.substitution_functions_presence.has_any() {
				value = resolve_unresolved_style_value_for_property(abstract_element, property_id, typed)
			}
		}
		value = with_keyword_values_resolved_boundary(abstract_element.element(), property_id, value)
		owned.finish()
		physical_property_id := map_logical_alias_to_physical_property(property_id, mapping_context)
		specified_values[physical_property_id] = value
	}

	// The specified overlay lives for this synchronous computation only. Borrow
	// it once instead of retaining a captured map and base style per property.
	property_source := ComputedPropertyValueSource{
		properties:       computed_properties
		specified_values: &specified_values
	}
	for property_id, value in specified_values {
		mut owned := if retire_lookup {
			platform.enter_retained_allocations()
		} else {
			platform.RetainedAllocationScope{}
		}
		if resolved := keyframe_value_without_context(property_id, value) {
			result[property_id] = resolved
			owned.finish()
			continue
		}
		mut computation_context := s.get_computation_context_for_property(property_id, computed_properties, abstract_element)
		computation_context.reset_viewport_metric_dependency_tracking()
		computed_value := compute_value_of_property_from_source(property_id, value,
			property_source, computation_context, 1.0)
		if computation_context.depends_on_viewport_metrics() {
			mut mutable_properties := unsafe { &ComputedProperties(computed_properties) }
			mutable_properties.set_depends_on_viewport_metrics()
			if property_affects_font_metrics(property_id) {
				mutable_properties.set_font_metrics_depend_on_viewport_metrics()
			}
		}
		result[property_id] = computed_value
		owned.finish()
	}
	return result
}
