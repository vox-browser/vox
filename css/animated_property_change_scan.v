module css

import dom
import os
import sync.stdatomic

const retain_separate_animation_change_scans = os.getenv('VOX_RETAIN_SEPARATE_ANIMATION_CHANGE_SCANS') != ''
const animation_change_scan_diagnostics = os.getenv('VOX_ANIMATION_CHANGE_SCAN_DIAGNOSTICS') != ''

__global animation_change_scan_reported stdatomic.AtomicVal[bool]

struct AnimatedPropertyChanges {
mut:
	invalidation    RequiredInvalidationAfterStyleChange
	compositor_only bool = true
	local_paint     bool = true
	background_only bool = true
}

fn (mut changes AnimatedPropertyChanges) note_changed_property(property PropertyID) {
	if !property_is_compositor_animated(property) { changes.compositor_only = false }
	if !property_is_local_paint_animated(property) {
		changes.local_paint = false
		changes.background_only = false
	} else if property != .background_color {
		changes.background_only = false
	}
}

fn scan_animated_property_changes(old_values map[PropertyID]&dom.StyleValue,
	new_values map[PropertyID]&dom.StyleValue) AnimatedPropertyChanges {
	mut changes := AnimatedPropertyChanges{}
	for property, old_value in old_values {
		longhand := computed_interpolation_is_longhand_property(property)
		if !longhand && !changes.compositor_only && !changes.local_paint { continue }
		new_value := if value := new_values[property] {
			?&dom.StyleValue(value)
		} else {
			?&dom.StyleValue(none)
		}
		invalidation := compute_property_invalidation(property, old_value, new_value)
		if longhand {
			changes.invalidation = required_invalidation_after_style_change_or(changes.invalidation, invalidation)
		}
		if !invalidation.is_none() { changes.note_changed_property(property) }
	}
	for property, new_value in new_values {
		if property in old_values { continue }
		if computed_interpolation_is_longhand_property(property) {
			invalidation := compute_property_invalidation(property, none, new_value)
			changes.invalidation = required_invalidation_after_style_change_or(changes.invalidation, invalidation)
		}
		// The original paint classifiers treat every added key as a change,
		// including keys ignored by longhand invalidation.
		changes.note_changed_property(property)
	}
	return changes
}

fn sampled_animation_property_changes(old_values map[PropertyID]&dom.StyleValue,
	computed &ComputedProperties) AnimatedPropertyChanges {
	if retain_separate_animation_change_scans {
		invalidation := animated_property_maps_invalidation(old_values, computed.animated_property_values())
		compositor := animated_changes_are_compositor_only(old_values, computed.animated_property_values())
		local, background := animated_changes_are_local_paint(old_values, computed.animated_property_values())
		return AnimatedPropertyChanges{
			invalidation:    invalidation
			compositor_only: compositor
			local_paint:     local
			background_only: background
		}
	}
	// Inspect one owned snapshot before any recascade or descendant update.
	// Public snapshot callers still receive independent maps, and no borrowed
	// sample/map reference escapes in the result.
	current_values := computed.animated_property_values()
	if animation_change_scan_diagnostics && (old_values.len > 0 || current_values.len > 0)
		&& animation_change_scan_reported.compare_and_swap(false, true) {
		eprintln('Vox animation property changes: single snapshot and scan')
	}
	return scan_animated_property_changes(old_values, current_values)
}
